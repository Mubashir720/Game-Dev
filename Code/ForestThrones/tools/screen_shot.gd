extends SceneTree
var _f := 0
var _wait := 60
var _out := "user://screen.png"
var _scene := "res://scenes/menus/main_menu.tscn"
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="): _scene = a.substr(6)
		elif a.begins_with("out="): _out = a.substr(4)
		elif a.begins_with("wait="): _wait = int(a.substr(5))
	var p = load(_scene)
	if p == null:
		printerr("cannot load ", _scene); quit(1); return
	var inst = p.instantiate()
	root.add_child(inst)
func _process(_d: float) -> bool:
	_f += 1
	if _f == _wait:
		print("draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		root.get_texture().get_image().save_png(_out)
		print("saved=", ProjectSettings.globalize_path(_out))
		return true
	return false
