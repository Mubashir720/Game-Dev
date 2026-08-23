extends AbilityBase

## GDD §4 — Tax Edict (active) / Stockpile (passive).
## All coin sources +50% for 20s. Works at 50% effectiveness even without a
## Queen, which is the whole point of the archetype: Queen-loss insurance.

const EDICT_BONUS_COINS := 6

func _init() -> void:
	ability_name = "Tax Edict"
	ability_blurb = "+50%% coin income for 20s — half-strength even with no Queen"
	cooldown = Constants.REGENT_TAX_EDICT_COOLDOWN

func _execute_ability(who: Node3D) -> void:
	spawn_pulse(who, 6.0, Color(0.95, 0.78, 0.25))
	var brain = who.get("squad_brain") if "squad_brain" in who else null
	if brain == null:
		return
	# Half value when the Queen is gone — GDD's insurance clause.
	var queen_alive: bool = brain.queen != null and is_instance_valid(brain.queen) and brain.queen.is_alive()
	var amount: int = EDICT_BONUS_COINS if queen_alive else int(EDICT_BONUS_COINS * 0.5)
	brain.add_coins(amount, "tax_edict")
