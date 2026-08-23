extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════════
#  MAP GENERATOR v5 — Chunked, instanced, streamable world generator
#
#  The landscape design from v4 is unchanged and intact: winding rivers, warped
#  organic biome borders, rolling hills, a radial road network with dynamically
#  placed bridges, continuous per-vertex biome colour blending, slope-aware rock
#  bleed and animated water.
#
#  What changed is HOW it is put on screen.
#
#  v4 emitted the world as loose nodes: one Node3D per grass tuft, one
#  StaticBody3D with ~11 MeshInstance3D children per tree, a fresh
#  StandardMaterial3D for practically every part. Measured on a 200x200 map that
#  produced 113,038 nodes, 88,714 draw calls, 13,510 materials and 1.69 GB of
#  RAM in 12.6 s — an instant out-of-memory crash on any phone.
#
#  v5 emits the same content as instanced geometry:
#    • Every prop design is baked ONCE into a shared mesh (PropBaker) with a few
#      randomised variants, then placed as MultiMesh instances — one matrix per
#      copy instead of a node tree per copy.
#    • The world is cut into CHUNK_CELLS-sized chunks. Each chunk owns its own
#      terrain mesh, its MultiMesh batches and ONE collision body, so the engine
#      can frustum-cull, distance-fade and stream them independently.
#    • Ground scatter, detail props, midground props and canopy props are split
#      into draw-distance layers, so grass only renders in the near ring while
#      trees still read to the horizon.
#    • Terrain is built directly into packed arrays with analytic normals rather
#      than through SurfaceTool, so chunk seams are invisible and generation is
#      an order of magnitude faster.
#    • Cell data (zone / height / colour / road) lives in flat packed arrays
#      indexed by y * W + x instead of Dictionary[Vector2i], which removes
#      hundreds of thousands of hash lookups from the hot loops.
#
#  Generation can run synchronously (generate) or time-sliced across frames with
#  progress reporting (generate_async) so the loading screen stays responsive.
# ═══════════════════════════════════════════════════════════════════════════════

const PropFactory = preload("res://scenes/world/prop_factory.gd")
const PropLibrary = preload("res://scenes/world/prop_library.gd")
const Baker = preload("res://scripts/render/prop_baker.gd")
const Batcher = preload("res://scripts/render/chunk_batcher.gd")
const Registry = preload("res://scripts/render/visual_registry.gd")
const TERRAIN_SHADER = preload("res://assets/shaders/terrain_ground.gdshader")
const WATER_SHADER = preload("res://assets/shaders/water_flow.gdshader")

# ── Chunking ───────────────────────────────────────────────────────────────────
## Cells per chunk edge. 20 cells x 2.0 units = a 40x40 unit chunk; a 200x200
## map becomes a 10x10 grid of them. Small enough to cull usefully, big enough
## that we don't drown in MultiMesh nodes.
const CHUNK_CELLS := 20

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

# Continuous-blend falloff widths (grid units)
const BLEND_HIGHLAND := 9.0
const BLEND_SWAMP := 9.0
const BLEND_CLEARING := 6.0
const BLEND_RIVERBANK := 3.0
const BLEND_FOREST_FLOOR := 0.24

# Ground biome palette — rich saturated tones
const COLOR_DROP_ZONE := Color(0.165, 0.300, 0.125)
const COLOR_FOREST    := Color(0.115, 0.235, 0.105)
const COLOR_CLEARING  := Color(0.195, 0.360, 0.145)
const COLOR_RIVERBED  := Color(0.16, 0.22, 0.12)
const COLOR_HIGHLAND  := Color(0.32, 0.30, 0.26)
const COLOR_SWAMP     := Color(0.130, 0.195, 0.098)
const COLOR_THRONE    := Color(0.16, 0.10, 0.22)
const COLOR_PATH      := Color(0.30, 0.22, 0.14)

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

# ── Cell field (flat packed arrays, index = y * W + x) ─────────────────────────
var _W := 0
var _H := 0
var _zone := PackedByteArray()
var _height := PackedFloat32Array()
var _vcolor := PackedColorArray()
var _is_path := PackedByteArray()
var _field_ready := false

