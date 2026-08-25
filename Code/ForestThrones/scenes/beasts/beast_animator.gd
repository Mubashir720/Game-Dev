extends Node
class_name BeastAnimator

# ═══════════════════════════════════════════════════════════════════════════════
#  BEAST ANIMATOR  ·  v2
#
#  Drives the beast rigs ActorBaker preserves: Body, Head, Tail, Wing_L/R and four
#  LimbPivot_FL/FR/BL/BR — all direct children of the rig root.
#
#  FIXED: the old version did `body.position.y += …` and `body.position.z += …`
#  every frame without ever restoring a base, so the body slowly drifted up and
#  forward over a match. Base transforms are now cached once and every frame sets
#  position = base + offset, so motion oscillates around home instead of walking
#  away from it.
#
#  NEW: lunge-and-return attacks (bite / gore / tusk / peck), a hit recoil, and a
#  death collapse — so wild beasts and companions read as alive and reactive.
# ═══════════════════════════════════════════════════════════════════════════════

enum St { IDLE, RUN, ATTACK, CHARGE, HIT, DEAD }

var state: St = St.IDLE
var _t_action := 0.0
var _action_dur := 0.5
var _idle_t := 0.0
var _move_t := 0.0
var _base: Dictionary = {}     # instance_id -> {node_name: Transform3D}


func animate_beast(node: Node3D, beast_type: String, is_moving: bool, delta: float) -> void:
	if not is_instance_valid(node):
		return
	var b := _parts(node)
	if b.is_empty():
		return

	_idle_t += delta
	_move_t += delta * (10.0 if is_moving else 0.0)
	if state != St.DEAD:
		if state == St.IDLE or state == St.RUN:
			state = St.RUN if is_moving else St.IDLE

	if state == St.ATTACK or state == St.CHARGE or state == St.HIT:
		_t_action += delta / max(_action_dur, 0.001)
		if _t_action >= 1.0:
			_t_action = 0.0
			state = St.IDLE

	# Reset every driven part to its cached base, then add motion.
	var body: Node3D = b.body
	var head: Node3D = b.head
	var tail: Node3D = b.tail
	var legs := [b.fl, b.fr, b.bl, b.br]
	if body: body.transform = b.base_body
	if head: head.transform = b.base_head
	if tail: tail.transform = b.base_tail
	for i in range(4):
		if legs[i]: (legs[i] as Node3D).transform = (b.base_legs[i] as Transform3D)

	# ── Locomotion / idle base ──
	if state == St.RUN:
		var t := _move_t
		var stride := 0.4
		var bob := 0.05
		match beast_type:
			"boar", "war_boar": stride = 0.3; bob = 0.035
			"stag", "great_stag": stride = 0.48; bob = 0.06
			"raven", "storm_raven": stride = 0.14; bob = 0.07
		if body:
			body.position.y += absf(sin(t)) * bob
			body.rotation.z += sin(t) * 0.03
		if head:
			head.rotation.x += sin(t * 2.0 + PI * 0.5) * 0.06
		# Trot gait: diagonal pairs in phase.
		if b.fl: (b.fl as Node3D).rotation.x += sin(t) * stride
		if b.br: (b.br as Node3D).rotation.x += sin(t) * stride
		if b.fr: (b.fr as Node3D).rotation.x += sin(t + PI) * stride
		if b.bl: (b.bl as Node3D).rotation.x += sin(t + PI) * stride
		if tail: tail.rotation.y += sin(t * 1.5) * 0.18
	else:
		var t := _idle_t
		if body: body.scale = b.base_body.basis.get_scale() * (1.0 + sin(t * 1.6) * 0.012)
		if head:
			head.rotation.y += sin(t * 0.7) * 0.08
			head.rotation.x += sin(t * 1.1) * 0.03
		if tail: tail.rotation.y += sin(t * 1.3) * 0.12

	# ── Action overlays ──
	match state:
		St.ATTACK:
			var lunge := _bell(_t_action, 0.4, 0.26)
			if body: body.position.z += lunge * 0.45
			match beast_type:
				"wolf", "dire_wolf":
					if head: head.rotation.x += -lunge * 0.9        # snap bite down
				"boar", "war_boar":
					if head: head.rotation.x += lunge * 0.9         # tusk gore up
				"stag", "great_stag":
					if head: head.rotation.x += -lunge * 0.8        # antler sweep
				"raven", "storm_raven":
					if head: head.rotation.x += -lunge * 1.0
					if body: body.position.y += -lunge * 0.2        # dive peck
				_:
					if head: head.rotation.x += -lunge * 0.8
			if b.fl: (b.fl as Node3D).rotation.x += -lunge * 0.3
			if b.fr: (b.fr as Node3D).rotation.x += -lunge * 0.3
		St.CHARGE:
			var r := sin(_t_action * PI)
			match beast_type:
				"wolf", "dire_wolf":
					if head: head.rotation.x += deg_to_rad(-50) * r  # howl
				"boar", "war_boar":
					if body: body.rotation.z += sin(_t_action * 18.0) * 0.06
					if head: head.rotation.x += deg_to_rad(-14) * r
				"stag", "great_stag":
					if body: body.rotation.x += -0.14 * r            # rear up
				_:
					if head: head.rotation.x += deg_to_rad(-24) * r
		St.HIT:
			var recoil := (1.0 - _t_action) * (1.0 - _t_action)
			if body:
				body.position.z += -recoil * 0.18
				body.rotation.z += recoil * 0.12
			if head: head.rotation.x += recoil * 0.3
		_:
			pass

	if state == St.DEAD:
		# Collapse onto side and sink.
		if body:
			body.rotation.z += deg_to_rad(85)
			body.position.y += -0.25
		for l in legs:
			if l: (l as Node3D).rotation.x += -0.6

	# Raven wing flap.
	if beast_type in ["raven", "storm_raven"]:
		var wl = b.get("wl")
		var wr = b.get("wr")
		var flap := (sin(_move_t * 6.0) * 0.5) if is_moving else (sin(_idle_t * 1.5) * 0.06)
		if wl: (wl as Node3D).rotation.z = -flap
		if wr: (wr as Node3D).rotation.z = flap


