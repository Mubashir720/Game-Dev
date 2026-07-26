extends Node3D

const MapGenerator = preload("res://scenes/world/map_generator.gd")
const ResourceSpawner = preload("res://scenes/resources/resource_spawner.gd")

var _map_gen: MapGenerator = null

func _ready() -> void:
	_map_gen = MapGenerator.new()
	_map_gen.generate(self)
	ResourceSpawner.spawn_resources(self, _map_gen)
	print("3D Isometric World + Resource Nodes Generated Successfully.")

## Returns the zone type for a given 3D world position
func get_zone_at_world(world_pos: Vector3) -> Constants.ZoneType:
	var grid := world_to_grid(world_pos)
	return _map_gen.determine_zone(grid, Constants.GRID_SIZE)

## Returns the zone type for a given 2D grid position
func get_zone_at(grid_pos: Vector2i) -> Constants.ZoneType:
	if _map_gen:
		return _map_gen.determine_zone(grid_pos, Constants.GRID_SIZE)
	return Constants.ZoneType.DENSE_FOREST

## Converts a 3D world position to a 2D grid cell
func world_to_grid(world_pos: Vector3) -> Vector2i:
	var tile_dim := Constants.TILE_SIZE
	var center := Constants.GRID_SIZE / 2
	var gx := int(round(world_pos.x / tile_dim.x)) + center.x
	var gy := int(round(world_pos.z / tile_dim.y)) + center.y
	gx = clamp(gx, 0, Constants.GRID_SIZE.x - 1)
	gy = clamp(gy, 0, Constants.GRID_SIZE.y - 1)
	return Vector2i(gx, gy)

## Converts a 2D grid position to 3D world position (Y = 0)
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var tile_dim := Constants.TILE_SIZE
	var center := Constants.GRID_SIZE / 2
	return Vector3(
		(grid_pos.x - center.x) * tile_dim.x,
		0.0,
		(grid_pos.y - center.y) * tile_dim.y
	)
