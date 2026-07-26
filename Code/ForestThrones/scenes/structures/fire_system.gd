extends Node

var burning_list: Array = []
var _spread_timer := 0.0
const SPREAD_INTERVAL := 3.0 # Check fire spread every 3 seconds (GDD §3.4)
const SPREAD_DISTANCE := 4.0 # 2 tiles * 2.0 units/tile in 3D world space

func register_burning(structure: StructureBase) -> void:
	if not burning_list.has(structure):
		burning_list.append(structure)
		print("FireSystem: Registered burning structure at: ", structure.grid_position)

func unregister_burning(structure: StructureBase) -> void:
	if burning_list.has(structure):
		burning_list.erase(structure)
		print("FireSystem: Unregistered burning structure at: ", structure.grid_position)

func _process(delta: float) -> void:
	if burning_list.is_empty():
		return
		
	_spread_timer += delta
	if _spread_timer >= SPREAD_INTERVAL:
		_spread_timer = 0.0
		_check_fire_spread()

func _check_fire_spread() -> void:
	var all_structures = get_tree().get_nodes_in_group("structures")
	var to_ignite: Array = []
	
	for burning in burning_list:
		if not is_instance_valid(burning):
			continue
		for struct in all_structures:
			if not is_instance_valid(struct) or struct == burning:
				continue
			if struct.current_state == StructureBase.StructureState.BURNING or struct.current_state == StructureBase.StructureState.DESTROYED:
				continue
			if not struct.is_flammable:
				continue
				
			# Distance check
			var dist = burning.global_position.distance_to(struct.global_position)
			if dist <= SPREAD_DISTANCE:
				to_ignite.append(struct)
				
	for struct in to_ignite:
		struct.ignite()
		# Check Forest Curse condition: if all structures of a squad are burning
		_check_squad_base_burning(struct.squad_id)

func _check_squad_base_burning(squad_id: int) -> void:
	if squad_id == -1:
		return
		
	# Find all structures owned by this squad
	var all_structs = get_tree().get_nodes_in_group("structures")
	var squad_structs = []
	var burning_count = 0
	
	for s in all_structs:
		if s.squad_id == squad_id and s.current_state != StructureBase.StructureState.DESTROYED:
			squad_structs.append(s)
			if s.current_state == StructureBase.StructureState.BURNING:
				burning_count += 1
				
	# GDD: Forest Curse triggers if entire squad base is burning/destroyed by enemies
	if squad_structs.size() > 0 and burning_count == squad_structs.size():
		print("FireSystem: Forest Curse triggered! Squad ", squad_id, "'s base is entirely on fire!")
		EventBus.forest_curse_triggered.emit(squad_id, "base_on_fire")
