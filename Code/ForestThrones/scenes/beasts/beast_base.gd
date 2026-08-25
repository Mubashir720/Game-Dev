extends CharacterBody3D

const BeastFactory = preload("res://scenes/beasts/beast_factory.gd")
const BeastAnimator = preload("res://scenes/beasts/beast_animator.gd")
const RiggedBeast = preload("res://scenes/beasts/rigged_beast.gd")

## Every species now uses a real animated model (see rigged_beast.gd): Fox for
## wolf/boar, Horse for stag, Stork for raven.
const RIGGED_SPECIES := ["wolf", "boar", "stag", "raven"]
var _rigged = null

@export var beast_type: String = "wolf"
@export var beast_name: String = "Shadow"

var owner_player: Node3D = null
var hunger: float = 100.0
var xp: int = 0
var is_evolved: bool = false
var is_guard_mode: bool = false
var visual_node: Node3D = null
var _animator = BeastAnimator.new()

func _ready() -> void:
	# Layer 1 = World Environment, Props, Structures, Buildings
	# Layer 2 = Entities (Player / NPCs / Beasts)
	collision_layer = 1 | 2
	collision_mask = 1 | 2 | 4 | 8 | 16
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 0.35

	# Fallback collision shape if instanced programmatically
	if get_node_or_null("CollisionShape3D") == null:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new(); box.size = Vector3(0.8, 0.8, 1.2)
		col.shape = box; col.position = Vector3(0, 0.4, 0)
		add_child(col)

	add_to_group("beasts")
	if beast_type in RIGGED_SPECIES:
		var rb = RiggedBeast.new()
		rb.setup(beast_type, is_evolved)
		visual_node = rb
		_rigged = rb
	else:
		visual_node = BeastFactory.build_beast(beast_type, is_evolved)
	add_child(visual_node)

func _physics_process(delta: float) -> void:
	# Beast hunger decay (GDD §11: -1 per 20 seconds)
	hunger = max(0.0, hunger - Constants.BEAST_HUNGER_DECAY_RATE * delta)

	var beast_speed := 5.5
	# Water Wading Speed Modifier for Beasts
	if global_position.y < -0.15:
		beast_speed *= 0.60 # −40% speed penalty when wading in deep water

	# Apply gravity for smooth slope & highland terrain alignment
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	else:
		velocity.y = -0.10

	if _attack_timer > 0.0:
		_attack_timer -= delta

	var is_moving := false
	var move_to := Vector3.ZERO
	var have_move := false

	if is_instance_valid(owner_player):
		# A tamed beast guards its owner: it hunts whoever is hostile to the owner
		# and bites them (GDD §11 — "attacks anyone who hits them"). With no threat
		# it heels at the owner's side, or patrols the base in Guard Mode.
		var foe = _nearest_owner_enemy()
		if foe != null:
			var fd: float = global_position.distance_to(foe.global_position)
			if fd <= ATTACK_RANGE:
				velocity.x = move_toward(velocity.x, 0, beast_speed)
				velocity.z = move_toward(velocity.z, 0, beast_speed)
				_look_at_flat(foe.global_position)
				_bite(foe)
			else:
				move_to = foe.global_position; have_move = true
		elif not is_guard_mode and global_position.distance_to(owner_player.global_position) > 2.5:
			move_to = owner_player.global_position; have_move = true
		elif is_guard_mode:
			var gp: Vector3 = get_meta("guard_pos", owner_player.global_position)
			if global_position.distance_to(gp) > 3.0:
				move_to = gp; have_move = true
	# Untamed beasts just idle in place (wild patrol is out of scope here).

	if have_move:
		var d2 := Vector3(move_to.x - global_position.x, 0.0, move_to.z - global_position.z)
		if d2.length() > 0.05:
			d2 = d2.normalized()
			velocity.x = d2.x * beast_speed
			velocity.z = d2.z * beast_speed
			_look_at_flat(move_to)
			is_moving = true
	elif not (is_instance_valid(owner_player) and _nearest_owner_enemy() != null):
		velocity.x = move_toward(velocity.x, 0, beast_speed)
		velocity.z = move_toward(velocity.z, 0, beast_speed)

	# Solid 3D physics movement across terrain slopes, highlands, structures, and bridges
	move_and_slide()

	if _rigged != null:
		_rigged.animate(is_moving)
	elif visual_node and _animator:
		_animator.animate_beast(visual_node, beast_type, is_moving, delta)


const ATTACK_RANGE := 1.8
const AGGRO_RADIUS := 11.0
var _attack_timer: float = 0.0


func set_guard_mode(on: bool, guard_pos: Vector3 = Vector3.ZERO) -> void:
	is_guard_mode = on
	if on:
		set_meta("guard_pos", guard_pos if guard_pos != Vector3.ZERO else global_position)


func _look_at_flat(p: Vector3) -> void:
	var t := Vector3(p.x, global_position.y, p.z)
	if global_position.distance_squared_to(t) > 0.01:
		look_at(t, Vector3.UP)


## The closest actor hostile to the beast's owner, within aggro range of the beast.
func _nearest_owner_enemy():
	if not is_instance_valid(owner_player) or not ("squad_id" in owner_player):
		return null
	var my_squad = owner_player.squad_id
	var best = null
	var best_d := AGGRO_RADIUS * AGGRO_RADIUS
	for a in get_tree().get_nodes_in_group("actors"):
		if not is_instance_valid(a) or a == owner_player:
			continue
		if not a.has_method("is_alive") or not a.is_alive():
			continue
		if a.squad_id == my_squad:
			continue
		var d: float = global_position.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _bite(foe) -> void:
	if _attack_timer > 0.0 or foe == null or not is_instance_valid(foe):
		return
	_attack_timer = Constants.BEAST_ATTACK_COOLDOWN
	if _rigged != null:
		_rigged.trigger_attack()
	elif _animator and _animator.has_method("trigger_beast_attack"):
		_animator.trigger_beast_attack()
	var dmg: float = Constants.BEAST_WOLF_DAMAGE
	if is_evolved:
		dmg *= 1.4
	foe.take_damage(dmg, owner_player, false)
	add_xp(1)

func add_xp(amount: int) -> void:
	xp += amount
	if xp >= Constants.BEAST_EVOLUTION_XP and not is_evolved:
		evolve()

func evolve() -> void:
	is_evolved = true
	if visual_node:
		visual_node.queue_free()
	_rigged = null
	if beast_type in RIGGED_SPECIES:
		var rb = RiggedBeast.new()
		rb.setup(beast_type, true)
		visual_node = rb
		_rigged = rb
	else:
		visual_node = BeastFactory.build_beast(beast_type, true)
	add_child(visual_node)
	EventBus.beast_evolved.emit(self, beast_type + "_evolved")
