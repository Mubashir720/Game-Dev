extends PlayerState

func physics_update(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length_squared() <= 0.01:
		if player and "state_machine" in player and player.state_machine:
			player.state_machine.transition_to("idle")
		return
		
	if player and player is CharacterBody3D:
		var dir := Vector3(input_dir.x, 0, input_dir.y).normalized()
		player.velocity = dir * player.speed
		player.move_and_slide()
