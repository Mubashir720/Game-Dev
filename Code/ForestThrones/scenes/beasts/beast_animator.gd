extends Node

# ═══════════════════════════════════════════════════════════════════════════════
#  BEAST ANIMATOR — Production-quality animation for detailed multi-part beasts
#  Works with named nodes: Body, Head, Tail, LimbPivot_FL/FR/BL/BR, Wing_L/R
# ═══════════════════════════════════════════════════════════════════════════════

enum BeastAnimState { IDLE, RUN, ATTACK, HOWL_CHARGE, SPECIAL }

var state: BeastAnimState = BeastAnimState.IDLE
var anim_t: float = 0.0
var idle_t: float = 0.0  # Separate timer for idle breathing

func animate_beast(beast_node: Node3D, beast_type: String, is_moving: bool, delta: float) -> void:
	if not is_instance_valid(beast_node):
		return

	# Find named parts (safe lookups)
	var body := _find_child(beast_node, "Body")
	var head := _find_child(beast_node, "Head")
	var tail := _find_child(beast_node, "Tail")
	var fl := _find_child(beast_node, "LimbPivot_FL")
	var fr := _find_child(beast_node, "LimbPivot_FR")
	var bl := _find_child(beast_node, "LimbPivot_BL")
	var br := _find_child(beast_node, "LimbPivot_BR")

	idle_t += delta * 2.0

	if is_moving:
		anim_t += delta * 10.0
		_animate_locomotion(beast_type, body, head, tail, fl, fr, bl, br, anim_t)
	else:
		_animate_idle(beast_type, body, head, tail, fl, fr, bl, br, idle_t, delta)

	# State-based overlays
	match state:
		BeastAnimState.ATTACK:
			anim_t += delta * 12.0
			_play_beast_attack(beast_type, body, head, tail, fl, fr, anim_t)
			if anim_t >= PI:
				state = BeastAnimState.IDLE
				anim_t = 0.0

		BeastAnimState.HOWL_CHARGE:
			anim_t += delta * 6.0
			_play_howl_charge(beast_type, body, head, tail, anim_t)
			if anim_t >= PI:
				state = BeastAnimState.IDLE
				anim_t = 0.0

	# Raven wing flap (always active if moving or special state)
	if beast_type in ["raven", "storm_raven"]:
		var wing_l := _find_child(beast_node, "Wing_L")
		var wing_r := _find_child(beast_node, "Wing_R")
		_animate_wings(wing_l, wing_r, is_moving, idle_t, delta)


func trigger_beast_attack() -> void:
	state = BeastAnimState.ATTACK
	anim_t = 0.0

func trigger_howl_charge() -> void:
	state = BeastAnimState.HOWL_CHARGE
	anim_t = 0.0


# ─── IDLE ANIMATION (Breathing, subtle sway) ─────────────────────────────────
func _animate_idle(beast_type: String, body: Node3D, head: Node3D, tail: Node3D,
		fl: Node3D, fr: Node3D, bl: Node3D, br: Node3D, t: float, delta: float) -> void:
	# Gentle breathing on body
	if body:
		body.scale.y = 1.0 + sin(t) * 0.012
	# Head subtle look-around
	if head:
		head.rotation.y = move_toward(head.rotation.y, sin(t * 0.7) * 0.08, delta * 1.5)
		head.rotation.x = move_toward(head.rotation.x, sin(t * 1.1) * 0.03, delta * 1.5)
	# Tail gentle sway
	if tail:
		match beast_type:
			"wolf", "dire_wolf":
				tail.rotation.y = sin(t * 1.3) * 0.15
			"stag", "great_stag":
				tail.rotation.x = sin(t * 1.5) * 0.05
			"boar", "war_boar":
				tail.rotation.y = sin(t * 2.0) * 0.1
	# Legs return to rest
	for limb in [fl, fr, bl, br]:
		if limb:
			limb.rotation.x = move_toward(limb.rotation.x, 0.0, delta * 3.0)


