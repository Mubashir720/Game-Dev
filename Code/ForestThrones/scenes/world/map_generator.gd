extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════════
#  MAP GENERATOR v4 — Continuous Terrain World Generator
#  Upgrades over v3:
#   • Ground is ONE continuous heightmapped mesh (SurfaceTool, per-vertex height
#     and per-vertex color) instead of 40,000 separate flat tile planes + vertical
#     "skirt" boxes. Slopes now interpolate smoothly across triangles, so biomes
#     physically slope into each other instead of meeting at a hard vertical wall.
#   • Biome color blending is a true continuous field (distance-based weights,
#     independent of the per-cell zone classification) so borders read as a
#     gradient, like hand-painted terrain, not a dithered checkerboard of tiles.
#   • Slope-aware rock bleed + procedural micro-noise detail (terrain_ground.gdshader)
#     so large flat regions never read as a single dead-flat color.
#   • Rivers and ponds use an animated flowing-water shader (water_flow.gdshader)
#     with real scrolling current, foam streaks, and fresnel edge highlighting,
#     instead of a static tinted-glass plane.
#   • Biome borders are noise-warped (no straight rectangle seams between zones)
#   • A single, consistent winding river definition shared by zone logic AND the
#     visible water mesh
#   • Rolling hills via large-scale elevation noise layered under every biome
#   • Swamp ponds, riverbank reed/lily detail, forest fern understory
#   • A real road network: center cross-paths PLUS 8 radial roads connecting every
#     drop zone to the center, so every "land" is physically connected, with soft
#     feathered dirt-road edges baked into the terrain vertex colors
#   • Bridges are placed dynamically wherever a road actually crosses the river,
#     sized and rotated to the true crossing geometry
# ═══════════════════════════════════════════════════════════════════════════════

const PropFactory = preload("res://scenes/world/prop_factory.gd")
const TERRAIN_SHADER = preload("res://assets/shaders/terrain_ground.gdshader")
const WATER_SHADER = preload("res://assets/shaders/water_flow.gdshader")

# ── Biome layout constants (grid-space, 200x200) ────────────────────────────────
const MARGIN := 10
const THRONE_RADIUS := 3.2
const WEST_RIVER_X := 30.0
const EAST_RIVER_X := 170.0
const RIVER_WOBBLE := 9.0
const RIVER_WIDTH_BASE := 5.6
const RIVER_WIDTH_VAR := 2.6

const HIGHLAND_CENTERS := [Vector2(38.0, 38.0), Vector2(162.0, 162.0)]
const HIGHLAND_RADIUS := 26.0
const SWAMP_CENTER := Vector2(160.0, 42.0)
const SWAMP_RADIUS := 26.0
const CLEARING_CENTERS := [
	Vector2(70.0, 70.0), Vector2(130.0, 70.0),
	Vector2(70.0, 130.0), Vector2(130.0, 130.0),
]
const CLEARING_RADIUS := 13.0
const POND_CENTERS := [Vector2(152.0, 38.0), Vector2(170.0, 55.0)]
const POND_RADIUS := 6.0

# Continuous-blend falloff widths (grid units) — how far a biome's color/height
# bleeds into its neighbor before fully transitioning. Larger = softer border.
const BLEND_HIGHLAND := 9.0
const BLEND_SWAMP := 9.0
const BLEND_CLEARING := 6.0
const BLEND_RIVERBANK := 3.0
const BLEND_FOREST_FLOOR := 0.24 # baseline forest presence everywhere (lets forest bleed through)

# Ground biome palette (Rich AAA Battle Royale dark fantasy colors)
const COLOR_DROP_ZONE := Color(0.32, 0.24, 0.16)   # Warm packed dirt ring
const COLOR_FOREST    := Color(0.10, 0.28, 0.12)   # Deep rich pine emerald green
const COLOR_CLEARING  := Color(0.22, 0.54, 0.18)   # Vibrant Battle Royale meadow green
const COLOR_RIVERBED  := Color(0.16, 0.22, 0.20)   # Wet dark river gravel
const COLOR_HIGHLAND  := Color(0.26, 0.28, 0.30)   # Mountain slate granite stone
const COLOR_SWAMP     := Color(0.14, 0.24, 0.12)   # Dark murky cypress green
const COLOR_THRONE    := Color(0.12, 0.08, 0.18)   # Cursed obsidian basalt
const COLOR_PATH      := Color(0.42, 0.30, 0.18)   # Rich golden soil trail

const CLOSE_OFFSETS := [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
const FAR_OFFSETS := [
	Vector2i(5, 0), Vector2i(-5, 0), Vector2i(0, 5), Vector2i(0, -5),
	Vector2i(4, 4), Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4),
]

