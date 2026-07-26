extends AbilityBase

func _init() -> void:
	ability_name = "Volley"
	cooldown = Constants.ARCHER_VOLLEY_COOLDOWN

func _execute_ability(caster: Node3D) -> void:
	print("Archer fires Volley (3 arrows spread)")
