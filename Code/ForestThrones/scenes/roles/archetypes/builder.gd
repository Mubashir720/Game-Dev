extends AbilityBase

func _init() -> void:
	ability_name = "Rapid Build"
	cooldown = 45.0

func _execute_ability(caster: Node3D) -> void:
	print("Builder activates Rapid Build (3x build speed)")
