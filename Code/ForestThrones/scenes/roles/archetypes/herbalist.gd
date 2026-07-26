extends AbilityBase

const BREW_HERB_COST := 2
const BREW_HEAL_AMOUNT := 35.0
const MEND_RADIUS_TILES := 5.0
const MEND_REGEN_RATE := 2.0

var _mend_timer := 0.0

func _init() -> void:
	ability_name = "Brew"
	cooldown = 0.0

func _execute_ability(caster: Node3D) -> void:
	if caster and caster.has_method("heal"):
		caster.heal(BREW_HEAL_AMOUNT)

func passive_tick(caster: Node3D, delta: float) -> void:
	_mend_timer += delta
	if _mend_timer >= 1.0:
		_mend_timer = 0.0
		if caster and caster.has_method("heal"):
			caster.heal(MEND_REGEN_RATE)
