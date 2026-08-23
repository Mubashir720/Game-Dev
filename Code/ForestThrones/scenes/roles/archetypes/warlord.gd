extends AbilityBase

## GDD §4 — Rally Cry (active) / War Banner (passive).
## Squad within 10 tiles gets +20% speed and damage for 8s. 45s cooldown.

func _init() -> void:
	ability_name = "Rally Cry"
	ability_blurb = "+20%% speed and damage to the squad within 10 tiles"
	cooldown = Constants.WARLORD_RALLY_COOLDOWN

func _execute_ability(who: Node3D) -> void:
	spawn_pulse(who, Constants.WARLORD_RALLY_RADIUS, Color(1.0, 0.84, 0.20))
	var buffed := 1
	who.apply_buff(
		1.0 + Constants.WARLORD_RALLY_SPEED_BUFF,
		1.0 + Constants.WARLORD_RALLY_DAMAGE_BUFF,
		Constants.WARLORD_RALLY_DURATION)
	for a in allies_within(who, Constants.WARLORD_RALLY_RADIUS):
		a.apply_buff(
			1.0 + Constants.WARLORD_RALLY_SPEED_BUFF,
			1.0 + Constants.WARLORD_RALLY_DAMAGE_BUFF,
			Constants.WARLORD_RALLY_DURATION)
		buffed += 1
	EventBus.legendary_moment.emit("Rally Cry (%d rallied)" % buffed, [who])