var _elev_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _hill_noise := FastNoiseLite.new()
var _warp_x := FastNoiseLite.new()
var _warp_y := FastNoiseLite.new()
var _river_noise_w := FastNoiseLite.new()
var _river_noise_e := FastNoiseLite.new()
var _pond_noise := FastNoiseLite.new()

var _drop_coords: Array = [
	Vector2i(20, 20), Vector2i(100, 15), Vector2i(180, 20),
	Vector2i(15, 100), Vector2i(185, 100),
	Vector2i(20, 180), Vector2i(100, 185), Vector2i(180, 180),
]

func _init() -> void:
	_elev_noise.seed = 1337
	_elev_noise.frequency = 0.008
	_elev_noise.fractal_octaves = 4
	_elev_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	_detail_noise.seed = 4242
	_detail_noise.frequency = 0.04
	_detail_noise.fractal_octaves = 2

	_hill_noise.seed = 777
	_hill_noise.frequency = 0.018
	_hill_noise.fractal_octaves = 3
	_hill_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	_warp_x.seed = 91
	_warp_x.frequency = 0.010
	_warp_y.seed = 137
	_warp_y.frequency = 0.010

	_river_noise_w.seed = 55
	_river_noise_w.frequency = 0.012
	_river_noise_e.seed = 56
	_river_noise_e.frequency = 0.012

	_pond_noise.seed = 909
	_pond_noise.frequency = 0.09


