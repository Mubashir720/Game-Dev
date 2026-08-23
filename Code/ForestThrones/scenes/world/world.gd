extends Node3D

## ═══════════════════════════════════════════════════════════════════════════════
##  WORLD — owns the generated map, the resource field and the chunk streamer.
##
##  Generation can run blocking (generate_now) or time-sliced across frames
##  (generate_streamed) so a loading screen stays alive. Everything downstream —
##  AI pathing, the build system, resource harvesting — queries this node rather
##  than walking the scene tree.
## ═══════════════════════════════════════════════════════════════════════════════

const MapGenerator = preload("res://scenes/world/map_generator.gd")
const ResourceField = preload("res://scenes/resources/resource_field.gd")
const WorldStreamer = preload("res://scenes/world/world_streamer.gd")

signal generation_progress(fraction: float, stage: String)
signal generation_finished()

## Generate as soon as this node enters the tree. Turn off when a loading screen
## drives generation explicitly.
@export var auto_generate: bool = true
## Stream chunk collision/visibility around the anchors during play.
@export var enable_streaming: bool = true

var map_generator = null
var resource_field: ResourceField = null
var streamer: WorldStreamer = null

var is_ready_for_play := false
var build_report := {}


func _ready() -> void:
	if auto_generate:
		generate_now()


# ═══════════════════════════════════════════════════════════════════════════════
#  GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

## Blocking build. Fine for tools, tests and desktop; on device prefer
## generate_streamed so the loading screen keeps animating.
func generate_now() -> void:
	var t0 := Time.get_ticks_msec()
	map_generator = MapGenerator.new()
	map_generator.generate(self)
	_after_terrain()
	build_report = _make_report(t0)
	is_ready_for_play = true
	generation_finished.emit()


## Time-sliced build. Emits generation_progress as it goes.
func generate_streamed() -> void:
	var t0 := Time.get_ticks_msec()
	map_generator = MapGenerator.new()
	await map_generator.generate_async(self, get_tree(),
			func(f: float, s: String): generation_progress.emit(f * 0.85, s))

	generation_progress.emit(0.88, "Seeding resources")
	await get_tree().process_frame
	_after_terrain()

	build_report = _make_report(t0)
	is_ready_for_play = true
	generation_progress.emit(1.0, "Ready")
	generation_finished.emit()


func _after_terrain() -> void:
	resource_field = ResourceField.new()
	resource_field.name = "ResourceField"
	add_child(resource_field)
	resource_field.build(map_generator, MapGenerator.CHUNK_CELLS)

	streamer = WorldStreamer.new()
	streamer.name = "WorldStreamer"
	add_child(streamer)
	streamer.setup(map_generator, MapGenerator.CHUNK_CELLS)
	streamer.set_enabled(enable_streaming)


func _make_report(t0: int) -> Dictionary:
	return {
		"total_ms": Time.get_ticks_msec() - t0,
		"map": map_generator.last_stats if map_generator else {},
		"resources": resource_field.stats if resource_field else {},
	}


## Register a player / bot / beast whose surroundings must stay solid.
func add_stream_anchor(n: Node3D) -> void:
	if streamer:
		streamer.add_anchor(n)


func remove_stream_anchor(n: Node3D) -> void:
	if streamer:
		streamer.remove_anchor(n)


# ═══════════════════════════════════════════════════════════════════════════════
#  WORLD QUERIES
# ═══════════════════════════════════════════════════════════════════════════════

## Zone type at a 3D world position.
func get_zone_at_world(world_pos: Vector3) -> Constants.ZoneType:
	var g := world_to_grid(world_pos)
	return get_zone_at(g)


## Zone type at a 2D grid cell.
func get_zone_at(grid_pos: Vector2i) -> Constants.ZoneType:
	if map_generator:
		return map_generator.zone_at(grid_pos.x, grid_pos.y)
	return Constants.ZoneType.DENSE_FOREST


## Ground height at a world position, interpolated between grid samples.
## Use this to place anything on the terrain instead of assuming y = 0.
func ground_height(world_pos: Vector3) -> float:
	if map_generator:
		return map_generator.height_at_world(world_pos)
	return 0.0


## Snap a position onto the terrain surface.
func on_ground(world_pos: Vector3, lift: float = 0.0) -> Vector3:
	return Vector3(world_pos.x, ground_height(world_pos) + lift, world_pos.z)


func is_road(world_pos: Vector3) -> bool:
	var g := world_to_grid(world_pos)
	return map_generator.is_road(g.x, g.y) if map_generator else false


func drop_zone_world_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if map_generator == null:
		return out
	for dc in map_generator.drop_zone_coords():
		var p := grid_to_world(dc)
		out.append(Vector3(p.x, ground_height(p), p.z))
	return out


func world_to_grid(world_pos: Vector3) -> Vector2i:
	var tile: Vector2 = Constants.TILE_SIZE
	var center: Vector2i = Constants.GRID_SIZE / 2
	var gx := int(round(world_pos.x / tile.x)) + center.x
	var gy := int(round(world_pos.z / tile.y)) + center.y
	return Vector2i(
		clamp(gx, 0, Constants.GRID_SIZE.x - 1),
		clamp(gy, 0, Constants.GRID_SIZE.y - 1))


func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var tile: Vector2 = Constants.TILE_SIZE
	var center: Vector2i = Constants.GRID_SIZE / 2
	return Vector3(
		(grid_pos.x - center.x) * tile.x,
		0.0,
		(grid_pos.y - center.y) * tile.y)


## Half-extent of the playable map in world units.
func map_half_extent() -> float:
	return float(Constants.GRID_SIZE.x) * Constants.TILE_SIZE.x * 0.5
