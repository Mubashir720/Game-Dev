extends Area3D

@export var owner_entity: Node3D = null

func _ready() -> void:
	collision_layer = 2
	collision_mask = 4

func take_damage(amount: float) -> void:
	if owner_entity and owner_entity.has_method("take_damage"):
		owner_entity.take_damage(amount)
