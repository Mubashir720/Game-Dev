extends PlayerState

func physics_update(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if player and player is CharacterBody3D:
		var dir := Vector3(input_dir.x, 0, input_dir.y).normalized()
		player.velocity = dir * Constants.DOWNED_CRAWL_SPEED * 0.05
		player.move_and_slide()
