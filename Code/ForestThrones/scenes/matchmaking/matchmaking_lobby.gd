extends CanvasLayer

var mmr_rating := 1250
var _search_timer := 0.0
var _is_searching := false
var search_btn: Button
var ticker_lbl: Label
var room_input: LineEdit

func _ready() -> void:
	# Programmatic UI
	var control := Control.new()
	control.layout_mode = 3
	control.anchors_preset = 15
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	add_child(control)
	
	# Dimmed BG
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.05, 0.95)
	bg.anchors_preset = 15
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	control.add_child(bg)
	
	# Center Panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 360)
	panel.anchors_preset = 8
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = 2
	panel.grow_vertical = 2
	control.add_child(panel)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.12, 0.09)
	sb.border_color = Color(0.38, 0.35, 0.25)
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4
	sb.corner_radius_all = 6
	sb.content_margin_left = 16
	sb.content_margin_top = 16
	sb.content_margin_right = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	
	var vbox = VBoxContainer.new()
	vbox.theme_override_constants.separation = 12
	panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "FOREST THRONES LOBBY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)
	
	# MMR Rating Display
	var mmr_lbl = Label.new()
	mmr_lbl.text = "Player Skill Rating (MMR): %d" % mmr_rating
	mmr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mmr_lbl.add_theme_font_size_override("font_size", 12)
	mmr_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	vbox.add_child(mmr_lbl)
	
	# Room Code input
	var room_hbox = HBoxContainer.new()
	room_hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
	vbox.add_child(room_hbox)
	
	var room_lbl = Label.new()
	room_lbl.text = "Room Code: "
	room_hbox.add_child(room_lbl)
	
	room_input = LineEdit.new()
	room_input.placeholder_text = "FRST-88"
	room_input.custom_minimum_size = Vector2(100, 26)
	room_hbox.add_child(room_input)
	
	# Status message
	ticker_lbl = Label.new()
	ticker_lbl.text = "Select room and quick match to search for matches."
	ticker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ticker_lbl.add_theme_font_size_override("font_size", 10)
	ticker_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(ticker_lbl)
	
	# Matchmaking actions
	search_btn = Button.new()
	search_btn.text = "Find Match"
	search_btn.pressed.connect(_on_search_pressed)
	vbox.add_child(search_btn)
	
	# Extra options
	var tutorial_btn = Button.new()
	tutorial_btn.text = "Start Practice Island Tutorial"
	tutorial_btn.pressed.connect(_on_tutorial_pressed)
	vbox.add_child(tutorial_btn)
	
	var pass_btn = Button.new()
	pass_btn.text = "Open Battle Pass rewards"
	pass_btn.pressed.connect(_on_pass_pressed)
	vbox.add_child(pass_btn)
	
	var close_btn = Button.new()
	close_btn.text = "Close Lobby"
	close_btn.pressed.connect(queue_free)
	vbox.add_child(close_btn)

func _process(delta: float) -> void:
	if _is_searching:
		_search_timer += delta
		ticker_lbl.text = "Searching for matchmaking peers... (Elapsed: %ds)" % int(_search_timer)
		if _search_timer >= 3.0:
			# Match found simulation!
			_is_searching = false
			ticker_lbl.text = "Match found! Syncing entities..."
			_start_game_simulation()

func _on_search_pressed() -> void:
	if _is_searching:
		_is_searching = false
		search_btn.text = "Find Match"
		ticker_lbl.text = "Search cancelled."
	else:
		_is_searching = true
		_search_timer = 0.0
		search_btn.text = "Cancel Search"
		ticker_lbl.text = "Searching..."

func _on_tutorial_pressed() -> void:
	var tm_scene = load("res://scenes/tutorial/tutorial_manager.tscn")
	if tm_scene:
		var tm = tm_scene.instantiate()
		get_tree().current_scene.add_child(tm)
		tm.start_tutorial()
	queue_free()

func _on_pass_pressed() -> void:
	var bp_scene = load("res://scenes/progression/battle_pass_ui.tscn")
	if bp_scene:
		var bp = bp_scene.instantiate()
		get_tree().current_scene.add_child(bp)
	queue_free()

func _start_game_simulation() -> void:
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		var game_mgr = get_node_or_null("/root/GameManager")
		if game_mgr:
			game_mgr.start_match()
		queue_free()
	)
