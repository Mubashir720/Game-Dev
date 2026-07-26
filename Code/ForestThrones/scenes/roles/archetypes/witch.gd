extends AbilityBase

func _init() -> void:
	ability_name = "Hex"
	cooldown = Constants.WITCH_HEX_COOLDOWN

func _execute_ability(caster: Node3D) -> void:
	print("Witch casts Hex (-30% speed & -20% damage on target)")
