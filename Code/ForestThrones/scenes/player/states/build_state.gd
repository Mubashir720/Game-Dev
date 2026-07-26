extends PlayerState

var target_structure: StructureBase = null
var hammer_timer := 0.0

func enter(params: Dictionary = {}) -> void:
	target_structure = params.get("structure")
	player.velocity = Vector2.ZERO
	player.is_harvesting = true # Re-use swing tool variables for building hammer swings
	player.queue_redraw()
	hammer_timer = 0.0

func exit() -> void:
	player.is_harvesting = false
	player.queue_redraw()

func update(delta: float) -> void:
	if not is_instance_valid(target_structure) or target_structure.state != target_structure.StructureState.CONSTRUCTING:
		player.state_machine.transition_to("idle")
		return
		
	# Check distance to structure
	var dist = player.global_position.distance_to(target_structure.global_position)
	if dist > 80.0: # Too far, cancel construction
		player.state_machine.transition_to("idle")
		return
		
	# Swing hammer visual ticks
	hammer_timer += delta
	if hammer_timer >= 0.4:
		hammer_timer = 0.0
		player.harvest_hit_tick() # Animate hammer chop
		
	# Advance construction progress
	var build_speed_mult = 1.0
	if player.archetype == "Builder":
		build_speed_mult = 3.0
		
	var progress_rate = (100.0 / target_structure.data.build_time) * build_speed_mult
	target_structure.advance_build(progress_rate * delta)

func physics_update(_delta: float) -> void:
	# Cancel on movement input
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_right"): input_dir.x += 1
	if Input.is_action_pressed("move_left"):  input_dir.x -= 1
	if Input.is_action_pressed("move_down"):  input_dir.y += 1
	if Input.is_action_pressed("move_up"):    input_dir.y -= 1
	if input_dir != Vector2.ZERO:
		player.state_machine.transition_to("walk")