func generate(world_node: Node3D) -> void:
	var grid_size = Constants.GRID_SIZE
	var tile_dim = Constants.TILE_SIZE
	var center_grid = grid_size / 2

	var ground_container := Node3D.new()
	ground_container.name = "GroundTiles"
	world_node.add_child(ground_container)

	var water_container := Node3D.new()
	water_container.name = "WaterSurfaces"
	world_node.add_child(water_container)

	var scatter_container := Node3D.new()
	scatter_container.name = "GroundScatter"
	world_node.add_child(scatter_container)

	var props_container := Node3D.new()
	props_container.name = "Props"
	world_node.add_child(props_container)

	var bridges_container := Node3D.new()
	bridges_container.name = "Bridges"
	world_node.add_child(bridges_container)

	# 1. Pre-pass: compute zone + height for every cell ONCE, cache both.
	#    (v2 called determine_zone twice per tile during generation; caching here
	#    also lets the border-blend logic do cheap dictionary lookups instead of
	#    re-running the zone classifier for every neighbor check.)
	var zone_grid := {}
	var height_grid := {}
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var gp := Vector2i(x, y)
			var z = determine_zone(gp, grid_size)
			zone_grid[gp] = z
			height_grid[gp] = _calculate_height(x, y, z)

	# 2. Pre-calculate the road network: center cross-roads + 8 radial roads
	#    connecting every drop zone to the throne, so every part of the map is
	#    physically reachable by land instead of isolated behind a river band.
	var path_cells := _calculate_path_network(grid_size, center_grid, _drop_coords)

	# 2b. ONE continuous heightmapped ground mesh for the whole map — replaces the
	#     old 40,000-separate-flat-tile + vertical-skirt-box approach entirely, so
	#     neighboring biomes physically slope into each other and the color blend
	#     is a true smooth gradient instead of per-tile snapping.
	_build_terrain_mesh(ground_container, grid_size, tile_dim, center_grid, zone_grid, height_grid, path_cells)

	# 3. River water surfaces — ribbons of connected quads that follow the exact
	#    same winding centerline used by determine_zone(), so the visible water
	#    always sits precisely on top of the RIVERBED tiles.
	_generate_river_water_mesh(water_container, grid_size, tile_dim, center_grid)

	# 4. Pond water surfaces (swamp)
	_generate_pond_water_mesh(water_container, tile_dim, center_grid)

	# Scatter materials
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.24, 0.50, 0.22); grass_mat.roughness = 0.85
	var flower_colors = [Color(0.92, 0.82, 0.20), Color(0.95, 0.95, 0.92), Color(0.75, 0.30, 0.85)]
	var pebble_mat := StandardMaterial3D.new()
	pebble_mat.albedo_color = Color(0.48, 0.46, 0.42); pebble_mat.roughness = 0.90

	# 5. Scatter & Props — ground mesh itself was already built as one continuous
	#    surface in step 2b above
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var grid_pos := Vector2i(x, y)
			var zone = zone_grid[grid_pos]
			var is_path = path_cells.has(grid_pos) and zone != Constants.ZoneType.RIVERBED and zone != Constants.ZoneType.CURSED_THRONE

			var world_x = (x - center_grid.x) * tile_dim.x
			var world_z = (y - center_grid.y) * tile_dim.y
			var world_y = height_grid[grid_pos]

			# Riverbank & pond-edge detail (reeds, lily pads, pebbles)
			if zone == Constants.ZoneType.RIVERBED:
				var r0 = randf()
				if r0 < 0.10:
					var stone := MeshInstance3D.new()
					var sm := SphereMesh.new()
					sm.radius = 0.08 + randf() * 0.08; sm.height = sm.radius * 0.8
					stone.mesh = sm; stone.material_override = pebble_mat
					stone.position = Vector3(world_x + (randf() - 0.5) * 1.5, -0.05, world_z + (randf() - 0.5) * 1.5)
					scatter_container.add_child(stone)
				elif r0 < 0.14 and _is_riverbank_edge(grid_pos, zone_grid):
					var reeds = PropFactory.build_reed_cluster()
					reeds.position = Vector3(world_x, world_y, world_z)
					scatter_container.add_child(reeds)
				elif r0 < 0.17:
					var lily = PropFactory.build_lily_pad()
					lily.position = Vector3(world_x, -0.04, world_z)
					scatter_container.add_child(lily)

			# Ground Scatter
			elif not is_path:
				_spawn_ground_scatter(scatter_container, zone, Vector3(world_x, world_y, world_z), grass_mat, flower_colors, pebble_mat)

			# Environment Props — density fades out near biome borders instead of
			# cutting off hard, so forest doesn't just stop dead against a clearing.
			if zone != Constants.ZoneType.CURSED_THRONE and zone != Constants.ZoneType.DROP_ZONE and zone != Constants.ZoneType.RIVERBED and not is_path:
				var border_info = _neighbor_zone_info(grid_pos, zone, zone_grid)
				var density_scale = 1.0 - border_info.blend * 0.55
				if randf() < 0.06 * density_scale:
					var prop_node: Node3D = null
					var r = randf()

					match zone:
						Constants.ZoneType.DENSE_FOREST:
							if r < 0.42: prop_node = PropFactory.build_tree("pine")
							elif r < 0.68: prop_node = PropFactory.build_tree("oak")
							elif r < 0.84: prop_node = PropFactory.build_tree("canopy")
							elif r < 0.94: prop_node = PropFactory.build_fern_cluster()
							else: prop_node = PropFactory.build_fallen_log()

						Constants.ZoneType.OPEN_CLEARING:
							if r < 0.35: prop_node = PropFactory.build_berry_bush()
							elif r < 0.60: prop_node = PropFactory.build_tree("oak")
							elif r < 0.85: prop_node = PropFactory.build_rock("boulder")
							else: prop_node = PropFactory.build_trail_marker() if randf() < 0.15 else PropFactory.build_berry_bush()

						Constants.ZoneType.ROCKY_HIGHLANDS:
							if r < 0.40: prop_node = PropFactory.build_rock("boulder")
							elif r < 0.65: prop_node = PropFactory.build_rock("ore_vein")
							elif r < 0.85: prop_node = PropFactory.build_rock("cluster")
							else: prop_node = PropFactory.build_hill_rock_pile()

						Constants.ZoneType.SWAMP:
							if r < 0.34: prop_node = PropFactory.build_tree("dead")
							elif r < 0.62: prop_node = PropFactory.build_herb_plant()
							elif r < 0.85: prop_node = PropFactory.build_mushroom_cluster()
							else: prop_node = PropFactory.build_reed_cluster()

					if prop_node:
						prop_node.position = Vector3(world_x, world_y, world_z)
						prop_node.rotation.y = randf() * TAU
						props_container.add_child(prop_node)

	# 6. Central Cursed Throne Altar
	var throne = PropFactory.build_cursed_throne()
	throne.position = Vector3(0, 0.4, 0)
	props_container.add_child(throne)

	# 7. Giant Beast Skeleton Fossils
	var skel1 = PropFactory.build_beast_skeleton()
	skel1.position = Vector3(50 * tile_dim.x, 0.0, -30 * tile_dim.y)
	props_container.add_child(skel1)

	var skel2 = PropFactory.build_beast_skeleton()
	skel2.position = Vector3(-45 * tile_dim.x, 0.0, 40 * tile_dim.y)
	props_container.add_child(skel2)

	# 8. Wooden River Bridges — computed dynamically from where the 8 radial roads
	#    actually intersect the winding river, correctly sized & rotated per crossing.
	_generate_bridges(bridges_container, grid_size, tile_dim, center_grid, _drop_coords)

	# 9. 8 Squad Camps
	var squad_colors = [
		Color(0.85, 0.25, 0.20), Color(0.20, 0.55, 0.90),
		Color(0.25, 0.80, 0.35), Color(0.90, 0.75, 0.15),
		Color(0.80, 0.30, 0.85), Color(0.15, 0.85, 0.80),
		Color(0.90, 0.50, 0.15), Color(0.60, 0.65, 0.70),
	]
	for i in range(_drop_coords.size()):
		var dc = _drop_coords[i]
		var cpos = Vector3((dc.x - center_grid.x) * tile_dim.x, 0.0, (dc.y - center_grid.y) * tile_dim.y)
		var camp = PropFactory.build_squad_camp(squad_colors[i])
		camp.position = cpos
		props_container.add_child(camp)

	# 10. Ruined Stone Arches
	for z_off in [-8.0, 8.0]:
		var arch = PropFactory.build_ruined_arch()
		arch.position = Vector3(0, 0.4, z_off)
		props_container.add_child(arch)

	# 11. NPC Vendor Stalls
	var v1 = PropFactory.build_vendor_stall(false)
	v1.position = Vector3(-40 * tile_dim.x, 0.0, 0.0)
	props_container.add_child(v1)

	var v2 = PropFactory.build_vendor_stall(false)
	v2.position = Vector3(40 * tile_dim.x, 0.0, 0.0)
	props_container.add_child(v2)


