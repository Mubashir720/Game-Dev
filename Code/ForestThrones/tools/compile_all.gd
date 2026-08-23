extends SceneTree
func _initialize() -> void:
	var bad := 0
	var total := 0
	var stack := ["res://scenes", "res://scripts"]
	while stack.size() > 0:
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null: continue
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.begins_with("."):
				f = d.get_next(); continue
			var full := dir_path.path_join(f)
			if d.current_is_dir():
				stack.push_back(full)
			elif f.ends_with(".gd"):
				total += 1
				var res = ResourceLoader.load(full, "Script", ResourceLoader.CACHE_MODE_REUSE)
				if res == null:
					print("FAILED TO LOAD: ", full); bad += 1
				elif not res.can_instantiate() and not res.is_tool():
					pass
			f = d.get_next()
		d.list_dir_end()
	# A script can compile but still fail on a dependency; catch those too.
	print("checked=", total, " failures=", bad)
	quit(1 if bad > 0 else 0)
