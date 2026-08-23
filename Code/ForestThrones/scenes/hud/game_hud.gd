extends Control

## ═══════════════════════════════════════════════════════════════════════════════
##  GAME HUD — the in-match interface, built for a thumb.
##
##  The previous HUD was a single centred Label reading "Forest Thrones — Match
##  In Progress". This is the real thing, and every element on it exists because
##  a specific GDD system is unplayable without it:
##
##    • Virtual joystick + action cluster   — it is a touchscreen game (§17)
##    • HP / Hunger / Thirst                — §8, all three can kill you
##    • Squad roster with Trust dots        — §11, the entire deduction loop
##    • Treasury and stockpile              — §7, the win condition if time runs out
##    • Match clock with phase markers      — §12, minute 8 and minute 17 change everything
##    • Ransom ticker                       — §10, a capture is broadcast to all 32 players
##    • Event feed                          — betrayals and kills need to be witnessed
##
##  Layout rules: nothing interactive within 40 px of a screen edge (rounded
##  corners and gesture bars eat that), every button at least 56 px, and the
##  bottom-centre third kept clear because that is where the character stands.
## ═══════════════════════════════════════════════════════════════════════════════

const UITheme = preload("res://scenes/hud/ui_theme.gd")
const Joystick = preload("res://scenes/hud/virtual_joystick.gd")
const MinimapWidget = preload("res://scenes/minimap/minimap.gd")

var director = null
var world = null
var player: Actor = null

var _hp_bar: ProgressBar = null
var _hunger_bar: ProgressBar = null
var _thirst_bar: ProgressBar = null
var _clock: Label = null
var _phase: Label = null
var _squads_alive: Label = null
var _coins: Label = null
var _res_labels: Dictionary = {}
var _roster_rows: Array = []
var _feed: VBoxContainer = null
var _ticker: PanelContainer = null
var _ticker_label: Label = null
var _joystick: Control = null
var _ability_button: Button = null
var _ability_cooldown: ProgressBar = null
var _minimap: Control = null

var _ticker_timer := 0.0
var _feed_lines: Array = []


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_connect_events()


func bind_match(match_director, world_node) -> void:
	director = match_director
	world = world_node
	player = match_director.player_actor
	if player:
		player.hp_changed.connect(func(_c, _m): _refresh_vitals())
	if _minimap and _minimap.has_method("bind_match"):
		_minimap.bind_match(match_director, world_node)
	_refresh_ability()
	_rebuild_roster()
	_refresh_clock()
	_refresh_vitals()
	_refresh_economy()


# ═══════════════════════════════════════════════════════════════════════════════
#  LAYOUT
# ═══════════════════════════════════════════════════════════════════════════════

func _build() -> void:
	for c in get_children():
		c.queue_free()

	# Safe-area inset. Phones have rounded corners, notches and a gesture bar;
	# anything closer than this to an edge is either clipped or un-pressable.
	#
	# This MUST be a plain Control, not a MarginContainer. A MarginContainer is a
	# layout container: it force-fits every child to its own rect and throws away
	# their anchors, which collapsed the whole HUD — top bar, both side columns
	# and the control cluster — into one full-width panel stacked on top of
	# itself. A Control leaves anchored children alone, which is the entire point
	# of anchoring them.
	const INSET := 22.0
	var safe := Control.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.offset_left = INSET
	safe.offset_top = INSET
	safe.offset_right = -INSET
	safe.offset_bottom = -INSET
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)

	_build_top_bar(safe)
	_build_left_column(safe)
	_build_right_column(safe)
	_build_controls(safe)