# ═══════════════════════════════════════════════════════════════════════════════
#  RIVER GEOMETRY — single source of truth used by zone classification, the water
#  mesh, AND bridge placement so all three always agree with each other.
# ═══════════════════════════════════════════════════════════════════════════════

func _river_center(y: float, side: int) -> float:
	var base = WEST_RIVER_X if side < 0 else EAST_RIVER_X
	var n = _river_noise_w.get_noise_1d(y) if side < 0 else _river_noise_e.get_noise_1d(y)
	return base + n * RIVER_WOBBLE

func _river_width(y: float, side: int) -> float:
	var n = _river_noise_w.get_noise_1d(y * 2.0 + 300.0) if side < 0 else _river_noise_e.get_noise_1d(y * 2.0 + 300.0)
	return RIVER_WIDTH_BASE + abs(n) * RIVER_WIDTH_VAR

func _is_in_river(x: float, y: float) -> int:
	# Returns -1 (west), 1 (east), or 0 (not in a river) for the given float grid coords
	var wc = _river_center(y, -1)
	if abs(x - wc) < _river_width(y, -1) * 0.5:
		return -1
	var ec = _river_center(y, 1)
	if abs(x - ec) < _river_width(y, 1) * 0.5:
		return 1
	return 0

func _is_in_pond(x: float, y: float) -> bool:
	for pc in POND_CENTERS:
		var d = Vector2(x, y).distance_to(pc)
		var jitter = _pond_noise.get_noise_2d(x, y) * 1.6
		if d < POND_RADIUS + jitter:
			return true
	return false


