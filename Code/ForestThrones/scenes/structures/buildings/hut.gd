extends StructureBase

# GDD §6: Basic Hut — 50 HP, Proximity Aura (+1 HP/s), Moveable

func _ready() -> void:
	super._ready()
	structure_type = "hut"
	max_hp = 50.0
	current_hp = max_hp
	is_flammable = true

func _process(delta: float) -> void:
	super._process(delta)
	if current_state == StructureState.BUILT:
		_apply_proximity_aura(delta)

func _apply_proximity_aura(delta: float) -> void:
	# GDD §6: Squad members within 8 tiles get +1 HP/s passive regen
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p.has_meta("squad_id") and p.get_meta("squad_id") == str(squad_id):
			if global_position.distance_to(p.global_position) <= 16.0: # 8 tiles = 16 units
				if "hp" in p and p.hp < Constants.MAX_HP:
					p.hp = min(Constants.MAX_HP, p.hp + 1.0 * delta)
