extends Node2D
class_name PrisonInteractionUI
## PrisonInteractionUI — In-world overlay that shows prison options above a Cage.
## Panels: [Ransom: ___ coins] [Labor] [Execute] [Interrogate]
## Appears when the owning squad's captor stands within range of an occupied cage.

signal ransom_posted(amount: int)
signal execute_pressed
signal interrogate_pressed

var _cage: Node = null
var _visible_tween: Tween = null

# Panel colors
const PANEL_BG      := Color(0.12, 0.08, 0.04, 0.92)
const PANEL_BORDER  := Color(0.65, 0.48, 0.12)
const BTN_COLORS    := {
	"ransom":      Color(0.18, 0.55, 0.22),
	"execute":     Color(0.62, 0.10, 0.10),
	"interrogate": Color(0.15, 0.30, 0.60),
	"labor":       Color(0.45, 0.35, 0.10),
}

func _ready() -> void:
	z_index = 50
	visible = false
	set_process(false)

func show_for_cage(cage: Node) -> void:
	_cage = cage
	visible = true
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.18)
	queue_redraw()

func hide_panel() -> void:
	if not visible:
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(func(): visible = false)

func _draw() -> void:
	if not visible:
		return
	# Background panel
	var w := 180.0
	var h := 100.0
	var rect := Rect2(-w / 2, -h - 60, w, h)
	draw_rect(rect, PANEL_BG)
	draw_rect(rect, PANEL_BORDER, false, 2.0)

	# Title
	draw_string(ThemeDB.fallback_font, Vector2(-w / 2 + 8, -h - 42),
		"PRISONER OPTIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.78, 0.2))

	# Buttons drawn as colored rectangles with labels
	var buttons := [
		{"label": "⚖ Ransom",     "key": "ransom",      "x": -w/2 + 6,  "y": -h - 28},
		{"label": "⚒ Labor",      "key": "labor",       "x": -w/2 + 96, "y": -h - 28},
		{"label": "☠ Execute",    "key": "execute",     "x": -w/2 + 6,  "y": -h - 10},
		{"label": "🔍 Interrogate","key": "interrogate", "x": -w/2 + 96, "y": -h - 10},
	]
	for btn in buttons:
		var btn_rect := Rect2(btn.x, btn.y, 84.0, 18.0)
		draw_rect(btn_rect, BTN_COLORS[btn.key])
		draw_rect(btn_rect, PANEL_BORDER, false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(btn.x + 4, btn.y + 13),
			btn.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
