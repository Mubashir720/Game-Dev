extends AbilityBase

func _init() -> void:
	ability_name = "Shield Wall"
	cooldown = 30.0

func _execute_ability(caster: Node3D) -> void:
	print("Guardian activates Shield Wall (block 60% melee)")
