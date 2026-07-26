extends "res://scenes/beasts/beast_base.gd"

func try_interact(player: Node3D) -> bool:
	complete_taming(player)
	return true

func complete_taming(player: Node3D) -> void:
	owner_player = player
	print("Stag tamed by player")
