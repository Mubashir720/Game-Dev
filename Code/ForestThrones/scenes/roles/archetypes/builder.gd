extends AbilityBase

## GDD §4 — Rapid Build (active) / Blueprint (passive).
## Structures 3x faster. Here: immediately raise the squad's next structure,
## which is the same outcome against the build system that exists.

func _init() -> void:
	ability_name = "Rapid Build"
	ability_blurb = "Instantly raise your squad's next structure"
	cooldown = 30.0

func _execute_ability(who: Node3D) -> void:
	var brain = who.get("squad_brain") if "squad_brain" in who else null
	if brain == null or not brain.wants_builder():
		current_cooldown = cooldown * 0.25
		return
	spawn_pulse(who, 4.0, Color(0.95, 0.80, 0.30), 0.6)
	brain.contribute_build(who)
