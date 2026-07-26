extends PanelContainer

# ═══════════════════════════════════════════════════════════════════════════════
#  MINIMAP — AAA Production-Quality Radar & Tactical Map
#  Features: High-res zone map, fog of war, player location & direction marker,
#  squadmate tracking, landmark & base structure icon overlay, day/night vision radius.
# ═══════════════════════════════════════════════════════════════════════════════

@onready var map_texture_rect: TextureRect = $MapTextureRect
@onready var fog_texture_rect: TextureRect = $FogTextureRect
@onready var player_marker: ColorRect = $MarkerContainer/PlayerMarker

var _map_image: Image
var _fog_image: Image
var _map_texture: ImageTexture
var _fog_texture: ImageTexture
var _player_ref: Node3D = null
var _world_node = null

# Custom icon markers container
var _icon_container: Control = null

func _ready() -> void:
	call_deferred("_initialize_minimap")

func _initialize_minimap() -> void:
	var size := Constants.GRID_SIZE

	# Find 3D world node
	_world_node = get_tree().current_scene.find_child("World", true, false)

	# Create icon overlay container
	_icon_container = Control.new()
	_icon_container.name = "IconOverlay"
	_icon_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_icon_container)

	# 1. Generate high-quality static zone color map
	_map_image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var colors := {
		Constants.ZoneType.OPEN_CLEARING:   Color(0.28, 0.58, 0.24),
		Constants.ZoneType.DENSE_FOREST:    Color(0.10, 0.32, 0.14),
		Constants.ZoneType.RIVERBED:        Color(0.12, 0.42, 0.78),
		Constants.ZoneType.ROCKY_HIGHLANDS: Color(0.48, 0.46, 0.42),
		Constants.ZoneType.SWAMP:           Color(0.18, 0.22, 0.14),
		Constants.ZoneType.CURSED_THRONE:   Color(0.45, 0.12, 0.65),
		Constants.ZoneType.DROP_ZONE:       Color(0.42, 0.16, 0.16)
	}

	for y in range(size.y):
		for x in range(size.x):
			var pos := Vector2i(x, y)
			var zone := Constants.ZoneType.DENSE_FOREST
			if _world_node and _world_node.has_method("get_zone_at"):
				zone = _world_node.get_zone_at(pos)
			_map_image.set_pixel(pos.x, pos.y, colors.get(zone, Color.BLACK))

	_map_texture = ImageTexture.create_from_image(_map_image)
	if map_texture_rect:
		map_texture_rect.texture = _map_texture

	# 2. Fog of war (black = unexplored, semi = explored, transparent = visible)
	_fog_image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	_fog_image.fill(Color(0, 0, 0, 1.0))
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	if fog_texture_rect:
		fog_texture_rect.texture = _fog_texture

## Set the 3D player node to track
func set_player(player: Node3D) -> void:
	_player_ref = player

func _process(_delta: float) -> void:
	if not is_instance_valid(_player_ref):
		return
	if not _world_node or not _world_node.has_method("world_to_grid"):
		return

	# Convert 3D world position to grid coordinates
	var player_grid: Vector2i = _world_node.world_to_grid(_player_ref.global_position)

	_update_fog(player_grid)
	_update_player_marker(player_grid)
	_update_landmark_icons()

func _update_player_marker(player_grid: Vector2i) -> void:
	if not player_marker or not map_texture_rect:
		return
	var panel_size := map_texture_rect.size
	var marker_x := (float(player_grid.x) / Constants.GRID_SIZE.x) * panel_size.x
	var marker_y := (float(player_grid.y) / Constants.GRID_SIZE.y) * panel_size.y
	player_marker.position = Vector2(marker_x - 4.0, marker_y - 4.0)

	# Update rotation if player has facing direction
	if is_instance_valid(_player_ref):
		var rot_y = _player_ref.rotation.y
		player_marker.rotation = -rot_y

func _update_fog(player_pos: Vector2i) -> void:
	var size := Constants.GRID_SIZE
	var radius := 16

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		var day_t: float = gm.current_day_time
		if day_t > 0.70 or day_t < 0.10: # Night vision restriction
			radius = 9

	# Shift previously visible pixels to explored (semi-transparent dark)
	for y in range(size.y):
		for x in range(size.x):
			var c := _fog_image.get_pixel(x, y)
			if c.a < 0.15:
				_fog_image.set_pixel(x, y, Color(0, 0, 0, 0.48))

	# Radial smooth fog reveal around player
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var tp := player_pos + Vector2i(dx, dy)
			if tp.x >= 0 and tp.x < size.x and tp.y >= 0 and tp.y < size.y:
				var dist = player_pos.distance_to(tp)
				if dist <= radius:
					var alpha = clamp((dist - (radius - 3)) / 3.0, 0.0, 1.0) * 0.48
					var current_a = _fog_image.get_pixel(tp.x, tp.y).a
					_fog_image.set_pixel(tp.x, tp.y, Color(0, 0, 0, min(current_a, alpha)))

	if _fog_texture:
		_fog_texture.update(_fog_image)

func _update_landmark_icons() -> void:
	if not _icon_container or not map_texture_rect:
		return

	# Clear previous dynamic icons
	for child in _icon_container.get_children():
		child.queue_free()

	var panel_size := map_texture_rect.size

	# 1. Cursed Throne Center Marker
	var center_grid := Constants.GRID_SIZE / 2
	var throne_pos = Vector2(
		(float(center_grid.x) / Constants.GRID_SIZE.x) * panel_size.x,
		(float(center_grid.y) / Constants.GRID_SIZE.y) * panel_size.y
	)
	var throne_marker := ColorRect.new()
	throne_marker.size = Vector2(8, 8)
	throne_marker.color = Color(0.70, 0.20, 0.90) # Glowing purple
	throne_marker.position = throne_pos - Vector2(4, 4)
	_icon_container.add_child(throne_marker)

	# 2. Base Structures Markers (Hut, Cage, Treasury)
	var structures = get_tree().get_nodes_in_group("structures")
	for s in structures:
		if is_instance_valid(s) and _world_node and _world_node.has_method("world_to_grid"):
			var sg: Vector2i = _world_node.world_to_grid(s.global_position)
			var sx := (float(sg.x) / Constants.GRID_SIZE.x) * panel_size.x
			var sy := (float(sg.y) / Constants.GRID_SIZE.y) * panel_size.y

			var smarker := ColorRect.new()
			smarker.size = Vector2(6, 6)
			smarker.color = Color(0.90, 0.75, 0.20) # Gold structure marker
			smarker.position = Vector2(sx - 3, sy - 3)
			_icon_container.add_child(smarker)
