extends SceneTree

## Dumps the real on-screen rect of every significant HUD control, then reports
## any pair that overlaps. Guessing at layout is how the action buttons ended up
## on top of the treasury panel; this measures instead.

func _initialize() -> void:
	await process_frame
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	var root_node: Node = scene.instantiate()
	root.add_child(root_node)
	for i in 240:
		await process_frame

	var hud: Node = root.find_child("GameHUD", true, false)
	if hud == null:
		print("HUD NOT FOUND"); quit(1); return

	print("viewport=", root.get_visible_rect().size)

	var interactive: Array = []
	var panels: Array = []
	_collect(hud, interactive, panels)

	print("\n── interactive controls ──")
	for e in interactive:
		print("  %-22s %s" % [e.name, e.rect])
	print("\n── panels ──")
	for e in panels:
		print("  %-22s %s" % [e.name, e.rect])

	var bad := 0
	print("\n── button vs panel overlaps ──")
	for b in interactive:
		for p in panels:
			if b.rect.intersects(p.rect):
				var o: Rect2 = b.rect.intersection(p.rect)
				print("  OVERLAP  %s  x  %s   area=%d" % [b.name, p.name, int(o.size.x * o.size.y)])
				bad += 1
	# Buttons overflowing their own box (text wider than the circle) or the screen.
	var vp: Rect2 = Rect2(Vector2.ZERO, root.get_visible_rect().size)
	print("\n── off-screen / text overflow ──")
	for b in interactive:
		if not vp.encloses(b.rect):
			print("  OFFSCREEN  %s  %s" % [b.name, b.rect]); bad += 1
		if b.has("text_w") and b.text_w > b.avail_w + 0.5:
			print("  CLIPPED CAPTION  '%s'  needs=%.0f has=%.0f" % [b.name, b.text_w, b.avail_w]); bad += 1

	# The pill only ever shows the ability of whichever archetype spawned. Check
	# it against ALL TWELVE names, or the bug ships for eleven of them.
	print("\n── ability pill vs every archetype name ──")
	var pill: Dictionary = {}
	for b in interactive:
		if b.has("avail_w") and b.rect.size.x > b.rect.size.y:
			pill = b
	if pill.is_empty():
		print("  ability pill not found"); bad += 1
	else:
		var f: Font = null
		var fs: int = 14
		var probe_btn: Button = _find_pill(hud, pill.rect)
		if probe_btn != null:
			f = probe_btn.get_theme_font("font")
			fs = probe_btn.get_theme_font_size("font_size")
		for id in AbilityController.ABILITY_SCRIPTS:
			var scr: GDScript = load(AbilityController.ABILITY_SCRIPTS[id])
			var inst = scr.new()
			var nm: String = String(inst.ability_name).to_upper()
			var w: float = f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if f != null else 0.0
			var fits: bool = w <= pill.avail_w + 0.5
			print("  %-11s %-14s w=%.0f / %.0f  %s" % [id, nm, w, pill.avail_w, "ok" if fits else "OVERFLOW"])
			if not fits:
				bad += 1
			inst.free()

	print("\nRESULT=", "FAIL" if bad > 0 else "PASS", "  problems=", bad)
	quit(1 if bad > 0 else 0)


func _find_pill(n: Node, rect: Rect2) -> Button:
	for c in n.get_children():
		if c is Button and c.get_global_rect().is_equal_approx(rect):
			return c
		var r: Button = _find_pill(c, rect)
		if r != null:
			return r
	return null


func _collect(n: Node, interactive: Array, panels: Array) -> void:
	for c in n.get_children():
		if c is Button:
			var e := {"name": String(c.text), "rect": c.get_global_rect()}
			# What the caption actually needs vs the room the stylebox leaves it.
			# clip_text stops a long label from inflating the button, but it will
			# happily render "ATTAC" instead — so measure, don't trust.
			var f: Font = c.get_theme_font("font")
			var fs: int = c.get_theme_font_size("font_size")
			if f != null:
				e["text_w"] = f.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var pad: float = 0.0
				var sb: StyleBox = c.get_theme_stylebox("normal")
				if sb != null:
					pad = sb.content_margin_left + sb.content_margin_right
				e["avail_w"] = c.get_global_rect().size.x - pad
			interactive.append(e)
		elif (c is PanelContainer or c is Panel) and c.get_global_rect().size.x > 60:
			panels.append({"name": String(c.name), "rect": c.get_global_rect()})
		_collect(c, interactive, panels)
