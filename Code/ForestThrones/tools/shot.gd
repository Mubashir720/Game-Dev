extends SceneTree

var _frames := 0
var _scene_path := "res://scenes/main/main.tscn"
var _out := "user://shot.png"
var _wait := 90
var _cam_pos := Vector3.ZERO
var _use_cam_pos := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="): _scene_path = a.substr(6)
		elif a.begins_with("out="): _out = a.substr(4)
		elif a.begins_with("wait="): _wait = int(a.substr(5))
		elif a.begins_with("cam="):
			var p = a.substr(4).split(",")
			if p.size() == 3:
				_cam_pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
				_use_cam_pos = true
	var packed = load(_scene_path)
	if packed == null:
		printerr("cannot load ", _scene_path); quit(1); return
	var inst = packed.instantiate()
	root.add_child(inst)
	root.set("current_scene", inst)

func _process(_d: float) -> bool:
	_frames += 1
	if _use_cam_pos and _frames == 20:
		var cam := _find_cam(root)
		if cam:
			cam.set("target_node", null)
			cam.global_position = _cam_pos + Vector3(12, 13, 12)
			cam.look_at(_cam_pos, Vector3.UP)
	if _frames == _wait:
		print("draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		print("primitives=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		print("objects=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		print("video_mem_mb=", String.num(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 1))
		print("static_mem_mb=", String.num(OS.get_static_memory_usage() / 1048576.0, 1))
		var img := root.get_texture().get_image()
		img.save_png(_out)
		print("saved=", ProjectSettings.globalize_path(_out))
		return true
	return false

func _find_cam(n: Node) -> Camera3D:
	if n is Camera3D and n.current: return n
	for c in n.get_children():
		var r := _find_cam(c)
		if r: return r
	return null
