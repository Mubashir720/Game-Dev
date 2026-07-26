extends "res://scenes/beasts/beast_base.gd"

func check_taming_requirements(player: Node3D) -> bool:
	return true

func deduct_taming_requirements(player: Node3D) -> void:
	pass

func try_interact(player: Node3D) -> bool:
	_launch_scout(player)
	return true

func _launch_scout(player: Node3D) -> void:
	print("Raven launched scout flight for player")
