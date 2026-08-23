extends Control

## ═══════════════════════════════════════════════════════════════════════════════
##  CHARACTER SELECT — pick a role, then an archetype within it.
##
##  GDD §4 is explicit: a squad is four fixed ROLES, and each role offers three
##  ARCHETYPES. Presenting twelve characters in one flat grid, as the old screen
##  did, throws away the most important thing the design says about them — that
##  King, Queen, Soldier A and Soldier B do different jobs, and that losing one
##  creates a specific weakness.
##
##  So the screen is two levels: role tabs across the top, three archetype cards
##  below, a live rotating 3D model of the highlighted archetype, and its actual
##  active/passive abilities in plain words. Every ability string here is copied
##  from the GDD table so the screen never drifts from the design.
## ═══════════════════════════════════════════════════════════════════════════════

const UITheme = preload("res://scenes/hud/ui_theme.gd")
const CharacterFactory = preload("res://scenes/player/character_factory.gd")
const CharacterAnimator = preload("res://scenes/player/character_animator.gd")

## GDD §4 — Archetypes: Active and Passive Abilities.
const ARCHETYPES := {
	"warlord": {
		"name": "Warlord", "role": Constants.Role.KING,
		"active": "Rally Cry — squad within 10 tiles gets +20% speed and damage for 8s. (45s)",
		"passive": "War Banner — plant a flag for +15% squad damage within 8 tiles.",
		"style": "Frontline anchor. The highest damage ceiling of any King.",
	},
	"regent": {
		"name": "Regent", "role": Constants.Role.KING,
		"active": "Tax Edict — all coin sources +50% for 20s. (90s) Works at 50% even without a Queen.",
		"passive": "Stockpile — carry 50% more of every resource type.",
		"style": "Insurance pick. Keeps the economy alive after a Queen capture.",
	},
	"beastlord": {
		"name": "Beastlord", "role": Constants.Role.KING,
		"active": "Tame wild animals. Tamed beast stats +30%.",
		"passive": "Pack Leader — +15% move speed while your companion lives.",
		"style": "Fights with a partner. Strongest map control in the roster.",
	},
	"engineer": {
		"name": "Engineer", "role": Constants.Role.QUEEN,
		"active": "Overclock — all squad builds take 50% time for 15s. (60s)",
		"passive": "Trap Master — traps deal +40% damage, built twice as fast.",
		"style": "Turns a base into a fortress faster than anyone.",
	},
	"witch": {
		"name": "Witch", "role": Constants.Role.QUEEN,
		"active": "Hex — target gets -30% speed and -20% damage for 10s. (30s)",
		"passive": "Curse Ward — once per match, auto-removes a Forest Curse.",
		"style": "Control and denial. Wins fights before they start.",
	},
	"herbalist": {
		"name": "Herbalist", "role": Constants.Role.QUEEN,
		"active": "Brew — healing potion from 2 herbs instead of 3. Restores 35 HP.",
		"passive": "Mend — squadmates within 5 tiles of base regen +2 HP/s.",
		"style": "Sustain. A squad that never has to retreat to heal.",
	},
	"guardian": {
		"name": "Guardian", "role": Constants.Role.SOLDIER_A,
		"active": "Shield Wall — hold to block 60% of incoming melee. Cannot attack while blocking.",
		"passive": "Taunt — every 40s, force the nearest enemy to attack you for 5s.",
		"style": "The wall. Buys the time your squad needs to react.",
	},
	"berserker": {
		"name": "Berserker", "role": Constants.Role.SOLDIER_A,
		"active": "Frenzy — 6s of double attack speed, knockback-immune. (2 min)",
		"passive": "Bloodlust — +5% damage per kill this match, stacking to +40%.",
		"style": "Snowball. Terrifying if fed, ordinary if starved.",
	},
	"sapper": {
		"name": "Sapper", "role": Constants.Role.SOLDIER_A,
		"active": "Demolish — destroy any structure in 3 seconds. (20s)",
		"passive": "Trap Disarm — remove enemy bear traps without triggering them.",
		"style": "The answer to a turtled base. Nothing stays built near you.",
	},
	"scout": {
		"name": "Scout", "role": Constants.Role.SOLDIER_B,
		"active": "Flare — reveal all enemies within 20 tiles on the minimap for 30s.",
		"passive": "Stealth — invisible on enemy minimaps while not attacking.",
		"style": "Information. Your squad always knows what is coming.",
	},
	"archer": {
		"name": "Archer", "role": Constants.Role.SOLDIER_B,
		"active": "Volley — fire 3 arrows in a spread. (4s)",
		"passive": "Eagle Eye — +50% ranged damage at 6+ tiles.",
		"style": "Reach. Punishes anyone crossing open ground.",
	},
	"builder": {
		"name": "Builder", "role": Constants.Role.SOLDIER_B,
		"active": "Rapid Build — structures built 3x faster. Can build while moving.",
		"passive": "Blueprint — copy any enemy structure you have seen, at 50% cost.",
		"style": "Tempo. Your base exists before anyone else's does.",
	},
}

