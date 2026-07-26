extends WeaponBase
## Upgraded Sword — Advanced 3D melee weapon (GDD §9)

func _ready() -> void:
	super._ready()
	weapon_name = "Upgraded Sword"
	damage = Constants.UPGRADED_SWORD_DAMAGE
	attack_speed = 0.55
	knockback = 120.0
