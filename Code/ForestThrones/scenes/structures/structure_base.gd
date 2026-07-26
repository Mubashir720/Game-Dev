extends StaticBody3D
class_name StructureBase

const StructureFactory = preload("res://scenes/structures/structure_factory.gd")

enum StructureState { CONSTRUCTING, BUILT, BURNING, DESTROYED }

## Runtime data from StructureData resource
var data: StructureData = null
var current_state: StructureState = StructureState.BUILT
var squad_id: int = -1
var grid_position: Vector2i = Vector2i.ZERO

@export var structure_type: String = "hut"
@export var max_hp: float = 50.0

var current_hp: float = 50.0

## Fire
var is_on_fire: bool = false
var is_flammable: bool = true
var _burn_timer: float = 0.0
const BURN_DAMAGE_PER_SECOND := 5.0
const BURN_DURATION := 60.0

## 3D visual
var visual_node: Node3D = null
var _fire_light: OmniLight3D = null

## Build progress
var build_time_remaining: float = 0.0

func _ready() -> void:
	add_to_group("structures")
	collision_layer = 1
	collision_mask = 1
	
	if data:
		max_hp = data.max_hp
		is_flammable = data.is_flammable
		build_time_remaining = data.build_time
		
	current_hp = max_hp
	
	var type_key = data.structure_name.to_lower().replace(" ", "_") if data else structure_type
	visual_node = StructureFactory.build_structure(type_key)
	add_child(visual_node)
	
	# Generate solid 3D Physics Collision Shape so entities cannot pass through
	_create_physics_collision(type_key)
	
	# If constructing, start dimmed
	if current_state == StructureState.CONSTRUCTING:
		_apply_construction_tint()

func _create_physics_collision(type_key: String) -> void:
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	
	match type_key:
		"cage", "cage_basic", "cage_full":
			box.size = Vector3(2.3, 2.2, 2.3)
			col_shape.position = Vector3(0, 1.1, 0)
		"hut", "hut_upgraded":
			box.size = Vector3(2.6, 2.2, 2.6)
			col_shape.position = Vector3(0, 1.1, 0)
		"wood_wall", "stone_wall":
			box.size = Vector3(2.0, 1.6, 0.4)
			col_shape.position = Vector3(0, 0.8, 0)
		"treasury":
			box.size = Vector3(1.3, 0.9, 0.9)
			col_shape.position = Vector3(0, 0.45, 0)
		"mint", "workshop", "watchtower":
			box.size = Vector3(2.3, 2.0, 2.3)
			col_shape.position = Vector3(0, 1.0, 0)
		_:
			box.size = Vector3(1.6, 1.2, 1.6)
			col_shape.position = Vector3(0, 0.6, 0)
			
	col_shape.shape = box
	add_child(col_shape)

func _process(delta: float) -> void:
	# Build progress tick
	if current_state == StructureState.CONSTRUCTING:
		build_time_remaining -= delta
		if build_time_remaining <= 0.0:
			current_state = StructureState.BUILT
			_remove_construction_tint()
		return
		
	# Fire burn tick
	if is_on_fire and current_state == StructureState.BURNING:
		_burn_timer += delta
		take_damage(BURN_DAMAGE_PER_SECOND * delta)
		if _burn_timer >= BURN_DURATION:
			destroy_structure()

# ─── Public API ───────────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if current_state == StructureState.DESTROYED:
		return
	current_hp = max(0.0, current_hp - amount)
	if current_hp == 0.0:
		destroy_structure()

func repair(amount: float) -> void:
	if current_state == StructureState.DESTROYED:
		return
	current_hp = min(max_hp, current_hp + amount)

func ignite() -> void:
	if current_state == StructureState.DESTROYED or not is_flammable:
		return
	if is_on_fire:
		return
		
	is_on_fire = true
	current_state = StructureState.BURNING
	_burn_timer = 0.0
	
	# Add fire OmniLight
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.45, 0.12)
	_fire_light.light_energy = 3.0
	_fire_light.omni_range = 8.0
	_fire_light.position.y = 1.5
	add_child(_fire_light)
	
	set_on_fire(true)
	FireSystem.register_burning(self)

func set_on_fire(fire_state: bool) -> void:
	is_on_fire = fire_state
	if visual_node:
		for i in visual_node.get_child_count():
			var child = visual_node.get_child(i)
			if child is MeshInstance3D and child.material_override:
				child.material_override.emission_enabled = fire_state
				if fire_state:
					child.material_override.emission = Color(1.0, 0.4, 0.1)
					child.material_override.emission_energy_multiplier = 0.8

func extinguish() -> void:
	is_on_fire = false
	current_state = StructureState.BUILT
	_burn_timer = 0.0
	if _fire_light and is_instance_valid(_fire_light):
		_fire_light.queue_free()
		_fire_light = null
	set_on_fire(false)
	FireSystem.unregister_burning(self)

func destroy_structure() -> void:
	current_state = StructureState.DESTROYED
	if _fire_light and is_instance_valid(_fire_light):
		_fire_light.queue_free()
	queue_free()

# ─── Build tint helpers ────────────────────────────────────────────────────────

func _apply_construction_tint() -> void:
	if not visual_node:
		return
	for child in visual_node.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.4, 0.65, 1.0, 0.55)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			child.material_override = mat

func _remove_construction_tint() -> void:
	if not visual_node:
		return
	for child in visual_node.get_children():
		if child is MeshInstance3D:
			child.material_override = null