func _build_top_bar(parent: Control) -> void:
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", UITheme.SPACE_SM)
	top.custom_minimum_size = Vector2(0, 120)
	parent.add_child(top)

	# Left slot keeps the clock centred regardless of the right slot's width.
	var lspacer := Control.new()
	lspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lspacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(lspacer)

	var clock_panel := UITheme.panel(Color(0.055, 0.075, 0.105, 0.82), UITheme.GOLD_DIM)
	clock_panel.custom_minimum_size = Vector2(260, 0)
	clock_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(clock_panel)

	var clock_col := VBoxContainer.new()
	clock_col.add_theme_constant_override("separation", 0)
	clock_panel.add_child(clock_col)

	_clock = UITheme.title("25:00", UITheme.FONT_HEADING, UITheme.TEXT)
	clock_col.add_child(_clock)

	_phase = UITheme.body("SUSPICION PHASE", UITheme.FONT_MICRO, UITheme.GOLD)
	_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase.autowrap_mode = TextServer.AUTOWRAP_OFF
	clock_col.add_child(_phase)

	_squads_alive = UITheme.body("8 squads · 32 alive", UITheme.FONT_MICRO, UITheme.TEXT_MUTED)
	_squads_alive.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_squads_alive.autowrap_mode = TextServer.AUTOWRAP_OFF
	clock_col.add_child(_squads_alive)

	var rspacer := Control.new()
	rspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rspacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(rspacer)

	# Ransom ticker sits directly under the clock — GDD §10 wants every capture
	# in front of all 32 players, so it takes the most-looked-at strip on screen.
	_ticker = UITheme.panel(Color(0.30, 0.06, 0.08, 0.90), UITheme.EMBER)
	_ticker.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_ticker.position.y = 132
	_ticker.visible = false
	_ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_ticker)

	_ticker_label = UITheme.body("", UITheme.FONT_LABEL, Color.WHITE)
	_ticker.add_child(_ticker_label)


func _build_left_column(parent: Control) -> void:
	var left := VBoxContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", UITheme.SPACE_SM)
	left.custom_minimum_size = Vector2(268, 0)
	parent.add_child(left)

	# ── Vitals ────────────────────────────────────────────────────────────────
	var vit := UITheme.panel(Color(0.055, 0.075, 0.105, 0.82), UITheme.GOLD_DIM)
	vit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(vit)

	var vcol := VBoxContainer.new()
	vcol.add_theme_constant_override("separation", UITheme.SPACE_XS)
	vit.add_child(vcol)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", UITheme.SPACE_SM)
	vcol.add_child(name_row)
	var pname := UITheme.body("YOU", UITheme.FONT_LABEL, UITheme.TEXT)
	pname.name = "PlayerName"
	pname.autowrap_mode = TextServer.AUTOWRAP_OFF
	pname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(pname)
	var prole := UITheme.body("", UITheme.FONT_MICRO, UITheme.GOLD)
	prole.name = "PlayerRole"
	# AUTOWRAP_OFF matters: UITheme.body() word-wraps by default, and in a tight
	# HBox that turned "KING" into four stacked letters.
	prole.autowrap_mode = TextServer.AUTOWRAP_OFF
	prole.custom_minimum_size = Vector2(78, 0)
	prole.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_row.add_child(prole)

	_hp_bar = UITheme.stat_bar(UITheme.BLOOD, 16)
	vcol.add_child(_hp_bar)
	_hunger_bar = UITheme.stat_bar(Color(0.88, 0.55, 0.24), 8)
	vcol.add_child(_hunger_bar)
	_thirst_bar = UITheme.stat_bar(UITheme.FROST, 8)
	vcol.add_child(_thirst_bar)

	# ── Squad roster with Trust dots (GDD §11) ────────────────────────────────
	var roster := UITheme.panel(Color(0.055, 0.075, 0.105, 0.82), UITheme.GOLD_DIM)
	roster.name = "RosterPanel"
	roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(roster)

	var rcol := VBoxContainer.new()
	rcol.name = "RosterList"
	rcol.add_theme_constant_override("separation", UITheme.SPACE_XS)
	roster.add_child(rcol)
	rcol.add_child(UITheme.body("YOUR SQUAD", UITheme.FONT_MICRO, UITheme.TEXT_FAINT))

	# ── Event feed ────────────────────────────────────────────────────────────
	_feed = VBoxContainer.new()
	_feed.add_theme_constant_override("separation", 2)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_feed)


