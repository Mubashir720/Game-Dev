extends AbilityBase

## GDD §4 — Brew (active) / Mend (passive).
## Brew restores 35 HP. Mend regenerates squadmates near the base at +2 HP/s.

const MEND_RADIUS_TILES := 5.0

var _mend_timer := 0.0

func _init() -> void:
	ability_name = "Brew"
	ability_blurb = "Heal 35 HP — and mend squadmates near your base"
	cooldown = 18.0

func _execute_ability(who: Node3D) -> void:
	spawn_pulse(who, 3.0, Color(0.40, 0.85, 0.45), 0.7)
	who.heal(Constants.HERBALIST_POTION_HEAL)
	# The lowest-health nearby ally gets it too — a solo heal on a support
	# archetype is not what GDD §4 describes.
	var allies := allies_within(who, MEND_RADIUS_TILES)
	if not allies.is_empty():
		allies.sort_custom(func(a, b): return a.hp < b.hp)
		allies[0].heal(Constants.HERBALIST_POTION_HEAL * 0.6)

func passive_tick(who: Node3D, delta: float) -> void:
	var brain = who.get("squad_brain") if "squad_brain" in who else null
	if brain == null:
		return
	# Mend only works near the squad's own base (GDD §4).
	if who.global_position.distance_to(brain.base_position) > MEND_RADIUS_TILES * Constants.TILE_SIZE.x:
		return
	_mend_timer += delta
	if _mend_timer < 1.0:
		return
	_mend_timer = 0.0
	who.heal(Constants.HERBALIST_MEND_REGEN_RATE)
	for a in allies_within(who, MEND_RADIUS_TILES):
		a.heal(Constants.HERBALIST_MEND_REGEN_RATE)
