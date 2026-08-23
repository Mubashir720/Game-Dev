extends Control
class_name VirtualJoystick

## ═══════════════════════════════════════════════════════════════════════════════
##  VIRTUAL JOYSTICK — the movement control for a touchscreen game.
##
##  It is FLOATING, not fixed: the stick appears wherever the thumb lands inside
##  its zone rather than at a painted position. Fixed sticks force the player to
##  look down to find them, which is exactly what you cannot afford in a game
##  where a Traitor might be walking up behind you.
##
##  Design details that matter on a real phone:
##    • A generous invisible touch zone, much bigger than the drawn stick
##    • Multitouch-safe — tracks its own finger by index, so pressing an action
##      button with the other thumb never steals or cancels movement
##    • Dead zone so a resting thumb does not drift the character
##    • Drawn with _draw(), so it costs no textures and scales to any DPI
## ═══════════════════════════════════════════════════════════════════════════════

const UITheme = preload("res://scenes/hud/ui_theme.gd")

signal moved(direction: Vector2)
signal released()

## Radius the knob can travel from the stick's origin.
@export var travel_radius: float = 96.0
## Inputs shorter than this fraction of travel are ignored.
@export var dead_zone: float = 0.16
## Visual radius of the base ring.
@export var base_radius: float = 104.0
@export var knob_radius: float = 46.0

var value: Vector2 = Vector2.ZERO

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _active: bool = false
var _fade: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and not _active:
			_begin(t.index, t.position)
			accept_event()
		elif not t.pressed and t.index == _touch_index:
			_end()
			accept_event()

	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			_update(d.position)
			accept_event()

	# Mouse path so the game is testable on desktop without a touchscreen.
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not _active:
				_begin(-1, mb.position)
				accept_event()
			elif not mb.pressed and _touch_index == -1:
				_end()
				accept_event()

	elif event is InputEventMouseMotion and _active and _touch_index == -1:
		_update((event as InputEventMouseMotion).position)
		accept_event()


func _begin(index: int, pos: Vector2) -> void:
	_touch_index = index
	_active = true
	_origin = pos
	_knob = pos
	value = Vector2.ZERO
	queue_redraw()


func _update(pos: Vector2) -> void:
	var delta := pos - _origin
	if delta.length() > travel_radius:
		delta = delta.normalized() * travel_radius
	_knob = _origin + delta

	var raw := delta / travel_radius
	if raw.length() < dead_zone:
		value = Vector2.ZERO
	else:
		# Rescale past the dead zone so the very first bit of movement isn't a
		# jump from 0 to 0.16 — it should ramp smoothly from a standstill.
		var mag: float = (raw.length() - dead_zone) / (1.0 - dead_zone)
		value = raw.normalized() * clampf(mag, 0.0, 1.0)
	moved.emit(value)
	queue_redraw()


func _end() -> void:
	_active = false
	_touch_index = -1
	value = Vector2.ZERO
	released.emit()
	queue_redraw()


func _process(delta: float) -> void:
	var target: float = 1.0 if _active else 0.35
	if absf(_fade - target) > 0.01:
		_fade = lerpf(_fade, target, minf(1.0, delta * 10.0))
		queue_redraw()


func _draw() -> void:
	var centre: Vector2 = _origin if _active else Vector2(base_radius + 30.0, size.y - base_radius - 30.0)
	var knob: Vector2 = _knob if _active else centre
	var a: float = clampf(_fade, 0.0, 1.0)

	# Base ring
	draw_circle(centre, base_radius, Color(0, 0, 0, 0.28 * a))
	draw_arc(centre, base_radius, 0.0, TAU, 48, Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.45 * a), 3.0, true)
	draw_arc(centre, base_radius * 0.62, 0.0, TAU, 40, Color(1, 1, 1, 0.10 * a), 2.0, true)

	# Direction wedge — shows which way the character will actually go, which
	# matters because movement is camera-relative on an isometric view.
	if _active and value.length() > 0.05:
		var dir := value.normalized()
		var tip := centre + dir * (base_radius - 8.0)
		var side := Vector2(-dir.y, dir.x) * 16.0
		draw_colored_polygon(
			PackedVector2Array([tip, centre + dir * 40.0 + side, centre + dir * 40.0 - side]),
			Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.55))

	# Knob
	draw_circle(knob, knob_radius, Color(0.10, 0.13, 0.18, 0.85 * a))
	draw_circle(knob, knob_radius - 6.0, Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.75 * a))
	draw_arc(knob, knob_radius, 0.0, TAU, 32, Color(1, 1, 1, 0.55 * a), 2.5, true)
