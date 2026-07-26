extends AbilityBase

func _init() -> void:
	ability_name = "Tame"
	cooldown = 30.0

func _execute_ability(caster: Node3D) -> void:
	print("Beastlord tames target beast (+30% stats)")
