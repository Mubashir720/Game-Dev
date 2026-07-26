extends CanvasLayer
class_name TutorialManager

var current_step := 1
var label_task: Label
var panel: PanelContainer

# Tracking variables
var _walk_distance := 0.0
var _last_pos := Vector2.ZERO

func start_tutorial() -> void:
	current_step = 1
	_build_ui()
	visible = true
	
	# Connect to event triggers
	EventBus.resource_harvested.connect(_on_resource_harvested)
	EventBus.coins_earned.connect(_on_coins_earned)
	EventBus.beast_tamed.connect(_on_beast_tamed)
	EventBus.ransom_posted.connect(_on_ransom_posted)
	EventBus.ransom_paid.connect(_on_ransom_paid)
	
	var player = get_tree().current_scene.find_child("Player", true, false)
	if is_instance_valid(player):
		_last_pos = player.global_position
		
	set_process(true)
	update_task_display()

func _ready() -> void:
	pass

func _build_ui() -> void:
	# Clean up old
	for c in get_children():
		c.queue_free()
		
	# Panel in top-left
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 70)
	panel.position = Vector2(20, 200) # Below stats panel
	add_child(panel)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.06, 0.85) # Semi-trans wood
	sb.border_color = Color(0.9, 0.7, 0.2) # Gold highlight
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.corner_radius_all = 4
	sb.content_margin_left = 8
	sb.content_margin_top = 8
	sb.content_margin_right = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var header = Label.new()
	header.text = "PRACTICE ISLAND TUTORIAL"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(header)
	
	label_task = Label.new()
	label_task.autowrap_mode = TextServer.AUTOWRAP_WORD
	label_task.add_theme_font_size_override("font_size", 10)
	vbox.add_child(label_task)

func _process(delta: float) -> void:
	if not visible:
		return
		
	var player = get_tree().current_scene.find_child("Player", true, false)
	if not is_instance_valid(player):
		return
		
	match current_step:
		1: # Walk
			var dist = player.global_position.distance_to(_last_pos)
			_last_pos = player.global_position
			_walk_distance += dist
			label_task.text = "Step 1: Walk around using WASD.\nProgress: %d/100m" % int(_walk_distance / 10.0)
			if _walk_distance >= 1000.0:
				advance_step()
		3: # Build
			# Check if player builds wood wall
			var world = player.get_tree().current_scene.find_child("World", true, false)
			if world:
				var structures = world.get_node_or_null("Structures")
				if structures and structures.get_child_count() > 0:
					advance_step()
		4: # Survival
			# Check if player eats or heals
			if player.stats.hunger < 100.0 or player.stats.thirst < 100.0:
				advance_step()
		5: # Combat
			# Check if player is attacking
			if Input.is_action_just_pressed("attack"):
				advance_step()
		6: # Capture
			# Check if player uses capture hold
			if Input.is_action_pressed("capture"):
				advance_step()
		7: # Vendor
			# Check if vendor shop UI is open in scene tree
			var shop = get_tree().current_scene.find_child("VendorShopUI", true, false)
			if is_instance_valid(shop) and shop.visible:
				advance_step()
		8: # Deposit
			# Check if treasury balance increases
			var world = get_tree().current_scene.find_child("World", true, false)
			if world:
				var structures = world.get_node_or_null("Structures")
				if structures:
					for child in structures.get_children():
						if "balance" in child and child.balance > 0:
							advance_step()
							break
		10: # Ransom Board
			# Check if Ransom Board is open
			var rb = get_tree().current_scene.find_child("RansomBoard", true, false)
			if is_instance_valid(rb) and rb.visible:
				advance_step()

func update_task_display() -> void:
	if not is_instance_valid(label_task):
		return
		
	match current_step:
		1:
			label_task.text = "Step 1: Walk around using WASD."
		2:
			label_task.text = "Step 2: Chop down a Tree (E) to harvest Wood."
		3:
			label_task.text = "Step 3: Toggle Build mode (B) and place a Wall."
		4:
			label_task.text = "Step 4: Consume Food/Water to satisfy survival stats."
		5:
			label_task.text = "Step 5: Press Left Click (LMB) to swing your Sword."
		6:
			label_task.text = "Step 6: Hold (R) near an entity to simulate capture flow."
		7:
			label_task.text = "Step 7: Walk to a Merchant Vendor stall and interact (E)."
		8:
			label_task.text = "Step 8: Deposit gathered coins into the physical Treasury chest."
		9:
			label_task.text = "Step 9: Stand close to a Stag companion or feed a Wolf to tame it."
		10:
			label_task.text = "Step 10: Open the notices Ransom Board at the top status panel."

func advance_step() -> void:
	current_step += 1
	_play_chime()
	
	if current_step > 10:
		label_task.text = "Tutorial Complete!\nMMR Rating: +100. Returning to Lobby..."
		set_process(false)
		_complete_tutorial_sequence()
	else:
		update_task_display()

func _play_chime() -> void:
	# Visual text indicator
	var flash_lbl = Label.new()
	flash_lbl.text = "Completed!"
	flash_lbl.add_theme_font_size_override("font_size", 16)
	flash_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	flash_lbl.global_position = panel.global_position + Vector2(80, -25)
	get_tree().current_scene.add_child(flash_lbl)
	
	var tween = create_tween()
	tween.tween_property(flash_lbl, "position:y", flash_lbl.position.y - 30.0, 0.7)
	tween.tween_property(flash_lbl, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tween.tween_callback(flash_lbl.queue_free).set_delay(0.7)

func _complete_tutorial_sequence() -> void:
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func():
		var lobby_scene = load("res://scenes/matchmaking/matchmaking_lobby.tscn")
		if lobby_scene:
			var lobby = lobby_scene.instantiate()
			lobby.mmr_rating = 1350 # Increased MMR!
			get_tree().current_scene.add_child(lobby)
		queue_free()
	)

# Event signals
func _on_resource_harvested(_type, _amount, _pos) -> void:
	if current_step == 2:
		advance_step()

func _on_coins_earned(_squad, _amount, _source) -> void:
	# General coins trigger
	pass

func _on_beast_tamed(_player, _beast_type) -> void:
	if current_step == 9:
		advance_step()

func _on_ransom_posted(_squad, _p, _a) -> void:
	pass

func _on_ransom_paid(_squad, _p, _a) -> void:
	pass
