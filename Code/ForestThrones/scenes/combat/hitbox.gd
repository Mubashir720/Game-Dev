extends Area3D

@export var damage: float = 15.0
@export var knockback_force: float = 100.0
@export var attacker: Node3D = null

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if area.has_method("take_damage"):
		CombatManager.apply_damage(attacker, area.owner, damage)
