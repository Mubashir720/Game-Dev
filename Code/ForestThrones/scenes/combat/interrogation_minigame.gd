extends CanvasLayer
class_name InterrogationMinigame
## InterrogationMinigame — Resistance-breaking mini-game (GDD §10).
## A stress meter fills while interrogator holds a key.
## Detainee must repeatedly tap SPACE to resist. If stress hits 100 → confess.

signal confession_obtained(revealed_info: String)
signal detainee_held_firm

const STRESS_RATE     := 18.0   # Stress per second applied
const RESIST_POWER    := 22.0   # Stress removed per tap
const MAX_STRESS      := 100.0

var _stress      := 0.0
var _active      := false
var _detainee: Node = null
var _interrogator: Node = null

# Possible info revelations (expands with Traitor data)
const INFO_POOL := [
	"Traitor is among the Soldiers!",
	"Treasury is buried near the Oak.",
	"They have a Cage at the Highlands.",
	"The King plans to defect tonight.",
]

var _draw_node: Node2D

func _ready() -> void:
	layer = 11
	visible = false
	_draw_node = Node2D.new()
	add_child(_draw_node)
	_draw_node.draw.connect(_on_draw)

func begin(interrogator: Node, detainee: Node) -> void:
	_active       = true
	_stress       = 0.0
	_interrogator = interrogator
	_detainee     = detainee
	visible       = true
	_draw_node.queue_redraw()
	set_process(true)

func close() -> void:
	_active = false
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	if not _active:
		return
	# Interrogator holds Q to apply pressure
	if Input.is_action_pressed("interrogate"):
		_stress = min(_stress + STRESS_RATE * delta, MAX_STRESS)
	# Detainee taps Space to resist
	if Input.is_action_just_pressed("ui_accept"):
		_stress = max(_stress - RESIST_POWER, 0.0)
	if _stress >= MAX_STRESS:
		_finish(true)
	_draw_node.queue_redraw()

func _finish(broken: bool) -> void:
	close()
	if broken:
		var info: String = INFO_POOL[randi() % INFO_POOL.size()]
		confession_obtained.emit(info)
	else:
		detainee_held_firm.emit()

func _on_draw() -> void:
	var vp_size := Vector2(get_viewport().size)
	var center  := vp_size * 0.5

	# Dim overlay
	_draw_node.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.0, 0.0, 0.0, 0.65))

	# Stress bar background
	var bar_w := 300.0
	var bar_h := 28.0
	var bar_pos := center + Vector2(-bar_w * 0.5, -20)
	_draw_node.draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.15, 0.05, 0.05))
	# Stress fill (red → white when near 100)
	var t := _stress / MAX_STRESS
	var fill_color := Color(0.8, 0.1, 0.1).lerp(Color(1.0, 0.9, 0.9), t)
	_draw_node.draw_rect(Rect2(bar_pos, Vector2(bar_w * t, bar_h)), fill_color)
	_draw_node.draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.7, 0.1, 0.1), false, 2.5)

	# Title
	_draw_node.draw_string(ThemeDB.fallback_font, center + Vector2(-90, -60),
		"INTERROGATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.9, 0.2, 0.2))

	# Instructions
	_draw_node.draw_string(ThemeDB.fallback_font, center + Vector2(-120, 24),
		"[Interrogator] Hold Q — [Detainee] Mash SPACE to resist",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.75, 0.75))

	# Stress label
	_draw_node.draw_string(ThemeDB.fallback_font, center + Vector2(-30, 8),
		str(int(_stress)) + "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
