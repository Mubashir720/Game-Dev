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
## Raised when the player USEs next to a downed enemy — HUD shows Capture/Execute.
signal capture_prompt(enemy)
## Raised when a carried prisoner is imprisoned — HUD shows prisoner options.
signal prison_prompt(prisoner)
## Raised when the player interacts next to an NPC vendor — HUD opens the shop.
signal shop_prompt(vendor)

var _prisoner: Actor = null
const CARRY_SPEED_MULT := 0.55

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
	# Carrying a prisoner: slowed, arms full (GDD §10 — 60% speed, cannot attack).
	if _prisoner != null:
		move_intent *= CARRY_SPEED_MULT

	is_blocking = Input.is_action_pressed("block")

	super._physics_process(delta)
	_update_carry()

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
	if _prisoner != null:
		return false      # arms full while carrying a prisoner
	if not can_attack():
		return false
	var target := _nearest_hostile(attack_range * 1.2)
	if target:
		return attack(target)
	# A swing at nothing still plays, so combat never feels unresponsive.
	if _animator:
		_animator.trigger_attack()
	return false


## Context action: deliver a prisoner, capture a downed enemy, harvest, revive, deposit.
func try_interact() -> bool:
	# Carrying a prisoner → imprison at your own cage or base.
	if _prisoner != null:
		if _can_imprison_here():
			imprison_prisoner()
		else:
			play_anim("interact")
		return true

	# A downed ENEMY within reach → let the HUD offer Capture or Execute.
	var downed_enemy := _nearest_downed_enemy(interact_range)
	if downed_enemy != null:
		capture_prompt.emit(downed_enemy)
		return true

	# Standing at an NPC vendor → open the shop (GDD §7).
	var vendor = _nearest_vendor()
	if vendor != null:
		shop_prompt.emit(vendor)
		return true

	var ally := _nearest_downed_ally(interact_range)
	if ally:
		ally.revive(35.0)
		play_anim("interact")
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
			play_anim("interact")
			interacted.emit(squad_brain)
			return true

	return false


# ═══════════════════════════════════════════════════════════════════════════════
#  HEAVY / CHARGE ATTACK  (GDD §9 — double-tap Attack)
# ═══════════════════════════════════════════════════════════════════════════════

## A committed charge attack: bigger damage + knockback, longer recovery. Bound
## to a double-tap of the Attack button on the HUD.
func try_heavy_attack() -> bool:
	if not can_attack():
		return false
	if _animator:
		if _animator.has_method("trigger_charge"):
			_animator.trigger_charge()
		else:
			_animator.trigger_attack()
	var target := _nearest_hostile(attack_range * 1.35)
	_attack_timer = attack_cooldown * 1.5
	if target == null:
		return false
	var dmg := attack_damage * damage_multiplier * 1.8 + 10.0   # charge bonus
	var friendly := target.squad_id == squad_id and not traitor_activated
	if target.squad_id == squad_id:
		dmg *= Constants.FRIENDLY_FIRE_DAMAGE_MODIFIER
	target.take_damage(dmg, self, friendly)
	# Knockback — the thing that makes a charge FEEL heavy.
	if target is CharacterBody3D:
		var kb := (target.global_position - global_position)
		kb.y = 0.0
		if kb.length() > 0.01:
			target.velocity += kb.normalized() * 7.0
	return true


# ═══════════════════════════════════════════════════════════════════════════════
#  BUILDING  (HUD build menu → place)
# ═══════════════════════════════════════════════════════════════════════════════

const BuildSystemScript = preload("res://scenes/structures/build_system.gd")
var _build_system = null

func _get_build_system():
	if _build_system == null or not is_instance_valid(_build_system):
		_build_system = BuildSystemScript.new()
		_build_system.name = "PlayerBuildSystem"
		add_child(_build_system)      # _ready() registers the structure catalogue
	return _build_system

## The structures the player can build, for the HUD menu: id, label, cost dict,
## and whether they can currently afford it.
func buildable_options() -> Array:
	var bs = _get_build_system()
	var out: Array = []
	for id in bs.structures_registry.keys():
		var data = bs.structures_registry[id]
		out.append({
			"id": id,
			"label": String(id).capitalize(),
			"cost": data.cost,
			"affordable": _can_afford(data.cost),
		})
	return out

func _can_afford(cost: Dictionary) -> bool:
	for t in cost.keys():
		if inventory.get(t, 0) < cost[t]:
			return false
	return true

## Place the chosen structure just in front of the player, on the grid.
func place_build(struct_id: String) -> bool:
	var bs = _get_build_system()
	var fwd := Vector3(sin(_facing), 0.0, cos(_facing))
	if fwd.length_squared() < 0.01:
		fwd = Vector3(0, 0, 1)
	var pos := global_position + fwd.normalized() * 2.4
	var ok: bool = bs.place_structure(pos, struct_id, self)
	if ok:
		play_anim("build")
	return ok


# ═══════════════════════════════════════════════════════════════════════════════
#  CAPTURE · IMPRISON · RANSOM · EXECUTE  (GDD §10)
# ═══════════════════════════════════════════════════════════════════════════════

func _nearest_downed_enemy(radius: float) -> Actor:
	if director == null:
		return null
	var best: Actor = null
	var best_d := radius * radius
	for a in director.actors:
		if a == self or not is_instance_valid(a):
			continue
		if a.squad_id == squad_id and not a.traitor_activated:
			continue
		if not a.is_downed() or a.is_captured or a.is_imprisoned:
			continue
		var d := global_position.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best

