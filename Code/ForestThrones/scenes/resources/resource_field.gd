extends Node3D
class_name ResourceField

## ═══════════════════════════════════════════════════════════════════════════════
##  RESOURCE FIELD — every harvestable node on the map, as data instead of nodes.
##
##  GDD §5 gives six resources with different yields, hit counts and respawn
##  timers, scattered by biome. The old implementation spawned one StaticBody3D
##  per resource, each instantiating a full PropFactory tree — roughly 1,800
##  bodies and 23,000 MeshInstance3D children for a single map.
##
##  Here each resource is a RECORD in packed arrays. Rendering is one MultiMesh
##  per (chunk, resource type), collision is one StaticBody3D per chunk, and
##  lookup is a spatial hash so "what can I harvest from here" is O(1) instead
##  of a scan over every node in the world.
##
##  Harvesting still animates: the MultiMesh instance's transform is written
##  directly, which is cheaper than tweening a node and works identically.
## ═══════════════════════════════════════════════════════════════════════════════

const PropFactory = preload("res://scenes/world/prop_factory.gd")
const Baker = preload("res://scripts/render/prop_baker.gd")
const Batcher = preload("res://scripts/render/chunk_batcher.gd")

## Spatial hash cell size in world units. Interaction radius is ~2.5, so a
## 4-unit cell means a query touches at most 4 cells.
const HASH_CELL := 4.0

## Which prop represents each resource, and its harvest economy (GDD §5).
const RESOURCE_DEFS := {
	Constants.ResourceType.WOOD:  {"prop": "res_wood",  "amount": 3, "hits": 5, "respawn": 60.0,  "scale": [0.9, 1.3]},
	Constants.ResourceType.STONE: {"prop": "res_stone", "amount": 2, "hits": 4, "respawn": 90.0,  "scale": [0.8, 1.3]},
	Constants.ResourceType.FOOD:  {"prop": "res_food",  "amount": 1, "hits": 2, "respawn": 45.0,  "scale": [0.85, 1.2]},
	Constants.ResourceType.METAL: {"prop": "res_metal", "amount": 1, "hits": 6, "respawn": 120.0, "scale": [0.9, 1.2]},
	Constants.ResourceType.HERBS: {"prop": "res_herbs", "amount": 1, "hits": 2, "respawn": 80.0,  "scale": [0.85, 1.25]},
}

## Per-biome spawn chances (GDD §3: the throne has no natural resources).
const BIOME_SPAWN := {
	Constants.ZoneType.DENSE_FOREST: [
		[Constants.ResourceType.WOOD, 0.055], [Constants.ResourceType.FOOD, 0.012],
	],
	Constants.ZoneType.OPEN_CLEARING: [
		[Constants.ResourceType.FOOD, 0.045], [Constants.ResourceType.WOOD, 0.014],
	],
	Constants.ZoneType.ROCKY_HIGHLANDS: [
		[Constants.ResourceType.STONE, 0.048], [Constants.ResourceType.METAL, 0.012],
	],
	Constants.ZoneType.SWAMP: [
		[Constants.ResourceType.HERBS, 0.060], [Constants.ResourceType.FOOD, 0.014],
	],
	Constants.ZoneType.DROP_ZONE: [
		[Constants.ResourceType.WOOD, 0.030], [Constants.ResourceType.FOOD, 0.020],
	],
}

enum State { AVAILABLE, DEPLETED, RESPAWNING }

# ── Records (parallel arrays; index = record id) ───────────────────────────────
var _r_type := PackedInt32Array()
var _r_state := PackedInt32Array()
var _r_hits := PackedInt32Array()
var _r_max_hits := PackedInt32Array()
var _r_amount := PackedInt32Array()
var _r_respawn_at := PackedFloat32Array()
var _r_respawn_time := PackedFloat32Array()
var _r_pos := PackedVector3Array()
var _r_batch := PackedInt32Array()      # index into _batch_mm
var _r_slot := PackedInt32Array()       # instance index inside that MultiMesh
var _r_scale := PackedFloat32Array()
var _r_yaw := PackedFloat32Array()

var _batch_mm: Array[MultiMesh] = []
var _batch_origin: Array[Vector3] = []

var _hash := {}                          # Vector2i cell -> PackedInt32Array of ids
var _respawn_queue: Array[int] = []
var _elapsed := 0.0

var stats := {"records": 0, "batches": 0, "build_ms": 0}


# ═══════════════════════════════════════════════════════════════════════════════
#  BUILD
# ═══════════════════════════════════════════════════════════════════════════════

