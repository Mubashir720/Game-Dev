extends SceneTree
var _f := 0
var _root = null
var _next_report := 30.0
func _initialize() -> void:
	Engine.time_scale = 6.0
	var packed = load("res://scenes/main/main.tscn")
	_root = packed.instantiate()
	root.add_child(_root)

func _process(_d: float) -> bool:
	_f += 1
	var gm = root.get_node_or_null("/root/GameManager")
	if gm == null: return false
	var d = _root.get("director")
	if d == null: return false
	if gm.match_time >= _next_report:
		_next_report += 60.0
		var goals := {}
		for a in d.actors:
			if a.has_method("get") and a.get("goal") != null:
				var g = a.goal
				goals[g] = int(goals.get(g, 0)) + 1
		var s0 = d.squads[0]
		var downed := 0
		for a in d.actors:
			if a.is_downed(): downed += 1
		print("t=%.0fs post=%d downed=%d | coins: " % [gm.match_time, d.squads[0].posture, downed], _coins(d),
			  " | squad1 stock W%d S%d F%d M%d, builds=%d, structs=%d" % [
				s0.stock_of(0), s0.stock_of(1), s0.stock_of(2), s0.stock_of(4),
				s0.build_index, s0.structures.size()],
			  " | goals=", goals)
	if gm.match_time >= 620.0:
		print("--- traitors ---")
		for s in d.squads:
			print("  ", s.squad_id, " traitor=", (s.traitor.name if s.traitor else "NONE"),
				  " active=", s.traitor_active, " alive=", s.alive_count(), " coins=", s.treasury)
		print("static_mem_mb=", String.num(OS.get_static_memory_usage()/1048576.0,1))
		return true
	return false

func _coins(d) -> String:
	var out := ""
	for s in d.squads:
		out += "%d " % s.treasury
	return out
