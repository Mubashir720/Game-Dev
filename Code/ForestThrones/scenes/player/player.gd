extends Actor
class_name PlayerActor

## ═══════════════════════════════════════════════════════════════════════════════
##  PLAYER ACTOR — the local player's body.
##
##  Everything a body does (stats, inventory, HP states, movement, combat,
##  animation) lives in Actor. This class only turns INPUT into intent, so the
##  player and the 31 bots run identical simulation code and can never drift
##  out of sync with each other's rules.
##
##  Input sources, in priority order:
##    1. Virtual joystick from the mobile HUD (set_stick_input)
##    2. Keyboard / gamepad via the project's input actions
##
##  This is a mobile-first game, so the joystick is authoritative when active.
## ═══════════════════════════════════════════════════════════════════════════════

signal interacted(target)
signal build_mode_toggled(active: bool)

## Filled by the HUD's virtual joystick each frame. Zero when untouched.
var stick_input: Vector2 = Vector2.ZERO

var build_mode: bool = false
var interact_range: float = 2.6

var world = null
var director = null
var squad_brain = null

var _harvest_cooldown := 0.0
var _held_resource_id := -1


func _ready() -> void:
	super._ready()
	is_bot = false
	add_to_group("player")


func _physics_process(delta: float) -> void:
	if _harvest_cooldown > 0.0:
		_harvest_cooldown -= delta

	var dir := _read_input()
	# Movement is expressed in world space, but the camera is a fixed 45-degree
	# isometric view — so "up" on the stick must mean "away from the camera",
	# not "negative Z". Without this rotation, every input feels 45 degrees off.
	move_intent = _camera_relative(dir)

	is_blocking = Input.is_action_pressed("block")

	super._physics_process(delta)

	if Input.is_action_just_pressed("attack"):
		try_attack()
	if Input.is_action_just_pressed("interact"):
		try_interact()
	if Input.is_action_just_pressed("build_mode"):
		build_mode = not build_mode
		build_mode_toggled.emit(build_mode)


func _read_input() -> Vector2:
	if stick_input.length_squared() > 0.01:
		return stick_input
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Rotate stick input into the isometric camera's frame.
static func _camera_relative(v: Vector2) -> Vector3:
	if v.length_squared() < 0.0001:
		return Vector3.ZERO
	const ISO := 0.7071067811865476   # cos/sin of 45 degrees
	return Vector3(
		(v.x + v.y) * ISO,
		0.0,
		(v.y - v.x) * ISO)


func set_stick_input(v: Vector2) -> void:
	stick_input = v if v.length() <= 1.0 else v.normalized()


# ═══════════════════════════════════════════════════════════════════════════════
#  ACTIONS
# ═══════════════════════════════════════════════════════════════════════════════

## Swing at whatever hostile is closest and in range.
func try_attack() -> bool:
	if not can_attack():
		return false
	var target := _nearest_hostile(attack_range * 1.2)
	if target:
		return attack(target)
	# A swing at nothing still plays, so combat never feels unresponsive.
	if _animator:
		_animator.trigger_attack()
	return false


## Context action: harvest a node, revive a squadmate, or capture a downed enemy.
func try_interact() -> bool:
	var ally := _nearest_downed_ally(interact_range)
	if ally:
		ally.revive(35.0)
		interacted.emit(ally)
		return true

	if world and world.resource_field:
		var rid: int = world.resource_field.find_nearest(global_position, interact_range)
		if rid >= 0 and _harvest_cooldown <= 0.0:
			_harvest_cooldown = 0.45
			if _animator:
				_animator.trigger_harvest()
			world.resource_field.harvest(rid, self)
			interacted.emit(null)
			return true

	# Standing at your own base deposits everything you're carrying.
	if squad_brain and global_position.distance_to(squad_brain.base_position) < 3.5:
		var deposited := false
		for t in inventory.keys():
			var amount: int = inventory[t]
			if amount > 0:
				squad_brain.deposit(t, amount)
				inventory[t] = 0
				deposited = true
		if deposited:
			interacted.emit(squad_brain)
			return true

	return false


func _nearest_hostile(radius: float) -> Actor:
	if director == null:
		return null
	var best: Actor = null
	var best_d := radius * radius
	for a in director.actors:
		if a == self or not is_instance_valid(a) or not a.is_alive():
			continue
		if a.squad_id == squad_id and not a.traitor_activated:
			continue
		var d: float = global_position.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _nearest_downed_ally(radius: float) -> Actor:
	if director == null:
		return null
	for a in director.actors:
		if a == self or not is_instance_valid(a):
			continue
		if a.squad_id == squad_id and a.is_downed():
			if global_position.distance_to(a.global_position) <= radius:
				return a
	return null