func build(map_generator, chunk_cells: int) -> void:
	var t0 := Time.get_ticks_msec()
	var grid: Vector2i = Constants.GRID_SIZE
	var tile: Vector2 = Constants.TILE_SIZE
	var center := grid / 2
	var chunks_x := int(ceil(float(grid.x) / float(chunk_cells)))
	var chunks_y := int(ceil(float(grid.y) / float(chunk_cells)))

	_warm_templates()

	for cy in range(chunks_y):
		for cx in range(chunks_x):
			var x0 := cx * chunk_cells
			var y0 := cy * chunk_cells
			var x1: int = min(x0 + chunk_cells, grid.x)
			var y1: int = min(y0 + chunk_cells, grid.y)

			var origin := Vector3(
				((float(x0 + x1) * 0.5) - float(center.x)) * tile.x, 0.0,
				((float(y0 + y1) * 0.5) - float(center.y)) * tile.y)

			var chunk_root := Node3D.new()
			chunk_root.name = "ResChunk_%d_%d" % [cx, cy]
			chunk_root.position = origin
			add_child(chunk_root)

			# type -> { xforms, ids }
			var pending := {}
			var body_shapes: Array = []

			for gy in range(y0, y1):
				for gx in range(x0, x1):
					var zone: int = map_generator.zone_at(gx, gy)
					var table = BIOME_SPAWN.get(zone, null)
					if table == null:
						continue
					var roll: float = map_generator.cell_random(gx, gy, 401)
					var acc := 0.0
					var chosen := -1
					for row in table:
						acc += float(row[1])
						if roll < acc:
							chosen = int(row[0])
							break
					if chosen < 0:
						continue

					var wx: float = (float(gx) - float(center.x)) * tile.x
					var wz: float = (float(gy) - float(center.y)) * tile.y
					var wy: float = map_generator.height_at(gx, gy)
					var jx: float = (map_generator.cell_random(gx, gy, 403) - 0.5) * tile.x * 0.7
					var jz: float = (map_generator.cell_random(gx, gy, 407) - 0.5) * tile.y * 0.7
					var world_pos := Vector3(wx + jx, wy, wz + jz)

					if not pending.has(chosen):
						pending[chosen] = {"xforms": [], "ids": []}

					var d: Dictionary = RESOURCE_DEFS[chosen]
					var sc: float = lerp(float(d.scale[0]), float(d.scale[1]),
							map_generator.cell_random(gx, gy, 409))
					var yaw: float = map_generator.cell_random(gx, gy, 411) * TAU

					var id := _add_record(chosen, world_pos, sc, yaw, d)
					var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc)),
							world_pos - origin)
					pending[chosen].xforms.append(xf)
					pending[chosen].ids.append(id)

					var cyl := CylinderShape3D.new()
					cyl.radius = 0.42 * sc
					cyl.height = 1.7 * sc
					body_shapes.append({"shape": cyl,
							"xform": Transform3D(Basis.IDENTITY,
									world_pos - origin + Vector3(0, 0.85 * sc, 0))})

			# Flush this chunk's MultiMeshes.
			for rtype in pending.keys():
				var entry: Dictionary = pending[rtype]
				var tpl := _template_for(rtype)
				if tpl.is_empty() or tpl.get("mesh") == null:
					continue
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_colors = true
				mm.mesh = tpl.mesh
				mm.instance_count = entry.xforms.size()
				for k in range(entry.xforms.size()):
					mm.set_instance_transform(k, entry.xforms[k])
					mm.set_instance_color(k, Color.WHITE)
					var rid: int = entry.ids[k]
					_r_batch[rid] = _batch_mm.size()
					_r_slot[rid] = k

				var mmi := MultiMeshInstance3D.new()
				mmi.name = "Res_%d" % rtype
				mmi.multimesh = mm
				mmi.visibility_range_end = 70.0
				mmi.visibility_range_end_margin = 14.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				chunk_root.add_child(mmi)

				_batch_mm.append(mm)
				_batch_origin.append(origin)

			if not body_shapes.is_empty():
				var body := StaticBody3D.new()
				body.name = "ResourceCollision"
				body.collision_layer = 1
				body.collision_mask = 1
				for bs in body_shapes:
					var cs := CollisionShape3D.new()
					cs.shape = bs.shape
					cs.transform = bs.xform
					body.add_child(cs)
				chunk_root.add_child(body)

	_build_hash()
	stats.records = _r_type.size()
	stats.batches = _batch_mm.size()
	stats.build_ms = Time.get_ticks_msec() - t0


func _add_record(rtype: int, pos: Vector3, sc: float, yaw: float, d: Dictionary) -> int:
	var id := _r_type.size()
	_r_type.append(rtype)
	_r_state.append(State.AVAILABLE)
	_r_hits.append(int(d.hits))
	_r_max_hits.append(int(d.hits))
	_r_amount.append(int(d.amount))
	_r_respawn_at.append(0.0)
	_r_respawn_time.append(float(d.respawn))
	_r_pos.append(pos)
	_r_batch.append(-1)
	_r_slot.append(-1)
	_r_scale.append(sc)
	_r_yaw.append(yaw)
	return id


func _build_hash() -> void:
	_hash.clear()
	for id in range(_r_pos.size()):
		var cell := _cell_of(_r_pos[id])
		if not _hash.has(cell):
			_hash[cell] = PackedInt32Array()
		_hash[cell].append(id)


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / HASH_CELL)), int(floor(p.z / HASH_CELL)))


# ═══════════════════════════════════════════════════════════════════════════════
#  QUERY & HARVEST
# ═══════════════════════════════════════════════════════════════════════════════

