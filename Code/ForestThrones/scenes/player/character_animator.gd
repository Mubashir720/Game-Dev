extends Node
class_name CharacterAnimator

# ═══════════════════════════════════════════════════════════════════════════════
#  CHARACTER ANIMATOR  ·  v2 "skeletal pass"
#
#  Procedural skeletal animation for all 12 archetypes, driving the pivots the
#  ActorBaker preserves:  Root ▸ Torso ▸ (arms, Head) ,  Root ▸ legs.
#
#  WHAT WAS BROKEN (and why combat felt dead):
#    • `_find_child` searched only DIRECT children. The baker nests the arms and
#      head under Torso, so LimbPivot_RA / LimbPivot_LA / Head always returned
#      null — every arm-swing, every attack, every weapon stance silently did
#      nothing. Only the legs (direct children of the root) ever moved. That is
#      the whole reason an attack looked like "walk up and stand there".
#      Fixed: recursive, cached bone lookup.
#
#  WHAT'S NEW:
#    • One smoothed pose system. Every state writes TARGET angles into shared
#      member vectors; the applied pose eases toward them each frame, so states
#      blend instead of snapping — the difference between robotic and natural.
#    • Attacks have real timing: anticipation ▸ strike ▸ follow-through, with a
#      forward step and torso rotation so the whole body commits to the hit.
#    • Hit reactions (flinch), downed crawl, death limpness, and carry poses.
#
#  NOTE on structure: pose builders write to member vectors (_t_*), NOT to
#  parameters — Vector3 is a value type in GDScript, so a mutated parameter would
#  be silently discarded.
# ═══════════════════════════════════════════════════════════════════════════════

enum St { IDLE, WALK, ATTACK, GATHER, BLOCK, ABILITY, HIT, DOWNED, DEAD }

var base_state: St = St.IDLE
var action_state: St = St.IDLE
var vital_state: St = St.IDLE
var carrying: bool = false
var carried: bool = false

var _t_action: float = 0.0
var _action_dur: float = 0.5
var _idle_t: float = 0.0
var _walk_t: float = 0.0
var _rig: Dictionary = {}

# Applied (smoothed) pose.
var _p_ra := Vector3.ZERO
var _p_la := Vector3.ZERO
var _p_rl := Vector3.ZERO
var _p_ll := Vector3.ZERO
var _p_torso := Vector3.ZERO
var _p_head := Vector3.ZERO
var _p_tpos := Vector3.ZERO

# Target pose (rebuilt every frame by the pose builders).
var _t_ra := Vector3.ZERO
var _t_la := Vector3.ZERO
var _t_rl := Vector3.ZERO
var _t_ll := Vector3.ZERO
var _t_torso := Vector3.ZERO
var _t_head := Vector3.ZERO
var _t_tpos := Vector3.ZERO
var _resp := 12.0
var _archetype := "warlord"


