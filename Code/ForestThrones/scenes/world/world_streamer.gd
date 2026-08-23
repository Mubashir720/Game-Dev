extends Node
class_name WorldStreamer

## ═══════════════════════════════════════════════════════════════════════════════
##  WORLD STREAMER — keeps only the part of the map that matters "live".
##
##  The map is cut into chunks by MapGenerator. Rendering already culls them by
##  frustum and distance, but PHYSICS does not: every tree collider and every
##  square metre of terrain collision stays in the broadphase whether or not
##  anyone is near it. With 32 players, 8 squads of structures and a few dozen
##  beasts all querying physics, that is real, avoidable CPU.
##
##  This node keeps a set of "anchors" (the local player, AI squads, active
##  beasts) and enables collision only for chunks within COLLISION_RADIUS of an
##  anchor. Chunks outside it keep rendering — the world still looks whole —
##  they just stop taking part in physics until someone walks back toward them.
##
##  It also owns the far-visibility cut: chunks beyond HIDE_RADIUS from every
##  anchor are hidden outright, which matters when 8 squads are spread over a
##  400 x 400 unit map and no single camera can see most of it.
## ═══════════════════════════════════════════════════════════════════════════════

## Chunks within this distance (in chunk units, Chebyshev) of any anchor are solid.
@export var collision_radius: int = 2
## Chunks beyond this distance from every anchor are hidden entirely.
@export var hide_radius: int = 4
## Seconds between streaming passes. Chunks are 40 units across and players move
## at ~6 u/s, so a quarter-second cadence is far more often than needed.
@export var update_interval: float = 0.25

var _map_gen = null
var _anchors: Array[Node3D] = []
var _chunks_x := 0
var _chunks_y := 0
var _chunk_size_world := 40.0
var _timer := 0.0
var _solid := {}      # chunk index -> bool
var _visible := {}    # chunk index -> bool
var _enabled := true

var stats := {"solid": 0, "visible": 0, "hidden": 0, "last_pass_us": 0}


func setup(map_generator, chunk_cells: int) -> void:
	_map_gen = map_generator
	var c: Vector2i = map_generator.chunk_count()
	_chunks_x = c.x
	_chunks_y = c.y
	_chunk_size_world = float(chunk_cells) * Constants.TILE_SIZE.x
	_solid.clear()
	_visible.clear()
	# Everything starts solid and visible; the first pass trims it down.
	for i in range(_chunks_x * _chunks_y):
		_solid[i] = true
		_visible[i] = true


func add_anchor(n: Node3D) -> void:
	if n != null and not _anchors.has(n):
		_anchors.append(n)


func remove_anchor(n: Node3D) -> void:
	_anchors.erase(n)


func set_enabled(v: bool) -> void:
	_enabled = v
	if not v:
		_restore_all()


func _process(delta: float) -> void:
	if not _enabled or _map_gen == null:
		return
	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0
	_pass()


func _pass() -> void:
	var t0 := Time.get_ticks_usec()

	# Anchors can be freed between passes (a player dies, a beast despawns).
	var live: Array[Vector2i] = []
	var i := _anchors.size() - 1
	while i >= 0:
		var a := _anchors[i]
		if not is_instance_valid(a):
			_anchors.remove_at(i)
		else:
			live.append(_chunk_coord_of(a.global_position))
		i -= 1

	if live.is_empty():
		return

	var solid_count := 0
	var visible_count := 0
	var hidden_count := 0

	for cy in range(_chunks_y):
		for cx in range(_chunks_x):
			var idx := cy * _chunks_x + cx
			var nearest := 9999
			for lc in live:
				var d: int = max(abs(cx - lc.x), abs(cy - lc.y))
				if d < nearest:
					nearest = d
					if nearest == 0:
						break

			var want_solid := nearest <= collision_radius
			var want_visible := nearest <= hide_radius

			if _solid.get(idx, true) != want_solid:
				_solid[idx] = want_solid
				_set_chunk_solid(idx, want_solid)

			if _visible.get(idx, true) != want_visible:
				_visible[idx] = want_visible
				var root: Node3D = _map_gen.chunk_root(cx, cy)
				if root:
					root.visible = want_visible

			if want_solid: solid_count += 1
			if want_visible: visible_count += 1
			else: hidden_count += 1

	stats.solid = solid_count
	stats.visible = visible_count
	stats.hidden = hidden_count
	stats.last_pass_us = Time.get_ticks_usec() - t0


func _set_chunk_solid(idx: int, solid: bool) -> void:
	var cx := idx % _chunks_x
	var cy := idx / _chunks_x
	var root: Node3D = _map_gen.chunk_root(cx, cy)
	if root == null:
		return
	# Terrain collision is a trimesh — expensive to keep in the broadphase, and
	# cheap to rebuild, so it is created and freed on demand.
	_map_gen.set_chunk_collision(idx, solid)
	# Prop colliders (trees, rocks) stay allocated but drop out of every layer
	# and mask, which removes them from broadphase without a rebuild cost.
	for child in root.get_children():
		if child is StaticBody3D and child.name.begins_with("ChunkCollision"):
			child.collision_layer = 1 if solid else 0
			child.collision_mask = 1 if solid else 0


func _restore_all() -> void:
	for cy in range(_chunks_y):
		for cx in range(_chunks_x):
			var idx := cy * _chunks_x + cx
			_solid[idx] = true
			_visible[idx] = true
			_set_chunk_solid(idx, true)
			var root: Node3D = _map_gen.chunk_root(cx, cy)
			if root:
				root.visible = true


func _chunk_coord_of(world_pos: Vector3) -> Vector2i:
	var half_world: float = float(Constants.GRID_SIZE.x) * Constants.TILE_SIZE.x * 0.5
	var cx := int(floor((world_pos.x + half_world) / _chunk_size_world))
	var cy := int(floor((world_pos.z + half_world) / _chunk_size_world))
	return Vector2i(clamp(cx, 0, _chunks_x - 1), clamp(cy, 0, _chunks_y - 1))
