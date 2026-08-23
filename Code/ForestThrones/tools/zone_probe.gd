extends SceneTree

## Verifies the closing border (GDD §12): that it actually reaches the Throne by
## match end, and that it damages actors outside it and nobody inside it.
##
## Actors are parked far apart so bot combat cannot contaminate the HP readings —
## an earlier version of this probe stacked 16 hostiles on one tile and measured
## them killing each other.
var _root = null
var _f := 0
var _phase := 0
var _hp := {}
var _outside: Array = []
var _inside: Array = []

func _initialize() -> void:
	_root = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(_root)

func _process(_d: float) -> bool:
	_f += 1
	var gm = root.get_node_or_null("/root/GameManager")
	var d = _root.get("director")
	if gm == null or d == null: return false

	if _phase == 0 and _f > 180:
		_phase = 1
		# Late in the shrink, so the border is small and unambiguous.
		gm.match_time = Constants.MATCH_DURATION - 40.0
		var i := 0
		for a in d.actors:
			if not is_instance_valid(a): continue
			# Spread everyone out so nobody is in anybody's attack range.
			var ang: float = float(i) * 0.42
			if i % 2 == 0:
				a.global_position = Vector3(cos(ang) * 170.0, 2.0, sin(ang) * 170.0)
				_outside.append(a)
			else:
				a.global_position = Vector3(cos(ang) * 6.0, 2.0, sin(ang) * 6.0)
				_inside.append(a)
			a.hunger = 100.0; a.thirst = 100.0
			# Freeze the actors. Otherwise 16 mutually hostile bots parked near
			# the Throne simply converge and fight, and their combat damage is
			# indistinguishable from border damage in the readings.
			a.set_physics_process(false)
			_hp[a] = a.hp
			i += 1
		return false

	if _phase == 1 and _f > 500:
		var zs = _root.find_child("ZoneShrink", true, false)
		print("radius_tiles=%.1f  world_radius=%.1f  (map half-extent = %.0f tiles)"
			% [zs.radius_tiles, zs.world_radius(), float(Constants.GRID_SIZE.x) * 0.5])
		# Assert on the BORDER specifically, not on raw HP. Bots keep using their
		# abilities even while frozen, so raw HP loss includes Archer Volley
		# fire and is not a clean signal for what the zone did.
		var flagged_out := 0
		var flagged_in := 0
		for a in _outside:
			if is_instance_valid(a) and bool(a.get_meta("outside_zone", false)): flagged_out += 1
		for a in _inside:
			if is_instance_valid(a) and bool(a.get_meta("outside_zone", false)): flagged_in += 1
		print("border flagged outside=%d/%d   wrongly flagged inside=%d/%d   total border hits=%d"
			% [flagged_out, _outside.size(), flagged_in, _inside.size(), zs.total_hits])
		var ho := 0; var hi := 0
		for a in _outside:
			if is_instance_valid(a) and _hp[a] - a.hp > 0.5: ho += 1
		print("-- inside actors that lost HP --")
		for a in _inside:
			if not is_instance_valid(a): continue
			var lost: float = _hp[a] - a.hp
			if lost > 0.5:
				hi += 1
				var r: float = sqrt(a.global_position.x * a.global_position.x + a.global_position.z * a.global_position.z)
				print("   %-18s lost=%.1f  radius=%.1f  outside_flag=%s  hunger=%.0f thirst=%.0f  goal=%s"
					% [a.name, lost, r, str(a.get_meta("outside_zone", false)), a.hunger, a.thirst,
					   str(a.get("goal")) if "goal" in a else "-"])
		print("damaged outside=%d/%d   damaged inside=%d/%d" % [ho, _outside.size(), hi, _inside.size()])
		var pass_ok: bool = flagged_out == _outside.size() \
			and flagged_in == 0 \
			and zs.total_hits > 0 \
			and zs.radius_tiles < 20.0
		print("RESULT=", "PASS" if pass_ok else "FAIL")
		return true
	return false