func animate_character(node: Node3D, archetype_id: String, is_moving: bool, delta: float) -> void:
	if not is_instance_valid(node):
		return
	_archetype = archetype_id.to_lower()
	var r := _bones(node)
	if r.is_empty():
		return

	_idle_t += delta
	_walk_t += delta * (11.0 if is_moving else 0.0)
	if vital_state != St.DOWNED and vital_state != St.DEAD:
		base_state = St.WALK if is_moving else St.IDLE

	if action_state != St.IDLE and action_state != St.BLOCK:
		_t_action += delta / max(_action_dur, 0.001)
		if _t_action >= 1.0:
			_t_action = 0.0
			action_state = St.IDLE

	# Reset targets, then layer poses lowest → highest priority.
	_t_ra = Vector3.ZERO; _t_la = Vector3.ZERO
	_t_rl = Vector3.ZERO; _t_ll = Vector3.ZERO
	_t_torso = Vector3.ZERO; _t_head = Vector3.ZERO; _t_tpos = Vector3.ZERO
	_resp = 12.0

	# 1 — locomotion / idle base.
	if base_state == St.WALK:
		# A run cycle with weight: legs stride, hips counter-rotate against the
		# shoulders, the torso leans in and bobs, arms swing with a bent elbow feel,
		# and the head counters the twist. The counter-rotation is what stops a walk
		# from looking like a marching toy.
		var s := sin(_walk_t)
		var s2 := sin(_walk_t + PI)
		var bob := absf(sin(_walk_t))
		_t_rl.x = s * 0.72
		_t_ll.x = s2 * 0.72
		_t_ra.x = s2 * 0.52
		_t_la.x = s * 0.52
		_t_ra.z = 0.14          # arms held slightly out from the body
		_t_la.z = -0.14
		_t_torso.x = 0.12                              # lean into the run
		_t_torso.y = s * 0.12                           # shoulders twist…
		_t_torso.z = s * 0.05                           # …and the body rolls with the step
		_t_tpos.y = bob * 0.06                          # vertical foot-fall bob
		_t_head.y = -s * 0.06                           # head counters the shoulder twist
		_t_head.x = -bob * 0.04
	else:
		# Idle with life: slow breathing (chest rise + shoulder lift), a gentle
		# weight shift from foot to foot, and an occasional head glance.
		var breath := sin(_idle_t * 1.5)
		var shift := sin(_idle_t * 0.8)
		_t_torso.x = 0.03 + breath * 0.025
		_t_torso.z = shift * 0.03
		_t_tpos.y = breath * 0.018
		_t_ra.x = breath * 0.03
		_t_la.x = breath * 0.03
		_t_head.y = sin(_idle_t * 0.55) * 0.12
		_t_head.z = shift * 0.03
		_apply_weapon_ready()

	# 2 — action overlays.
	match action_state:
		St.ATTACK:
			_resp = 20.0
			_pose_attack(_t_action)
		St.GATHER:
			_resp = 16.0
			_pose_gather(_t_action)
		St.ABILITY:
			_resp = 12.0
			_pose_ability(_t_action)
		St.HIT:
			_resp = 24.0
			_pose_hit(_t_action)
		St.BLOCK:
			_resp = 16.0
			_pose_block()
		_:
			pass

	# 3 — carry poses.
	if carrying:
		_t_ra = Vector3(deg_to_rad(-95), deg_to_rad(-18), 0)
		_t_la = Vector3(deg_to_rad(-95), deg_to_rad(18), 0)
		_t_torso.x = 0.14
	if carried:
		_resp = 14.0
		_t_torso.x = 1.35
		_t_ra = Vector3(deg_to_rad(70), 0, 0)
		_t_la = Vector3(deg_to_rad(70), 0, 0)
		_t_tpos.y = 0.35

	# 4 — vital overrides.
	if vital_state == St.DOWNED:
		_resp = 10.0
		var crawl := sin(_idle_t * 4.0)
		_t_torso.x = 1.45
		_t_tpos.y = -0.35
		_t_ra = Vector3(deg_to_rad(60) + crawl * 0.5, deg_to_rad(-10), 0)
		_t_la = Vector3(deg_to_rad(60) - crawl * 0.5, deg_to_rad(10), 0)
		_t_rl.x = -0.4 + crawl * 0.15
		_t_ll.x = -0.4 - crawl * 0.15
	elif vital_state == St.DEAD:
		_resp = 8.0
		_t_torso.x = 1.55
		_t_tpos.y = -0.4
		_t_ra = Vector3(deg_to_rad(40), 0, 0)
		_t_la = Vector3(deg_to_rad(40), 0, 0)

	# ── Ease applied pose toward target, then write to bones. ──
	var k: float = clamp(_resp * delta, 0.0, 1.0)
	_p_ra = _p_ra.lerp(_t_ra, k)
	_p_la = _p_la.lerp(_t_la, k)
	_p_rl = _p_rl.lerp(_t_rl, k)
	_p_ll = _p_ll.lerp(_t_ll, k)
	_p_torso = _p_torso.lerp(_t_torso, k)
	_p_head = _p_head.lerp(_t_head, k)
	_p_tpos = _p_tpos.lerp(_t_tpos, k)

	if r.ra: r.ra.rotation = _p_ra
	if r.la: r.la.rotation = _p_la
	if r.rl: r.rl.rotation = _p_rl
	if r.ll: r.ll.rotation = _p_ll
	if r.head: r.head.rotation = _p_head
	if r.torso:
		r.torso.rotation = _p_torso
		r.torso.position = r.torso_base + _p_tpos


# ── Triggers ─────────────────────────────────────────────────────────────────
func trigger_attack() -> void:
	if vital_state != St.IDLE: return
	action_state = St.ATTACK; _action_dur = 0.5; _t_action = 0.0

func trigger_gather() -> void:
	if vital_state != St.IDLE: return
	action_state = St.GATHER; _action_dur = 0.75; _t_action = 0.0

func trigger_harvest() -> void:   # back-compat alias
	trigger_gather()

func trigger_ability() -> void:
	if vital_state != St.IDLE: return
	action_state = St.ABILITY; _action_dur = 0.9; _t_action = 0.0

func trigger_hit() -> void:
	if vital_state == St.DEAD: return
	action_state = St.HIT; _action_dur = 0.28; _t_action = 0.0

