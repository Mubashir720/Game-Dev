extends AbilityBase

## GDD §4 — Volley (active) / Eagle Eye (passive).
## Three arrows in a spread. +50% ranged damage at 6+ tiles.

const VOLLEY_RANGE_TILES := 10.0
const VOLLEY_ARROWS := 3

func _init() -> void:
	ability_name = "Volley"
	ability_blurb = "Three arrows at once — +50%% damage past 6 tiles"
	cooldown = Constants.ARCHER_VOLLEY_COOLDOWN

func _execute_ability(who: Node3D) -> void:
	var targets := enemies_within(who, VOLLEY_RANGE_TILES)
	if targets.is_empty():
		current_cooldown = cooldown * 0.35
		return
	spawn_pulse(who, 2.0, Color(0.55, 0.85, 0.45), 0.4)
	for i in range(mini(VOLLEY_ARROWS, targets.size() * VOLLEY_ARROWS)):
		var victim = targets[i % targets.size()]
		if not is_instance_valid(victim):
			continue
		var dist_tiles: float = who.global_position.distance_to(victim.global_position) / Constants.TILE_SIZE.x
		var dmg: float = Constants.BASIC_BOW_DAMAGE
		if dist_tiles >= Constants.ARCHER_EAGLE_EYE_RANGE_THRESHOLD:
			dmg *= 1.0 + Constants.ARCHER_EAGLE_EYE_DAMAGE_BUFF
		victim.take_damage(dmg * who.damage_multiplier, who, false)
