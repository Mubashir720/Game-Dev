extends AbilityBase

func _init() -> void:
	ability_name = "Flare"
	cooldown = 45.0

func _execute_ability(caster: Node3D) -> void:
	print("Scout launches Flare (reveals enemies within 20 tiles)")
