extends AbilityBase

## GDD §4 — Tame (active) / Pack Leader (passive).
## Tames the nearest wild beast; while a companion lives, +15% move speed.

const TAME_RADIUS_TILES := 6.0

var _companion: Node3D = null
var _speed_applied := false

func _init() -> void:
	ability_name = "Tame"
	ability_blurb = "Tame the nearest beast — its stats +30%%, your speed +15%%"
	cooldown = 25.0

func _execute_ability(who: Node3D) -> void:
	if _companion != null and is_instance_valid(_companion):
		return
	var nearest: Node3D = null
	var best := TAME_RADIUS_TILES * Constants.TILE_SIZE.x
	for b in who.get_tree().get_nodes_in_group("beasts"):
		if not is_instance_valid(b):
			continue
		var d: float = who.global_position.distance_to(b.global_position)
		if d < best:
			best = d
			nearest = b
	if nearest == null:
		return
	_companion = nearest
	nearest.set_meta("tamed", true)
	# Actually bind the beast to its owner so it follows and guards — beast_base
	# drives its behaviour off owner_player, not the meta flag.
	if "owner_player" in nearest:
		nearest.owner_player = who
	nearest.scale *= 1.0 + Constants.BEASTLORD_BEAST_STAT_BUFF * 0.3
	spawn_pulse(who, TAME_RADIUS_TILES, Color(0.55, 0.85, 0.40))
	EventBus.beast_tamed.emit(who, nearest)

func passive_tick(who: Node3D, _delta: float) -> void:
	var has_pet: bool = _companion != null and is_instance_valid(_companion)
	if has_pet and not _speed_applied:
		_speed_applied = true
		who.speed_multiplier *= 1.0 + Constants.BEASTLORD_PACK_LEADER_SPEED_BUFF
	elif not has_pet and _speed_applied:
		_speed_applied = false
		who.speed_multiplier /= 1.0 + Constants.BEASTLORD_PACK_LEADER_SPEED_BUFF
