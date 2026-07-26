extends CharacterBody3D

const BeastFactory = preload("res://scenes/beasts/beast_factory.gd")
const BeastAnimator = preload("res://scenes/beasts/beast_animator.gd")

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

	var is_moving := false
	if is_instance_valid(owner_player) and not is_guard_mode:
		var dist = global_position.distance_to(owner_player.global_position)
		if dist > 2.5:
			var target_pos = owner_player.global_position
			var dir_2d = Vector3(target_pos.x - global_position.x, 0.0, target_pos.z - global_position.z).normalized()
			velocity.x = dir_2d.x * beast_speed
			velocity.z = dir_2d.z * beast_speed

			var look_target = Vector3(target_pos.x, global_position.y, target_pos.z)
			if global_position.distance_squared_to(look_target) > 0.01:
				look_at(look_target, Vector3.UP)
			is_moving = true
		else:
			velocity.x = move_toward(velocity.x, 0, beast_speed)
			velocity.z = move_toward(velocity.z, 0, beast_speed)
	else:
		velocity.x = move_toward(velocity.x, 0, beast_speed)
		velocity.z = move_toward(velocity.z, 0, beast_speed)

	# Solid 3D physics movement across terrain slopes, highlands, structures, and bridges
	move_and_slide()

	if visual_node and _animator:
		_animator.animate_beast(visual_node, beast_type, is_moving, delta)

func add_xp(amount: int) -> void:
	xp += amount
	if xp >= Constants.BEAST_EVOLUTION_XP and not is_evolved:
		evolve()

func evolve() -> void:
	is_evolved = true
	if visual_node:
		visual_node.queue_free()
	visual_node = BeastFactory.build_beast(beast_type, true)
	add_child(visual_node)
	EventBus.beast_evolved.emit(self, beast_type + "_evolved")