func _build_right_column(parent: Control) -> void:
	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", UITheme.SPACE_SM)
	right.custom_minimum_size = Vector2(210, 0)
	parent.add_child(right)

	# Minimap first — it is the most-glanced-at element in the match.
	var map_frame := UITheme.panel(Color(0.035, 0.050, 0.070, 0.88), UITheme.GOLD_DIM)
	map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(map_frame)

	_minimap = MinimapWidget.new()
	_minimap.name = "Minimap"
	_minimap.map_size = Vector2(196, 196)
	_minimap.custom_minimum_size = Vector2(196, 196)
	map_frame.add_child(_minimap)

	var econ := UITheme.panel(Color(0.055, 0.075, 0.105, 0.82), UITheme.GOLD_DIM)
	econ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Do not let this panel absorb the column's leftover height. Without this it
	# stretched to 341px for ~130px of content and swallowed the action buttons.
	econ.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.add_child(econ)

	var ecol := VBoxContainer.new()
	ecol.add_theme_constant_override("separation", UITheme.SPACE_SM)
	econ.add_child(ecol)

	var coin_row := HBoxContainer.new()
	coin_row.custom_minimum_size = Vector2(0, 30)
	ecol.add_child(coin_row)
	var coin_tag := UITheme.line("TREASURY", UITheme.FONT_MICRO, UITheme.TEXT_FAINT)
	coin_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coin_row.add_child(coin_tag)
	_coins = UITheme.line("0", UITheme.FONT_HEADING, UITheme.GOLD)
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coin_row.add_child(_coins)

	var sep := HSeparator.new()
	ecol.add_child(sep)

	# Two columns, not four stacked rows: same information in half the height,
	# which is what buys the action cluster its room back.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UITheme.SPACE_MD)
	grid.add_theme_constant_override("v_separation", UITheme.SPACE_XS)
	ecol.add_child(grid)

	for t in [Constants.ResourceType.WOOD, Constants.ResourceType.STONE,
			Constants.ResourceType.FOOD, Constants.ResourceType.METAL]:
		var cell := HBoxContainer.new()
		cell.custom_minimum_size = Vector2(88, 22)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", UITheme.SPACE_XS)
		grid.add_child(cell)

		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(9, 9)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel",
			UITheme.flat_style(UITheme.resource_color(t), UITheme.RADIUS_PILL))
		cell.add_child(dot)

		var nm := UITheme.line(UITheme.resource_name(t), UITheme.FONT_MICRO, UITheme.TEXT_MUTED)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(nm)

		var val := UITheme.line("0", UITheme.FONT_LABEL, UITheme.TEXT)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.custom_minimum_size = Vector2(26, 0)
		cell.add_child(val)
		_res_labels[t] = val


