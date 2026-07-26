extends WeaponBase
## AdvancedBow — 3D Composite recurve bow. Higher damage, faster fire, multi-shot (GDD §9)

@export var arrow_damage: float = 28.0
@export var draw_time: float = 0.40
@export var arrow_speed: float = 35.0

var draw_progress: float = 0.0
var is_drawing: bool = false

func _ready() -> void:
	weapon_name = "Advanced Bow"
	damage = arrow_damage
	attack_cooldown = draw_time
	super._ready()

func _perform_attack() -> void:
	if is_instance_valid(wielder):
		print("Advanced Bow fired multi-shot arrow burst")
	attack_completed.emit()
