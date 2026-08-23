extends SceneTree
func _initialize() -> void:
	var MG = load("res://scenes/world/map_generator.gd")
	var mg = MG.new()
	var gs = Constants.GRID_SIZE
	var t0 := Time.get_ticks_msec()
	var zone_grid := {}
	for y in range(gs.y):
		for x in range(gs.x):
			zone_grid[Vector2i(x,y)] = mg.determine_zone(Vector2i(x,y), gs)
	var t1 := Time.get_ticks_msec()
	print("zone_pass_ms=", t1-t0)

	# terrain surfacetool cost
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(gs.y-1):
		for x in range(gs.x-1):
			for k in range(6):
				st.set_color(Color.WHITE); st.set_uv(Vector2(x,y)); st.add_vertex(Vector3(x,0,y))
	st.generate_normals(); st.generate_tangents()
	var m = st.commit()
	var t2 := Time.get_ticks_msec()
	print("surfacetool_terrain_ms=", t2-t1)
	var t3 := Time.get_ticks_msec()
	var shape = m.create_trimesh_shape()
	print("trimesh_collision_ms=", Time.get_ticks_msec()-t3)

	# prop build cost
	var PF = load("res://scenes/world/prop_factory.gd")
	var t4 := Time.get_ticks_msec()
	var nodes := []
	for i in range(500):
		nodes.append(PF.build_tree("pine"))
	print("500_pine_build_ms=", Time.get_ticks_msec()-t4)
	for n in nodes: n.free()
	quit()