func set_blocking(b: bool) -> void:
	if b: action_state = St.BLOCK
	elif action_state == St.BLOCK: action_state = St.IDLE

func set_downed(b: bool) -> void:
	vital_state = St.DOWNED if b else St.IDLE

func set_dead(b: bool) -> void:
	vital_state = St.DEAD if b else St.IDLE

func set_carrying(b: bool) -> void:
	carrying = b

func set_carried(b: bool) -> void:
	carried = b


# ── Pose builders (write to _t_* members) ────────────────────────────────────
func _apply_weapon_ready() -> void:
	match _archetype:
		"warlord", "regent":
			_t_ra += Vector3(deg_to_rad(-28), deg_to_rad(-14), deg_to_rad(6))
			_t_la += Vector3(deg_to_rad(-16), deg_to_rad(14), 0)
		"berserker", "sapper":
			_t_ra += Vector3(deg_to_rad(-34), deg_to_rad(-28), deg_to_rad(14))
			_t_la += Vector3(deg_to_rad(-34), deg_to_rad(28), deg_to_rad(-14))
		"archer", "scout":
			_t_la += Vector3(deg_to_rad(-62), deg_to_rad(20), 0)
			_t_ra += Vector3(deg_to_rad(-42), deg_to_rad(-26), 0)
		"guardian":
			_t_la += Vector3(deg_to_rad(-54), deg_to_rad(24), 0)
			_t_ra += Vector3(deg_to_rad(-26), deg_to_rad(-10), 0)
		"witch", "herbalist", "engineer", "builder", "beastlord":
			_t_ra += Vector3(deg_to_rad(-38), 0, 0)
			_t_la += Vector3(deg_to_rad(-12) + sin(_idle_t * 1.4) * 0.03, 0, 0)
		_:
			_t_ra += Vector3(deg_to_rad(-12), 0, 0)
			_t_la += Vector3(deg_to_rad(-12), 0, 0)

func _pose_attack(p: float) -> void:
	# sw(p): the master swing curve. Negative during anticipation (wind back),
	# snaps past 1.0 (overshoot) on the strike, then settles to 0. This
	# anticipation + overshoot is exactly what "weight" and "impact" are made of.
	var sw := _swing(p)
	var step := _bell(p, 0.40, 0.26)
	_t_tpos.z += clampf(sw, 0.0, 1.2) * 0.22 + step * 0.06   # drive body into the blow
	match _archetype:
		"archer", "scout":
			# Draw string back (deep anticipation), release snap, hold, relax.
			var draw := _ease_out(clamp(p / 0.42, 0.0, 1.0))
			_t_la.x += deg_to_rad(-72)
			_t_la.z += deg_to_rad(6)
			if p < 0.5:
				_t_ra.x += deg_to_rad(-52) - draw * deg_to_rad(34)   # pull back
				_t_torso.y += -0.12 * draw
			else:
				var rel := _ease_out(clamp((p - 0.5) / 0.5, 0.0, 1.0))
				_t_ra.x += deg_to_rad(-52) - deg_to_rad(34) + rel * deg_to_rad(70)
				_t_torso.y += -0.12 + rel * 0.12
			_t_head.x += -0.06
		"guardian":
			# Braced shield, driving spear thrust forward with a hip turn.
			_t_la = Vector3(deg_to_rad(-58), deg_to_rad(28), 0)
			_t_ra.x += deg_to_rad(-82)
			_t_tpos.z += clampf(sw, 0.0, 1.2) * 0.30
			_t_torso.y += clampf(sw, 0.0, 1.2) * 0.22
		"witch", "herbalist", "regent", "engineer":
			# Cast: raise on anticipation, thrust the staff forward with a wrist flick.
			_t_ra.x += -sw * 1.6
			_t_ra.y += clampf(sw, 0.0, 1.2) * deg_to_rad(-10)
			_t_head.x += -0.12
			_t_torso.x += clampf(sw, 0.0, 1.2) * 0.16
		"berserker":
			# Dual cross-chop: both arms wind up and scissor down with overshoot.
			_t_ra += Vector3(-sw * 2.0, deg_to_rad(-30), sw * 0.2)
			_t_la += Vector3(-sw * 2.0, deg_to_rad(30), -sw * 0.2)
			_t_torso.x += clampf(sw, -0.4, 1.2) * 0.30
			_t_torso.y += sin(p * PI) * 0.14
		"builder", "sapper", "beastlord":
			# Heavy overhead: big wind-up over the head, drive down through the body.
			_t_ra.x += -sw * 2.4
			_t_la.x += -sw * 0.5
			_t_torso.x += clampf(sw, -0.5, 1.2) * 0.42
			_t_head.x += clampf(sw, 0.0, 1.2) * 0.15
		_:
			# Warlord / default sword: over-shoulder diagonal cleave with hip rotation.
			_t_ra += Vector3(-sw * 2.2, 0, sw * 0.5)
			_t_la.x += -clampf(sw, 0.0, 1.2) * 0.35
			_t_torso.y += -_anticip(p) * 0.3 + clampf(sw, 0.0, 1.2) * 0.55
			_t_torso.x += clampf(sw, -0.4, 1.2) * 0.24

