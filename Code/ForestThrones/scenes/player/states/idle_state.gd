extends PlayerState

func enter(_params: Dictionary = {}) -> void:
	if player and player is CharacterBody3D:
		player.velocity = Vector3.ZERO

func physics_update(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length_squared() > 0.01:
		if player and "state_machine" in player and player.state_machine:
			player.state_machine.transition_to("walk")