# ── Triggers ─────────────────────────────────────────────────────────────────
func trigger_beast_attack() -> void:
	if state == St.DEAD: return
	state = St.ATTACK; _action_dur = 0.55; _t_action = 0.0

func trigger_howl_charge() -> void:
	if state == St.DEAD: return
	state = St.CHARGE; _action_dur = 0.9; _t_action = 0.0

func trigger_hit() -> void:
	if state == St.DEAD: return
	state = St.HIT; _action_dur = 0.3; _t_action = 0.0

func set_dead(b: bool) -> void:
	state = St.DEAD if b else St.IDLE


# ── Part lookup + base-transform cache ───────────────────────────────────────
func _parts(node: Node3D) -> Dictionary:
	var id := node.get_instance_id()
	var cached: Dictionary = _base.get(id, {})
	if not cached.is_empty() and is_instance_valid(cached.get("body")):
		return cached
	var body := _find(node, "Body")
	var head := _find(node, "Head")
	var tail := _find(node, "Tail")
	var fl := _find(node, "LimbPivot_FL")
	var fr := _find(node, "LimbPivot_FR")
	var bl := _find(node, "LimbPivot_BL")
	var br := _find(node, "LimbPivot_BR")
	if body == null:
		return {}
	var d := {
		"body": body, "head": head, "tail": tail,
		"fl": fl, "fr": fr, "bl": bl, "br": br,
		"wl": _find(node, "Wing_L"), "wr": _find(node, "Wing_R"),
		"base_body": body.transform,
		"base_head": (head.transform if head else Transform3D.IDENTITY),
		"base_tail": (tail.transform if tail else Transform3D.IDENTITY),
		"base_legs": [
			(fl.transform if fl else Transform3D.IDENTITY),
			(fr.transform if fr else Transform3D.IDENTITY),
			(bl.transform if bl else Transform3D.IDENTITY),
			(br.transform if br else Transform3D.IDENTITY),
		],
	}
	_base[id] = d
	return d

func _find(parent: Node3D, name: String) -> Node3D:
	var stack: Array = [parent]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D and n.name == name:
			return n
		for c in n.get_children():
			stack.push_back(c)
	return null

func _bell(x: float, center: float, w: float) -> float:
	var d := (x - center) / w
	return exp(-d * d)