func _make_water_material(shallow: Color, deep: Color, speed: float, wave_scale: float, foam: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("shallow_color", shallow)
	mat.set_shader_parameter("deep_color", deep)
	mat.set_shader_parameter("flow_speed", speed)
	mat.set_shader_parameter("wave_scale", wave_scale)
	mat.set_shader_parameter("foam_amount", foam)
	return mat


func _generate_river_water_mesh(water_container: Node3D, grid_size: Vector2i, tile_dim: Vector2, center_grid: Vector2i) -> void:
	# Flows roughly south -> north along the winding riverbed centerline
	var water_mat := _make_water_material(
		Color(0.14, 0.42, 0.62, 0.72), Color(0.04, 0.15, 0.30, 0.92), 0.6, 2.6, 0.4)

	var segment_span := 4 # grid rows per water ribbon segment — tight enough to hug the curve
	for side in [-1, 1]:
		var y := 0
		while y < grid_size.y:
			var y_end = min(y + segment_span, grid_size.y - 1)
			var y_mid = (y + y_end) * 0.5
			var cx = _river_center(y_mid, side)
			var w = _river_width(y_mid, side)

			var seg := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(w * tile_dim.x, float(y_end - y) * tile_dim.y + 0.15)
			seg.mesh = plane
			seg.material_override = water_mat
			seg.position = Vector3(
				(cx - center_grid.x) * tile_dim.x, -0.06,
				(y_mid - center_grid.y) * tile_dim.y)
			water_container.add_child(seg)
			y += segment_span


func _generate_pond_water_mesh(water_container: Node3D, tile_dim: Vector2, center_grid: Vector2i) -> void:
	# Ponds get a slower, murkier, more still current than the open river
	var water_mat := _make_water_material(
		Color(0.18, 0.36, 0.30, 0.80), Color(0.05, 0.16, 0.14, 0.92), 0.18, 1.2, 0.15)

	for pc in POND_CENTERS:
		var seg := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(POND_RADIUS * 2.0 * tile_dim.x, POND_RADIUS * 2.0 * tile_dim.y)
		seg.mesh = plane
		seg.material_override = water_mat
		seg.position = Vector3((pc.x - center_grid.x) * tile_dim.x, -0.07, (pc.y - center_grid.y) * tile_dim.y)
		water_container.add_child(seg)


func _is_riverbank_edge(pos: Vector2i, zone_grid: Dictionary) -> bool:
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if zone_grid.get(pos + off, Constants.ZoneType.RIVERBED) != Constants.ZoneType.RIVERBED:
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
#  ROAD NETWORK & BRIDGES
# ═══════════════════════════════════════════════════════════════════════════════

func _calculate_path_network(grid_size: Vector2i, center: Vector2i, drop_coords: Array) -> Dictionary:
	var paths := {}
	for x in range(30, grid_size.x - 30):
		paths[Vector2i(x, center.y)] = true
		paths[Vector2i(x, center.y + 1)] = true

	for y in range(30, grid_size.y - 30):
		paths[Vector2i(center.x, y)] = true
		paths[Vector2i(center.x + 1, y)] = true

	# Radial roads from every drop zone to the throne — physically connects every
	# squad's land to the center and to each other, instead of the single +-shaped
	# crossroads v2 had.
	for dc in drop_coords:
		_mark_line(paths, Vector2(dc.x, dc.y), Vector2(center.x, center.y), 1)

	return paths


func _mark_line(paths: Dictionary, a: Vector2, b: Vector2, half_width: int) -> void:
	var dist = a.distance_to(b)
	var steps = max(1, int(dist))
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var p = a.lerp(b, t)
		var cx = int(round(p.x))
		var cy = int(round(p.y))
		for ox in range(-half_width, half_width + 1):
			for oy in range(-half_width, half_width + 1):
				paths[Vector2i(cx + ox, cy + oy)] = true


func _generate_bridges(container: Node3D, grid_size: Vector2i, tile_dim: Vector2, center_grid: Vector2i, drop_coords: Array) -> void:
	for dc in drop_coords:
		var a = Vector2(dc.x, dc.y)
		var b = Vector2(center_grid.x, center_grid.y)
		var crossings = _find_river_crossings(a, b)
		for c in crossings:
			var dir = (b - a).normalized()
			var span = max(10.0, _river_width(c.y, -1 if c.x < center_grid.x else 1) * tile_dim.x * 1.4)
			var bridge = PropFactory.build_wooden_bridge(span)
			bridge.position = Vector3((c.x - center_grid.x) * tile_dim.x, 0.05, (c.y - center_grid.y) * tile_dim.y)
			bridge.rotation.y = atan2(dir.x, dir.y)
			container.add_child(bridge)


func _find_river_crossings(a: Vector2, b: Vector2) -> Array:
	var crossings := []
	var dist = a.distance_to(b)
	var steps = max(1, int(dist))
	var in_river = false
	var start_t := 0.0
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var p = a.lerp(b, t)
		var is_river = _is_in_river(p.x, p.y) != 0
		if is_river and not in_river:
			start_t = t
			in_river = true
		elif not is_river and in_river:
			var mid_t = (start_t + t) * 0.5
			crossings.append(a.lerp(b, mid_t))
			in_river = false
	if in_river:
		crossings.append(a.lerp(b, (start_t + 1.0) * 0.5))
	return crossings


# ═══════════════════════════════════════════════════════════════════════════════
#  ELEVATION — rolling hills layered under every biome, not just the highlands
# ═══════════════════════════════════════════════════════════════════════════════

func _calculate_height(x: int, y: int, zone: Constants.ZoneType) -> float:
	var base_n = _elev_noise.get_noise_2d(float(x), float(y))
	var det_n = _detail_noise.get_noise_2d(float(x), float(y)) * 0.10
	var hill_n = max(_hill_noise.get_noise_2d(float(x), float(y)), 0.0) # only positive lobes read as hills

	match zone:
		Constants.ZoneType.ROCKY_HIGHLANDS:
			return 0.6 + abs(base_n) * 1.3 + det_n + hill_n * 0.6
		Constants.ZoneType.CURSED_THRONE:
			return 0.4
		Constants.ZoneType.RIVERBED:
			return -0.18
		Constants.ZoneType.SWAMP:
			return -0.06 + base_n * 0.10
		Constants.ZoneType.DENSE_FOREST:
			return abs(base_n) * 0.35 + det_n + hill_n * 1.4
		Constants.ZoneType.OPEN_CLEARING:
			return abs(det_n * 0.5) + hill_n * 1.1
		Constants.ZoneType.DROP_ZONE:
			return hill_n * 0.4
		_:
			return hill_n * 0.9


# ═══════════════════════════════════════════════════════════════════════════════
#  BIOME BORDER BLENDING — soft dithered transition between neighboring zones
# ═══════════════════════════════════════════════════════════════════════════════

func _neighbor_zone_info(pos: Vector2i, own_zone: Constants.ZoneType, zone_grid: Dictionary) -> Dictionary:
	var result := {"blend": 0.0, "other": own_zone}
	var found_close = null
	var found_far = null

	for off in CLOSE_OFFSETS:
		var nz = zone_grid.get(pos + off, own_zone)
		if nz != own_zone:
			found_close = nz
			break

	if found_close == null:
		for off in FAR_OFFSETS:
			var nz = zone_grid.get(pos + off, own_zone)
			if nz != own_zone:
				found_far = nz
				break

	if found_close != null:
		result.other = found_close
		result.blend = 0.60
	elif found_far != null:
		result.other = found_far
		result.blend = 0.28

	return result


func _hash01(x: int, y: int) -> float:
	var n = sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
	return fmod(abs(n), 1.0)


# ═══════════════════════════════════════════════════════════════════════════════
#  CONTINUOUS TERRAIN MESH — one SurfaceTool-built ground mesh for the entire
#  map. Per-vertex height (already computed in height_grid) plus a smoothly
#  weighted per-vertex biome color, so slopes and biome borders read as a real
#  continuous landscape instead of a grid of flat colored boxes.
# ═══════════════════════════════════════════════════════════════════════════════

func _build_terrain_mesh(container: Node3D, grid_size: Vector2i, tile_dim: Vector2, center_grid: Vector2i,
		zone_grid: Dictionary, height_grid: Dictionary, path_cells: Dictionary) -> void:
	var w := grid_size.x
	var h := grid_size.y

	# Precompute every vertex color once (reused by both triangles of every quad
	# that touches it) so we don't recompute the same blend 4x per interior vertex.
	var colors := {}
	for y in range(h):
		for x in range(w):
			var gp := Vector2i(x, y)
			colors[gp] = _vertex_color(gp, zone_grid, height_grid, path_cells)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for y in range(h - 1):
		for x in range(w - 1):
			var p00 := Vector2i(x, y)
			var p10 := Vector2i(x + 1, y)
			var p01 := Vector2i(x, y + 1)
			var p11 := Vector2i(x + 1, y + 1)

			var v00 := _vertex_pos(p00, tile_dim, center_grid, height_grid)
			var v10 := _vertex_pos(p10, tile_dim, center_grid, height_grid)
			var v01 := _vertex_pos(p01, tile_dim, center_grid, height_grid)
			var v11 := _vertex_pos(p11, tile_dim, center_grid, height_grid)

			_add_tri(st, v00, v10, v11, colors[p00], colors[p10], colors[p11])
			_add_tri(st, v00, v11, v01, colors[p00], colors[p11], colors[p01])

	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _build_terrain_shader_material()
	mesh_inst.name = "ContinuousTerrain"
	container.add_child(mesh_inst)


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca); st.set_uv(Vector2(a.x, a.z) * 0.5); st.add_vertex(a)
	st.set_color(cb); st.set_uv(Vector2(b.x, b.z) * 0.5); st.add_vertex(b)
	st.set_color(cc); st.set_uv(Vector2(c.x, c.z) * 0.5); st.add_vertex(c)


