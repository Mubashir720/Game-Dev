extends StructureBase

# GDD §6: Upgraded Hut — 100 HP, Proximity Aura (+1.5 HP/s), 20-slot Storage Chest

func _ready() -> void:
	super._ready()
	structure_type = "hut_upgraded"
	max_hp = 100.0
	current_hp = max_hp
	is_flammable = true

func _process(delta: float) -> void:
	super._process(delta)
	if current_state == StructureState.BUILT:
		_apply_proximity_aura(delta)

func _apply_proximity_aura(delta: float) -> void:
	# GDD §6: Upgraded Proximity Aura (+1.5 HP/s within 8 tiles)
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p.has_meta("squad_id") and p.get_meta("squad_id") == str(squad_id):
			if global_position.distance_to(p.global_position) <= 16.0:
				if "hp" in p and p.hp < Constants.MAX_HP:
					p.hp = min(Constants.MAX_HP, p.hp + 1.5 * delta)
