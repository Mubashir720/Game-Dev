extends Camera3D

@export var target_node: Node3D = null
@export var follow_speed: float = 6.0
@export var iso_offset: Vector3 = Vector3(12.0, 13.0, 12.0)
@export var default_ortho_size: float = 18.0

var _shake_intensity: float = 0.0
var _shake_decay: float = 5.0
var _noise := FastNoiseLite.new()
var _shake_time: float = 0.0

func _ready() -> void:
	# 1 = Orthographic projection in Godot 4 Camera3D
	projection = 1
	size = default_ortho_size
	near = 1.0
	far = 200.0
	
	_noise.seed = randi()
	_noise.frequency = 0.2

func _process(delta: float) -> void:
	if target_node and is_instance_valid(target_node):
		var target_pos = target_node.global_position + iso_offset
		global_position = global_position.lerp(target_pos, follow_speed * delta)
		look_at(target_node.global_position, Vector3.UP)
		
	if _shake_intensity > 0.0:
		_shake_time += delta * 30.0
		var offset_x = _noise.get_noise_2d(_shake_time, 0.0) * _shake_intensity
		var offset_y = _noise.get_noise_2d(0.0, _shake_time) * _shake_intensity
		h_offset = offset_x
		v_offset = offset_y
		_shake_intensity = max(0.0, _shake_intensity - _shake_decay * delta)
	else:
		h_offset = 0.0
		v_offset = 0.0

func add_shake(intensity: float) -> void:
	_shake_intensity = max(_shake_intensity, intensity)
