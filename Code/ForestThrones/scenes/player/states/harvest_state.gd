extends PlayerState

func enter(_params: Dictionary = {}) -> void:
	if player and player is CharacterBody3D:
		player.velocity = Vector3.ZERO
