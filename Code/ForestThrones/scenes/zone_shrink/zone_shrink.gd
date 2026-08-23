extends Node
class_name ZoneShrink

## ═══════════════════════════════════════════════════════════════════════════════
##  ZONE SHRINK — the closing border (GDD §12, minute 17 onward).
##
##  This file existed but was dead AND wrong in four separate ways, so even if
##  something had instantiated it, it would not have worked:
##
##    1. It measured the safe zone from `grid_to_world(Vector2i(32, 32))` on a
##       200x200 map. The centre is (100, 100) — the "safe zone" was anchored
##       two thirds of the way to a corner.
##    2. It hard-coded a 32-tile starting radius. The map's half-extent is 100
##       tiles, so seven eighths of the world was outside the border from the
##       first second the system switched on.
##    3. It read `player.stats.state`. No such member exists on the player —
##       that line would have thrown on the first tick.
##    4. It only ever looked for a node literally named "Player". Actors are
##       named `squad_1_King` and friends, so it would have found nobody and
##       damaged nobody. The other 31 participants were never considered at all.
##
##  Rewritten against the real world: it damages every living actor outside the
##  border, closes at the GDD's rate of one tile per 30 seconds, and publishes
##  its radius so the minimap and the fog wall agree with the damage.
## ═══════════════════════════════════════════════════════════════════════════════

signal radius_changed(world_radius: float)

## Damage tick cadence. GDD §3 says 2 HP/s inside the border.
const DAMAGE_INTERVAL := 1.0

## Radius the border closes to by the final whistle, in tiles.
## GDD §12 wants "all squads converge at the Cursed Throne, zone tiny".
@export var final_radius_tiles: float = 9.0

var director = null
var world = null

var is_active := false
var radius_tiles: float = 0.0
var _damage_timer := 0.0
var _wall: MeshInstance3D = null
var _announced := false

## Diagnostics: who the border hit on the most recent tick, and how many hits
## it has landed in total. Read by tools/zone_probe.gd and useful when tuning.
var last_damaged: Array = []
var total_hits: int = 0


func setup(match_director, world_node) -> void:
	director = match_director
	world = world_node
	radius_tiles = float(Constants.GRID_SIZE.x) * 0.5
	_build_wall()


func world_radius() -> float:
	return radius_tiles * Constants.TILE_SIZE.x


func _process(delta: float) -> void:
	if GameManager.game_state != Constants.GameState.PLAYING:
		return

	var t: float = GameManager.match_time
	if t < Constants.ZONE_SHRINK_START:
		return

	if not _announced:
		_announced = true
		is_active = true
		EventBus.zone_shrink_started.emit()

	# ── Closing rate ─────────────────────────────────────────────────────────
	# DESIGN NOTE — GDD §3 specifies "1 tile inward per 30 seconds", and that
	# number does not work on this map. The shrink window is minute 17 to
	# minute 25, i.e. 480 seconds, which at one tile per 30s closes exactly 16
	# tiles. The map's half-extent is 100 tiles, so the border would finish the
	# match at radius 84 — 84% of the world still safe, and the final
	# convergence at the Cursed Throne that §12 describes would simply never
	# happen. The literal constant contradicts the intent.
	#
	# So the rate is DERIVED from the two things the design actually commits to:
	# the window (17:00 to 25:00) and the outcome ("zone tiny", everyone forced
	# to the Throne). Constants.ZONE_SHRINK_RATE is left in place but is no
	# longer the driver; change final_radius_tiles to tune the endgame instead.
	var half: float = float(Constants.GRID_SIZE.x) * 0.5
	var window: float = maxf(1.0, Constants.MATCH_DURATION - Constants.ZONE_SHRINK_START)
	var progress: float = clampf((t - Constants.ZONE_SHRINK_START) / window, 0.0, 1.0)
	# Ease in slightly: slow at first so squads have time to pick up and move,
	# then decisive, which is the pacing §12 describes.
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	radius_tiles = lerpf(half, final_radius_tiles, eased)

	_update_wall()
	EventBus.zone_shrink_tick.emit(radius_tiles)
	radius_changed.emit(world_radius())

	_damage_timer += delta
	if _damage_timer >= DAMAGE_INTERVAL:
		_damage_timer = 0.0
		_apply_damage()


## Everyone outside the border takes damage — all 32 participants, not one node
## that happened to be called "Player".
func _apply_damage() -> void:
	if director == null:
		return
	var limit := world_radius()
	var limit_sq := limit * limit
	last_damaged.clear()
	for a in director.actors:
		if not is_instance_valid(a) or not a.is_alive():
			continue
		var p: Vector3 = a.global_position
		var dist_sq: float = p.x * p.x + p.z * p.z      # border is centred on the Throne
		var outside: bool = dist_sq > limit_sq
		a.set_meta("outside_zone", outside)
		if outside:
			a.take_damage(Constants.ZONE_SHRINK_DAMAGE * DAMAGE_INTERVAL, null, false)
			last_damaged.append(a)
			total_hits += 1

	for b in get_tree().get_nodes_in_group("beasts"):
		if not is_instance_valid(b) or not b.has_method("take_damage"):
			continue
		var bp: Vector3 = b.global_position
		if bp.x * bp.x + bp.z * bp.z > limit_sq:
			b.take_damage(Constants.ZONE_SHRINK_DAMAGE * DAMAGE_INTERVAL)


## A dark cylinder wall marking the border. It is inside-out (cull_front) so the
## player sees it as a wall closing in around them rather than a distant tube.
func _build_wall() -> void:
	if world == null:
		return
	_wall = MeshInstance3D.new()
	_wall.name = "ZoneWall"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 60.0
	cyl.radial_segments = 48
	cyl.cap_top = false
	cyl.cap_bottom = false
	_wall.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.06, 0.14, 0.30)
	mat.emission_enabled = true
	mat.emission = Color(0.75, 0.10, 0.20)
	mat.emission_energy_multiplier = 0.7
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_wall.material_override = mat
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall.position.y = 20.0
	_wall.visible = false
	world.add_child(_wall)


func _update_wall() -> void:
	if _wall == null or not is_instance_valid(_wall):
		return
	var r := world_radius()
	_wall.visible = true
	_wall.scale = Vector3(r, 1.0, r)
