extends Control

## ═══════════════════════════════════════════════════════════════════════════════
##  LOADING SCREEN — covers world generation with something worth looking at.
##
##  Generating a 200x200 map with instanced scatter, resource placement and 32
##  spawned actors takes a couple of seconds even after the rewrite. Doing that
##  behind a frozen black screen is how a game feels broken; doing it behind a
##  live progress bar and a rotating loading tip is how it feels deliberate.
##
##  It also does real work: it loads the match scene, listens to its
##  loading_progress signal, and only swaps it in once generation reports done.
##  The world is genuinely finished before the player sees a single frame of it.
## ═══════════════════════════════════════════════════════════════════════════════

const UITheme = preload("res://scenes/hud/ui_theme.gd")

## Loading tips double as onboarding for the systems the GDD flags as confusing
## (§20 Risks: "New players confused by many systems").
const TIPS := [
	"Six of the eight squads carry a Traitor. Two are completely clean — but nobody is told which.",
	"The Traitor cannot betray you before minute 8. Use that time to read your squad.",
	"Your Hut is your respawn point. Lose it and every death after is permanent.",
	"The Queen mints a coin every 20 seconds — but only while she is at your base.",
	"Every ransom is broadcast to all 32 players for 90 seconds. Anyone can outbid.",
	"Executing a prisoner marks your whole squad on every minimap. Cruelty is expensive.",
	"A Buddy Link shows a squadmate's exact inventory. A hoarder cannot hide from it.",
	"The centre has no trees and no stone. Holding the Throne means hauling everything in.",
	"Beasts patrol the Cursed Throne for the first ten minutes. Early centre play is punished.",
	"Thirst drains faster than hunger at zero. Build a Well before you need one.",
	"Trust dots go green, yellow, then orange. They never go red — the game never confirms a Traitor.",
	"At minute 17 the border closes one tile every 30 seconds. Pick up your Hut and move.",
]

var _bar: ProgressBar = null
var _stage: Label = null
var _tip: Label = null
var _percent: Label = null
var _match_scene: Node = null
var _tip_timer := 0.0
var _tip_index := 0
var _done := false
var _fraction := 0.0
var _display_fraction := 0.0


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	call_deferred("_begin_load")


func _build() -> void:
	add_child(UITheme.backdrop(Color(0.055, 0.075, 0.105), Color(0.020, 0.035, 0.050)))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UITheme.SPACE_XL)
	margin.add_theme_constant_override("margin_right", UITheme.SPACE_XL)
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_XL)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_XL)
	add_child(margin)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", UITheme.SPACE_MD)
	margin.add_child(col)

	col.add_child(UITheme.title("FOREST THRONES", UITheme.FONT_TITLE, UITheme.GOLD))

	var mode := UITheme.body(
		"Practice Island" if GameManager.practice_mode else "Battle Siege · 32 players · 8 squads",
		UITheme.FONT_LABEL, UITheme.TEXT_MUTED)
	mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(mode)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UITheme.SPACE_XL)
	col.add_child(gap)

	var tip_panel := UITheme.panel(Color(0.075, 0.095, 0.130, 0.92), UITheme.GOLD_DIM)
	col.add_child(tip_panel)

	var tip_col := VBoxContainer.new()
	tip_col.add_theme_constant_override("separation", UITheme.SPACE_SM)
	tip_panel.add_child(tip_col)

	var tip_head := UITheme.body("FIELD NOTE", UITheme.FONT_MICRO, UITheme.GOLD)
	tip_col.add_child(tip_head)

	_tip_index = randi() % TIPS.size()
	_tip = UITheme.body(TIPS[_tip_index], UITheme.FONT_BODY, UITheme.TEXT)
	_tip.custom_minimum_size = Vector2(0, 76)
	tip_col.add_child(_tip)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, UITheme.SPACE_LG)
	col.add_child(gap2)

	var head := HBoxContainer.new()
	col.add_child(head)

	_stage = UITheme.body("Surveying the forest", UITheme.FONT_LABEL, UITheme.TEXT_MUTED)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_stage)

	_percent = UITheme.body("0%", UITheme.FONT_LABEL, UITheme.GOLD)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_percent)

	_bar = UITheme.stat_bar(UITheme.GOLD, 18)
	_bar.value = 0.0
	col.add_child(_bar)


func _begin_load() -> void:
	var packed: PackedScene = load("res://scenes/main/main.tscn")
	if packed == null:
		push_error("LoadingScreen: could not load the match scene.")
		return
	_match_scene = packed.instantiate()
	if _match_scene.has_signal("loading_progress"):
		_match_scene.loading_progress.connect(_on_progress)
	if _match_scene.has_signal("match_started"):
		_match_scene.match_started.connect(_on_match_started)
	if GameManager.practice_mode and "spawn_full_roster" in _match_scene:
		_match_scene.spawn_full_roster = false
	# Parent it OFF-SCREEN of the loading UI so generation runs while this
	# screen keeps drawing; the loading screen is removed once it reports done.
	get_tree().root.add_child(_match_scene)
	move_to_front()


func _on_progress(fraction: float, stage: String) -> void:
	_fraction = clamp(fraction, 0.0, 1.0)
	if _stage:
		_stage.text = stage


func _on_match_started() -> void:
	_done = true


func _process(delta: float) -> void:
	# Ease the bar toward the real value so it never snaps or stalls visibly.
	_display_fraction = lerp(_display_fraction, _fraction, min(1.0, delta * 6.0))
	if _bar:
		_bar.value = _display_fraction * 100.0
	if _percent:
		_percent.text = "%d%%" % int(round(_display_fraction * 100.0))

	_tip_timer += delta
	if _tip_timer >= 4.5:
		_tip_timer = 0.0
		_tip_index = (_tip_index + 1) % TIPS.size()
		if _tip:
			_tip.text = TIPS[_tip_index]

	if _done and _display_fraction > 0.985:
		set_process(false)
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.35)
		tween.tween_callback(queue_free)
