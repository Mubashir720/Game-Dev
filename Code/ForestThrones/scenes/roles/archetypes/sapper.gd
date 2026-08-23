extends AbilityBase

## GDD §4 — Demolish (active) / Trap Disarm (passive).
## Destroys any structure in 3 seconds — the answer to a turtled base.

const DEMOLISH_RANGE_TILES := 3.0

func _init() -> void:
	ability_name = "Demolish"
	ability_blurb = "Destroy the nearest enemy structure"
	cooldown = Constants.SAPPER_DEMOLISH_COOLDOWN

func _execute_ability(who: Node3D) -> void:
	var range_world: float = DEMOLISH_RANGE_TILES * Constants.TILE_SIZE.x
	var best: Node3D = null
	var best_d := range_world
	var d = _director(who)
	if d == null:
		return
	for s in d.squads:
		if s.squad_id == who.squad_id:
			continue
		for st in s.structures:
			if not is_instance_valid(st):
				continue
			var dist: float = who.global_position.distance_to(st.global_position)
			if dist < best_d:
				best_d = dist
				best = st
	if best == null:
		current_cooldown = cooldown * 0.25
		return
	spawn_pulse(who, DEMOLISH_RANGE_TILES, Color(0.95, 0.45, 0.15), 0.5)
	var tw := who.create_tween()
	tw.tween_property(best, "scale", Vector3(0.01, 0.01, 0.01), 0.45)
	tw.tween_callback(best.queue_free)