func _vertex_pos(gp: Vector2i, tile_dim: Vector2, center_grid: Vector2i, height_grid: Dictionary) -> Vector3:
	var wx = (gp.x - center_grid.x) * tile_dim.x
	var wz = (gp.y - center_grid.y) * tile_dim.y
	var wy: float = height_grid.get(gp, 0.0)
	return Vector3(wx, wy, wz)


func _build_terrain_shader_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	return mat


func _vertex_color(gp: Vector2i, zone_grid: Dictionary, height_grid: Dictionary, path_cells: Dictionary) -> Color:
	var zone = zone_grid.get(gp, Constants.ZoneType.DENSE_FOREST)

	# Hard-locked gameplay-critical zones stay visually distinct but still get a
	# touch of variance so they don't look like a painted-on decal.
	if zone == Constants.ZoneType.CURSED_THRONE:
		return COLOR_THRONE.lerp(Color(0.30, 0.24, 0.36), _hash01(gp.x, gp.y) * 0.25)
	if zone == Constants.ZoneType.DROP_ZONE:
		var dz_jitter = (_hash01(gp.x, gp.y) - 0.5) * 0.10
		return Color(
			clamp(COLOR_DROP_ZONE.r + dz_jitter, 0.0, 1.0),
			clamp(COLOR_DROP_ZONE.g + dz_jitter, 0.0, 1.0),
			clamp(COLOR_DROP_ZONE.b + dz_jitter, 0.0, 1.0))

	var pos := Vector2(gp.x, gp.y)

	# Continuous biome weights — a true distance-field blend, independent of the
	# hard per-cell zone_grid classification used for gameplay logic.
	var weights = _biome_weights(pos)
	var col: Color = COLOR_FOREST * weights.forest \
		+ COLOR_CLEARING * weights.clearing \
		+ COLOR_HIGHLAND * weights.highland \
		+ COLOR_SWAMP * weights.swamp

	# River / pond bank blending — grass fades into mud/sand before the water's
	# edge instead of the biome color cutting off dead against the river polygon.
	var river_blend = _river_bank_blend(pos)
	col = col.lerp(COLOR_RIVERBED, river_blend)

	# Slope-aware rock bleed: steep terrain reads as exposed rock/scree, same
	# trick real open-world terrain systems use so hillsides don't look painted.
	var slope = _slope_at(gp, height_grid)
	col = col.lerp(COLOR_HIGHLAND * 0.85, clamp(slope * 1.8, 0.0, 0.55))

	# Dirt road blending — sampled over a small neighborhood so the road edge
	# feathers smoothly instead of snapping at the path cell boundary.
	var path_blend = _path_blend_factor(gp, path_cells)
	col = col.lerp(COLOR_PATH, path_blend)

	# Fine per-vertex micro variation so large flat regions don't read as one
	# perfectly uniform color even before the shader's procedural detail layer.
	var micro = (_hash01(gp.x * 7 + 3, gp.y * 7 + 11) - 0.5) * 0.06
	return Color(
		clamp(col.r + micro, 0.0, 1.0),
		clamp(col.g + micro * 0.9, 0.0, 1.0),
		clamp(col.b + micro * 0.8, 0.0, 1.0))


