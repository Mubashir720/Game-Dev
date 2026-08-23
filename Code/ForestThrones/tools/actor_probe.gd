extends SceneTree
func _initialize() -> void:
	var CF = load("res://scenes/player/character_factory.gd")
	for id in ["warlord","witch","archer","berserker"]:
		var raw = CF.create_raw(id)
		var raw_n = _count(raw)
		raw.free()
		var baked = CF.create_character_by_archetype(id)
		var baked_n = _count(baked)
		print(id, " raw_meshes=", raw_n.mesh, " raw_nodes=", raw_n.nodes,
			  " | baked_meshes=", baked_n.mesh, " baked_nodes=", baked_n.nodes,
			  " surfaces=", baked_n.surf)
		print("   joints found: Torso=", baked.find_child("Torso", true, false) != null,
			  " Head=", baked.find_child("Head", true, false) != null,
			  " RA=", baked.find_child("LimbPivot_RA", true, false) != null,
			  " LL=", baked.find_child("LimbPivot_LL", true, false) != null)
		baked.free()
	quit()

func _count(n: Node) -> Dictionary:
	var r := {"nodes":0,"mesh":0,"surf":0}
	var st := [n]
	while st.size() > 0:
		var c = st.pop_back()
		r.nodes += 1
		if c is MeshInstance3D:
			r.mesh += 1
			if c.mesh: r.surf += c.mesh.get_surface_count()
		for k in c.get_children(): st.push_back(k)
	return r
