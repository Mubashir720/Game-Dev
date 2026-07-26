extends CanvasLayer

var top_bar: ColorRect
var bottom_bar: ColorRect
var label: Label

func play_moment(moment_title: String) -> void:
	# Programmatic UI elements creation
	var control := Control.new()
	control.layout_mode = 3
	control.anchors_preset = 15
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control)
	
	# Top black bar
	top_bar = ColorRect.new()
	top_bar.color = Color.BLACK
	top_bar.custom_minimum_size = Vector2(0, 0) # animate height
	top_bar.anchors_preset = 10 # top wide
	top_bar.anchor_right = 1.0
	top_bar.size = Vector2(1280, 0)
	control.add_child(top_bar)
	
	# Bottom black bar
	bottom_bar = ColorRect.new()
	bottom_bar.color = Color.BLACK
	bottom_bar.anchors_preset = 12 # bottom wide
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.size = Vector2(1280, 0)
	bottom_bar.grow_vertical = 0
	control.add_child(bottom_bar)
	
	# Center Label
	label = Label.new()
	label.text = moment_title.replace("_", " ").to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchors_preset = 8 # center
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.anchor_right = 0.5
	label.anchor_bottom = 0.5
	label.grow_horizontal = 2
	label.grow_vertical = 2
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0)) # Gold
	label.modulate.a = 0.0
	control.add_child(label)
	
	# Slide in letterboxes and apply slow motion
	var tween := create_tween()
	tween.set_ignore_time_scale(true) # Run at real time speed
	tween.set_parallel(true)
	
	# Animate bars
	tween.tween_property(top_bar, "size:y", 68.0, 0.4)
	tween.tween_property(bottom_bar, "size:y", 68.0, 0.4)
	tween.tween_property(bottom_bar, "position:y", 720.0 - 68.0, 0.4)
	
	# Slow motion trigger
	tween.tween_property(Engine, "time_scale", 0.25, 0.25)
	
	# Fade in text
	tween.tween_property(label, "modulate:a", 1.0, 0.4).set_delay(0.2)
	
	# Hold sequence
	var hold_tween := create_tween()
	hold_tween.set_ignore_time_scale(true)
	hold_tween.tween_interval(2.6) # hold for 2.6 seconds
	
	# Slide out and restore speed
	hold_tween.tween_property(top_bar, "size:y", 0.0, 0.4)
	hold_tween.tween_property(bottom_bar, "size:y", 0.0, 0.4)
	hold_tween.tween_property(bottom_bar, "position:y", 720.0, 0.4)
	hold_tween.tween_property(label, "modulate:a", 0.0, 0.3)
	hold_tween.tween_property(Engine, "time_scale", 1.0, 0.3)
	hold_tween.tween_callback(queue_free)
