extends CharacterBody3D

@export var fly_speed: float = 12.0

var pings_remaining: int = 3
var respawn_timer: float = Constants.DEFAULT_RESPAWN_TIME

func _ready() -> void:
	pings_remaining = 3
	_apply_ghost_material()

func _apply_ghost_material() -> void:
	# Ghost blue-white transparent look
	for child in get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.4, 0.7, 1.0, 0.3)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.5, 0.9)
			child.material_override = mat

func _physics_process(delta: float) -> void:
	respawn_timer -= delta
	if respawn_timer <= 0.0:
		_respawn_player()
		return
		
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = Vector3(input_dir.x, 0, input_dir.y).normalized() * fly_speed
	move_and_slide()

func place_ping(world_pos: Vector3) -> bool:
	if pings_remaining > 0:
		pings_remaining -= 1
		print("Ghost Scout placed ping at ", world_pos, ". Remaining: ", pings_remaining)
		return true
	return false

func perform_quick_respawn_tap() -> void:
	# Quick Respawn mini-game tap target hit -> reduce timer by 0.6s (up to 3s total)
	respawn_timer = max(0.0, respawn_timer - 0.60)

func _respawn_player() -> void:
	EventBus.player_respawned.emit(self)
	queue_free()
