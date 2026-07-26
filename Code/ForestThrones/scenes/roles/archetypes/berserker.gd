extends AbilityBase

func _init() -> void:
	ability_name = "Frenzy"
	cooldown = Constants.BERSERKER_FRENZY_COOLDOWN

func _execute_ability(caster: Node3D) -> void:
	print("Berserker enters Frenzy (6s double attack speed)")
