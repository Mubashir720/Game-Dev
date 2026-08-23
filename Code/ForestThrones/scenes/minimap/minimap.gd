extends Control
class_name Minimap

## ═══════════════════════════════════════════════════════════════════════════════
##  MINIMAP — the map you actually play from.
##
##  GDD §3 and §11 hang a lot of mechanics off this one widget: the Hut carrier
##  is "visible on ALL minimaps", executing a prisoner puts your squad's exact
##  position on all 32 minimaps, Scout's Flare reveals enemies on it, the Black
##  Market warns on it, and the shrinking border is read from it. If it does not
##  work, several of the game's headline systems have nowhere to display.
##
##  It renders once to a texture at load — biome colours, rivers, roads baked
##  from the generator's own zone field, so the minimap can never disagree with
##  the world — and then draws only the moving parts every frame.
## ═══════════════════════════════════════════════════════════════════════════════

const UITheme = preload("res://scenes/hud/ui_theme.gd")

## Resolution of the baked terrain image. 200 cells at 1 px each is plenty for a
## widget a couple of hundred pixels wide, and costs 160 KB once.
const BAKE_SIZE := 200

@export var map_size: Vector2 = Vector2(228, 228)
## Reveal radius in world units for enemies not otherwise revealed.
@export var passive_reveal: float = 26.0

var director = null
var world = null

var _terrain: ImageTexture = null
var _half_world: float = 200.0
var _revealed_until := {}      # actor -> unix-ish time in match seconds


func _ready() -> void:
	custom_minimum_size = map_size
	size = map_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind_match(match_director, world_node) -> void:
	director = match_director
	world = world_node
	_half_world = world.map_half_extent()
	_bake_terrain()
	queue_redraw()


## Reveal an actor on the minimap for `duration` seconds. Used by Scout Flare,
## the Hut carrier beacon, Blood Debt marking and Watchtower pings (GDD §11).
func reveal(actor, duration: float) -> void:
	_revealed_until[actor] = GameManager.match_time + duration


# ═══════════════════════════════════════════════════════════════════════════════
#  TERRAIN BAKE
# ═══════════════════════════════════════════════════════════════════════════════

func _bake_terrain() -> void:
	if world == null or world.map_generator == null:
		return
	var mg = world.map_generator
	var img := Image.create(BAKE_SIZE, BAKE_SIZE, false, Image.FORMAT_RGBA8)
	var grid: Vector2i = Constants.GRID_SIZE
	var step_x: float = float(grid.x) / float(BAKE_SIZE)
	var step_y: float = float(grid.y) / float(BAKE_SIZE)

	for py in range(BAKE_SIZE):
		for px in range(BAKE_SIZE):
			var gx := int(float(px) * step_x)
			var gy := int(float(py) * step_y)
			var zone: int = mg.zone_at(gx, gy)
			var c := _zone_color(zone)
			if mg.is_road(gx, gy) and zone != Constants.ZoneType.RIVERBED:
				c = c.lerp(Color(0.42, 0.33, 0.22), 0.55)
			# Shade by elevation so highlands and river trenches read as terrain
			# rather than as flat colour blobs.
			var h: float = mg.height_at(gx, gy)
			c = c.lightened(clampf(h * 0.10, -0.2, 0.22)) if h > 0.0 else c.darkened(clampf(-h * 0.28, 0.0, 0.28))
			img.set_pixel(px, py, c)

	_terrain = ImageTexture.create_from_image(img)


static func _zone_color(zone: int) -> Color:
	match zone:
		Constants.ZoneType.DENSE_FOREST:    return Color(0.12, 0.24, 0.13)
		Constants.ZoneType.OPEN_CLEARING:   return Color(0.24, 0.38, 0.18)
		Constants.ZoneType.ROCKY_HIGHLANDS: return Color(0.34, 0.33, 0.30)
		Constants.ZoneType.SWAMP:           return Color(0.16, 0.22, 0.14)
		Constants.ZoneType.RIVERBED:        return Color(0.13, 0.30, 0.46)
		Constants.ZoneType.CURSED_THRONE:   return Color(0.28, 0.14, 0.36)
		Constants.ZoneType.DROP_ZONE:       return Color(0.19, 0.30, 0.16)
	return Color(0.14, 0.22, 0.14)


# ═══════════════════════════════════════════════════════════════════════════════
#  DRAW
# ═══════════════════════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	if director != null:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)

	# Frame
	draw_rect(r, Color(0.03, 0.05, 0.07, 0.92), true)
	if _terrain:
		draw_texture_rect(_terrain, r.grow(-3.0), false, Color(1, 1, 1, 0.95))
	draw_rect(r, UITheme.GOLD_DIM, false, 2.0)

	if director == null:
		return

	# Zone-shrink border (GDD §12) — the single most important thing on the map
	# after minute 17.
	if GameManager.match_time >= Constants.ZONE_SHRINK_START:
		var radius_world: float = _zone_radius()
		var radius_px: float = (radius_world / _half_world) * (size.x * 0.5)
		draw_arc(size * 0.5, radius_px, 0.0, TAU, 64, Color(0.95, 0.30, 0.25, 0.85), 2.5, true)

	# The Cursed Throne
	draw_circle(_to_map(Vector3.ZERO), 4.0, Color(0.70, 0.40, 0.95, 0.9))

	# Squad bases
	for s in director.squads:
		var p := _to_map(s.base_position)
		var tint: Color = s.squad_color
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)),
			Color(tint.r, tint.g, tint.b, 0.9), true)

	# Actors
	var me = director.player_actor
	for a in director.actors:
		if not is_instance_valid(a) or not a.is_alive():
			continue
		var friendly: bool = me != null and a.squad_id == me.squad_id
		var revealed: bool = friendly
		if not friendly:
			# Enemies appear when close, or while explicitly revealed.
			if me != null and me.global_position.distance_to(a.global_position) < passive_reveal:
				revealed = true
			elif float(_revealed_until.get(a, -1.0)) > GameManager.match_time:
				revealed = true
		if not revealed:
			continue

		var p := _to_map(a.global_position)
		var tint: Color = a.squad_color
		if a.is_downed():
			tint = UITheme.EMBER
		draw_circle(p, 3.0 if friendly else 2.5, tint)
		if friendly:
			draw_arc(p, 4.5, 0.0, TAU, 10, Color(1, 1, 1, 0.55), 1.0, true)

	# Player marker, drawn last so it is never hidden
	if me != null and is_instance_valid(me):
		var pp := _to_map(me.global_position)
		draw_circle(pp, 4.5, Color(1, 1, 1, 0.95))
		draw_circle(pp, 2.5, UITheme.GOLD)


func _to_map(world_pos: Vector3) -> Vector2:
	var u: float = (world_pos.x + _half_world) / (_half_world * 2.0)
	var v: float = (world_pos.z + _half_world) / (_half_world * 2.0)
	return Vector2(clampf(u, 0.0, 1.0) * size.x, clampf(v, 0.0, 1.0) * size.y)


func _zone_radius() -> float:
	var elapsed: float = GameManager.match_time - Constants.ZONE_SHRINK_START
	var tiles_closed: float = elapsed / Constants.ZONE_SHRINK_RATE
	var half: float = float(Constants.GRID_SIZE.x) * 0.5
	return maxf(12.0, (half - tiles_closed) * Constants.TILE_SIZE.x)


## Legacy entry point kept so older call sites don't break.
func set_player(_p) -> void:
	pass