func _build_controls(parent: Control) -> void:
	# ── Virtual joystick, bottom-left ─────────────────────────────────────────
	_joystick = Joystick.new()
	_joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_joystick.size = Vector2(360, 330)
	_joystick.position = Vector2(0, -330)
	parent.add_child(_joystick)

	# ── Action cluster, bottom-right ──────────────────────────────────────────
	# GEOMETRY IS MEASURED, NOT GUESSED. The previous version assumed the
	# right-hand column stopped around y=480 on a 720-tall screen. It actually
	# reached y=599, so ATTACK, BUILD and the ability button all sat on top of
	# the treasury panel, and "RALLY CRY" ran 2px off the right edge of the
	# screen. tools/hud_probe.gd now measures every rect and fails the build on
	# any overlap or off-screen control — run it after touching this function.
	var cluster := Control.new()
	cluster.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	cluster.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cluster.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cluster.size = Vector2(330, 230)
	cluster.position = Vector2(-330, -230)
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cluster)

	# Thumb-arc placement: the primary action sits where the thumb rests, the
	# rest curve away from it. A vertical stack of equal buttons is the classic
	# mistake — the top one is unreachable without shifting grip.
	var attack := _action_button("ATTACK", UITheme.BLOOD, 108, 108, UITheme.FONT_LABEL)
	attack.position = Vector2(196, 106)
	attack.pressed.connect(func(): if player: player.try_attack())
	cluster.add_child(attack)

	var interact := _action_button("USE", UITheme.MOSS, 76, 76)
	interact.position = Vector2(76, 128)
	interact.pressed.connect(func(): if player: player.try_interact())
	cluster.add_child(interact)

	var build := _action_button("BUILD", UITheme.FROST, 72, 72)
	build.position = Vector2(92, 26)
	build.pressed.connect(func():
		if player:
			player.build_mode = not player.build_mode
			_push_feed("Build mode " + ("ON" if player.build_mode else "OFF"), UITheme.FROST))
	cluster.add_child(build)

	# The ability is a PILL, not a circle. Twelve archetypes means twelve names,
	# and "SHIELD WALL" / "RAPID BUILD" do not fit inside an 84px disc — that is
	# what pushed the button off-screen. A pill fits the longest of them and
	# tells the player what the button does without an icon set.
	var ability_slot := Control.new()
	ability_slot.position = Vector2(176, 6)
	ability_slot.size = Vector2(148, 58)
	ability_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cluster.add_child(ability_slot)

	_ability_button = _action_button("ABILITY", UITheme.PLUM, 148, 58)
	_ability_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ability_button.pressed.connect(_on_ability)
	ability_slot.add_child(_ability_button)

	# A drain bar along the bottom of the pill: the cooldown is readable at a
	# glance without a separate timer widget.
	_ability_cooldown = ProgressBar.new()
	_ability_cooldown.show_percentage = false
	_ability_cooldown.min_value = 0.0
	_ability_cooldown.max_value = 1.0
	_ability_cooldown.value = 1.0
	_ability_cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_cooldown.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_ability_cooldown.offset_left = 10
	_ability_cooldown.offset_right = -10
	_ability_cooldown.offset_top = -12
	_ability_cooldown.offset_bottom = -6
	_ability_cooldown.add_theme_stylebox_override("background",
		UITheme.flat_style(Color(0, 0, 0, 0.45), UITheme.RADIUS_PILL))
	_ability_cooldown.add_theme_stylebox_override("fill",
		UITheme.flat_style(UITheme.PLUM.lightened(0.35), UITheme.RADIUS_PILL))
	ability_slot.add_child(_ability_cooldown)


## `clip_text` is load-bearing. Without it a Button's minimum width is driven by
## its label, so a long caption silently inflates the control past the size it
## was placed at — which is exactly how the ability button ended up hanging off
## the edge of the screen.
func _action_button(label: String, tint: Color, w: int, h: int,
		font_size: int = UITheme.FONT_MICRO) -> Button:
	var b := Button.new()
	b.text = label
	b.clip_text = true
	b.custom_minimum_size = Vector2(w, h)
	b.size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", font_size)

	# Opaque enough that the button owns its colour. At 0.34 alpha the ATTACK
	# disc read lavender over water and red over grass — the primary action
	# changing hue with the terrain behind it. Darkening the tint keeps the
	# white caption legible on the light ones (FROST, MOSS) too.
	var base: Color = tint.darkened(0.42)
	var states := {
		"normal":   [Color(base.r, base.g, base.b, 0.88), tint],
		"hover":    [Color(tint.r, tint.g, tint.b, 0.80), Color.WHITE],
		"pressed":  [Color(tint.r, tint.g, tint.b, 0.95), Color.WHITE],
		"disabled": [Color(base.r, base.g, base.b, 0.55), Color(tint.r, tint.g, tint.b, 0.45)],
	}
	for state in states:
		var pair: Array = states[state]
		var sb: StyleBoxFlat = UITheme.button_style(pair[0], pair[1], UITheme.RADIUS_PILL)
		# button_style pads 24px each side for text buttons in menus. On a 72px
		# disc that leaves 24px of text room, which clipped "BUILD" to "BUI" and
		# "ATTACK" to "ATTAC". These are fixed-size discs — the caption gets the
		# whole width.
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override(state, sb)

	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	return b


