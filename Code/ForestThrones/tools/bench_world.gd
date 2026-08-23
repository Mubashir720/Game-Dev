extends SceneTree

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var MapGenerator = load("res://scenes/world/map_generator.gd")
	var world := Node3D.new()
	root.add_child(world)
	var mg = MapGenerator.new()
	mg.generate(world)
	var t1 := Time.get_ticks_msec()

	var stats := {"nodes":0, "mesh":0, "mmi":0, "mm_instances":0, "staticbody":0, "collision":0, "lights":0}
	var mats := {}
	var meshes := {}
	_walk(world, stats, mats, meshes)
	print("=== BENCH RESULT (v5) ===")
	print("map_generate_ms=", t1 - t0)
	print("substages=", mg.last_stats)
	print("total_nodes=", stats.nodes)
	print("mesh_instances=", stats.mesh)
	print("multimesh_nodes=", stats.mmi)
	print("multimesh_instances=", stats.mm_instances)
	print("draw_calls_approx=", stats.mesh + stats.mmi)
	print("static_bodies=", stats.staticbody)
	print("collision_shapes=", stats.collision)
	print("unique_material_objects=", mats.size())
	print("unique_mesh_objects=", meshes.size())
	print("static_mem_mb=", String.num(OS.get_static_memory_usage() / 1048576.0, 1))
	var Registry = load("res://scripts/render/visual_registry.gd")
	var Baker = load("res://scripts/render/prop_baker.gd")
	print("registry=", Registry.stats())
	print("baker=", Baker.stats())
	quit()

func _walk(n: Node, stats: Dictionary, mats: Dictionary, meshes: Dictionary) -> void:
	stats.nodes += 1
	if n is MultiMeshInstance3D:
		stats.mmi += 1
		if n.multimesh:
			stats.mm_instances += n.multimesh.instance_count
			if n.multimesh.mesh:
				meshes[n.multimesh.mesh.get_instance_id()] = true
				for i in range(n.multimesh.mesh.get_surface_count()):
					var m = n.multimesh.mesh.surface_get_material(i)
					if m: mats[m.get_instance_id()] = true
		if n.material_override: mats[n.material_override.get_instance_id()] = true
	elif n is MeshInstance3D:
		stats.mesh += 1
		if n.mesh:
			meshes[n.mesh.get_instance_id()] = true
			for i in range(n.mesh.get_surface_count()):
				var m2 = n.mesh.surface_get_material(i)
				if m2: mats[m2.get_instance_id()] = true
		if n.material_override: mats[n.material_override.get_instance_id()] = true
	elif n is StaticBody3D: stats.staticbody += 1
	elif n is CollisionShape3D: stats.collision += 1
	elif n is OmniLight3D or n is SpotLight3D: stats.lights += 1
	for c in n.get_children():
		_walk(c, stats, mats, meshes)