func _biome_weights(pos: Vector2) -> Dictionary:
	var wx = pos.x + _warp_x.get_noise_2d(pos.x, pos.y) * 9.0
	var wy = pos.y + _warp_y.get_noise_2d(pos.x, pos.y) * 9.0
	var wpos = Vector2(wx, wy)

	var s_highland := 0.0
	for hc in HIGHLAND_CENTERS:
		var edge_noise = _hill_noise.get_noise_2d(wx * 1.3, wy * 1.3) * 6.0
		var d = wpos.distance_to(hc) - (HIGHLAND_RADIUS + edge_noise)
		s_highland = max(s_highland, clamp(1.0 - d / BLEND_HIGHLAND, 0.0, 1.0))

	var swamp_edge = _hill_noise.get_noise_2d(wx * 1.1 + 500.0, wy * 1.1) * 7.0
	var d_sw = wpos.distance_to(SWAMP_CENTER) - (SWAMP_RADIUS + swamp_edge)
	var s_swamp = clamp(1.0 - d_sw / BLEND_SWAMP, 0.0, 1.0)

	var s_clearing := 0.0
	for cc in CLEARING_CENTERS:
		var clearing_edge = _detail_noise.get_noise_2d(wx + 1000.0, wy) * 4.0
		var d_cl = wpos.distance_to(cc) - (CLEARING_RADIUS + clearing_edge)
		s_clearing = max(s_clearing, clamp(1.0 - d_cl / BLEND_CLEARING, 0.0, 1.0))

	var s_forest = BLEND_FOREST_FLOOR

	var total = s_highland + s_swamp + s_clearing + s_forest
	if total <= 0.0001:
		total = 1.0

	return {
		"highland": s_highland / total,
		"swamp": s_swamp / total,
		"clearing": s_clearing / total,
		"forest": s_forest / total,
	}


func _river_bank_blend(pos: Vector2) -> float:
	var b := 0.0
	for side in [-1, 1]:
		var cx = _river_center(pos.y, side)
		var wdt = _river_width(pos.y, side)
		var d = abs(pos.x - cx) - wdt * 0.5
		b = max(b, clamp(1.0 - d / BLEND_RIVERBANK, 0.0, 1.0))
	for pc in POND_CENTERS:
		var jitter = _pond_noise.get_noise_2d(pos.x, pos.y) * 1.6
		var d2 = pos.distance_to(pc) - (POND_RADIUS + jitter)
		b = max(b, clamp(1.0 - d2 / BLEND_RIVERBANK, 0.0, 1.0))
	return b


func _slope_at(gp: Vector2i, height_grid: Dictionary) -> float:
	var h0: float = height_grid.get(gp, 0.0)
	var hx: float = height_grid.get(gp + Vector2i(1, 0), h0)
	var hy: float = height_grid.get(gp + Vector2i(0, 1), h0)
	return abs(hx - h0) + abs(hy - h0)


