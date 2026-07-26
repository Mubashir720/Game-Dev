extends Node

func _ready() -> void:
	EventBus.mutation_wave_started.connect(_on_mutation_wave)

func _on_mutation_wave(wave_number: int) -> void:
	print("MUTATION WAVE ", wave_number, " INCOMING!")
	var player = get_tree().current_scene.find_child("Player", true, false)
	if not is_instance_valid(player):
		return
		
	var world = get_tree().current_scene.find_child("World", true, false)
	if not world:
		return
		
	var wolf_script = load("res://scenes/beasts/types/wolf.gd")
	var boar_script = load("res://scenes/beasts/types/boar.gd")
	
	# Mutated waves spawn 3 beasts around player
	for i in range(3):
		var angle = randf() * TAU
		var dist = randf_range(160.0, 260.0)
		var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * dist
		
		var beast = load("res://scenes/beasts/beast_base.tscn").instantiate()
		var is_wolf = randf() < 0.5
		if is_wolf:
			beast.set_script(wolf_script)
		else:
			beast.set_script(boar_script)
			
		beast.global_position = spawn_pos
		beast.set_meta("is_mutated", true)
		beast.max_hp = 90.0
		beast.hp = 90.0
		beast.damage = 18.0
		beast.speed = 140.0
		
		# Auto-aggro on the player
		beast.state = beast.BeastState.ATTACK
		beast.target_entity = player
		
		var entities = world.get_node_or_null("Entities")
		if entities:
			entities.add_child(beast)
		else:
			world.add_child(beast)
			
		print("Mutated wave spawned: mutated ", beast.beast_type, " at ", spawn_pos)
