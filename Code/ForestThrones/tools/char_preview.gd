extends SceneTree
var _f := 0
var _out := "user://chars.png"
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	var CF = load("res://scenes/player/character_factory.gd")
	var scene := Node3D.new()
	root.add_child(scene)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.17, 0.20)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.65, 0.80)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	scene.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-35), 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	scene.add_child(sun)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(60, 20)
	ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.17, 0.26, 0.16)
	ground.material_override = gm
	scene.add_child(ground)

	var ids = CF.ARCHETYPE_IDS
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ids="): only = a.substr(4)
	if only != "":
		ids = only.split(",")
	for i in range(ids.size()):
		var c = CF.create_character_by_archetype(ids[i])
		c.position = Vector3((float(i) - (ids.size() - 1) * 0.5) * 3.0, 0, 0)
		c.rotation.y = 0.0
		scene.add_child(c)
		var lbl := Label3D.new()
		lbl.text = ids[i]
		lbl.font_size = 128
		lbl.pixel_size = 0.0022
		lbl.position = c.position + Vector3(0, 3.05, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		scene.add_child(lbl)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.6
	cam.position = Vector3(0, 2.6, 9.0)
	cam.current = true
	scene.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.0, 9.0), Vector3(0, 1.35, 0), Vector3.UP)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 30:
		print("draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		root.get_texture().get_image().save_png(_out)
		print("saved=", ProjectSettings.globalize_path(_out))
		return true
	return false
