extends Node3D
class_name WeaponBase

signal attack_completed()

@export var weapon_name: String = "Weapon"
@export var damage: float = 15.0
@export var attack_cooldown: float = 0.8
@export var attack_speed: float = 0.5
@export var knockback: float = 100.0

var wielder: Node3D = null
var current_cooldown: float = 0.0

func _ready() -> void:
	pass

func set_wielder(player: Node3D) -> void:
	wielder = player

func try_attack() -> bool:
	if current_cooldown > 0.0:
		return false
	current_cooldown = attack_cooldown
	_perform_attack()
	return true

func _perform_attack() -> void:
	attack_completed.emit()

func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = max(0.0, current_cooldown - delta)
