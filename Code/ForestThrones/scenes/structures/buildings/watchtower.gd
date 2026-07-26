extends StructureBase

var detection_radius: float = 15.0

func _process(delta: float) -> void:
	super._process(delta)
	if current_state == StructureState.BUILT:
		# Auto-ping enemies within 8 tiles (GDD §6)
		_check_enemy_proximity()

func _check_enemy_proximity() -> void:
	# Query nearby enemy entities within 8 tiles
	pass