const ROLE_TABS := [
	Constants.Role.KING, Constants.Role.QUEEN,
	Constants.Role.SOLDIER_A, Constants.Role.SOLDIER_B,
]

const ROLE_JOB := {
	Constants.Role.KING: "Strongest fighter. Highest HP. Squad anchor. 30s respawn.",
	Constants.Role.QUEEN: "Passive coin income. +30% crafting speed. Capture her and the squad's economy collapses.",
	Constants.Role.SOLDIER_A: "Frontline tank. Shields the squad while it gathers.",
	Constants.Role.SOLDIER_B: "Scout, speed, ranged support, fast building.",
}

var _selected_role: int = Constants.Role.KING
var _selected_id: String = "warlord"
var _preview: Node3D = null
var _preview_spin := 0.0
var _animator: CharacterAnimator = null
var _viewport: SubViewport = null
var _cards_box: VBoxContainer = null
var _detail_box: VBoxContainer = null
var _role_buttons: Array[Button] = []


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_selected_id = GameManager.selected_archetype_id
	if ARCHETYPES.has(_selected_id):
		_selected_role = ARCHETYPES[_selected_id].role
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	add_child(UITheme.backdrop())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UITheme.SPACE_MD)
	add_child(margin)

	var root_col := VBoxContainer.new()
	root_col.add_theme_constant_override("separation", UITheme.SPACE_SM)
	margin.add_child(root_col)

	# ── Header ────────────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	root_col.add_child(header)

	var back := UITheme.ghost_button("< Back")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn"))
	header.add_child(back)

	var htitle := UITheme.title("CHOOSE YOUR ROLE", UITheme.FONT_HEADING, UITheme.TEXT)
	htitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(htitle)

	var confirm := UITheme.primary_button("Confirm")
	confirm.custom_minimum_size = Vector2(160, UITheme.TOUCH_MIN)
	confirm.pressed.connect(_on_confirm)
	header.add_child(confirm)

	# ── Role tabs ─────────────────────────────────────────────────────────────
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", UITheme.SPACE_SM)
	root_col.add_child(tabs)

	_role_buttons.clear()
	for r in ROLE_TABS:
		var b := Button.new()
		b.text = UITheme.role_name(r)
		b.custom_minimum_size = Vector2(0, UITheme.TOUCH_MIN)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		b.pressed.connect(func(): _select_role(r))
		tabs.add_child(b)
		_role_buttons.append(b)

	var job := UITheme.body(ROLE_JOB[_selected_role], UITheme.FONT_LABEL, UITheme.TEXT_MUTED)
	job.name = "RoleJob"
	root_col.add_child(job)

	# ── Body: preview on the left, cards + detail on the right ────────────────
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", UITheme.SPACE_MD)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_col.add_child(body)

	var stage := UITheme.panel(Color(0.055, 0.075, 0.105, 0.88), UITheme.GOLD_DIM)
	stage.custom_minimum_size = Vector2(300, 0)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stage)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	stage.add_child(vpc)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	vpc.add_child(_viewport)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", UITheme.SPACE_SM)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(360, 0)
	body.add_child(right)

	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", UITheme.SPACE_SM)
	right.add_child(_cards_box)

	var detail_panel := UITheme.panel(Color(0.075, 0.095, 0.130, 0.92), UITheme.GOLD_DIM)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_panel)

	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", UITheme.SPACE_SM)
	detail_panel.add_child(_detail_box)

	_select_role(_selected_role)


