extends RefCounted

const ResourceNodeScene = preload("res://scenes/resources/resource_node.tscn")

static func spawn_resources(world: Node3D, map_generator) -> void:
	var size := Constants.GRID_SIZE
	var tile_dim := Constants.TILE_SIZE
	var center := Vector2i(size.x / 2, size.y / 2)
	
	var resource_parent := Node3D.new()
	resource_parent.name = "ResourceNodes"
	world.add_child(resource_parent)
	
	for y in range(size.y):
		for x in range(size.x):
			var pos := Vector2i(x, y)
			var zone: Constants.ZoneType = map_generator.determine_zone(pos, size)
			
			# GDD §3: Center (Cursed Throne) has NO trees, NO stone
			if zone == Constants.ZoneType.CURSED_THRONE:
				continue
			if zone == Constants.ZoneType.DROP_ZONE:
				continue
			
			var resource_to_spawn: int = -1
			var roll := randf()
			
			match zone:
				Constants.ZoneType.DENSE_FOREST:
					if roll < 0.055:
						resource_to_spawn = Constants.ResourceType.WOOD
					elif roll < 0.065:
						resource_to_spawn = Constants.ResourceType.FOOD
				Constants.ZoneType.OPEN_CLEARING:
					if roll < 0.045:
						resource_to_spawn = Constants.ResourceType.FOOD
					elif roll < 0.055:
						resource_to_spawn = Constants.ResourceType.WOOD
				Constants.ZoneType.ROCKY_HIGHLANDS:
					if roll < 0.045:
						resource_to_spawn = Constants.ResourceType.STONE
					elif roll < 0.055:
						resource_to_spawn = Constants.ResourceType.METAL
				Constants.ZoneType.SWAMP:
					if roll < 0.065:
						resource_to_spawn = Constants.ResourceType.HERBS
					elif roll < 0.075:
						resource_to_spawn = Constants.ResourceType.FOOD
				Constants.ZoneType.RIVERBED:
					# Water is collected at rivers — handled by interaction, not spawned nodes
					continue
			
			if resource_to_spawn == -1:
				continue
			
			# Convert grid to 3D world position (center origin)
			var world_x := (x - center.x) * tile_dim.x
			var world_z := (y - center.y) * tile_dim.y
			var world_y := 0.5 if zone == Constants.ZoneType.ROCKY_HIGHLANDS else 0.0
			
			var node: Node3D = ResourceNodeScene.instantiate()
			node.resource_type = resource_to_spawn
			_configure_node(node, resource_to_spawn)
			node.position = Vector3(world_x, world_y, world_z)
			resource_parent.add_child(node)

static func _configure_node(node: Node3D, type: int) -> void:
	match type:
		Constants.ResourceType.WOOD:
			node.amount = 3
			node.max_hits = 5
			node.respawn_time = 60.0
		Constants.ResourceType.STONE:
			node.amount = 2
			node.max_hits = 4
			node.respawn_time = 90.0
		Constants.ResourceType.FOOD:
			node.amount = 1
			node.max_hits = 2
			node.respawn_time = 45.0
		Constants.ResourceType.METAL:
			node.amount = 1
			node.max_hits = 6
			node.respawn_time = 120.0
		Constants.ResourceType.HERBS:
			node.amount = 1
			node.max_hits = 2
			node.respawn_time = 80.0
