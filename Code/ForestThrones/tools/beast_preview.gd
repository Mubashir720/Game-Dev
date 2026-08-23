extends SceneTree
var _f := 0
var _out := "user://beasts.png"
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	var BF = load("res://scenes/beasts/beast_factory.gd")
	var SF = load("res://scenes/structures/structure_factory.gd")
	var scene := Node3D.new(); root.add_child(scene)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.13,0.17,0.20)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55,0.65,0.80); e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e; scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-35), 0)
	sun.light_energy = 1.15; sun.shadow_enabled = true; scene.add_child(sun)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60,30)
	ground.mesh = pm; var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.17,0.26,0.16)
	ground.material_override = gm; scene.add_child(ground)

	var only := ""
	for a2 in OS.get_cmdline_user_args():
		if a2.begins_with("only="): only = a2.substr(5)
	var beasts = ["wolf","raven","boar","stag"]
	if only == "none" or only == "ground" or only == "structs": beasts = []
	for i in range(beasts.size()):
		var b = BF.build_beast(beasts[i], false)
		b.position = Vector3((float(i) - 1.5) * 3.4, 0, 1.6)
		b.rotation.y = deg_to_rad(-30)
		scene.add_child(b)
		if only != "nolabel":
			var l := Label3D.new(); l.text = beasts[i]; l.font_size = 110; l.pixel_size = 0.0022
			l.position = b.position + Vector3(0, 2.2, 0); l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			scene.add_child(l)
	var structs = ["hut","cage","workshop","watchtower"]
	if only == "none" or only == "ground" or only == "beasts": structs = []
	for i in range(structs.size()):
		var st = SF.build_structure(structs[i])
		st.position = Vector3((float(i) - 1.5) * 3.4, 0, -3.2)
		scene.add_child(st)
		var l2 := Label3D.new(); l2.text = structs[i]; l2.font_size = 110; l2.pixel_size = 0.0022
		l2.position = st.position + Vector3(0, 3.4, 0); l2.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		scene.add_child(l2)

	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 8.0; cam.current = true; scene.add_child(cam)
	cam.look_at_from_position(Vector3(0, 6.5, 10.0), Vector3(0, 1.0, -0.6), Vector3.UP)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 30:
		print("draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		root.get_texture().get_image().save_png(_out)
		print("saved=", ProjectSettings.globalize_path(_out))
		return true
	return false