func _select_role(role: int) -> void:
	_selected_role = role
	var options: Array = CharacterFactory.archetypes_for_role(role)
	if not options.has(_selected_id):
		_selected_id = options[0]

	for i in range(_role_buttons.size()):
		var active: bool = ROLE_TABS[i] == role
		var tint: Color = UITheme.role_color(ROLE_TABS[i])
		_role_buttons[i].add_theme_stylebox_override("normal",
			UITheme.button_style(
				Color(tint.r, tint.g, tint.b, 0.30) if active else UITheme.SURFACE_HIGH,
				tint if active else UITheme.GOLD_DIM))
		_role_buttons[i].add_theme_color_override("font_color",
			Color.WHITE if active else UITheme.TEXT_MUTED)

	var job := find_child("RoleJob", true, false)
	if job is Label:
		job.text = ROLE_JOB[role]

	_rebuild_cards(options)
	_select_archetype(_selected_id)


func _rebuild_cards(options: Array) -> void:
	for c in _cards_box.get_children():
		c.queue_free()
	for id in options:
		var data: Dictionary = ARCHETYPES[id]
		var b := Button.new()
		b.name = "Card_" + id
		b.custom_minimum_size = Vector2(0, UITheme.TOUCH_MIN + 10)
		b.text = "%s   —   %s" % [data.name, data.style]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", UITheme.FONT_LABEL)
		b.pressed.connect(func(): _select_archetype(id))
		_cards_box.add_child(b)


func _select_archetype(id: String) -> void:
	_selected_id = id
	var tint: Color = UITheme.role_color(_selected_role)

	for c in _cards_box.get_children():
		if c is Button:
			var active: bool = c.name == "Card_" + id
			c.add_theme_stylebox_override("normal",
				UITheme.button_style(
					Color(tint.r, tint.g, tint.b, 0.26) if active else UITheme.SURFACE_HIGH,
					tint if active else UITheme.GOLD_DIM))
			c.add_theme_color_override("font_color", Color.WHITE if active else UITheme.TEXT_MUTED)

	_rebuild_detail(id, tint)
	_rebuild_preview(id)


func _rebuild_detail(id: String, tint: Color) -> void:
	for c in _detail_box.get_children():
		c.queue_free()
	var data: Dictionary = ARCHETYPES[id]

	_detail_box.add_child(UITheme.title(String(data.name).to_upper(), UITheme.FONT_HEADING, tint))

	var role_line := UITheme.body(UITheme.role_name(data.role).to_upper(), UITheme.FONT_MICRO, UITheme.TEXT_FAINT)
	_detail_box.add_child(role_line)

	_detail_box.add_child(_ability_block("ACTIVE", String(data.active), UITheme.GOLD))
	_detail_box.add_child(_ability_block("PASSIVE", String(data.passive), UITheme.FROST))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(spacer)

	_detail_box.add_child(UITheme.body(String(data.style), UITheme.FONT_LABEL, UITheme.TEXT_MUTED))


func _ability_block(kind: String, text: String, tint: Color) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(UITheme.body(kind, UITheme.FONT_MICRO, tint))
	col.add_child(UITheme.body(text, UITheme.FONT_LABEL, UITheme.TEXT))
	return col


func _rebuild_preview(id: String) -> void:
	if _viewport == null:
		return
	for c in _viewport.get_children():
		c.queue_free()

	var scene := Node3D.new()
	_viewport.add_child(scene)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.55, 0.72)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	scene.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-30), deg_to_rad(-40), 0)
	key.light_energy = 1.5
	key.light_color = Color(1.0, 0.95, 0.86)
	scene.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-10), deg_to_rad(155), 0)
	rim.light_energy = 1.2
	rim.light_color = UITheme.role_color(_selected_role)
	scene.add_child(rim)

	_preview = CharacterFactory.create_character_by_archetype(id)
	if _preview:
		scene.add_child(_preview)
	_animator = CharacterAnimator.new()

	var cam := Camera3D.new()
	cam.fov = 30.0
	scene.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 2.0, 7.2), Vector3(0.0, 1.20, 0.0), Vector3.UP)
	cam.current = true


func _process(delta: float) -> void:
	if _preview and is_instance_valid(_preview):
		# A character-select preview must READ. A continuous 360-degree turntable
		# spends most of its cycle showing the character's back, which is the one
		# angle that tells the player nothing — and it makes comparing archetypes
		# harder, because you are never looking at two of them from the same
		# angle. Oscillate gently around front-facing instead: alive, but always
		# legible, and it screenshots the same way every time.
		_preview_spin += delta
		_preview.rotation.y = sin(_preview_spin * 0.9) * 0.42
		if _animator:
			_animator.animate_character(_preview, _selected_id, false, delta)


func _on_confirm() -> void:
	GameManager.selected_archetype_id = _selected_id
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
