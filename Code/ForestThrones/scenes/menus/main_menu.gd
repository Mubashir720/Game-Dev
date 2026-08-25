extends Control

## ═══════════════════════════════════════════════════════════════════════════════
##  MAIN MENU — the first screen of the game.
##
##  Built entirely in code from UITheme tokens rather than hand-placed nodes, so
##  it lays out correctly on every phone aspect ratio from 4:3 tablets to 21:9
##  handsets, and so a change to the design system reaches it automatically.
##
##  The hero is a live, rotating 3D render of the archetype you currently have
##  selected. It is the single most valuable thing this screen can show: it
##  tells you the game is 3D, tells you who you are about to play, and gives the
##  character-select screen a reason to exist.
## ═══════════════════════════════════════════════════════════════════════════════

const UITheme = preload("res://scenes/hud/ui_theme.gd")
const CharacterFactory = preload("res://scenes/player/character_factory.gd")
const CharacterAnimator = preload("res://scenes/player/character_animator.gd")
const RiggedCharacter = preload("res://scenes/player/rigged_character.gd")

const ARCHETYPE_BLURB := {
	"warlord":   "Rally Cry · War Banner",
	"regent":    "Tax Edict · Stockpile",
	"beastlord": "Tame Beasts · Pack Leader",
	"engineer":  "Overclock · Trap Master",
	"witch":     "Hex · Curse Ward",
	"herbalist": "Brew · Mend",
	"guardian":  "Shield Wall · Taunt",
	"berserker": "Frenzy · Bloodlust",
	"sapper":    "Demolish · Trap Disarm",
	"scout":     "Flare · Stealth",
	"archer":    "Volley · Eagle Eye",
	"builder":   "Rapid Build · Blueprint",
}

var _preview_character: Node3D = null
var _preview_spin := 0.0
var _preview_animator = null
var _subviewport: SubViewport = null
var _subtitle: Label = null
var _idle_t := 0.0


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()

	add_child(UITheme.backdrop())
	_add_atmosphere()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UITheme.SPACE_LG)
	margin.add_theme_constant_override("margin_right", UITheme.SPACE_LG)
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_LG)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_LG)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UITheme.SPACE_SM)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	# ── Wordmark ──────────────────────────────────────────────────────────────
	var crest := UITheme.title("FOREST THRONES", UITheme.FONT_TITLE + 8, UITheme.GOLD)
	crest.add_theme_constant_override("shadow_offset_y", 5)
	column.add_child(crest)

	var tag := UITheme.body(
		"Thirty-two players. Eight squads. Six traitors.",
		UITheme.FONT_LABEL, UITheme.TEXT_MUTED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tag)

	# ── Live 3D archetype preview ─────────────────────────────────────────────
	var stage := UITheme.panel(Color(0.055, 0.075, 0.105, 0.85), UITheme.GOLD_DIM)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stage)

	var stage_row := VBoxContainer.new()
	stage_row.add_theme_constant_override("separation", UITheme.SPACE_SM)
	stage.add_child(stage_row)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vpc.custom_minimum_size = Vector2(0, 150)
	stage_row.add_child(vpc)

	_subviewport = SubViewport.new()
	_subviewport.transparent_bg = true
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.msaa_3d = Viewport.MSAA_2X
	vpc.add_child(_subviewport)
	_build_preview_scene()

	_subtitle = UITheme.title(
		GameManager.selected_archetype_id.capitalize(), UITheme.FONT_HEADING, UITheme.TEXT)
	stage_row.add_child(_subtitle)

	var abilities := UITheme.body(
		ARCHETYPE_BLURB.get(GameManager.selected_archetype_id, ""),
		UITheme.FONT_LABEL, UITheme.GOLD)
	abilities.name = "AbilityLine"
	abilities.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_row.add_child(abilities)

	# ── Actions ───────────────────────────────────────────────────────────────
	var play := UITheme.primary_button("ENTER THE FOREST")
	play.pressed.connect(_on_play)
	column.add_child(play)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_SM)
	column.add_child(row)

	var pick := UITheme.secondary_button("Choose Character")
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.pressed.connect(_on_choose)
	row.add_child(pick)

	var practice := UITheme.secondary_button("Practice Island")
	practice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	practice.pressed.connect(_on_practice)
	row.add_child(practice)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", UITheme.SPACE_SM)
	column.add_child(footer)

	var settings := UITheme.ghost_button("Settings")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(settings)

	var quit := UITheme.ghost_button("Quit")
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit.pressed.connect(func(): get_tree().quit())
	footer.add_child(quit)


