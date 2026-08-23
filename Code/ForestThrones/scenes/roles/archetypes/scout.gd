extends AbilityBase

## GDD §4 — Flare (active) / Stealth (passive).
## Reveals every enemy within 20 tiles on the minimap for 30s.

func _init() -> void:
	ability_name = "Flare"
	ability_blurb = "Reveal all enemies within 20 tiles for 30s"
	cooldown = 45.0

func _execute_ability(who: Node3D) -> void:
	spawn_pulse(who, Constants.SCOUT_FLARE_RADIUS, Color(0.40, 0.85, 0.55), 1.3)
	var minimap = who.get_tree().root.find_child("Minimap", true, false)
	var revealed := 0
	for e in enemies_within(who, Constants.SCOUT_FLARE_RADIUS):
		if minimap and minimap.has_method("reveal"):
			minimap.reveal(e, Constants.SCOUT_FLARE_DURATION)
		revealed += 1
	if revealed > 0:
		EventBus.legendary_moment.emit("Flare — %d enemies revealed" % revealed, [who])