## Handcuff + sling a downed enemy onto the shoulder.
func capture_downed(enemy: Actor) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_downed():
		return false
	if _prisoner != null:
		return false
	_prisoner = enemy
	enemy.set_captured(self)
	set_carry_state(true, false)
	play_anim("interact")
	EventBus.player_handcuffed.emit(self, enemy)
	interacted.emit(enemy)
	return true

## Execute a downed enemy outright — loot + Forest Curse, no capture.
func execute_downed(enemy: Actor) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	play_anim("attack")
	EventBus.prisoner_executed.emit(self, enemy)
	EventBus.forest_curse_triggered.emit(squad_id, 2)
	enemy.kill(self)
	if squad_brain and squad_brain.has_method("add_coins"):
		squad_brain.add_coins(10, "execution_loot")
	return true

func _update_carry() -> void:
	if _prisoner == null:
		return
	if not is_instance_valid(_prisoner) or not _prisoner.is_captured:
		_prisoner = null
		set_carry_state(false, false)
		return
	_prisoner.global_position = global_position + Vector3(0.0, 1.05, 0.0)
	_prisoner.velocity = Vector3.ZERO

func _can_imprison_here() -> bool:
	return squad_brain != null and global_position.distance_to(squad_brain.base_position) < 4.5

## Lock the carried prisoner into your base cage; HUD then shows the options.
func imprison_prisoner() -> void:
	if _prisoner == null:
		return
	var p := _prisoner
	_prisoner = null
	set_carry_state(false, false)
	if squad_brain:
		p.global_position = squad_brain.base_position + Vector3(1.2, 0.0, 0.0)
	p.set_imprisoned_state()
	play_anim("interact")
	EventBus.player_imprisoned.emit(self, p, squad_brain)
	prison_prompt.emit(p)

## Driven by the HUD prisoner-options popup. Returns a short line describing the
## outcome so the HUD can report exactly what happened (GDD §10, the 5 options).
func prison_action(action: String, prisoner: Actor) -> String:
	if prisoner == null or not is_instance_valid(prisoner):
		return "No prisoner"
	match action:
		"execute":
			EventBus.prisoner_executed.emit(self, prisoner)
			EventBus.forest_curse_triggered.emit(squad_id, 2)
			prisoner.kill(self)
			if squad_brain and squad_brain.has_method("add_coins"):
				squad_brain.add_coins(10, "execution_loot")
			return "Executed — you carry a Blood Debt now"
		"ransom":
			var amount := 50
			EventBus.ransom_posted.emit(squad_id, prisoner, amount)
			if squad_brain and squad_brain.has_method("add_coins"):
				squad_brain.add_coins(amount, "ransom")
			prisoner.release_prisoner()
			return "Ransom paid (+%d coins)" % amount
		"labor":
			# Chain Gang: the prisoner works off resources for the captor squad.
			EventBus.forced_labor_started.emit(squad_id, prisoner, Constants.ResourceType.WOOD)
			if squad_brain:
				squad_brain.deposit(Constants.ResourceType.WOOD, 6)
				squad_brain.add_coins(15, "forced_labor")
			prisoner.release_prisoner()
			return "Chain Gang — +6 wood, +15 coins"
		"interrogate":
			# GDD §10 Tier 1: reveals the prisoner's squad coin total.
			interacted.emit(prisoner)
			var t := 0
			if director:
				var s = director.squad_by_id(prisoner.squad_id)
				if s != null:
					t = s.treasury
			return "Interrogation: their squad holds %d coins" % t
		"sell":
			# Sell to Black Market: flat 15 coins, no Curse; prisoner respawns elsewhere.
			if squad_brain and squad_brain.has_method("add_coins"):
				squad_brain.add_coins(Constants.BLACK_MARKET_PRISONER_SALE_PRICE, "black_market_sale")
			prisoner.release_prisoner()
			return "Sold to Black Market (+%d coins)" % Constants.BLACK_MARKET_PRISONER_SALE_PRICE
		"community_service":
			# Release with a Debtor's Mark (GDD §10): slower + visible for a while.
			prisoner.set_meta("debtor_mark", true)
			prisoner.speed_multiplier *= 0.85
			prisoner.release_prisoner()
			return "Released with a Debtor's Mark"
		"release":
			prisoner.release_prisoner()
			return "Prisoner released"
	return ""


## The nearest always-open NPC vendor within its interact range, or null.
func _nearest_vendor():
	var best = null
	var best_d := 1e20
	for v in get_tree().get_nodes_in_group("vendors"):
		if not is_instance_valid(v) or not v.has_method("in_range"):
			continue
		if not v.in_range(self):
			continue
		var d: float = global_position.distance_squared_to(v.global_position)
		if d < best_d:
			best_d = d
			best = v
	return best


## Buy an item from a vendor; the HUD shop panel calls this. Returns the vendor's
## {"ok", "reason"} result so the HUD can flash success or the failure reason.
func buy_from_vendor(vendor, item_id: String) -> Dictionary:
	if vendor == null or not is_instance_valid(vendor) or not vendor.has_method("buy"):
		return {"ok": false, "reason": "Vendor gone"}
	return vendor.buy(self, item_id)


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
