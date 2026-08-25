extends Node

var structures_registry: Dictionary = {}
var active_player: Node3D = null
var is_building := false
var selected_structure: StructureData = null

func _ready() -> void:
	_register_all_structures()

func _register_all_structures() -> void:
	_reg("hut",          {Constants.ResourceType.WOOD: 8},                                              100.0, 3.0,  true,  true)
	_reg("hut_upgraded", {Constants.ResourceType.WOOD: 6, Constants.ResourceType.STONE: 3},             150.0, 5.0,  true,  false)
	_reg("wood_wall",    {Constants.ResourceType.WOOD: 4},                                              50.0,  1.5,  true,  false)
	_reg("stone_wall",   {Constants.ResourceType.STONE: 6},                                             150.0, 2.5,  false, false)
	_reg("cage_basic",   {Constants.ResourceType.WOOD: 10},                                             80.0,  3.5,  true,  false)
	_reg("cage_full",    {Constants.ResourceType.WOOD: 8, Constants.ResourceType.METAL: 4},             120.0, 5.0,  true,  false)
	_reg("mint",         {Constants.ResourceType.WOOD: 12, Constants.ResourceType.STONE: 8,
						  Constants.ResourceType.METAL: 4},                                             100.0, 6.0,  false, false)
	_reg("watchtower",   {Constants.ResourceType.WOOD: 10, Constants.ResourceType.STONE: 4},            80.0,  4.0,  true,  false)
	_reg("workshop",     {Constants.ResourceType.WOOD: 10, Constants.ResourceType.STONE: 6},            100.0, 4.0,  true,  false)
	_reg("bear_trap",    {Constants.ResourceType.METAL: 4, Constants.ResourceType.WOOD: 2},             10.0,  1.0,  false, false)
	_reg("fire_pit",     {Constants.ResourceType.WOOD: 4},                                              60.0,  2.0,  false, false)

func _reg(id: String, cost: Dictionary, hp: float, build_time: float, flammable: bool, moveable: bool) -> void:
	var data := StructureData.new()
	data.structure_name = id
	data.cost = cost
	data.max_hp = hp
	data.build_time = build_time
	data.is_flammable = flammable
	data.is_moveable = moveable
	data.grid_footprint = Vector2i(1, 1)
	structures_registry[id] = data

# ─── Public API ───────────────────────────────────────────────────────────────

func start_build_mode(struct_id: String, player: Node3D) -> void:
	if not structures_registry.has(struct_id):
		push_warning("BuildSystem: '" + struct_id + "' not found in registry.")
		return
	active_player = player
	selected_structure = structures_registry[struct_id]
	is_building = true

func exit_build_mode() -> void:
	is_building = false
	selected_structure = null
	active_player = null

func can_build(player: Node3D, data: StructureData) -> bool:
	if not is_instance_valid(player):
		return false
	var inv = player.get("inventory")
	if inv == null or not (inv is Dictionary):
		return false
	for r_type in data.cost.keys():
		if int(inv.get(r_type, 0)) < int(data.cost[r_type]):
			return false
	return true

func place_structure(build_position: Vector3, struct_id: String, player: Node3D) -> bool:
	if not structures_registry.has(struct_id):
		return false
	var data: StructureData = structures_registry[struct_id]
	if not can_build(player, data):
		push_warning("BuildSystem: Player cannot afford '" + struct_id + "'.")
		return false

	# Deduct costs
	for r_type in data.cost.keys():
		player.inventory[r_type] -= data.cost[r_type]

	# Create structure node
	var structure := StructureBase.new()
	structure.data = data
	structure.squad_id = int(player.get_meta("squad_id", -1))
	structure.grid_position = Vector2i(int(build_position.x / Constants.TILE_SIZE.x),
										int(build_position.z / Constants.TILE_SIZE.y))
	structure.current_state = StructureBase.StructureState.CONSTRUCTING
	structure.position = Vector3(build_position.x, 0.0, build_position.z)

	# Attach under the World node. Resolve it robustly: the player carries a direct
	# `world` reference (always valid in a live match); fall back to the scene tree
	# only if that is missing. `get_tree().current_scene` can be null depending on
	# how the match was launched, which is what crashed the old lookup.
	var world: Node = null
	if "world" in player and player.world != null and is_instance_valid(player.world):
		world = player.world
	if world == null:
		var cs := get_tree().current_scene
		if cs != null:
			world = cs.find_child("World", true, false)
	if world == null:
		world = get_tree().root.find_child("World", true, false)

	if world != null:
		var structures_node := world.get_node_or_null("Structures")
		if structures_node != null:
			structures_node.add_child(structure)
		else:
			world.add_child(structure)
	else:
		# Last resort: never drop the structure on the floor of a null scene.
		add_child(structure)

	if player.has_method("play_anim"):
		player.play_anim("build")
	exit_build_mode()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not is_building or not selected_structure:
		return
	if event.is_action_pressed("cancel"):
		exit_build_mode()
		get_viewport().set_input_as_handled()
