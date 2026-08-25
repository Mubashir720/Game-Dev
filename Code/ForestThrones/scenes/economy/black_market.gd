extends Node
class_name BlackMarket

## ═══════════════════════════════════════════════════════════════════════════════
##  BLACK MARKET  (GDD §3, §7)
##
##  A pop-up shop that appears at a random spot every 8 minutes, warns the map 60
##  seconds ahead, and stays open for 3 minutes selling the only advanced weapons
##  available mid-match. Prices scale with the buying squad's wealth (rich pay
##  +20%, poor pay −15%), applied per-vendor when it spawns.
##
##  It reuses the NpcVendor node for the actual buying — this manager only owns
##  the spawn/warn/despawn schedule and drops one vendor into the world at a time.
## ═══════════════════════════════════════════════════════════════════════════════

const NpcVendorScript = preload("res://scenes/economy/npc_vendor.gd")

var director = null
var world = null

var _next_spawn: float = Constants.TRAITOR_ACTIVATION_UNLOCK_TIME   # first at minute 8
var _warned := false
var _active_vendor = null
var _close_at: float = -1.0
var _rng := RandomNumberGenerator.new()


func setup(match_director, world_node) -> void:
	director = match_director
	world = world_node
	_rng.seed = 0xB1ACC


func _process(_delta: float) -> void:
	var t: float = GameManager.match_time

	if _active_vendor != null and t >= _close_at:
		_despawn()

	if _active_vendor != null:
		return

	if not _warned and t >= _next_spawn - Constants.BLACK_MARKET_WARNING_TIME:
		_warned = true
		EventBus.black_market_warning.emit()

	if t >= _next_spawn:
		_spawn()
		_next_spawn = t + Constants.BLACK_MARKET_SPAWN_INTERVAL
		_warned = false


func _spawn() -> void:
	if world == null:
		return
	var half: float = world.map_half_extent() if world.has_method("map_half_extent") else 180.0
	var pos := Vector3(_rng.randf_range(-half * 0.7, half * 0.7), 0.0,
			_rng.randf_range(-half * 0.7, half * 0.7))
	if world.has_method("on_ground"):
		pos = world.on_ground(pos, 0.1)

	var v = NpcVendorScript.new()
	v.name = "BlackMarket"
	v.is_black_market = true
	v.custom_catalog = NpcVendorScript.BLACK_MARKET_CATALOG
	v.price_mult = _wealth_price_mult()
	v.add_to_group("vendors")
	v.position = pos
	world.add_child(v)
	_active_vendor = v
	_close_at = GameManager.match_time + Constants.BLACK_MARKET_DURATION
	EventBus.black_market_spawned.emit(pos)


## Rich squads pay more, poor squads pay less (GDD §7), judged by the player
## squad's treasury so the price the player sees is fair to them.
func _wealth_price_mult() -> float:
	if director == null or director.player_squad == null:
		return 1.0
	var coins: int = director.player_squad.treasury
	if coins >= 120:
		return 1.20
	if coins <= 30:
		return 0.85
	return 1.0


func _despawn() -> void:
	if _active_vendor != null and is_instance_valid(_active_vendor):
		_active_vendor.remove_from_group("vendors")
		_active_vendor.queue_free()
	_active_vendor = null
	_close_at = -1.0
	EventBus.black_market_despawned.emit()
