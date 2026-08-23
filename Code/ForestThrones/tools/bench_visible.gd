extends SceneTree

var _tri_cache := {}

func _initialize() -> void:
	var MapGenerator = load("res://scenes/world/map_generator.gd")
	var world := Node3D.new()
	root.add_child(world)
	var mg = MapGenerator.new()
	mg.generate(world)

	var samples := [Vector3(0,0,0), Vector3(-120,0,-120), Vector3(60,0,-40),
					Vector3(-160,0,0), Vector3(100,0,120), Vector3(-40,0,80)]
	var worst := {}
	var results := []
	for cam in samples:
		var res := {"mmi":0, "mesh":0, "draws":0, "instances":0, "tris":0}
		_walk(world, Vector3.ZERO, cam, res)
		res["cam"] = cam
		results.append(res)
		if worst.is_empty() or res.draws > worst.draws:
			worst = res
	print("=== VISIBLE DRAW CALL ESTIMATE (distance culling only, no frustum) ===")
	for r in results:
		print("  cam=", r.cam, " draws=", r.draws, " mm_nodes=", r.mmi, " instances=", r.instances, " tris=", r.tris)
	print("WORST: cam=", worst.cam, " draw_calls=", worst.draws, " instances=", worst.instances, " triangles=", worst.tris)
	quit()

func _walk(n: Node, parent_pos: Vector3, cam: Vector3, res: Dictionary) -> void:
	var pos := parent_pos
	if n is Node3D:
		pos = parent_pos + n.position
	if n is GeometryInstance3D:
		var d := pos.distance_to(cam)
		var limit: float = n.visibility_range_end if n.visibility_range_end > 0.0 else 400.0
		if d <= limit:
			if n is MultiMeshInstance3D and n.multimesh:
				res.mmi += 1
				var mesh: Mesh = n.multimesh.mesh
				var surf: int = mesh.get_surface_count() if mesh else 1
				res.draws += surf
				res.instances += n.multimesh.instance_count
				res.tris += _tris(mesh) * n.multimesh.instance_count
			elif n is MeshInstance3D:
				res.mesh += 1
				res.draws += (n.mesh.get_surface_count() if n.mesh else 1)
				res.tris += _tris(n.mesh)
	for c in n.get_children():
		_walk(c, pos, cam, res)

func _tris(m: Mesh) -> int:
	if m == null: return 0
	var id := m.get_instance_id()
	if _tri_cache.has(id): return _tri_cache[id]
	var t := 0
	for i in range(m.get_surface_count()):
		var a = m.surface_get_arrays(i)
		if a.size() > Mesh.ARRAY_INDEX and a[Mesh.ARRAY_INDEX] != null and a[Mesh.ARRAY_INDEX].size() > 0:
			t += a[Mesh.ARRAY_INDEX].size() / 3
		elif a.size() > Mesh.ARRAY_VERTEX and a[Mesh.ARRAY_VERTEX] != null:
			t += a[Mesh.ARRAY_VERTEX].size() / 3
	_tri_cache[id] = t
	return t
