extends SceneTree

## ═══════════════════════════════════════════════════════════════════════════════
##  SCREEN PROBE — layout audit for every UI scene in the flow.
##
##  Same job as tools/hud_probe.gd, applied to the menus. It loads each screen,
##  waits for the layout to settle, then measures real on-screen rects and fails
##  on the three defects that actually ship:
##
##    • a control that runs off the edge of the screen
##    • a caption clipped by its own button
##    • a tap target below the 44px minimum, which is unusable on a phone
##
##  Deliberately NOT checked: button-over-panel overlap. Menus legitimately nest
##  buttons inside panels, so that test only makes sense on the HUD, where panels
##  and controls occupy separate regions.
##
##  Run at several aspect ratios — the project stretches `canvas_items` with
##  `aspect=expand`, so the shape of the window moves the layout, not its size:
##
##      xvfb-run -a godot --rendering-driver opengl3 --resolution 960x720 \
##          --script tools/screen_probe.gd
## ═══════════════════════════════════════════════════════════════════════════════

const SCREENS := [
	"res://scenes/menus/main_menu.tscn",
	"res://scenes/menus/archetype_select.tscn",
	"res://scenes/menus/loading_screen.tscn",
	"res://scenes/hud/post_match_summary.tscn",
]

## Apple and Google both put the minimum comfortable touch target near 44pt.
const MIN_TOUCH := 44.0

var _fail := 0


func _initialize() -> void:
	await process_frame
	var vp: Vector2 = root.get_visible_rect().size
	print("viewport=", vp)

	for path in SCREENS:
		await _check(path, vp)

	print("\nRESULT=", "FAIL" if _fail > 0 else "PASS", "  problems=", _fail)
	quit(1 if _fail > 0 else 0)


func _check(path: String, vp: Vector2) -> void:
	var ps: PackedScene = load(path)
	if ps == null:
		print("\n%s  COULD NOT LOAD" % path)
		_fail += 1
		return
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	# Containers settle over a couple of frames; measuring on frame one reports
	# every control at its pre-layout size and finds nothing.
	for i in 8:
		await process_frame

	var name: String = path.get_file().get_basename()
	var problems: Array = []
	var screen := Rect2(Vector2.ZERO, vp)
	_scan(inst, screen, problems)

	if problems.is_empty():
		print("\n%-22s ok" % name)
	else:
		print("\n%-22s %d problem(s)" % [name, problems.size()])
		for p in problems:
			print("    " + String(p))
		_fail += problems.size()
	inst.queue_free()
	await process_frame


func _scan(n: Node, screen: Rect2, problems: Array) -> void:
	for c in n.get_children():
		if c is Control and c.visible:
			var r: Rect2 = (c as Control).get_global_rect()
			if r.size.x > 1.0 and r.size.y > 1.0:
				_check_control(c as Control, r, screen, problems)
		_scan(c, screen, problems)


func _check_control(c: Control, r: Rect2, screen: Rect2, problems: Array) -> void:
	var label: String = _describe(c)

	# Off-screen. A small tolerance: a 1px rounding overhang is not a bug.
	if r.position.x < -1.0 or r.position.y < -1.0 \
			or r.end.x > screen.size.x + 1.0 or r.end.y > screen.size.y + 1.0:
		problems.append("OFFSCREEN      %s  rect=%s" % [label, str(r)])

	if c is Button:
		var b := c as Button
		# Tap target.
		if r.size.x < MIN_TOUCH or r.size.y < MIN_TOUCH:
			problems.append("TAP TOO SMALL  %s  %.0fx%.0f (min %d)" % [
				label, r.size.x, r.size.y, int(MIN_TOUCH)])
		# Clipped caption.
		if b.clip_text and b.text != "":
			var f: Font = b.get_theme_font("font")
			if f != null:
				var fs: int = b.get_theme_font_size("font_size")
				var tw: float = f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var pad := 0.0
				var sb: StyleBox = b.get_theme_stylebox("normal")
				if sb != null:
					pad = sb.content_margin_left + sb.content_margin_right
				if tw > r.size.x - pad + 0.5:
					problems.append("CLIPPED        %s  needs=%.0f has=%.0f" % [
						label, tw, r.size.x - pad])


func _describe(c: Control) -> String:
	if c is Button and (c as Button).text != "":
		return "'%s'" % (c as Button).text
	if c is Label and (c as Label).text != "":
		var t: String = (c as Label).text
		return "'%s'" % (t.substr(0, 24) if t.length() > 24 else t)
	return String(c.name)
