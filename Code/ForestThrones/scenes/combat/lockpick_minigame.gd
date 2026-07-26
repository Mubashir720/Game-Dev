extends CanvasLayer
class_name LockpickMinigame
## LockpickMinigame — Interactive mini-game UI (GDD §10).
## Player rotates a pick icon to match a "sweet spot" zone on a lock cylinder.
## Press SPACE at correct angle to advance a tumbler. 5 tumblers = success.

signal succeeded
signal failed

const TUMBLERS_NEEDED := 5
const SWEET_SPOT_WIDTH := 0.18  # radians (~10 degrees each side)
const PICK_ROTATE_SPEED := 2.0  # radians per second

var _pick_angle    := 0.0
var _sweet_angle   := 0.0
var _tumblers_done := 0
var _active        := false
var _fail_timer    := 0.0   # Time the pick is held in wrong zone before snap-back

# Drawing nodes (Canvas-space)
var _draw_node: Node2D

func _ready() -> void:
	layer = 10
	visible = false
	_draw_node = Node2D.new()
	_draw_node.set_script(null)
	add_child(_draw_node)
	_draw_node.draw.connect(_on_draw)

func open() -> void:
	_active        = true
	_tumblers_done = 0
	_pick_angle    = 0.0
	_new_sweet_spot()
	visible = true
	_draw_node.queue_redraw()
	set_process(true)

func close() -> void:
	_active = false
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	if not _active:
		return

	# Rotate pick with left/right
	var dir := 0.0
	if Input.is_action_pressed("move_right"): dir += 1.0
	if Input.is_action_pressed("move_left"):  dir -= 1.0
	_pick_angle += dir * PICK_ROTATE_SPEED * delta
	_pick_angle  = fmod(_pick_angle, TAU)

	# Attempt tumbler
	if Input.is_action_just_pressed("interact"):
		_try_click_tumbler()

	_draw_node.queue_redraw()

func _try_click_tumbler() -> void:
	var diff: float = abs(angle_difference(_pick_angle, _sweet_angle))
	if diff <= SWEET_SPOT_WIDTH:
		_tumblers_done += 1
		_new_sweet_spot()
		if _tumblers_done >= TUMBLERS_NEEDED:
			_finish(true)
	else:
		# Miss — add camera jiggle feedback
		_pick_angle = 0.0

func _new_sweet_spot() -> void:
	_sweet_angle = randf() * TAU

func _finish(success: bool) -> void:
	close()
	if success:
		succeeded.emit()
	else:
		failed.emit()

func _on_draw() -> void:
	var center := Vector2(get_viewport().size) * 0.5
	# Dim overlay
	_draw_node.draw_rect(Rect2(Vector2.ZERO, get_viewport().size), Color(0, 0, 0, 0.55))

	# Lock cylinder
	var radius := 80.0
	_draw_node.draw_circle(center, radius, Color(0.18, 0.14, 0.08))
	_draw_node.draw_arc(center, radius, 0, TAU, 48, Color(0.55, 0.42, 0.12), 4.0)

	# Sweet spot arc (green)
	_draw_node.draw_arc(center, radius,
		_sweet_angle - SWEET_SPOT_WIDTH,
		_sweet_angle + SWEET_SPOT_WIDTH,
		12, Color(0.2, 0.9, 0.3, 0.9), 8.0)

	# Pick line
	var pick_end := center + Vector2(cos(_pick_angle), sin(_pick_angle)) * (radius + 10.0)
	var pick_start := center + Vector2(cos(_pick_angle), sin(_pick_angle)) * 18.0
	_draw_node.draw_line(pick_start, pick_end, Color(0.8, 0.8, 0.85), 3.0)

	# Tumblers progress dots
	for i in range(TUMBLERS_NEEDED):
		var dot_pos := center + Vector2((-TUMBLERS_NEEDED * 0.5 + i + 0.5) * 22.0, radius + 28.0)
		var col := Color(0.2, 0.9, 0.3) if i < _tumblers_done else Color(0.35, 0.35, 0.35)
		_draw_node.draw_circle(dot_pos, 7.0, col)

	# Title
	_draw_node.draw_string(ThemeDB.fallback_font, center + Vector2(-60, -radius - 24),
		"PICK THE LOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.78, 0.2))
	_draw_node.draw_string(ThemeDB.fallback_font, center + Vector2(-85, -radius - 6),
		"← → Rotate  •  E Click at green zone", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.75, 0.75))
