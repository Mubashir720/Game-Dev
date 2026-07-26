extends RefCounted

func generate(world: Node2D) -> void:
    # 1. Dynamically create a high-quality isometric TileSet with grid borders
    var tile_set = TileSet.new()
    tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
    tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
    tile_set.tile_size = Constants.TILE_SIZE

    # Create Atlas Texture (8 tiles of 128x64 = 1024x64 image)
    var img = Image.create(1024, 64, false, Image.FORMAT_RGBA8)
    var colors = [
        Color(0.28, 0.62, 0.22), # 0: Grass (Open Clearing)
        Color(0.08, 0.35, 0.12), # 1: Dense Forest
        Color(0.12, 0.42, 0.78), # 2: Water (Riverbed)
        Color(0.48, 0.48, 0.52), # 3: Stone (Rocky Highlands)
        Color(0.22, 0.25, 0.16), # 4: Mud (Swamp)
        Color(0.38, 0.12, 0.52), # 5: Purple (Cursed Throne)
        Color(0.68, 0.16, 0.16), # 6: Crimson (Drop Zone)
        Color(0.82, 0.62, 0.12)  # 7: Gold (NPC Vendor)
    ]

    for i in range(8):
        var base_color = colors[i]
        var border_color = base_color.darkened(0.25)
        for y in range(64):
            for x in range(128):
                var px = i * 128 + x
                var py = y
                var dist = abs(x - 64) / 64.0 + abs(y - 32) / 32.0
                if dist <= 1.0:
                    if dist >= 0.94: # Thin 1px clean grid border
                        img.set_pixel(px, py, border_color)
                    else:
                        img.set_pixel(px, py, base_color)
                else:
                    img.set_pixel(px, py, Color(0, 0, 0, 0))

    var texture = ImageTexture.create_from_image(img)
    var atlas_source = TileSetAtlasSource.new()
    atlas_source.texture = texture
    atlas_source.texture_region_size = Constants.TILE_SIZE
    for i in range(8):
        atlas_source.create_tile(Vector2i(i, 0))
    tile_set.add_source(atlas_source, 0)

    # Assign TileSet to all layers
    world.ground_layer.tile_set = tile_set
    world.object_layer.tile_set = tile_set
    world.canopy_layer.tile_set = tile_set

    # 2. Partition the map cells and populate the grids
    var size = Constants.GRID_SIZE
    for y in range(size.y):
        for x in range(size.x):
            var pos = Vector2i(x, y)
            var zone = _determine_zone(pos, size)
            
            # Properties based on Zone
            var walkable = true
            var elevation = 0
            var speed_modifier = 1.0
            var tile_idx = 1 # Default Dense Forest

            match zone:
                Constants.ZoneType.DROP_ZONE:
                    tile_idx = 6
                Constants.ZoneType.DENSE_FOREST:
                    tile_idx = 1
                Constants.ZoneType.OPEN_CLEARING:
                    tile_idx = 0
                Constants.ZoneType.RIVERBED:
                    tile_idx = 2
                    walkable = false # Water blocks movement
                Constants.ZoneType.ROCKY_HIGHLANDS:
                    tile_idx = 3
                    elevation = 1
                Constants.ZoneType.SWAMP:
                    tile_idx = 4
                    speed_modifier = 0.8 # -20% movement speed
                Constants.ZoneType.CURSED_THRONE:
                    tile_idx = 5
                    elevation = 1

            # Register with world
            world.register_cell(pos, zone, walkable, elevation, speed_modifier)
            
            # Place ground tile
            world.ground_layer.set_cell(pos, 0, Vector2i(tile_idx, 0))

    # 3. Spawn interactive resource nodes (wood, stone, herbs, metal, food)
    var spawner = load("res://scenes/resources/resource_spawner.gd").new()
    spawner.spawn_resources(world, world.ground_layer)


func _determine_zone(pos: Vector2i, size: Vector2i) -> Constants.ZoneType:
    # 1. Cursed Throne (Center 3x3)
    var center = size / 2
    if abs(pos.x - center.x) <= 1 and abs(pos.y - center.y) <= 1:
        return Constants.ZoneType.CURSED_THRONE
        
    # 2. 8 Drop Zones (6x6 areas at outer bounds)
    var edge_margin := 6
    # North-West (0,0)
    if pos.x < edge_margin and pos.y < edge_margin:
        return Constants.ZoneType.DROP_ZONE
    # North (center, 0)
    if abs(pos.x - center.x) < 3 and pos.y < edge_margin:
        return Constants.ZoneType.DROP_ZONE
    # North-East (max, 0)
    if pos.x >= size.x - edge_margin and pos.y < edge_margin:
        return Constants.ZoneType.DROP_ZONE
    # East (max, center)
    if pos.x >= size.x - edge_margin and abs(pos.y - center.y) < 3:
        return Constants.ZoneType.DROP_ZONE
    # South-East (max, max)
    if pos.x >= size.x - edge_margin and pos.y >= size.y - edge_margin:
        return Constants.ZoneType.DROP_ZONE
    # South (center, max)
    if abs(pos.x - center.x) < 3 and pos.y >= size.y - edge_margin:
        return Constants.ZoneType.DROP_ZONE
    # South-West (0, max)
    if pos.x < edge_margin and pos.y >= size.y - edge_margin:
        return Constants.ZoneType.DROP_ZONE
    # West (0, center)
    if pos.x < edge_margin and abs(pos.y - center.y) < 3:
        return Constants.ZoneType.DROP_ZONE

    # 3. Riverbeds (East & West edges, 3-tile wide water, inside the boundaries but outside drop zones)
    if (pos.x >= 6 and pos.x <= 8) or (pos.x >= size.x - 9 and pos.x <= size.x - 7):
        return Constants.ZoneType.RIVERBED

    # 4. Rocky Highlands (NW & SE quadrants, far from center)
    if (pos.x < 18 and pos.y < 18) or (pos.x > size.x - 19 and pos.y > size.y - 19):
        return Constants.ZoneType.ROCKY_HIGHLANDS

    # 5. Swamp (NE quadrant)
    if pos.x > size.x - 20 and pos.y < 20:
        return Constants.ZoneType.SWAMP

    # 6. 4 Open Clearings (Mid-map 8x8 regions)
    # NW clearing
    if abs(pos.x - 20) <= 4 and abs(pos.y - 20) <= 4:
        return Constants.ZoneType.OPEN_CLEARING
    # NE clearing
    if abs(pos.x - 44) <= 4 and abs(pos.y - 20) <= 4:
        return Constants.ZoneType.OPEN_CLEARING
    # SW clearing
    if abs(pos.x - 20) <= 4 and abs(pos.y - 44) <= 4:
        return Constants.ZoneType.OPEN_CLEARING
    # SE clearing
    if abs(pos.x - 44) <= 4 and abs(pos.y - 44) <= 4:
        return Constants.ZoneType.OPEN_CLEARING

    # Default
    return Constants.ZoneType.DENSE_FOREST
