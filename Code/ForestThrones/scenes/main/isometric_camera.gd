extends Camera3D

## ═══════════════════════════════════════════════════════════════════════════════
##  ISOMETRIC MATCH CAMERA
##
##  Fixed-angle orthographic follow camera with smoothed tracking, screen shake,
##  and a distance cut sized to what the player can actually see.
## ═══════════════════════════════════════════════════════════════════════════════

@export var target_node: Node3D = null
@export var follow_speed: float = 6.0
@export var iso_offset: Vector3 = Vector3(12.0, 13.0, 12.0)
@export var default_ortho_size: float = 18.0

## Hard draw-distance cut. An orthographic frustum is a BOX, so a 200-unit far
## plane dragged 200 units of forest into every single frame no matter how small
## the visible area was — it was the single largest source of draw calls.
## Distance fog is tuned to close over well before this, so the cut is invisible.
## See scenes/main/environment.tres.
@export var far_plane: float = 115.0

## Zoom limits for pinch-zoom on touch devices.
@export var min_ortho_size: float = 12.0
@export var max_ortho_size: float = 26.0

var _shake_intensity: float = 0.0
var _shake_decay: float = 5.0
var _noise := FastNoiseLite.new()
var _shake_time: float = 0.0
var _target_size: float = 18.0


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = default_ortho_size
	_target_size = default_ortho_size
	near = 0.5
	far = far_plane

	_noise.seed = randi()
	_noise.frequency = 0.2


func _process(delta: float) -> void:
	if target_node and is_instance_valid(target_node):
		var target_pos: Vector3 = target_node.global_position + iso_offset
		global_position = global_position.lerp(target_pos, follow_speed * delta)
		look_at(target_node.global_position, Vector3.UP)

	if abs(size - _target_size) > 0.01:
		size = lerp(size, _target_size, 8.0 * delta)

	if _shake_intensity > 0.0:
		_shake_time += delta * 30.0
		h_offset = _noise.get_noise_2d(_shake_time, 0.0) * _shake_intensity
		v_offset = _noise.get_noise_2d(0.0, _shake_time) * _shake_intensity
		_shake_intensity = max(0.0, _shake_intensity - _shake_decay * delta)
	else:
		h_offset = 0.0
		v_offset = 0.0


func add_shake(intensity: float) -> void:
	_shake_intensity = max(_shake_intensity, intensity)


func set_zoom(ortho_size: float) -> void:
	_target_size = clamp(ortho_size, min_ortho_size, max_ortho_size)


func zoom_by(delta_size: float) -> void:
	set_zoom(_target_size + delta_size)


func snap_to_target() -> void:
	if target_node and is_instance_valid(target_node):
		global_position = target_node.global_position + iso_offset
		look_at(target_node.global_position, Vector3.UP)