func _pose_gather(p: float) -> void:
	var chop := absf(sin(p * TAU))
	var raise := 1.0 - chop
	_t_ra.x += raise * 1.5 - chop * 1.1
	_t_la.x += (raise * 1.5 - chop * 1.1) * 0.55
	_t_torso.x += chop * 0.28

func _pose_ability(p: float) -> void:
	var rise := sin(clamp(p, 0.0, 1.0) * PI)
	match _archetype:
		"warlord", "regent", "beastlord":
			_t_ra.x += -rise * 2.6
			_t_head.x += -rise * 0.5
		"witch":
			_t_ra.x += -rise * 2.4; _t_la.x += -rise * 2.4
			_t_ra.y += deg_to_rad(-30); _t_la.y += deg_to_rad(30)
			_t_torso.x += -rise * 0.1
		"herbalist":
			_t_ra.x += -rise * 2.2; _t_head.x += rise * 0.35
		_:
			_t_ra.x += -rise * 2.5; _t_la.x += -rise * 2.5
			_t_head.x += -rise * 0.3

func _pose_hit(p: float) -> void:
	var recoil := (1.0 - p) * (1.0 - p)
	_t_torso.x += -recoil * 0.5
	_t_head.x += -recoil * 0.4
	_t_ra += Vector3(-recoil * 0.3, deg_to_rad(-18) * recoil, 0)
	_t_la += Vector3(-recoil * 0.3, deg_to_rad(18) * recoil, 0)

func _pose_block() -> void:
	match _archetype:
		"guardian":
			_t_la = Vector3(deg_to_rad(-72), deg_to_rad(46), deg_to_rad(-20))
			_t_ra = Vector3(deg_to_rad(-40), deg_to_rad(-20), 0)
			_t_torso.y += deg_to_rad(-14)
		"warlord":
			_t_ra = Vector3(deg_to_rad(-64), deg_to_rad(30), 0)
			_t_la = Vector3(deg_to_rad(-64), deg_to_rad(-20), 0)
		_:
			_t_ra.x += deg_to_rad(-46)
			_t_la.x += deg_to_rad(-60)


# ── Bone lookup (recursive, cached) ──────────────────────────────────────────
func _bones(node: Node3D) -> Dictionary:
	var id := node.get_instance_id()
	var cached: Dictionary = _rig.get(id, {})
	if not cached.is_empty() and is_instance_valid(cached.get("torso")):
		return cached
	var torso := _find(node, "Torso")
	var d := {
		"ra": _find(node, "LimbPivot_RA"),
		"la": _find(node, "LimbPivot_LA"),
		"rl": _find(node, "LimbPivot_RL"),
		"ll": _find(node, "LimbPivot_LL"),
		"torso": torso,
		"head": _find(node, "Head"),
		"torso_base": (torso.position if torso else Vector3.ZERO),
	}
	if torso:
		_rig[id] = d
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

# Master swing curve for melee: anticipation (wind back to negative) → strike
# (snap past 1.0, an overshoot) → settle back to rest. This shape is what gives a
# swing weight and snap instead of a linear slide.
func _swing(p: float) -> float:
	if p < 0.24:
		return -0.4 * _ease_in(p / 0.24)                 # coil back
	elif p < 0.46:
		return lerpf(-0.4, 1.18, _ease_out((p - 0.24) / 0.22))   # explosive strike
	else:
		return lerpf(1.18, 0.0, _ease_in_out((p - 0.46) / 0.54)) # follow through + settle

# How much the body is still coiling (1 at start of anticipation → 0 by strike).
func _anticip(p: float) -> float:
	return clampf((0.24 - p) / 0.24, 0.0, 1.0)

func _ease_out(x: float) -> float:
	var q := clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - q) * (1.0 - q)

func _ease_in(x: float) -> float:
	var q := clampf(x, 0.0, 1.0)
	return q * q

func _ease_in_out(x: float) -> float:
	var q := clampf(x, 0.0, 1.0)
	return (2.0 * q * q) if q < 0.5 else (1.0 - pow(-2.0 * q + 2.0, 2.0) * 0.5)
