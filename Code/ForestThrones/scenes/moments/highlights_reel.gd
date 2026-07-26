extends CanvasLayer

var display_rect: TextureRect
var title_lbl: Label
var frame_index := 0
var playback_timer := 0.0
var active_moment: Dictionary = {}

func open_moment(moment_data: Dictionary) -> void:
	active_moment = moment_data
	frame_index = 0
	playback_timer = 0.0
	
	_build_ui()
	visible = true

func _build_ui() -> void:
	# Main container layout
	var control := Control.new()
	control.layout_mode = 3
	control.anchors_preset = 15
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	add_child(control)
	
	# Dimmed BG
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.anchors_preset = 15
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	control.add_child(bg)
	
	# Dialogue panel container
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
	sb.bg_color = Color(0.15, 0.12, 0.09)
	sb.border_color = Color(0.4, 0.35, 0.25)
	sb.border_width_left = 4
	sb_border_width_top(sb)
	sb.corner_radius_all = 6
	sb.content_margin_left = 16
	sb.content_margin_top = 16
	sb.content_margin_right = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	
	var vbox = VBoxContainer.new()
	vbox.theme_override_constants.separation = 10
	panel.add_child(vbox)
	
	# Header
	title_lbl = Label.new()
	var label_txt = active_moment.get("title", "HIGHLIGHT MOMENT").replace("_", " ").upper()
	title_lbl.text = "MOMENT REEL: " + label_txt
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(title_lbl)
	
	# TextureRect for playback
	var frame_panel = PanelContainer.new()
	frame_panel.custom_minimum_size = Vector2(400, 225)
	var sb_frame = StyleBoxFlat.new()
	sb_frame.bg_color = Color.BLACK
	frame_panel.add_theme_stylebox_override("panel", sb_frame)
	vbox.add_child(frame_panel)
	
	display_rect = TextureRect.new()
	display_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_panel.add_child(display_rect)
	
	# Share Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
	btn_hbox.theme_override_constants.separation = 10
	vbox.add_child(btn_hbox)
	
	var save_btn = Button.new()
	save_btn.text = "Save to Photos"
	save_btn.pressed.connect(func(): _show_share_alert("Saved clip to Photo Library!"))
	btn_hbox.add_child(save_btn)
	
	var share_btn = Button.new()
	share_btn.text = "Share to TikTok"
	share_btn.pressed.connect(func(): _show_share_alert("TikTok sharing initiated!"))
	btn_hbox.add_child(share_btn)
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(queue_free)
	btn_hbox.add_child(close_btn)

func sb_border_width_top(sb: StyleBoxFlat) -> void:
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4

func _process(delta: float) -> void:
	if active_moment.is_empty() or not active_moment.has("frames"):
		return
		
	var frames_list = active_moment.frames
	if frames_list.is_empty():
		return
		
	playback_timer += delta
	# Update frame at 12 FPS (approx every 0.08 seconds)
	if playback_timer >= 0.083:
		playback_timer = 0.0
		frame_index = (frame_index + 1) % frames_list.size()
		if is_instance_valid(display_rect):
			display_rect.texture = frames_list[frame_index]

func _show_share_alert(msg: String) -> void:
	var alert := Label.new()
	alert.text = msg
	alert.add_theme_font_size_override("font_size", 14)
	alert.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert.global_position = get_viewport().get_mouse_position() + Vector2(-50, -25)
	get_tree().current_scene.add_child(alert)
	
	var tween = create_tween()
	tween.tween_property(alert, "position:y", alert.position.y - 35.0, 0.8)
	tween.tween_property(alert, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.tween_callback(alert.queue_free).set_delay(0.8)
