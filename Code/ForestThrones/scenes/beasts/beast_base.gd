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
	collision_layer = 1 | 2
	collision_mask = 1 | 2 | 4 | 8 | 16
	visual_node = BeastFactory.build_beast(beast_type, is_evolved)
	add_child(visual_node)

func _physics_process(delta: float) -> void:
	# Beast hunger decay (GDD §11: -1 per 20 seconds)
	hunger = max(0.0, hunger - Constants.BEAST_HUNGER_DECAY_RATE * delta)

	var is_moving := false
	if is_instance_valid(owner_player) and not is_guard_mode:
		var dist = global_position.distance_to(owner_player.global_position)
		if dist > 2.5:
			var target_pos = owner_player.global_position
			var dir = (target_pos - global_position).normalized()
			velocity = dir * 5.0
			move_and_slide()
			look_at(Vector3(target_pos.x, global_position.y, target_pos.z), Vector3.UP)
			is_moving = true

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
