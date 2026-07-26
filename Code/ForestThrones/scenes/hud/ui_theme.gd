extends RefCounted

static func apply_rpg_theme(root_control: Control) -> void:
	var theme := Theme.new()
	
	# PanelContainer Style (Dark Slate Glassmorphism + Gold Border)
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.09, 0.11, 0.15, 0.88) # #171c26
	panel_sb.border_color = Color(0.83, 0.69, 0.22, 0.95) # Gold #c9a13a
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(8)
	panel_sb.shadow_color = Color(0, 0, 0, 0.5)
	panel_sb.shadow_size = 6
	theme.set_stylebox("panel", "PanelContainer", panel_sb)
	
	# Button Style (Normal)
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.22, 0.29, 0.95)
	btn_normal.border_color = Color(0.70, 0.58, 0.20, 0.8)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(6)
	btn_normal.content_margin_left = 16
	btn_normal.content_margin_right = 16
	btn_normal.content_margin_top = 8
	btn_normal.content_margin_bottom = 8
	theme.set_stylebox("normal", "Button", btn_normal)
	
	# Button Style (Hover)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.28, 0.34, 0.45, 0.95)
	btn_hover.border_color = Color(0.95, 0.80, 0.30, 1.0)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(6)
	btn_hover.content_margin_left = 16
	btn_hover.content_margin_right = 16
	btn_hover.content_margin_top = 8
	btn_hover.content_margin_bottom = 8
	theme.set_stylebox("hover", "Button", btn_hover)
	
	# Label font color
	theme.set_color("font_color", "Label", Color(0.95, 0.93, 0.88))
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.8))
	theme.set_constant("shadow_offset_y", "Label", 1)
	
	root_control.theme = theme
