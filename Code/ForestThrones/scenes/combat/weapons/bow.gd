extends WeaponBase

@export var arrow_speed: float = 20.0
@export var range_tiles: float = Constants.BASIC_BOW_RANGE

func _init() -> void:
	weapon_name = "Bow"
	damage = Constants.BASIC_BOW_DAMAGE
	attack_cooldown = 1.0

func _perform_attack() -> void:
	if is_instance_valid(wielder):
		print("Bow shot arrow in 3D direction")
	attack_completed.emit()