# ─── LOCOMOTION (Walk/run cycle with leg swing, body bob, head bob) ──────────
func _animate_locomotion(beast_type: String, body: Node3D, head: Node3D, tail: Node3D,
		fl: Node3D, fr: Node3D, bl: Node3D, br: Node3D, t: float) -> void:
	var stride_amplitude := 0.35
	var bob_amplitude := 0.04

	match beast_type:
		"boar", "war_boar":
			stride_amplitude = 0.28  # Shorter legs, faster cadence
			bob_amplitude = 0.03
		"stag", "great_stag":
			stride_amplitude = 0.45  # Longer, more graceful strides
			bob_amplitude = 0.05
		"raven", "storm_raven":
			stride_amplitude = 0.12  # Minimal leg movement (mostly hopping)
			bob_amplitude = 0.06

	# Body vertical bob
	if body:
		body.position.y += sin(t * 2.0) * bob_amplitude

	# Head forward bob (counter to body)
	if head:
		head.rotation.x = sin(t * 2.0 + PI * 0.5) * 0.06

	# Leg swing (diagonal pairs move together — trot gait)
	if fl:
		fl.rotation.x = sin(t) * stride_amplitude
	if br:
		br.rotation.x = sin(t) * stride_amplitude  # Same phase as FL
	if fr:
		fr.rotation.x = sin(t + PI) * stride_amplitude  # Opposite phase
	if bl:
		bl.rotation.x = sin(t + PI) * stride_amplitude  # Opposite phase

	# Tail movement during run
	if tail:
		match beast_type:
			"wolf", "dire_wolf":
				tail.rotation.y = sin(t * 1.5) * 0.2
				tail.rotation.x = sin(t * 0.8) * 0.08
			"stag", "great_stag":
				tail.rotation.x = 0.2 + sin(t) * 0.1  # Tail up when running
			"boar", "war_boar":
				tail.rotation.y = sin(t * 3.0) * 0.15  # Fast wagging


# ─── ATTACK ANIMATION ────────────────────────────────────────────────────────
func _play_beast_attack(beast_type: String, body: Node3D, head: Node3D, tail: Node3D,
		fl: Node3D, fr: Node3D, t: float) -> void:
	var lunge = sin(t) * 0.5

	# Body lunges forward
	if body:
		body.position.z += lunge

	match beast_type:
		"wolf", "dire_wolf":
			# Bite snap — head lunges forward and snaps
			if head:
				head.rotation.x = sin(t * 2.5) * 0.5
				head.position.z += lunge * 0.4
		"boar", "war_boar":
			# Tusk gore — head goes down then thrusts upward
			if head:
				head.rotation.x = -0.4 + sin(t) * 0.6
		"stag", "great_stag":
			# Antler thrust — head sweeps forward and up
			if head:
				head.rotation.x = 0.3 - sin(t) * 0.5
		"raven", "storm_raven":
			# Diving peck — whole body dips
			if head:
				head.rotation.x = sin(t * 3.0) * 0.6

	# Front legs plant during attack
	if fl:
		fl.rotation.x = -sin(t) * 0.2
	if fr:
		fr.rotation.x = -sin(t) * 0.2


# ─── HOWL / CHARGE ANIMATION ─────────────────────────────────────────────────
func _play_howl_charge(beast_type: String, body: Node3D, head: Node3D, tail: Node3D, t: float) -> void:
	match beast_type:
		"wolf", "dire_wolf":
			# Howl — head tilts up, body tenses
			if head:
				head.rotation.x = deg_to_rad(-50.0)
			if body:
				body.scale.y = 1.0 + sin(t * 4.0) * 0.02  # Vibrating tension
			if tail:
				tail.rotation.x = 0.2  # Tail straight out
		"boar", "war_boar":
			# Pawing ground before charge
			if body:
				body.rotation.z = sin(t * 3.0) * 0.08
			if head:
				head.rotation.x = deg_to_rad(-15.0)  # Head lowered
		"stag", "great_stag":
			# Rearing up — majestic pose
			if body:
				body.rotation.x = sin(t * 2.0) * -0.15
			if head:
				head.rotation.x = deg_to_rad(-20.0)
		"raven", "storm_raven":
			# Puffing up — body expands, caw pose
			if body:
				body.scale = Vector3(1.0 + sin(t * 3.0) * 0.05, 1.0 + sin(t * 3.0) * 0.08, 1.0)
			if head:
				head.rotation.x = deg_to_rad(-30.0)


# ─── WING ANIMATION (Raven only) ─────────────────────────────────────────────
func _animate_wings(wing_l: Node3D, wing_r: Node3D, is_moving: bool, t: float, delta: float) -> void:
	var target_angle: float
	if is_moving:
		# Active flapping
		target_angle = sin(t * 6.0) * 0.5
	else:
		# Idle: slight fold breathing
		target_angle = sin(t * 1.5) * 0.05

	if wing_l:
		wing_l.rotation.z = move_toward(wing_l.rotation.z, -target_angle, delta * 8.0)
	if wing_r:
		wing_r.rotation.z = move_toward(wing_r.rotation.z, target_angle, delta * 8.0)


# ─── UTILITY ─────────────────────────────────────────────────────────────────
func _find_child(parent: Node3D, child_name: String) -> Node3D:
	if parent.has_node(child_name):
		var child = parent.get_node(child_name)
		if child is Node3D:
			return child
	# Fallback: search immediate children
	for child in parent.get_children():
		if child is Node3D and child.name == child_name:
			return child
	return null