func _path_blend_factor(gp: Vector2i, path_cells: Dictionary) -> float:
	var count := 0
	var total := 0
	for ox in range(-2, 3):
		for oy in range(-2, 3):
			total += 1
			if path_cells.has(gp + Vector2i(ox, oy)):
				count += 1
	return float(count) / float(total)


# ═══════════════════════════════════════════════════════════════════════════════
#  GROUND SCATTER (grass tufts etc.)
# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_ground_scatter(container: Node3D, zone: Constants.ZoneType, pos: Vector3,
		grass_mat: Material, flower_colors: Array, pebble_mat: Material) -> void:
	var rng = randf()

	if zone == Constants.ZoneType.OPEN_CLEARING or zone == Constants.ZoneType.DENSE_FOREST or zone == Constants.ZoneType.DROP_ZONE:
		if rng < 0.28:
			var tuft := Node3D.new()
			for i in range(4):
				var blade := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.02, 0.16 + randf() * 0.08, 0.01)
				blade.mesh = bm; blade.material_override = grass_mat
				var ang = (i / 4.0) * TAU
				blade.position = Vector3(cos(ang) * 0.04, bm.size.y * 0.5, sin(ang) * 0.04)
				tuft.add_child(blade)
			var off_x = (randf() - 0.5) * 1.4
			var off_z = (randf() - 0.5) * 1.4
			tuft.position = pos + Vector3(off_x, 0, off_z)
			container.add_child(tuft)


# ═══════════════════════════════════════════════════════════════════════════════
#  ZONE CLASSIFICATION — organic biome shapes via noise-warped region tests.
#  Throne / Drop Zones / River stay on raw (unwarped) coordinates so gameplay-
#  critical geometry (spawn fairness, resource-free throne, river crossings)
#  remains precise and deterministic. Everything else gets warped borders so
#  biomes bleed into each other like a real landscape instead of clipped boxes.
# ═══════════════════════════════════════════════════════════════════════════════

func determine_zone(pos: Vector2i, size: Vector2i) -> Constants.ZoneType:
	var center = size / 2

	# 1. Cursed Throne — small precise radius at dead center
	if Vector2(pos.x, pos.y).distance_to(Vector2(center.x, center.y)) <= THRONE_RADIUS:
		return Constants.ZoneType.CURSED_THRONE

	# 2. Drop Zones — 8 equal corners/edges at the map boundary
	var margin := MARGIN
	if (pos.x < margin or pos.x >= size.x - margin) and (pos.y < margin or pos.y >= size.y - margin):
		return Constants.ZoneType.DROP_ZONE

	# 3. River (winding, noise-driven) + swamp ponds
	if _is_in_river(float(pos.x), float(pos.y)) != 0:
		return Constants.ZoneType.RIVERBED
	if _is_in_pond(float(pos.x), float(pos.y)):
		return Constants.ZoneType.RIVERBED

	# From here on, use noise-domain-warped coordinates so every remaining biome
	# has an organic, hand-painted-looking coastline instead of a straight edge.
	var wx = float(pos.x) + _warp_x.get_noise_2d(float(pos.x), float(pos.y)) * 9.0
	var wy = float(pos.y) + _warp_y.get_noise_2d(float(pos.x), float(pos.y)) * 9.0
	var wpos = Vector2(wx, wy)

	# 4. Rocky Highlands — two organic elevated massifs (NW / SE)
	for hc in HIGHLAND_CENTERS:
		var edge_noise = _hill_noise.get_noise_2d(wx * 1.3, wy * 1.3) * 6.0
		if wpos.distance_to(hc) < HIGHLAND_RADIUS + edge_noise:
			return Constants.ZoneType.ROCKY_HIGHLANDS

	# 5. Swamp — organic wetland blob (NE)
	var swamp_edge = _hill_noise.get_noise_2d(wx * 1.1 + 500.0, wy * 1.1) * 7.0
	if wpos.distance_to(SWAMP_CENTER) < SWAMP_RADIUS + swamp_edge:
		return Constants.ZoneType.SWAMP

	# 6. Open Clearings — 4 organic meadow blobs, mid-map
	for cc in CLEARING_CENTERS:
		var clearing_edge = _detail_noise.get_noise_2d(wx + 1000.0, wy) * 4.0
		if wpos.distance_to(cc) < CLEARING_RADIUS + clearing_edge:
			return Constants.ZoneType.OPEN_CLEARING

	# 7. Default — Dense Forest fills every remaining tile
	return Constants.ZoneType.DENSE_FOREST
