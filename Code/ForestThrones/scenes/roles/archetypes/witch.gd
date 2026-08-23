extends AbilityBase

## GDD §4 — Hex (active) / Curse Ward (passive).
## Target gets -30% speed and -20% damage for 10s.

const HEX_RANGE_TILES := 8.0

func _init() -> void:
	ability_name = "Hex"
	ability_blurb = "-30%% speed, -20%% damage on the nearest enemy for 10s"
	cooldown = Constants.WITCH_HEX_COOLDOWN

func _execute_ability(who: Node3D) -> void:
	var targets := enemies_within(who, HEX_RANGE_TILES)
	if targets.is_empty():
		current_cooldown = cooldown * 0.25   # near-refund on a whiff
		return
	var victim = targets[0]
	spawn_pulse(victim, 2.0, Color(0.65, 0.35, 0.90), 1.2)
	victim.apply_buff(
		1.0 + Constants.WITCH_HEX_SPEED_DEBUFF,
		1.0 + Constants.WITCH_HEX_DAMAGE_DEBUFF,
		Constants.WITCH_HEX_DURATION)
