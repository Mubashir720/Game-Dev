extends AbilityBase

func _init() -> void:
	ability_name = "Overclock"
	cooldown = Constants.ENGINEER_OVERCLOCK_COOLDOWN

func _execute_ability(caster: Node3D) -> void:
	print("Engineer activates Overclock (all builds take 50% time for 15s)")