## Slow drifting embers behind the menu. Cheap, and it stops the background
## reading as a flat colour field while the player decides what to do.
func _add_atmosphere() -> void:
	var particles := CPUParticles2D.new()
	particles.amount = 26
	particles.lifetime = 9.0
	particles.preprocess = 5.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(900, 20)
	particles.position = Vector2(640, 900)
	particles.direction = Vector2(0, -1)
	particles.spread = 22.0
	particles.gravity = Vector2(0, -8)
	particles.initial_velocity_min = 12.0
	particles.initial_velocity_max = 34.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 4.0
	particles.color = Color(0.95, 0.72, 0.30, 0.35)
	add_child(particles)


func _build_preview_scene() -> void:
	for c in _subviewport.get_children():
		c.queue_free()

	var scene := Node3D.new()
	_subviewport.add_child(scene)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.55, 0.72)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	scene.add_child(env)

	# Three-point lighting: key, cool rim, warm fill. This is what makes a
	# character-select model look photographed instead of lit by one lamp.
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-32), deg_to_rad(-38), 0)
	key.light_color = Color(1.0, 0.94, 0.84)
	key.light_energy = 1.45
	scene.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-12), deg_to_rad(150), 0)
	rim.light_color = Color(0.45, 0.62, 0.95)
	rim.light_energy = 1.10
	scene.add_child(rim)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-58), deg_to_rad(70), 0)
	fill.light_color = Color(0.95, 0.65, 0.40)
	fill.light_energy = 0.45
	scene.add_child(fill)

	var pedestal := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.15
	cyl.bottom_radius = 1.30
	cyl.height = 0.22
	cyl.radial_segments = 24
	pedestal.mesh = cyl
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.12, 0.15, 0.20)
	pm.metallic = 0.30
	pm.roughness = 0.55
	pedestal.material_override = pm
	pedestal.position.y = -0.11
	scene.add_child(pedestal)

	if ResourceLoader.exists("res://assets/models/characters/Knight.glb"):
		var rc := RiggedCharacter.new()
		rc.setup(GameManager.selected_archetype_id, Color(0.80, 0.62, 0.30))
		_preview_character = rc
		scene.add_child(rc)
		_preview_animator = rc
	else:
		_preview_character = CharacterFactory.create_character_by_archetype(GameManager.selected_archetype_id)
		if _preview_character:
			scene.add_child(_preview_character)
		_preview_animator = CharacterAnimator.new()

	var cam := Camera3D.new()
	cam.fov = 32.0
	scene.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 2.05, 7.4), Vector3(0.0, 1.25, 0.0), Vector3.UP)
	cam.current = true


func _process(delta: float) -> void:
	if _preview_character and is_instance_valid(_preview_character):
		# A character-select preview must READ. A continuous 360-degree turntable
		# spends most of its cycle showing the character's back, which is the one
		# angle that tells the player nothing — and it makes comparing archetypes
		# harder, because you are never looking at two of them from the same
		# angle. Oscillate gently around front-facing instead: alive, but always
		# legible, and it screenshots the same way every time.
		_preview_spin += delta
		_preview_character.rotation.y = sin(_preview_spin * 0.9) * 0.42
		_idle_t += delta
		if _preview_animator:
			_preview_animator.animate_character(
				_preview_character, GameManager.selected_archetype_id, false, delta)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/loading_screen.tscn")


func _on_choose() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/archetype_select.tscn")


func _on_practice() -> void:
	GameManager.practice_mode = true
	get_tree().change_scene_to_file("res://scenes/menus/loading_screen.tscn")
