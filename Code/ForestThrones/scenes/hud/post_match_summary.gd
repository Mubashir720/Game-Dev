extends Control

## ═══════════════════════════════════════════════════════════════════════════════
##  POST-MATCH SUMMARY — the payoff screen.
##
##  GDD §12 ends the match with "Traitor revealed. Clips shown. XP awarded." and
##  §11 makes the reveal the emotional centre of the whole design. This screen is
##  where a match becomes a story you can retell, so it leads with the answer to
##  the question everyone has been asking for 25 minutes: who had the token?
##
##  Order is deliberate:
##    1. Result — did your squad win
##    2. THE TRAITORS — every token holder, whether they activated, in every squad
##    3. Final standings — treasury and survivors, so the coin win condition reads
##    4. Your match — XP earned, broken down by GDD §15's award table
## ═══════════════════════════════════════════════════════════════════════════════

const UITheme = preload("res://scenes/hud/ui_theme.gd")

var director = null
var _winner = null


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_result(match_director, winner) -> void:
	director = match_director
	_winner = winner
	_build()
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.5)


func _build() -> void:
	for c in get_children():
		c.queue_free()

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.92)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UITheme.SPACE_LG)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UITheme.SPACE_SM)
	margin.add_child(col)

	# ── Result ────────────────────────────────────────────────────────────────
	var player_squad = director.player_squad if director else null
	var won: bool = _winner != null and _winner == player_squad
	var headline: String = "VICTORY" if won else ("DEFEAT" if player_squad else "MATCH OVER")
	var tint: Color = UITheme.GOLD if won else UITheme.BLOOD
	col.add_child(UITheme.title(headline, UITheme.FONT_DISPLAY, tint))

	var sub := "Your squad held the forest." if won else "The forest kept its throne."
	if _winner != null and not won:
		sub = "%s took the throne." % _squad_name(_winner)
	var sub_label := UITheme.body(sub, UITheme.FONT_LABEL, UITheme.TEXT_MUTED)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub_label)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", UITheme.SPACE_MD)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	body.add_child(_traitor_panel())
	body.add_child(_standings_panel())

	# ── Actions ───────────────────────────────────────────────────────────────
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", UITheme.SPACE_SM)
	col.add_child(actions)

	var again := UITheme.primary_button("Play Again")
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func():
		GameManager.game_state = Constants.GameState.LOBBY
		get_tree().change_scene_to_file("res://scenes/menus/loading_screen.tscn"))
	actions.add_child(again)

	var menu := UITheme.secondary_button("Main Menu")
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(func():
		GameManager.game_state = Constants.GameState.LOBBY
		get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn"))
	actions.add_child(menu)


## GDD §11: six tokens across six squads, two squads clean. Showing the FULL
## distribution — including which two squads were never at risk — is what makes
## the next match's paranoia informed rather than random.
func _traitor_panel() -> Control:
	var p := UITheme.panel(Color(0.13, 0.045, 0.055, 0.92), UITheme.BLOOD)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UITheme.SPACE_XS)
	p.add_child(col)

	col.add_child(UITheme.title("THE TRAITORS", UITheme.FONT_HEADING, UITheme.BLOOD))

	if director == null:
		return p

	var clean := 0
	for s in director.squads:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UITheme.SPACE_SM)
		col.add_child(row)

		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel",
			UITheme.flat_style(s.squad_color, UITheme.RADIUS_PILL))
		row.add_child(dot)

		var nm := UITheme.body(_squad_name(s), UITheme.FONT_LABEL, UITheme.TEXT)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)

		var verdict := "no traitor"
		var vtint: Color = UITheme.MOSS
		if s.traitor != null and is_instance_valid(s.traitor):
			if s.traitor_active:
				verdict = "%s — BETRAYED" % String(s.traitor.archetype_id).capitalize()
				vtint = UITheme.BLOOD
			else:
				verdict = "%s — never activated" % String(s.traitor.archetype_id).capitalize()
				vtint = UITheme.GOLD
		else:
			clean += 1

		var v := UITheme.body(verdict, UITheme.FONT_MICRO, vtint)
		v.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(v)

	col.add_child(UITheme.body(
		"%d squads were clean the whole match." % clean,
		UITheme.FONT_MICRO, UITheme.TEXT_FAINT))
	return p


func _standings_panel() -> Control:
	var p := UITheme.panel(Color(0.055, 0.075, 0.105, 0.92), UITheme.GOLD_DIM)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UITheme.SPACE_XS)
	p.add_child(col)

	col.add_child(UITheme.title("FINAL STANDINGS", UITheme.FONT_HEADING, UITheme.GOLD))

	if director == null:
		return p

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UITheme.SPACE_SM)
	col.add_child(head)
	var h1 := _cell("SQUAD", UITheme.FONT_MICRO, UITheme.TEXT_FAINT)
	h1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h1)
	var h2 := _cell("ALIVE", UITheme.FONT_MICRO, UITheme.TEXT_FAINT, 54)
	h2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(h2)
	var h3 := _cell("COINS", UITheme.FONT_MICRO, UITheme.TEXT_FAINT, 64)
	h3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(h3)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)

	var rank := 1
	for row_data in director.leaderboard():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UITheme.SPACE_SM)
		rows.add_child(row)

		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel",
			UITheme.flat_style(row_data.color, UITheme.RADIUS_PILL))
		row.add_child(dot)

		var nm := UITheme.body("%d. %s" % [rank, row_data.name], UITheme.FONT_LABEL, UITheme.TEXT)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)

		var alive := _cell(str(row_data.alive), UITheme.FONT_LABEL, UITheme.TEXT_MUTED, 54)
		alive.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(alive)
		var coins := _cell(str(row_data.treasury), UITheme.FONT_LABEL, UITheme.GOLD, 64)
		coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(coins)
		rank += 1

	# GDD §15 XP table.
	var xp := 100
	var lines: Array[String] = ["Match played  +100"]
	if _winner != null and director != null and _winner == director.player_squad:
		xp += 300
		lines.append("Squad victory  +300")
	col.add_child(UITheme.body("XP EARNED  %d" % xp, UITheme.FONT_HEADING, UITheme.MOSS))
	for l in lines:
		col.add_child(UITheme.body(l, UITheme.FONT_MICRO, UITheme.TEXT_MUTED))
	return p


## A fixed-width, non-wrapping table cell.
##
## UITheme.body() word-wraps by default, which is right for prose and wrong for
## a table: in a narrow column it turned the "ALIVE" and "COINS" headers into
## vertical stacks of single letters.
func _cell(text: String, size: int, tint: Color, width: int = 0) -> Label:
	var l := UITheme.body(text, size, tint)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	if width > 0:
		l.custom_minimum_size = Vector2(width, 0)
	return l


func _squad_name(squad) -> String:
	if squad == null:
		return "Nobody"
	var names = load("res://scenes/ai/match_director.gd").SQUAD_NAMES
	return String(names[squad.squad_index % names.size()])