# ═══════════════════════════════════════════════════════════════════════════════
#  LIVE DATA
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if player and is_instance_valid(player) and _joystick:
		player.set_stick_input(_joystick.value)

	_refresh_clock()
	_refresh_vitals()
	_refresh_economy()
	_refresh_roster()
	_refresh_ability()

	if _ticker_timer > 0.0:
		_ticker_timer -= delta
		if _ticker_timer <= 0.0 and _ticker:
			_ticker.visible = false


func _refresh_clock() -> void:
	if _clock == null:
		return
	var remaining: float = max(0.0, Constants.MATCH_DURATION - GameManager.match_time)
	_clock.text = "%d:%02d" % [int(remaining) / 60, int(remaining) % 60]

	var t: float = GameManager.match_time
	if t < Constants.TRAITOR_ACTIVATION_UNLOCK_TIME:
		_phase.text = "SUSPICION PHASE"
		_phase.add_theme_color_override("font_color", UITheme.GOLD)
	elif t < Constants.ZONE_SHRINK_START:
		_phase.text = "BETRAYAL WINDOW OPEN"
		_phase.add_theme_color_override("font_color", UITheme.EMBER)
	else:
		_phase.text = "THE BORDER IS CLOSING"
		_phase.add_theme_color_override("font_color", UITheme.BLOOD)

	if director and _squads_alive:
		_squads_alive.text = "%d squads · %d alive" % [
			director.alive_squad_count(), director.alive_player_count()]


func _refresh_vitals() -> void:
	if player == null or not is_instance_valid(player):
		return
	if _hp_bar:
		_hp_bar.value = (player.hp / player.max_hp()) * 100.0
		# HP bar shifts colour as it drops, so peripheral vision catches it.
		var ratio := player.hp / player.max_hp()
		var tint: Color = UITheme.BLOOD if ratio > 0.4 else UITheme.EMBER
		if ratio <= 0.15:
			tint = Color(1.0, 0.25, 0.20)
		_hp_bar.add_theme_stylebox_override("fill", UITheme.flat_style(tint, UITheme.RADIUS_PILL))
	if _hunger_bar:
		_hunger_bar.value = player.hunger
	if _thirst_bar:
		_thirst_bar.value = player.thirst

	var nm := find_child("PlayerName", true, false)
	if nm is Label:
		nm.text = player.archetype_id.capitalize()
	var rl := find_child("PlayerRole", true, false)
	if rl is Label:
		rl.text = UITheme.role_name(player.role).to_upper()
		rl.add_theme_color_override("font_color", UITheme.role_color(player.role))


func _refresh_economy() -> void:
	if director == null or director.player_squad == null:
		return
	var brain = director.player_squad
	if _coins:
		_coins.text = str(brain.treasury)
	for t in _res_labels.keys():
		_res_labels[t].text = str(brain.stock_of(t))


