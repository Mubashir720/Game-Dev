extends SceneTree
var _f := 0
var _root = null
var _t0 := 0
func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	var packed = load("res://scenes/main/main.tscn")
	_root = packed.instantiate()
	root.add_child(_root)

func _process(_d: float) -> bool:
	_f += 1
	if _f % 60 == 0:
		var gm = root.get_node_or_null("/root/GameManager")
		if gm == null: return false
		var d = _root.get("director")
		if d:
			print("[t=%ds] actors=%d squads=%d alive_squads=%d lod(full=%d red=%d min=%d) match_time=%.1f" % [
				(Time.get_ticks_msec()-_t0)/1000, d.actors.size(), d.squads.size(),
				d.alive_squad_count(), d.stats.lod_full, d.stats.lod_reduced, d.stats.lod_minimal,
				gm.match_time])
			var lb = d.leaderboard()
			var line := ""
			for r in lb:
				line += "%s:%dc/%da  " % [r.name, r.treasury, r.alive]
			print("    ", line)
	if _f >= 60 * 12:
		print("report=", _root.get("report"))
		print("static_mem_mb=", String.num(OS.get_static_memory_usage()/1048576.0,1))
		return true
	return false
