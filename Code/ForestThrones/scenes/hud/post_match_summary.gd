extends CanvasLayer

var winning_squad = null
var list_vbox: VBoxContainer
var title_lbl: Label

func _ready() -> void:
	# Programmatic UI Setup
	var control := Control.new()
	control.layout_mode = 3
	control.anchors_preset = 15
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	add_child(control)
	
	# Dark vignette background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.06, 0.96)
	bg.anchors_preset = 15
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	control.add_child(bg)
	
	# Center Panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 380)
	panel.anchors_preset = 8
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = 2
	panel.grow_vertical = 2
	control.add_child(panel)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.12) # Deep royal burgundy-purple
	sb.border_color = Color(0.9, 0.75, 0.3) # Gold border
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4
	sb.corner_radius_all = 8
	sb.content_margin_left = 20
	sb.content_margin_top = 20
	sb.content_margin_right = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	
	var vbox = VBoxContainer.new()
	vbox.theme_override_constants.separation = 15
	panel.add_child(vbox)
	
	# Scoreboard Title
	title_lbl = Label.new()
	title_lbl.text = "MATCH SUMMARY"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title_lbl)
	
	# Winner Banner
	var winner_banner = PanelContainer.new()
	vbox.add_child(winner_banner)
	var sb_banner = StyleBoxFlat.new()
	sb_banner.bg_color = Color(0.25, 0.18, 0.08, 0.6)
	sb_banner.border_color = Color(1.0, 0.8, 0.2)
	sb_banner.border_width_top = 1
	sb_banner.border_width_bottom = 1
	winner_banner.add_theme_stylebox_override("panel", sb_banner)
	
	var winner_lbl = Label.new()
	winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_lbl.add_theme_font_size_override("font_size", 14)
	winner_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	winner_banner.add_child(winner_lbl)
	
	# Determine winner text
	var game_manager = get_node_or_null("/root/GameManager")
	if is_instance_valid(game_manager):
		winning_squad = game_manager._evaluate_winning_squad()
		
	if winning_squad:
		winner_lbl.text = "👑 VICTORY: SQUAD %d WINS THE FOREST THRONE! 👑" % winning_squad.squad_id
	else:
		winner_lbl.text = "💀 DEFEAT: NO SQUAD SURVIVED THE FOREST CURSE! 💀"
		
	# Squad table list header
	var header_row = HBoxContainer.new()
	header_row.theme_override_constants.separation = 10
	vbox.add_child(header_row)
	
	var h_rank = Label.new()
	h_rank.text = "Rank"
	h_rank.custom_minimum_size = Vector2(50, 0)
	header_row.add_child(h_rank)
	
	var h_squad = Label.new()
	h_squad.text = "Squad"
	h_squad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(h_squad)
	
	var h_gold = Label.new()
	h_gold.text = "Gold Treasury"
	h_gold.custom_minimum_size = Vector2(110, 0)
	h_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(h_gold)
	
	var h_status = Label.new()
	h_status.text = "Status"
	h_status.custom_minimum_size = Vector2(100, 0)
	h_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(h_status)
	
	# Separator line
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Scroll area for squads
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_vbox)
	
	# Populate Squad list
	populate_scoreboard()
	
	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
	btn_hbox.theme_override_constants.separation = 20
	vbox.add_child(btn_hbox)
	
	var highlights_btn = Button.new()
	highlights_btn.text = "Replay Match Highlights"
	highlights_btn.pressed.connect(_on_highlights_pressed)
	btn_hbox.add_child(highlights_btn)
	
	var lobby_btn = Button.new()
	lobby_btn.text = "Return to Lobby"
	lobby_btn.pressed.connect(_on_lobby_pressed)
	btn_hbox.add_child(lobby_btn)
	
	# Small Entry Fade In Animation
	panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	
	# Bounce scale slightly for premium feel
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = panel.custom_minimum_size / 2
	var scale_tween = create_tween()
	scale_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func populate_scoreboard() -> void:
	var game_manager = get_node_or_null("/root/GameManager")
	if not is_instance_valid(game_manager):
		return
		
	# Sort squads by treasury balance
	var sorted_squads = game_manager.squads.duplicate()
	sorted_squads.sort_custom(func(a, b):
		var balance_a = a.treasury.balance if (a.has_method("treasury") and a.treasury) else 0
		var balance_b = b.treasury.balance if (b.has_method("treasury") and b.treasury) else 0
		return balance_a > balance_b
	)
	
	for idx in range(sorted_squads.size()):
		var sq = sorted_squads[idx]
		var row = HBoxContainer.new()
		row.theme_override_constants.separation = 10
		list_vbox.add_child(row)
		
		# Rank Label
		var rank_lbl = Label.new()
		rank_lbl.text = "#%d" % (idx + 1)
		rank_lbl.custom_minimum_size = Vector2(50, 0)
		if idx == 0:
			rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0)) # Golden first
		else:
			rank_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		row.add_child(rank_lbl)
		
		# Squad Name Label
		var name_lbl = Label.new()
		name_lbl.text = "Squad %d" % sq.squad_id
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if sq.squad_id == 0:
			name_lbl.text += " (You)"
			name_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4)) # Highlight player
		row.add_child(name_lbl)
		
		# Gold Balance Label
		var bal = sq.treasury.balance if (sq.has_method("treasury") and sq.treasury) else 0
		var gold_lbl = Label.new()
		gold_lbl.text = "%d Gold" % bal
		gold_lbl.custom_minimum_size = Vector2(110, 0)
		gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		row.add_child(gold_lbl)
		
		# Status Label
		var status_lbl = Label.new()
		status_lbl.custom_minimum_size = Vector2(100, 0)
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if sq.is_eliminated:
			status_lbl.text = "ELIMINATED"
			status_lbl.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
		else:
			status_lbl.text = "ALIVE"
			status_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		row.add_child(status_lbl)

func _on_highlights_pressed() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	var moments_ctrl = game_mgr.get_node_or_null("MomentsEngineController") if game_mgr else null
	if moments_ctrl and not moments_ctrl.saved_moment.is_empty():
		var reel_scene = load("res://scenes/moments/highlights_reel.tscn")
		if reel_scene:
			var reel = reel_scene.instantiate()
			get_tree().current_scene.add_child(reel)
			reel.open_moment(moments_ctrl.saved_moment)
	else:
		# If no moment captured, spawn a warning ticker popup or overlay text
		var msg_lbl = Label.new()
		msg_lbl.text = "No moments captured this match yet!"
		msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg_lbl.global_position = get_viewport().get_mouse_position() + Vector2(-100, -30)
		msg_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		get_tree().current_scene.add_child(msg_lbl)
		
		var tween = create_tween()
		tween.tween_property(msg_lbl, "position:y", msg_lbl.position.y - 40.0, 0.8)
		tween.tween_property(msg_lbl, "modulate:a", 0.0, 0.4).set_delay(0.4)
		tween.tween_callback(msg_lbl.queue_free).set_delay(0.8)

func _on_lobby_pressed() -> void:
	var lobby_scene = load("res://scenes/matchmaking/matchmaking_lobby.tscn")
	if lobby_scene:
		var lobby = lobby_scene.instantiate()
		get_tree().current_scene.add_child(lobby)
	queue_free()
