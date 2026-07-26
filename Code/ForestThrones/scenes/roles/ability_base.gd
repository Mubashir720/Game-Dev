extends Node
class_name AbilityBase

@export var ability_name: String = "Ability"
@export var cooldown: float = 30.0

var current_cooldown: float = 0.0

func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = max(0.0, current_cooldown - delta)

func is_ready() -> bool:
	return current_cooldown == 0.0

func activate(caster: Node3D) -> bool:
	if not is_ready():
		return false
	current_cooldown = cooldown
	_execute_ability(caster)
	return true

func _execute_ability(_caster: Node3D) -> void:
	pass