func _rebuild_roster() -> void:
	var list := find_child("RosterList", true, false)
	if list == null or director == null or director.player_squad == null:
		return
	for c in list.get_children():
		if c.name != "":
			pass
	# Keep the header, drop old rows.
	var children := list.get_children()
	for i in range(children.size() - 1, 0, -1):
		children[i].queue_free()
	_roster_rows.clear()

	for m in director.player_squad.members:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UITheme.SPACE_XS)
		list.add_child(row)

		# Trust dot (GDD §11) — green / yellow / orange, NEVER red.
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel",
			UITheme.flat_style(UITheme.TRUST_GREEN, UITheme.RADIUS_PILL))
		row.add_child(dot)

		var label := UITheme.body(m.archetype_id.capitalize(), UITheme.FONT_MICRO, UITheme.TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var bar := UITheme.stat_bar(UITheme.MOSS, 6)
		bar.custom_minimum_size = Vector2(70, 6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)

		_roster_rows.append({"actor": m, "dot": dot, "bar": bar, "label": label})


func _refresh_roster() -> void:
	for r in _roster_rows:
		var a: Actor = r.actor
		if not is_instance_valid(a):
			continue
		r.bar.value = (a.hp / a.max_hp()) * 100.0
		var tint: Color = UITheme.MOSS
		if a.is_downed():
			tint = UITheme.EMBER
		elif not a.is_alive():
			tint = UITheme.TEXT_FAINT
		r.bar.add_theme_stylebox_override("fill", UITheme.flat_style(tint, UITheme.RADIUS_PILL))

		# Trust colour from the actor's tracked score.
		var trust: Color = UITheme.TRUST_GREEN
		if a.trust_score <= 40.0:
			trust = UITheme.TRUST_ORANGE
		elif a.trust_score <= 70.0:
			trust = UITheme.TRUST_YELLOW
		r.dot.add_theme_stylebox_override("panel", UITheme.flat_style(trust, UITheme.RADIUS_PILL))


# ═══════════════════════════════════════════════════════════════════════════════
#  EVENTS
# ═══════════════════════════════════════════════════════════════════════════════

func _connect_events() -> void:
	EventBus.traitor_revealed.connect(func(p):
		_push_feed("%s WAS THE TRAITOR" % _name_of(p), UITheme.BLOOD)
		_show_ticker("BETRAYAL — %s has turned" % _name_of(p), 6.0))
	EventBus.treasury_stolen.connect(func(thief, _squad, amount):
		_push_feed("%s stole %d coins" % [_name_of(thief), amount], UITheme.EMBER))
	EventBus.player_killed.connect(func(victim, killer):
		_push_feed("%s eliminated %s" % [_name_of(killer), _name_of(victim)], UITheme.TEXT_MUTED))
	EventBus.player_downed.connect(func(p):
		_push_feed("%s is down" % _name_of(p), UITheme.EMBER))
	EventBus.ransom_posted.connect(func(_captor, prisoner, amount):
		_show_ticker("RANSOM — %s held for %d coins" % [_name_of(prisoner), amount], 12.0))
	EventBus.legendary_moment.connect(func(kind, _who):
		_push_feed("★ %s" % kind, UITheme.GOLD))
	EventBus.zone_shrink_started.connect(func():
		_show_ticker("THE BORDER IS CLOSING", 8.0))
	EventBus.black_market_warning.connect(func():
		_show_ticker("Black Market opening in 60 seconds", 6.0))


static func _name_of(a) -> String:
	if a == null or not is_instance_valid(a):
		return "Someone"
	if "display_name" in a:
		return String(a.display_name)
	return String(a.name)


func _show_ticker(text: String, duration: float) -> void:
	if _ticker == null:
		return
	_ticker_label.text = text
	_ticker.visible = true
	_ticker_timer = duration
	_ticker.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_ticker, "modulate:a", 1.0, 0.20)


func _push_feed(text: String, tint: Color) -> void:
	if _feed == null:
		return
	var l := UITheme.body(text, UITheme.FONT_MICRO, tint)
	_feed.add_child(l)
	_feed_lines.append(l)
	# Cap the feed. An uncapped kill feed in a 32-player match will happily grow
	# to a hundred labels and quietly eat the frame.
	while _feed_lines.size() > 6:
		var old = _feed_lines.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)


## GDD §4 — fire the archetype's active ability.
func _on_ability() -> void:
	if player == null or player.abilities == null:
		return
	if player.abilities.use():
		_push_feed(player.abilities.ability_display_name(), UITheme.PLUM)
	else:
		_push_feed("%s not ready" % player.abilities.ability_display_name(), UITheme.TEXT_FAINT)


## The button dims and re-fills as the ability recharges, so the cooldown is
## readable without a separate timer widget.
func _refresh_ability() -> void:
	if _ability_button == null or player == null or player.abilities == null:
		return
	var charge: float = player.abilities.charge()
	var ready: bool = charge >= 1.0
	_ability_button.text = player.abilities.ability_display_name().to_upper()
	_ability_button.disabled = not ready
	if _ability_cooldown != null:
		_ability_cooldown.value = charge
		_ability_cooldown.visible = not ready
