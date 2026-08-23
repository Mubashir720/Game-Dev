extends AbilityBase

## GDD §4 — Frenzy (active) / Bloodlust (passive).
## 6s of double attack speed. +5% damage per kill, stacking to +40%.

var _stacks := 0

func _init() -> void:
	ability_name = "Frenzy"
	ability_blurb = "Double attack speed for 6s, knockback immune"
	cooldown = Constants.BERSERKER_FRENZY_COOLDOWN

func _execute_ability(who: Node3D) -> void:
	spawn_pulse(who, 3.0, Color(0.90, 0.25, 0.20), 0.8)
	var original: float = who.attack_cooldown
	who.attack_cooldown = original * 0.5
	who.apply_buff(1.10, 1.0, Constants.BERSERKER_FRENZY_DURATION)
	who.get_tree().create_timer(Constants.BERSERKER_FRENZY_DURATION).timeout.connect(func():
		if is_instance_valid(who):
			who.attack_cooldown = original)

func on_kill(who: Node3D, _victim: Node3D) -> void:
	var max_stacks := int(Constants.BERSERKER_BLOODLUST_MAX / Constants.BERSERKER_BLOODLUST_PER_KILL)
	if _stacks >= max_stacks:
		return
	_stacks += 1
	who.damage_multiplier += Constants.BERSERKER_BLOODLUST_PER_KILL
