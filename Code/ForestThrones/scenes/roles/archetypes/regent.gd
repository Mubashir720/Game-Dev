extends AbilityBase

func _init() -> void:
	ability_name = "Tax Edict"
	cooldown = Constants.REGENT_TAX_EDICT_COOLDOWN

func _execute_ability(caster: Node3D) -> void:
	print("Regent activates Tax Edict (+50% coins for 20s)")
	EventBus.coins_earned.emit("squad_1", 10, "tax_edict")
