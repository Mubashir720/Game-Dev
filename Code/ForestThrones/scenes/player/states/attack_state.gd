extends PlayerState

var _weapon = null

func enter(params: Dictionary = {}) -> void:
	_weapon = params.get("weapon", null)
	if not _weapon:
		if player and "state_machine" in player and player.state_machine:
			player.state_machine.transition_to("idle")
		return

func exit() -> void:
	_weapon = null

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if player and player is CharacterBody3D:
		var dir := Vector3(input_dir.x, 0, input_dir.y).normalized()
		player.velocity = dir * player.speed * 0.4
		player.move_and_slide()