var _chunks_x := 0
var _chunks_y := 0
var _chunk_roots: Array = []          # index = cy * _chunks_x + cx -> Node3D
var _terrain_meshes: Array = []       # index -> ArrayMesh (for lazy collision)
var _world_seed := 20250820

# Diagnostics
var last_stats := {}


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


# ═══════════════════════════════════════════════════════════════════════════════
#  PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Build the entire world in one blocking call. Used by tools, tests and the
## headless benchmark. In-game prefer generate_async().
func generate(world_node: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var containers := _prepare(world_node)
	var t_field := Time.get_ticks_msec()

	for ci in range(_chunks_x * _chunks_y):
		_build_chunk(containers.chunks, ci, true)
	var t_chunks := Time.get_ticks_msec()

	_build_landmarks(containers.landmarks)
	_generate_river_water_mesh(containers.water, Constants.GRID_SIZE, Constants.TILE_SIZE, Constants.GRID_SIZE / 2)
	_generate_pond_water_mesh(containers.water, Constants.TILE_SIZE, Constants.GRID_SIZE / 2)
	_generate_bridges(containers.landmarks, Constants.GRID_SIZE, Constants.TILE_SIZE, Constants.GRID_SIZE / 2, _drop_coords)
	var t_end := Time.get_ticks_msec()

	last_stats = {
		"field_ms": t_field - t0,
		"chunks_ms": t_chunks - t_field,
		"landmarks_ms": t_end - t_chunks,
		"total_ms": t_end - t0,
		"chunks": _chunks_x * _chunks_y,
	}


## Time-sliced generation. Yields back to the engine roughly every `budget_ms`
## so a loading screen keeps animating instead of freezing. `on_progress` is
## called with (fraction 0..1, stage_text).
func generate_async(world_node: Node3D, tree: SceneTree, on_progress: Callable = Callable(),
		budget_ms: int = 8) -> void:
	var _report := func(f: float, s: String) -> void:
		if on_progress.is_valid():
			on_progress.call(f, s)

	_report.call(0.02, "Surveying the forest")
	var containers := _prepare(world_node)
	await tree.process_frame

	_report.call(0.30, "Baking props")
	PropLibrary.warm_all()
	await tree.process_frame

	var total := _chunks_x * _chunks_y
	var slice_start := Time.get_ticks_msec()
	for ci in range(total):
		_build_chunk(containers.chunks, ci, true)
		if Time.get_ticks_msec() - slice_start >= budget_ms:
			_report.call(0.30 + 0.62 * (float(ci + 1) / float(total)), "Growing the forest")
			await tree.process_frame
			slice_start = Time.get_ticks_msec()

	_report.call(0.93, "Carving rivers")
	_generate_river_water_mesh(containers.water, Constants.GRID_SIZE, Constants.TILE_SIZE, Constants.GRID_SIZE / 2)
	_generate_pond_water_mesh(containers.water, Constants.TILE_SIZE, Constants.GRID_SIZE / 2)
	await tree.process_frame

	_report.call(0.97, "Raising landmarks")
	_build_landmarks(containers.landmarks)
	_generate_bridges(containers.landmarks, Constants.GRID_SIZE, Constants.TILE_SIZE, Constants.GRID_SIZE / 2, _drop_coords)
	_report.call(1.0, "Ready")


# ─── Cell field accessors (used by AI, build system, resource field) ──────────

func is_field_ready() -> bool:
	return _field_ready


func zone_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= _W or y >= _H:
		return Constants.ZoneType.DENSE_FOREST
	return _zone[y * _W + x]


func height_at(x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= _W or y >= _H:
		return 0.0
	return _height[y * _W + x]


## Smooth terrain height at an arbitrary world position (bilinear).
func height_at_world(world_pos: Vector3) -> float:
	var tile := Constants.TILE_SIZE
	var c := Constants.GRID_SIZE / 2
	var fx: float = world_pos.x / tile.x + float(c.x)
	var fy: float = world_pos.z / tile.y + float(c.y)
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx: float = fx - float(x0)
	var ty: float = fy - float(y0)
	var h00 := height_at(x0, y0)
	var h10 := height_at(x0 + 1, y0)
	var h01 := height_at(x0, y0 + 1)
	var h11 := height_at(x0 + 1, y0 + 1)
	return lerp(lerp(h00, h10, tx), lerp(h01, h11, tx), ty)


func is_road(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= _W or y >= _H:
		return false
	return _is_path[y * _W + x] != 0


func drop_zone_coords() -> Array:
	return _drop_coords.duplicate()


## Deterministic per-cell random, exposed so other systems (resource placement,
## AI camp siting) can make the same decisions on every client without needing
## to sync anything.
func cell_random(x: int, y: int, salt: int) -> float:
	return _rand01(x, y, salt)


func chunk_count() -> Vector2i:
	return Vector2i(_chunks_x, _chunks_y)


func chunk_root(cx: int, cy: int) -> Node3D:
	var i := cy * _chunks_x + cx
	if i < 0 or i >= _chunk_roots.size():
		return null
	return _chunk_roots[i]


# ═══════════════════════════════════════════════════════════════════════════════
#  FIELD PRE-PASS — every per-cell value computed once into flat packed arrays
# ═══════════════════════════════════════════════════════════════════════════════

func _prepare(world_node: Node3D) -> Dictionary:
	var grid_size: Vector2i = Constants.GRID_SIZE
	_W = grid_size.x
	_H = grid_size.y
	_chunks_x = int(ceil(float(_W) / float(CHUNK_CELLS)))
	_chunks_y = int(ceil(float(_H) / float(CHUNK_CELLS)))

	var n := _W * _H
	_zone.resize(n)
	_height.resize(n)
	_vcolor.resize(n)
	_is_path.resize(n)

	# 1. Road network first — height and colour both depend on it.
	var path_cells := _calculate_path_network(grid_size, grid_size / 2, _drop_coords)
	for i in range(n):
		_is_path[i] = 0
	for k in path_cells.keys():
		var p: Vector2i = k
		if p.x >= 0 and p.y >= 0 and p.x < _W and p.y < _H:
			_is_path[p.y * _W + p.x] = 1

	# 2. Zone + height.
	for y in range(_H):
		var row := y * _W
		for x in range(_W):
			var gp := Vector2i(x, y)
			var z: int = determine_zone(gp, grid_size)
			_zone[row + x] = z
			_height[row + x] = _calculate_height(x, y, z, path_cells)

	# 3. Vertex colour (needs the finished height field for the slope term).
	for y in range(_H):
		var row2 := y * _W
		for x in range(_W):
			_vcolor[row2 + x] = _compute_vertex_color(x, y)

	_field_ready = true

	# 4. Scene containers.
	var chunks := Node3D.new()
	chunks.name = "Chunks"
	world_node.add_child(chunks)

	var water := Node3D.new()
	water.name = "WaterSurfaces"
	world_node.add_child(water)

	var landmarks := Node3D.new()
	landmarks.name = "Landmarks"
	world_node.add_child(landmarks)

	_chunk_roots.clear()
	_chunk_roots.resize(_chunks_x * _chunks_y)
	_terrain_meshes.clear()
	_terrain_meshes.resize(_chunks_x * _chunks_y)

	return {"chunks": chunks, "water": water, "landmarks": landmarks}


# ═══════════════════════════════════════════════════════════════════════════════
#  CHUNK BUILD — terrain slab + instanced scatter + one collision body
# ═══════════════════════════════════════════════════════════════════════════════

func _build_chunk(parent: Node3D, chunk_index: int, with_collision: bool) -> Node3D:
	var cx := chunk_index % _chunks_x
	var cy := chunk_index / _chunks_x
	var tile := Constants.TILE_SIZE
	var center_grid: Vector2i = Constants.GRID_SIZE / 2

	var x0 := cx * CHUNK_CELLS
	var y0 := cy * CHUNK_CELLS
	var x1: int = min(x0 + CHUNK_CELLS, _W - 1)
	var y1: int = min(y0 + CHUNK_CELLS, _H - 1)
	if x0 >= x1 or y0 >= y1:
		return null

	# Chunk origin sits at the centre of its cell block, so per-chunk distance
	# culling and visibility ranges measure from somewhere sensible.
	var mid_gx := (x0 + x1) * 0.5
	var mid_gy := (y0 + y1) * 0.5
	var origin := Vector3(
		(mid_gx - float(center_grid.x)) * tile.x,
		0.0,
		(mid_gy - float(center_grid.y)) * tile.y)

	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [cx, cy]
	root.position = origin
	parent.add_child(root)
	_chunk_roots[chunk_index] = root

	# ── Terrain slab ──────────────────────────────────────────────────────────
	var terrain_mesh := _build_terrain_slab(x0, y0, x1, y1, origin)
	_terrain_meshes[chunk_index] = terrain_mesh

	var terrain_mi := MeshInstance3D.new()
	terrain_mi.name = "Terrain"
	terrain_mi.mesh = terrain_mesh
	terrain_mi.material_override = _terrain_material()
	terrain_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(terrain_mi)

	if with_collision:
		_attach_terrain_collision(root, terrain_mesh)

	# ── Scatter: one batcher per draw-distance layer ──────────────────────────
	var layers := {
		PropLibrary.Layer.CANOPY: Batcher.new(),
		PropLibrary.Layer.MIDGROUND: Batcher.new(),
		PropLibrary.Layer.DETAIL: Batcher.new(),
		PropLibrary.Layer.GROUND: Batcher.new(),
	}

	for gy in range(y0, y1):
		var row := gy * _W
		for gx in range(x0, x1):
			var zone: int = _zone[row + gx]
			var on_road: bool = _is_path[row + gx] != 0
			var wx: float = (float(gx) - float(center_grid.x)) * tile.x
			var wz: float = (float(gy) - float(center_grid.y)) * tile.y
			var wy: float = _height[row + gx]
			var local := Vector3(wx, wy, wz) - origin

			_scatter_cell(layers, gx, gy, zone, on_road, local)

	var made_batches := 0
	for layer in layers.keys():
		var b = layers[layer]
		if b.is_empty():
			continue
		made_batches += b.flush_visuals(root,
			PropLibrary.LAYER_RANGE[layer],
			PropLibrary.LAYER_FADE[layer],
			PropLibrary.LAYER_SHADOWS[layer],
			PropLibrary.LAYER_FAR_RANGE[layer],
			PropLibrary.LAYER_FAR_FRACTION[layer])
		if with_collision:
			b.flush_collision(root, 1, 1)

	return root


## Decide what (if anything) grows on one cell and push it into the batchers.
func _scatter_cell(layers: Dictionary, gx: int, gy: int, zone: int, on_road: bool, local: Vector3) -> void:
	var in_clearing := _in_clearing(gx, gy)

	# 1. Big scatter (trees, rocks, bushes...)
	var blocked: bool = in_clearing \
		or zone == Constants.ZoneType.CURSED_THRONE \
		or zone == Constants.ZoneType.RIVERBED
	if not blocked and not on_road:
		var density := PropLibrary.density_for(zone)
		if density > 0.0:
			# Thin out props near a biome border so zones bleed instead of ending
			# in a hard wall of trees.
			var border := _border_blend(gx, gy, zone)
			density *= (1.0 - border * 0.40)
			if _rand01(gx, gy, 11) < density:
				var key := PropLibrary.pick_for_biome(zone, _rand01(gx, gy, 23))
				if key != "":
					_place(layers, key, gx, gy, local, 31)

	# 2. Riverbank detail — reeds, lilies, driftwood at the water's edge.
	if zone == Constants.ZoneType.RIVERBED and _is_riverbank_cell(gx, gy):
		if _rand01(gx, gy, 43) < 0.22:
			var rkey := PropLibrary.pick_river_edge(_rand01(gx, gy, 47))
			if rkey != "":
				var lp := local
				if rkey == "lily_pad":
					lp.y = -0.04 - local.y + local.y  # lilies float on the surface
					lp = Vector3(local.x, -0.04, local.z)
				_place(layers, rkey, gx, gy, lp, 53)

	# 3. Roadside furniture — lanterns, signs, carts along the radial roads.
	if on_road and (gx % 13 == 0 or gy % 13 == 0) and _rand01(gx, gy, 59) < 0.30:
		var r := _rand01(gx, gy, 61)
		var road_key := "torch_post"
		if r < 0.40: road_key = "torch_post"
		elif r < 0.68: road_key = "lantern_post"
		elif r < 0.85: road_key = "sign"
		else: road_key = "trail_marker"
		_place(layers, road_key, gx, gy, local, 67)

	# 4. Ground cover — grass, flowers, pebbles. Never on the road surface.
	if not on_road:
		var chance := PropLibrary.cover_chance(zone)
		if chance > 0.0 and _rand01(gx, gy, 71) < chance:
			var ckey := PropLibrary.pick_cover(zone, _rand01(gx, gy, 73))
			if ckey != "":
				_place(layers, ckey, gx, gy, local, 79)
				# A second, offset tuft on a fraction of cells breaks up the grid.
				if _rand01(gx, gy, 83) < 0.45:
					_place(layers, ckey, gx, gy, local, 89)


func _place(layers: Dictionary, key: String, gx: int, gy: int, local: Vector3, salt: int) -> void:
	var d := PropLibrary.def(key)
	if d.is_empty():
		return
	var variant := int(_rand01(gx, gy, salt + 1) * float(PropLibrary.VARIANTS))
	var tpl := PropLibrary.template(key, variant)
	if tpl.is_empty() or tpl.get("mesh") == null:
		return

	var sc_range: Array = d.scale
	var s: float = lerp(float(sc_range[0]), float(sc_range[1]), _rand01(gx, gy, salt + 2))
	var yaw: float = _rand01(gx, gy, salt + 3) * TAU
	# Sub-cell jitter so nothing lines up on the lattice.
	var jx: float = (_rand01(gx, gy, salt + 4) - 0.5) * Constants.TILE_SIZE.x * 0.85
	var jz: float = (_rand01(gx, gy, salt + 5) - 0.5) * Constants.TILE_SIZE.y * 0.85

	var xf := Transform3D(Basis.IDENTITY, local + Vector3(jx, 0.0, jz))
	xf.basis = Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))

	var t_range: Array = d.tint
	var t: float = lerp(float(t_range[0]), float(t_range[1]), _rand01(gx, gy, salt + 6))
	# A touch of independent hue drift keeps a forest from looking like one
	# tree brightened up and down.
	var hue_drift: float = (_rand01(gx, gy, salt + 7) - 0.5) * 0.10
	var tint := Color(
		clamp(t - hue_drift * 0.5, 0.0, 2.0),
		clamp(t + hue_drift, 0.0, 2.0),
		clamp(t - hue_drift, 0.0, 2.0), 1.0)

	var layer: int = d.layer
	layers[layer].add_template(tpl, xf, tint, bool(d.solid))


# ═══════════════════════════════════════════════════════════════════════════════
#  TERRAIN SLAB — direct packed-array mesh build with analytic normals so
#  neighbouring chunks share exactly the same normal at their seam.
# ═══════════════════════════════════════════════════════════════════════════════

func _build_terrain_slab(x0: int, y0: int, x1: int, y1: int, origin: Vector3) -> ArrayMesh:
	var tile := Constants.TILE_SIZE
	var center_grid: Vector2i = Constants.GRID_SIZE / 2
	var vw := x1 - x0 + 1
	var vh := y1 - y0 + 1
	var vcount := vw * vh

	var verts := PackedVector3Array(); verts.resize(vcount)
	var norms := PackedVector3Array(); norms.resize(vcount)
	var cols := PackedColorArray(); cols.resize(vcount)
	var uvs := PackedVector2Array(); uvs.resize(vcount)

	var inv_dx: float = 1.0 / (2.0 * tile.x)
	var inv_dz: float = 1.0 / (2.0 * tile.y)

	for j in range(vh):
		var gy := y0 + j
		for i in range(vw):
			var gx := x0 + i
			var idx := j * vw + i
			var wx: float = (float(gx) - float(center_grid.x)) * tile.x
			var wz: float = (float(gy) - float(center_grid.y)) * tile.y
			var wy := height_at(gx, gy)
			verts[idx] = Vector3(wx, wy, wz) - origin

			var hl := height_at(gx - 1, gy)
			var hr := height_at(gx + 1, gy)
			var hu := height_at(gx, gy - 1)
			var hd := height_at(gx, gy + 1)
			norms[idx] = Vector3((hl - hr) * inv_dx, 1.0, (hu - hd) * inv_dz).normalized()

			cols[idx] = _vcolor[gy * _W + gx]
			uvs[idx] = Vector2(wx, wz) * 0.5

	var indices := PackedInt32Array()
	indices.resize((vw - 1) * (vh - 1) * 6)
	var k := 0
	for j in range(vh - 1):
		for i in range(vw - 1):
			var a := j * vw + i
			var b := a + 1
			var c := a + vw
			var d := c + 1
			indices[k] = a; indices[k + 1] = b; indices[k + 2] = d
			indices[k + 3] = a; indices[k + 4] = d; indices[k + 5] = c
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _attach_terrain_collision(root: Node3D, mesh: ArrayMesh) -> StaticBody3D:
	if mesh == null:
		return null
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	root.add_child(body)
	return body


## Build (or free) a chunk's terrain collision on demand — only chunks near a
## living entity need to be solid.
func set_chunk_collision(chunk_index: int, enabled: bool) -> void:
	if chunk_index < 0 or chunk_index >= _chunk_roots.size():
		return
	var root: Node3D = _chunk_roots[chunk_index]
	if root == null:
		return
	var existing := root.get_node_or_null("TerrainCollision")
	if enabled and existing == null:
		_attach_terrain_collision(root, _terrain_meshes[chunk_index])
	elif not enabled and existing != null:
		existing.queue_free()


var _terrain_mat: ShaderMaterial = null

func _terrain_material() -> ShaderMaterial:
	if _terrain_mat == null:
		_terrain_mat = ShaderMaterial.new()
		_terrain_mat.shader = TERRAIN_SHADER
	return _terrain_mat


# ═══════════════════════════════════════════════════════════════════════════════
#  LANDMARKS — one-off hero pieces. Few enough to stay as real nodes.
# ═══════════════════════════════════════════════════════════════════════════════

func _build_landmarks(container: Node3D) -> void:
	var tile := Constants.TILE_SIZE
	var center_grid: Vector2i = Constants.GRID_SIZE / 2

	# Landmarks are one-offs, so they stay real nodes — but they are baked too,
	# because a squad camp is ~40 MeshInstance3D children out of the factory and
	# eight of them was 320 draw calls for scenery nobody stands next to.
	_place_landmark(container, "throne", func(): return PropFactory.build_cursed_throne(),
			Vector3(0, 0.4, 0), 0.0)

	var skel_spots := [Vector2i(50, -30), Vector2i(-45, 40)]
	for i in range(skel_spots.size()):
		var sp: Vector2i = skel_spots[i]
		_place_landmark(container, "skeleton", func(): return PropFactory.build_beast_skeleton(),
				Vector3(sp.x * tile.x, 0.0, sp.y * tile.y), float(i) * 1.1)

	var squad_colors = [
		Color(0.85, 0.25, 0.20), Color(0.20, 0.55, 0.90),
		Color(0.25, 0.80, 0.35), Color(0.90, 0.75, 0.15),
		Color(0.80, 0.30, 0.85), Color(0.15, 0.85, 0.80),
		Color(0.90, 0.50, 0.15), Color(0.60, 0.65, 0.70),
	]
	for i in range(_drop_coords.size()):
		var dc: Vector2i = _drop_coords[i]
		var col: Color = squad_colors[i]
		_place_landmark(container, "camp_%d" % i, func(): return PropFactory.build_squad_camp(col),
				Vector3((dc.x - center_grid.x) * tile.x, height_at(dc.x, dc.y),
						(dc.y - center_grid.y) * tile.y), 0.0)

	for z_off in [-8.0, 8.0]:
		_place_landmark(container, "arch", func(): return PropFactory.build_ruined_arch(),
				Vector3(0, 0.4, z_off), 0.0)

	for vx in [-40, 40]:
		_place_landmark(container, "vendor", func(): return PropFactory.build_vendor_stall(false),
				Vector3(vx * tile.x, height_at(center_grid.x + vx, center_grid.y), 0.0), 0.0)

	for spec2 in [Vector2i(-30, -30), Vector2i(30, 30)]:
		_place_landmark(container, "stone_circle", func(): return PropFactory.build_stone_circle(),
				Vector3(spec2.x * tile.x,
						height_at(center_grid.x + spec2.x, center_grid.y + spec2.y),
						spec2.y * tile.y), 0.0)


func _place_landmark(container: Node3D, key: String, builder: Callable,
		pos: Vector3, yaw: float) -> Node3D:
	var tpl := Baker.get_template("landmark_" + key, builder, 0)
	if tpl.is_empty() or tpl.get("mesh") == null:
		return null
	var node := Baker.instantiate(tpl, true, true, "Landmark_" + key)
	node.position = pos
	node.rotation.y = yaw
	container.add_child(node)
	return node


# ═══════════════════════════════════════════════════════════════════════════════
#  HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

## Cells inside a clearing get no scattered props at all. Squads spawn into a
## usable camp instead of the inside of a tree, and hero landmarks stay readable
## instead of being swallowed by the canopy.
const CLEARING_SPOTS := [
	# [grid_x, grid_y, radius_in_cells]
	[100, 100, 9],                 # Cursed Throne plaza
	[60, 100, 5], [140, 100, 5],   # NPC vendor stalls
	[70, 70, 4], [130, 130, 4],    # ancient stone circles
]
const DROP_ZONE_CLEAR_RADIUS := 8


## True when this cell must stay empty of scatter.
func _in_clearing(gx: int, gy: int) -> bool:
	for dc in _drop_coords:
		var dx: int = gx - dc.x
		var dy: int = gy - dc.y
		if dx * dx + dy * dy <= DROP_ZONE_CLEAR_RADIUS * DROP_ZONE_CLEAR_RADIUS:
			return true
	for spot in CLEARING_SPOTS:
		var ex: int = gx - int(spot[0])
		var ey: int = gy - int(spot[1])
		var r: int = int(spot[2])
		if ex * ex + ey * ey <= r * r:
			return true
	return false


## Cheap deterministic per-cell random in [0,1). Deterministic means the map is
## identical for every client and reproducible in bug reports.
func _rand01(x: int, y: int, salt: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + salt * 2246822519 + _world_seed
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7FFFFFFF) / 2147483647.0


func _is_riverbank_cell(gx: int, gy: int) -> bool:
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if zone_at(gx + off.x, gy + off.y) != Constants.ZoneType.RIVERBED:
			return true
	return false


## 0 = deep inside a biome, 1 = right on a border. Used to thin prop density so
## biomes fade into each other.
func _border_blend(gx: int, gy: int, own_zone: int) -> float:
	for off in CLOSE_OFFSETS:
		if zone_at(gx + off.x, gy + off.y) != own_zone:
			return 0.60
	for off2 in FAR_OFFSETS:
		if zone_at(gx + off2.x, gy + off2.y) != own_zone:
			return 0.28
	return 0.0


func _compute_vertex_color(x: int, y: int) -> Color:
	var gp := Vector2i(x, y)
	var zone: int = _zone[y * _W + x]

	if zone == Constants.ZoneType.CURSED_THRONE:
		return COLOR_THRONE.lerp(Color(0.30, 0.24, 0.36), _hash01(x, y) * 0.25)
	if zone == Constants.ZoneType.DROP_ZONE:
		var dz_jitter: float = (_hash01(x, y) - 0.5) * 0.10
		return Color(
			clamp(COLOR_DROP_ZONE.r + dz_jitter, 0.0, 1.0),
			clamp(COLOR_DROP_ZONE.g + dz_jitter, 0.0, 1.0),
			clamp(COLOR_DROP_ZONE.b + dz_jitter, 0.0, 1.0))

	var pos := Vector2(x, y)
	var weights := _biome_weights(pos)
	var col: Color = COLOR_FOREST * weights.forest \
		+ COLOR_CLEARING * weights.clearing \
		+ COLOR_HIGHLAND * weights.highland \
		+ COLOR_SWAMP * weights.swamp

	col = col.lerp(COLOR_RIVERBED, _river_bank_blend(pos))

	var slope := _slope_at_xy(x, y)
	col = col.lerp(COLOR_HIGHLAND * 0.85, clamp(slope * 1.8, 0.0, 0.55))

	col = col.lerp(COLOR_PATH, _path_blend_xy(x, y))

	var micro: float = (_hash01(x * 7 + 3, y * 7 + 11) - 0.5) * 0.06
	return Color(
		clamp(col.r + micro, 0.0, 1.0),
		clamp(col.g + micro * 0.9, 0.0, 1.0),
		clamp(col.b + micro * 0.8, 0.0, 1.0))


func _slope_at_xy(x: int, y: int) -> float:
	var h0 := height_at(x, y)
	return abs(height_at(x + 1, y) - h0) + abs(height_at(x, y + 1) - h0)


func _path_blend_xy(x: int, y: int) -> float:
	var count := 0
	for ox in range(-2, 3):
		for oy in range(-2, 3):
			if is_road(x + ox, y + oy):
				count += 1
	return float(count) / 25.0


# ═══════════════════════════════════════════════════════════════════════════════
#  PRESERVED LANDSCAPE MATHS — river geometry, road network, elevation, biome
#  weighting and zone classification are unchanged from v4. This is the design
#  of the world; only its rendering strategy was rebuilt above.
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
			plane.size = Vector2((w + 0.8) * tile_dim.x, float(y_end - y) * tile_dim.y + 0.30)
			seg.mesh = plane
			seg.material_override = water_mat
			seg.position = Vector3(
				(cx - center_grid.x) * tile_dim.x, -0.22,
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
			bridge.position = Vector3((c.x - center_grid.x) * tile_dim.x, 0.0, (c.y - center_grid.y) * tile_dim.y)
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

func _river_distance(pos: Vector2) -> float:
	var min_d := 9999.0
	for side in [-1, 1]:
		var cx = _river_center(pos.y, side)
		var w = _river_width(pos.y, side)
		var d = abs(pos.x - cx) - (w * 0.5)
		min_d = min(min_d, d)
	return min_d

func _calculate_height(x: int, y: int, zone: Constants.ZoneType, path_cells: Dictionary = {}) -> float:
	var base_n = _elev_noise.get_noise_2d(float(x), float(y))
	var det_n = _detail_noise.get_noise_2d(float(x), float(y)) * 0.10
	var hill_n = max(_hill_noise.get_noise_2d(float(x), float(y)), 0.0) # only positive lobes read as hills

	var base_h := 0.0
	match zone:
		Constants.ZoneType.ROCKY_HIGHLANDS:
			base_h = 0.6 + abs(base_n) * 1.3 + det_n + hill_n * 0.6
		Constants.ZoneType.CURSED_THRONE:
			base_h = 0.4
		Constants.ZoneType.RIVERBED:
			base_h = -0.48
		Constants.ZoneType.SWAMP:
			base_h = -0.06 + base_n * 0.10
		Constants.ZoneType.DENSE_FOREST:
			base_h = abs(base_n) * 0.35 + det_n + hill_n * 1.4
		Constants.ZoneType.OPEN_CLEARING:
			base_h = abs(det_n * 0.5) + hill_n * 1.1
		Constants.ZoneType.DROP_ZONE:
			base_h = hill_n * 0.4
		_:
			base_h = hill_n * 0.9

	# Continuous smooth riverbank slope into riverbed trench
	var r_dist = _river_distance(Vector2(float(x), float(y)))
	if r_dist < 4.0:
		var bank_factor = clamp((r_dist + 1.0) / 5.0, 0.0, 1.0)
		return lerp(-0.48, base_h, bank_factor)

	return base_h


# ═══════════════════════════════════════════════════════════════════════════════
#  BIOME BORDER BLENDING — soft dithered transition between neighboring zones
# ═══════════════════════════════════════════════════════════════════════════════

func _hash01(x: int, y: int) -> float:
	var n = sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
	return fmod(abs(n), 1.0)


# ═══════════════════════════════════════════════════════════════════════════════
#  CONTINUOUS TERRAIN MESH — one SurfaceTool-built ground mesh for the entire
#  map. Per-vertex height (already computed in height_grid) plus a smoothly
#  weighted per-vertex biome color, so slopes and biome borders read as a real
#  continuous landscape instead of a grid of flat colored boxes.
# ═══════════════════════════════════════════════════════════════════════════════

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
