extends AbilityBase

## GDD §4 — Shield Wall (active) / Taunt (passive).
## Blocks 60% of incoming melee. Every 40s, forces the nearest enemy to attack
## the Guardian for 5s — which is what makes the role a real screen.

const SHIELD_DURATION := 6.0
const TAUNT_RANGE_TILES := 8.0

var _taunt_timer := 0.0

func _init() -> void:
	ability_name = "Shield Wall"
	ability_blurb = "Block 60%% of incoming melee for 6s"
	cooldown = 20.0

func _execute_ability(who: Node3D) -> void:
	spawn_pulse(who, 2.5, Color(0.45, 0.70, 0.95), 0.6)
	who.is_blocking = true
	who.get_tree().create_timer(SHIELD_DURATION).timeout.connect(func():
		if is_instance_valid(who):
			who.is_blocking = false)

func passive_tick(who: Node3D, delta: float) -> void:
	_taunt_timer += delta
	if _taunt_timer < Constants.GUARDIAN_TAUNT_INTERVAL:
		return
	_taunt_timer = 0.0
	var targets := enemies_within(who, TAUNT_RANGE_TILES)
	if targets.is_empty():
		return
	var victim = targets[0]
	# Bots read this and re-target; it expires on its own.
	victim.set_meta("taunted_by", who)
	victim.set_meta("taunt_until", GameManager.match_time + Constants.GUARDIAN_TAUNT_DURATION)
	spawn_pulse(who, 3.0, Color(0.95, 0.70, 0.30), 0.5)
