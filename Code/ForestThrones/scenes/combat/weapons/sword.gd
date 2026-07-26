extends WeaponBase
## Basic Sword — Standard 3D melee weapon (GDD §9)

func _ready() -> void:
	super._ready()
	weapon_name = "Basic Sword"
	damage = Constants.BASIC_SWORD_DAMAGE
	attack_speed = 0.50
	knockback = 80.0
