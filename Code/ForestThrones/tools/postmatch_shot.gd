extends SceneTree
var _f := 0
var _root = null
var _ended := false
func _initialize() -> void:
	var p = load("res://scenes/main/main.tscn")
	_root = p.instantiate()
	root.add_child(_root)
	root.set("current_scene", _root)
func _process(_d: float) -> bool:
	_f += 1
	var d = _root.get("director")
	if d != null and not _ended and _f > 200:
		_ended = true
		# Force the match to resolve so the summary screen can be captured.
		for i in range(1, d.squads.size()):
			for m in d.squads[i].members:
				m.kill(null)
		if d.squads.size() > 2:
			d.squads[2].traitor_active = true
	if _f == 300:
		print("draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		root.get_texture().get_image().save_png("user://postmatch.png")
		print("saved")
		return true
	return false
