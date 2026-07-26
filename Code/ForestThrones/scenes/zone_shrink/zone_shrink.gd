extends Node

var current_radius := 32.0 # safe zone radius in tiles
var is_active := false
var _check_timer := 0.0

func _ready() -> void:
	EventBus.zone_shrink_started.connect(_on_zone_shrink_started)

func _on_zone_shrink_started() -> void:
	is_active = true
	current_radius = 32.0
	print("Zone Shrink Started! Safe radius is: ", current_radius)
	
	# Spawn a text notification in the ticker
	EventBus.legendary_moment.emit("zone_shrink_started", [])

func _process(delta: float) -> void:
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager or game_manager.game_state != Constants.GameState.PLAYING:
		return
		
	# Check starting time
	if not is_active and game_manager.match_time >= Constants.ZONE_SHRINK_START:
		EventBus.zone_shrink_started.emit()
		
	if is_active:
		# Shrink radius by 1 tile every 30 seconds
		# (1.0 / 30.0) tiles per second
		current_radius = max(2.0, 32.0 - (game_manager.match_time - Constants.ZONE_SHRINK_START) / 30.0)
		
		# Tick timer for damage (every 1 second)
		_check_timer += delta
		if _check_timer >= 1.0:
			_check_timer = 0.0
			_apply_zone_damage()
			
		# Notify minimap to draw radius
		EventBus.zone_shrink_tick.emit(current_radius)

func _apply_zone_damage() -> void:
	var world = get_tree().current_scene.find_child("World", true, false)
	if not world:
		return
		
	var center_world_pos = world.grid_to_world(Vector2i(32, 32))
	var radius_px = current_radius * Constants.TILE_SIZE.x # convert tile radius to pixel radius (approx)
	
	# Check local player
	var player = get_tree().current_scene.find_child("Player", true, false)
	if is_instance_valid(player) and player.stats.state != player.stats.HPState.DEAD:
		var dist = player.global_position.distance_to(center_world_pos)
		if dist > radius_px:
			player.take_damage(Constants.ZONE_SHRINK_DAMAGE)
			player.set_meta("outside_zone", true)
			print("Player taking zone damage! Distance: ", dist, " / ", radius_px)
		else:
			player.set_meta("outside_zone", false)
			
	# Also damage wild/tamed beasts
	var beasts = get_tree().get_nodes_in_group("beasts")
	for beast in beasts:
		if is_instance_valid(beast):
			var dist = beast.global_position.distance_to(center_world_pos)
			if dist > radius_px:
				beast.take_damage(Constants.ZONE_SHRINK_DAMAGE)