## Nearest harvestable record within `radius` of `world_pos`, or -1.
## `want_type` of -1 accepts any resource.
func find_nearest(world_pos: Vector3, radius: float = 2.6, want_type: int = -1) -> int:
	var best := -1
	var best_d := radius * radius
	var c := _cell_of(world_pos)
	var span := int(ceil(radius / HASH_CELL))
	for ox in range(-span, span + 1):
		for oz in range(-span, span + 1):
			var bucket = _hash.get(c + Vector2i(ox, oz), null)
			if bucket == null:
				continue
			for id in bucket:
				if _r_state[id] != State.AVAILABLE:
					continue
				if want_type >= 0 and _r_type[id] != want_type:
					continue
				var d: float = world_pos.distance_squared_to(_r_pos[id])
				if d < best_d:
					best_d = d
					best = id
	return best


func type_of(id: int) -> int:
	return _r_type[id] if id >= 0 and id < _r_type.size() else -1


func position_of(id: int) -> Vector3:
	return _r_pos[id] if id >= 0 and id < _r_pos.size() else Vector3.ZERO


func is_available(id: int) -> bool:
	return id >= 0 and id < _r_state.size() and _r_state[id] == State.AVAILABLE


## Deal one harvest hit. Returns true if the node was depleted by this hit.
func harvest(id: int, harvester: Node = null, rate: float = 1.0) -> bool:
	if id < 0 or id >= _r_state.size() or _r_state[id] != State.AVAILABLE:
		return false

	_r_hits[id] -= max(1, int(round(rate)))
	_shake(id)

	if _r_hits[id] > 0:
		return false

	_r_state[id] = State.DEPLETED
	_set_instance_scale(id, 0.0)

	if harvester and harvester.has_method("add_resource"):
		harvester.add_resource(_r_type[id], _r_amount[id])
	EventBus.resource_harvested.emit(_r_type[id], _r_amount[id], _r_pos[id])

	_r_state[id] = State.RESPAWNING
	_r_respawn_at[id] = _elapsed + _r_respawn_time[id]
	_respawn_queue.append(id)
	return true


func _process(delta: float) -> void:
	_elapsed += delta
	if _respawn_queue.is_empty():
		return
	# Respawns are rare, so walk the queue back-to-front and pop finished ones.
	var i := _respawn_queue.size() - 1
	while i >= 0:
		var id: int = _respawn_queue[i]
		if _elapsed >= _r_respawn_at[id]:
			_r_state[id] = State.AVAILABLE
			_r_hits[id] = _r_max_hits[id]
			_set_instance_scale(id, _r_scale[id])
			_respawn_queue.remove_at(i)
		i -= 1


func _set_instance_scale(id: int, s: float) -> void:
	var b: int = _r_batch[id]
	var slot: int = _r_slot[id]
	if b < 0 or slot < 0 or b >= _batch_mm.size():
		return
	var mm: MultiMesh = _batch_mm[b]
	var local: Vector3 = _r_pos[id] - _batch_origin[b]
	var basis := Basis(Vector3.UP, _r_yaw[id]).scaled(Vector3(s, s, s))
	mm.set_instance_transform(slot, Transform3D(basis, local))


func _shake(id: int) -> void:
	# A quick squash on the instance transform reads as a chop/mine impact and
	# costs one matrix write instead of a tween on a node.
	var b: int = _r_batch[id]
	var slot: int = _r_slot[id]
	if b < 0 or slot < 0 or b >= _batch_mm.size():
		return
	var mm: MultiMesh = _batch_mm[b]
	var local: Vector3 = _r_pos[id] - _batch_origin[b]
	var s: float = _r_scale[id]
	var squash := Basis(Vector3.UP, _r_yaw[id] + randf_range(-0.12, 0.12)) \
			.scaled(Vector3(s * 1.12, s * 0.88, s * 1.12))
	mm.set_instance_transform(slot, Transform3D(squash, local))
	var tw := create_tween()
	tw.tween_interval(0.08)
	tw.tween_callback(func():
		if _r_state[id] == State.AVAILABLE:
			_set_instance_scale(id, s))


# ═══════════════════════════════════════════════════════════════════════════════
#  TEMPLATES
# ═══════════════════════════════════════════════════════════════════════════════

static func _warm_templates() -> void:
	for rtype in RESOURCE_DEFS.keys():
		_template_for(rtype)


static func _template_for(rtype: int) -> Dictionary:
	match rtype:
		Constants.ResourceType.WOOD:
			return Baker.get_template("res_wood", func(): return PropFactory.build_tree("oak"), 0)
		Constants.ResourceType.STONE:
			return Baker.get_template("res_stone", func(): return PropFactory.build_rock("boulder"), 0)
		Constants.ResourceType.FOOD:
			return Baker.get_template("res_food", func(): return PropFactory.build_berry_bush(), 0)
		Constants.ResourceType.METAL:
			return Baker.get_template("res_metal", func(): return PropFactory.build_rock("ore_vein"), 0)
		Constants.ResourceType.HERBS:
			return Baker.get_template("res_herbs", func(): return PropFactory.build_herb_plant(), 0)
	return {}
