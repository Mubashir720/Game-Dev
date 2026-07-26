extends AbilityBase

func _init() -> void:
	ability_name = "Demolish"
	cooldown = Constants.SAPPER_DEMOLISH_COOLDOWN

func _execute_ability(caster: Node3D) -> void:
	print("Sapper activates Demolish (destroys structure in 3s)")
