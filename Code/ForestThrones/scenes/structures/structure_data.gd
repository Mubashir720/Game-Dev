extends Resource
class_name StructureData

@export var structure_name: String
@export var cost: Dictionary # {Constants.ResourceType: int}
@export var max_hp: float
@export var build_time: float = 3.0
@export var is_flammable: bool = true
@export var is_moveable: bool = false
@export var grid_footprint: Vector2i = Vector2i(1, 1)
@export var scene_path: String
@export var upgrade_to: Resource # Points to a StructureData resource (Resource to avoid cyclic dependency issues in Godot)
@export var upgrade_cost: Dictionary # {Constants.ResourceType: int}
@export var requires: Resource # Points to a StructureData resource
