extends AbilityBase

## GDD §4 — Overclock (active) / Trap Master (passive).
## Squad builds take 50% time for 15s. Here that means the squad's next
## structure is paid for at half cost, which is the same tempo gain expressed
## against the build system that actually exists.

func _init() -> void:
	ability_name = "Overclock"
	ability_blurb = "Squad builds at half cost for 15s"
	cooldown = Constants.ENGINEER_OVERCLOCK_COOLDOWN

func _execute_ability(who: Node3D) -> void:
	spawn_pulse(who, 5.0, Color(0.45, 0.80, 0.95))
	var brain = who.get("squad_brain") if "squad_brain" in who else null
	if brain == null:
		return
	brain.set_meta("overclock_until",
		GameManager.match_time + Constants.ENGINEER_OVERCLOCK_DURATION)
	# Refund half the next structure immediately as materials on hand.
	brain.deposit(Constants.ResourceType.WOOD, 6)
	brain.deposit(Constants.ResourceType.STONE, 3)
