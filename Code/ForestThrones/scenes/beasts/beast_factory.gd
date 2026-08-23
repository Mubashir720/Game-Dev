extends RefCounted

## ═══════════════════════════════════════════════════════════════════════════════
##  BEAST FACTORY — the four GDD companion species, built entirely from code.
##
##  As with characters, the _build_* functions are the DESIGN and stay readable.
##  What ships goes through ActorBaker.get_rig(), which welds each animated joint
##  into a single mesh and applies the shared stylised material. A wolf drops
##  from ~70 MeshInstance3D to 8, which is what makes wild packs plus eight
##  squads' companions affordable in one match.
## ═══════════════════════════════════════════════════════════════════════════════

const ActorBaker = preload("res://scripts/render/actor_baker.gd")

## The joints beast_animator.gd drives. These must survive baking.
const BEAST_JOINTS := [
	"Body", "Head", "Tail", "Wing_L", "Wing_R",
	"LimbPivot_FL", "LimbPivot_FR", "LimbPivot_BL", "LimbPivot_BR",
]

const SHADOW_SIZE := {
	"wolf": 1.45, "dire_wolf": 1.70,
	"raven": 0.75, "storm_raven": 0.95,
	"boar": 1.55, "war_boar": 1.80,
	"stag": 1.65, "great_stag": 1.95,
}


## Ship-ready beast: welded joints, stylised material, soft ground shadow.
static func build_beast(beast_type: String = "wolf", is_evolved: bool = false) -> Node3D:
	var key := beast_type.to_lower()
	if is_evolved:
		key += "_evolved"
	return ActorBaker.get_rig(
		key,
		func(): return build_raw(beast_type, is_evolved),
		BEAST_JOINTS,
		"actor",
		SHADOW_SIZE.get(beast_type.to_lower(), 1.4))


## Un-baked design output — for editing and preview only.
static func build_raw(beast_type: String = "wolf", is_evolved: bool = false) -> Node3D:
	match beast_type.to_lower():
		"wolf", "dire_wolf":
			return _build_wolf(is_evolved)
		"raven", "storm_raven":
			return _build_raven(is_evolved)
		"boar", "war_boar":
			return _build_boar(is_evolved)
		"stag", "great_stag":
			return _build_stag(is_evolved)
		_:
			return _build_wolf(false)


# ═══════════════════════════════════════════════════════════════════════════════
#  WOLF / DIRE WOLF
#  Normal: Forest grey-brown, amber eyes, lean muscular build
#  Evolved: Darker fur, glowing red eyes, scars, larger, faint ember emission
# ═══════════════════════════════════════════════════════════════════════════════
static func _build_wolf(is_evolved: bool) -> Node3D:
	var group := Node3D.new()
	group.name = "Dire_Wolf" if is_evolved else "Wolf"
	var sf = 1.35 if is_evolved else 1.0  # Scale factor for evolved

	# ─── PBR Materials ─────────────────────────────────────────────────────
	var fur_mat := StandardMaterial3D.new()
	fur_mat.albedo_color = Color(0.22, 0.20, 0.22) if is_evolved else Color(0.42, 0.36, 0.29)
	fur_mat.roughness = 0.92
	if is_evolved:
		fur_mat.emission_enabled = true
		fur_mat.emission = Color(0.5, 0.08, 0.05)
		fur_mat.emission_energy_multiplier = 0.25

	var belly_mat := StandardMaterial3D.new()
	belly_mat.albedo_color = Color(0.34, 0.30, 0.30) if is_evolved else Color(0.55, 0.48, 0.40)
	belly_mat.roughness = 0.88

	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.06, 0.06, 0.06)
	nose_mat.roughness = 0.3

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.15, 0.08) if is_evolved else Color(1.0, 0.72, 0.18)
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_mat.albedo_color
	eye_mat.emission_energy_multiplier = 1.2 if is_evolved else 0.8

	var claw_mat := StandardMaterial3D.new()
	claw_mat.albedo_color = Color(0.15, 0.12, 0.10)
	claw_mat.roughness = 0.6

	var teeth_mat := StandardMaterial3D.new()
	teeth_mat.albedo_color = Color(0.92, 0.90, 0.82)
	teeth_mat.roughness = 0.4

	# ─── BODY (Main torso — elongated barrel shape) ────────────────────────
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.48 * sf, 0.42 * sf, 1.05 * sf)
	body.mesh = body_mesh
	body.material_override = fur_mat
	body.position = Vector3(0, 0.52 * sf, 0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(body)

	# Ribcage detail (wider chest section)
	var chest := MeshInstance3D.new()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(0.52 * sf, 0.46 * sf, 0.45 * sf)
	chest.mesh = chest_mesh
	chest.material_override = fur_mat
	chest.position = Vector3(0, 0.54 * sf, 0.25 * sf)
	chest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(chest)

	# Belly (lighter underside)
	var belly := MeshInstance3D.new()
	var belly_mesh := BoxMesh.new()
	belly_mesh.size = Vector3(0.36 * sf, 0.12 * sf, 0.80 * sf)
	belly.mesh = belly_mesh
	belly.material_override = belly_mat
	belly.position = Vector3(0, 0.30 * sf, 0)
	group.add_child(belly)

	# ─── NECK (Thick muscular connection) ──────────────────────────────────
	var neck := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.16 * sf; neck_mesh.bottom_radius = 0.22 * sf
	neck_mesh.height = 0.28 * sf
	neck.mesh = neck_mesh
	neck.material_override = fur_mat
	neck.position = Vector3(0, 0.62 * sf, 0.52 * sf)
	neck.rotation.x = deg_to_rad(35.0)
	neck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(neck)

	# Neck mane / ruff (thicker fur around neck)
	var ruff := MeshInstance3D.new()
	var ruff_mesh := CylinderMesh.new()
	ruff_mesh.top_radius = 0.22 * sf; ruff_mesh.bottom_radius = 0.28 * sf
	ruff_mesh.height = 0.12 * sf
	ruff.mesh = ruff_mesh
	var ruff_mat := StandardMaterial3D.new()
	ruff_mat.albedo_color = fur_mat.albedo_color.lightened(0.08)
	ruff_mat.roughness = 1.0
	ruff.material_override = ruff_mat
	ruff.position = Vector3(0, 0.58 * sf, 0.48 * sf)
	ruff.rotation.x = deg_to_rad(35.0)
	group.add_child(ruff)

	# ─── HEAD (Wedge-shaped snout with jaw) ────────────────────────────────
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.32 * sf, 0.26 * sf, 0.36 * sf)
	head.mesh = head_mesh
	head.material_override = fur_mat
	head.position = Vector3(0, 0.72 * sf, 0.70 * sf)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(head)

	# Snout (tapered muzzle)
	var snout := MeshInstance3D.new()
	var snout_mesh := BoxMesh.new()
	snout_mesh.size = Vector3(0.20 * sf, 0.16 * sf, 0.24 * sf)
	snout.mesh = snout_mesh
	snout.material_override = fur_mat
	snout.position = Vector3(0, 0.66 * sf, 0.92 * sf)
	group.add_child(snout)

	# Nose tip (shiny black)
	var nose := MeshInstance3D.new()
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.045 * sf; nose_mesh.height = 0.05 * sf
	nose.mesh = nose_mesh
	nose.material_override = nose_mat
	nose.position = Vector3(0, 0.68 * sf, 1.05 * sf)
	group.add_child(nose)

	# Lower jaw
	var jaw := MeshInstance3D.new()
	var jaw_mesh := BoxMesh.new()
	jaw_mesh.size = Vector3(0.18 * sf, 0.08 * sf, 0.22 * sf)
	jaw.mesh = jaw_mesh
	jaw.material_override = fur_mat
	jaw.position = Vector3(0, 0.58 * sf, 0.90 * sf)
	group.add_child(jaw)

	# Teeth (upper fangs — visible canines)
	for side in [-1, 1]:
		var fang := MeshInstance3D.new()
		var fang_mesh := CylinderMesh.new()
		fang_mesh.top_radius = 0.0; fang_mesh.bottom_radius = 0.015 * sf
		fang_mesh.height = 0.06 * sf
		fang.mesh = fang_mesh
		fang.material_override = teeth_mat
		fang.position = Vector3(side * 0.07 * sf, 0.58 * sf, 0.98 * sf)
		group.add_child(fang)

	# ─── EYES (Glowing with pupil detail) ──────────────────────────────────
	var pupil_mat := StandardMaterial3D.new()
	pupil_mat.albedo_color = Color(0.02, 0.02, 0.02)
	for side in [-1, 1]:
		# Eye socket (slight indent)
		var socket := MeshInstance3D.new()
		var socket_mesh := SphereMesh.new()
		socket_mesh.radius = 0.05 * sf; socket_mesh.height = 0.04 * sf
		socket.mesh = socket_mesh
		var socket_mat := StandardMaterial3D.new()
		socket_mat.albedo_color = fur_mat.albedo_color.darkened(0.25)
		socket.material_override = socket_mat
		socket.position = Vector3(side * 0.12 * sf, 0.76 * sf, 0.82 * sf)
		group.add_child(socket)
		# Eye globe
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.038 * sf; eye_mesh.height = 0.045 * sf
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.12 * sf, 0.76 * sf, 0.84 * sf)
		group.add_child(eye)
		# Pupil
		var pupil := MeshInstance3D.new()
		var pupil_mesh := SphereMesh.new()
		pupil_mesh.radius = 0.018 * sf; pupil_mesh.height = 0.02 * sf
		pupil.mesh = pupil_mesh
		pupil.material_override = pupil_mat
		pupil.position = Vector3(side * 0.12 * sf, 0.76 * sf, 0.87 * sf)
		group.add_child(pupil)

	# ─── EARS (Pointed triangular wolf ears) ───────────────────────────────
	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var ear_mesh := CylinderMesh.new()
		ear_mesh.top_radius = 0.0; ear_mesh.bottom_radius = 0.06 * sf
		ear_mesh.height = 0.14 * sf
		ear.mesh = ear_mesh
		ear.material_override = fur_mat
		ear.position = Vector3(side * 0.11 * sf, 0.88 * sf, 0.68 * sf)
		ear.rotation.z = side * deg_to_rad(-15.0)
		ear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(ear)
		# Inner ear (pinkish)
		var inner := MeshInstance3D.new()
		var inner_mesh := CylinderMesh.new()
		inner_mesh.top_radius = 0.0; inner_mesh.bottom_radius = 0.03 * sf
		inner_mesh.height = 0.10 * sf
		inner.mesh = inner_mesh
		var inner_mat := StandardMaterial3D.new()
		inner_mat.albedo_color = Color(0.65, 0.45, 0.42)
		inner.material_override = inner_mat
		inner.position = Vector3(side * 0.11 * sf, 0.88 * sf, 0.70 * sf)
		inner.rotation.z = side * deg_to_rad(-15.0)
		group.add_child(inner)

	# ─── LEGS (4 legs — shoulder/hip + upper + lower + paw) ────────────────
	var leg_positions = [
		Vector3(-0.18 * sf, 0, 0.30 * sf),   # Front left
		Vector3(0.18 * sf, 0, 0.30 * sf),    # Front right
		Vector3(-0.18 * sf, 0, -0.30 * sf),  # Back left
		Vector3(0.18 * sf, 0, -0.30 * sf),   # Back right
	]
	var leg_names = ["LimbPivot_FL", "LimbPivot_FR", "LimbPivot_BL", "LimbPivot_BR"]
	for i in range(4):
		var leg := _make_wolf_leg(sf, fur_mat, claw_mat, leg_positions[i], i < 2)
		leg.name = leg_names[i]
		group.add_child(leg)

	# ─── TAIL (Bushy multi-segment) ───────────────────────────────────────
	var tail := _make_wolf_tail(sf, fur_mat)
	tail.name = "Tail"
	group.add_child(tail)

	# ─── EVOLVED: Battle scars + bone spikes ──────────────────────────────
	if is_evolved:
		# Scar across face
		var scar := MeshInstance3D.new()
		var scar_mesh := BoxMesh.new()
		scar_mesh.size = Vector3(0.24 * sf, 0.015 * sf, 0.015 * sf)
		scar.mesh = scar_mesh
		var scar_mat := StandardMaterial3D.new()
		scar_mat.albedo_color = Color(0.55, 0.20, 0.18)
		scar.material_override = scar_mat
		scar.position = Vector3(0, 0.76 * sf, 0.86 * sf)
		scar.rotation.z = deg_to_rad(18.0)
		group.add_child(scar)

		# Bone spike ridge along spine
		var bone_mat := StandardMaterial3D.new()
		bone_mat.albedo_color = Color(0.85, 0.80, 0.70)
		bone_mat.roughness = 0.5
		for j in range(5):
			var spike := MeshInstance3D.new()
			var spike_mesh := CylinderMesh.new()
			spike_mesh.top_radius = 0.0; spike_mesh.bottom_radius = 0.02 * sf
			spike_mesh.height = 0.10 * sf
			spike.mesh = spike_mesh
			spike.material_override = bone_mat
			spike.position = Vector3(0, 0.76 * sf, 0.35 * sf - j * 0.16 * sf)
			group.add_child(spike)

		# Glowing ember particles on paws (emission spheres)
		var ember_mat := StandardMaterial3D.new()
		ember_mat.albedo_color = Color(1.0, 0.3, 0.05, 0.6)
		ember_mat.emission_enabled = true
		ember_mat.emission = Color(1.0, 0.3, 0.05)
		ember_mat.emission_energy_multiplier = 1.5
		ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for pos in leg_positions:
			var ember := MeshInstance3D.new()
			var em_mesh := SphereMesh.new()
			em_mesh.radius = 0.04 * sf; em_mesh.height = 0.03 * sf
			ember.mesh = em_mesh
			ember.material_override = ember_mat
			ember.position = Vector3(pos.x, 0.02, pos.z)
			group.add_child(ember)

	return group


static func _make_wolf_leg(sf: float, fur_mat: Material, claw_mat: Material, pos: Vector3, is_front: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos

	var upper_h = 0.28 * sf if is_front else 0.26 * sf
	var lower_h = 0.22 * sf

	# Upper leg (thigh/shoulder)
	var upper := MeshInstance3D.new()
	var upper_mesh := CylinderMesh.new()
	upper_mesh.top_radius = 0.08 * sf; upper_mesh.bottom_radius = 0.065 * sf
	upper_mesh.height = upper_h
	upper.mesh = upper_mesh
	upper.material_override = fur_mat
	upper.position.y = 0.36 * sf
	upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(upper)

	# Lower leg (shin)
	var lower := MeshInstance3D.new()
	var lower_mesh := CylinderMesh.new()
	lower_mesh.top_radius = 0.06 * sf; lower_mesh.bottom_radius = 0.05 * sf
	lower_mesh.height = lower_h
	lower.mesh = lower_mesh
	lower.material_override = fur_mat
	lower.position.y = 0.14 * sf
	lower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(lower)

	# Paw
	var paw := MeshInstance3D.new()
	var paw_mesh := BoxMesh.new()
	paw_mesh.size = Vector3(0.10 * sf, 0.05 * sf, 0.12 * sf)
	paw.mesh = paw_mesh
	paw.material_override = fur_mat
	paw.position = Vector3(0, 0.025 * sf, 0.02 * sf)
	paw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(paw)

	# Claws (3 per paw)
	for ci in range(3):
		var claw := MeshInstance3D.new()
		var claw_mesh := CylinderMesh.new()
		claw_mesh.top_radius = 0.0; claw_mesh.bottom_radius = 0.008 * sf
		claw_mesh.height = 0.04 * sf
		claw.mesh = claw_mesh
		claw.material_override = claw_mat
		claw.position = Vector3((-0.03 + ci * 0.03) * sf, 0.005, 0.07 * sf)
		claw.rotation.x = deg_to_rad(65.0)
		pivot.add_child(claw)

	return pivot


static func _make_wolf_tail(sf: float, fur_mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0.58 * sf, -0.52 * sf)

	# 3 tapered segments for bushy tail
	var widths = [0.10, 0.12, 0.08]
	var lengths = [0.18, 0.20, 0.16]
	var y_off = 0.0
	for i in range(3):
		var seg := MeshInstance3D.new()
		var seg_mesh := CylinderMesh.new()
		seg_mesh.top_radius = widths[i] * sf * 0.7
		seg_mesh.bottom_radius = widths[i] * sf
		seg_mesh.height = lengths[i] * sf
		seg.mesh = seg_mesh
		var seg_mat := StandardMaterial3D.new()
		seg_mat.albedo_color = fur_mat.albedo_color if fur_mat is StandardMaterial3D else Color(0.42, 0.36, 0.29)
		seg_mat.roughness = 1.0
		seg.material_override = seg_mat
		seg.position = Vector3(0, y_off + 0.06 * sf, -(i * 0.14 * sf))
		seg.rotation.x = deg_to_rad(-25.0 - i * 12.0)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		pivot.add_child(seg)
		y_off += 0.04 * sf

	# Tail tip (lighter tuft)
	var tip := MeshInstance3D.new()
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.06 * sf; tip_mesh.height = 0.08 * sf
	tip.mesh = tip_mesh
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.58, 0.52, 0.44)
	tip_mat.roughness = 1.0
	tip.material_override = tip_mat
	tip.position = Vector3(0, y_off + 0.04 * sf, -0.42 * sf)
	pivot.add_child(tip)

	return pivot


# ═══════════════════════════════════════════════════════════════════════════════
#  RAVEN / STORM RAVEN
#  Normal: Jet-black iridescent plumage, sharp beak, folded wings
#  Evolved: Electric blue/purple glow, storm crackling, larger wingspan
# ═══════════════════════════════════════════════════════════════════════════════
static func _build_raven(is_evolved: bool) -> Node3D:
	var group := Node3D.new()
	group.name = "Storm_Raven" if is_evolved else "Raven"
	var sf = 1.25 if is_evolved else 1.0

	# ─── PBR Materials ─────────────────────────────────────────────────────
	var plumage_mat := StandardMaterial3D.new()
	plumage_mat.albedo_color = Color(0.06, 0.06, 0.10) if is_evolved else Color(0.08, 0.08, 0.10)
	plumage_mat.metallic = 0.45
	plumage_mat.roughness = 0.35
	if is_evolved:
		plumage_mat.emission_enabled = true
		plumage_mat.emission = Color(0.25, 0.15, 0.65)
		plumage_mat.emission_energy_multiplier = 0.5

	var beak_mat := StandardMaterial3D.new()
	beak_mat.albedo_color = Color(0.12, 0.10, 0.08)
	beak_mat.roughness = 0.4
	beak_mat.metallic = 0.2

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.4, 0.2, 0.9) if is_evolved else Color(0.10, 0.10, 0.12)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.4, 0.2, 0.9) if is_evolved else Color(0.05, 0.05, 0.05)
	eye_mat.emission_energy_multiplier = 1.5 if is_evolved else 0.2

	var claw_mat := StandardMaterial3D.new()
	claw_mat.albedo_color = Color(0.12, 0.10, 0.08)
	claw_mat.roughness = 0.5

	# ─── BODY (Streamlined oval) ──────────────────────────────────────────
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.18 * sf; body_mesh.height = 0.40 * sf
	body_mesh.radial_segments = 14; body_mesh.rings = 10
	body.mesh = body_mesh
	body.material_override = plumage_mat
	body.position = Vector3(0, 0.82 * sf, 0)
	body.scale = Vector3(1.0, 0.85, 1.4)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(body)

	# Breast feathers (lighter underside)
	var breast := MeshInstance3D.new()
	var breast_mesh := SphereMesh.new()
	breast_mesh.radius = 0.12 * sf; breast_mesh.height = 0.20 * sf
	breast.mesh = breast_mesh
	var breast_mat := StandardMaterial3D.new()
	breast_mat.albedo_color = Color(0.14, 0.13, 0.16)
	breast_mat.roughness = 0.5
	breast.material_override = breast_mat
	breast.position = Vector3(0, 0.76 * sf, 0.08 * sf)
	group.add_child(breast)

	# ─── HEAD (Small, angular) ────────────────────────────────────────────
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.11 * sf; head_mesh.height = 0.18 * sf
	head_mesh.radial_segments = 12; head_mesh.rings = 8
	head.mesh = head_mesh
	head.material_override = plumage_mat
	head.position = Vector3(0, 0.98 * sf, 0.18 * sf)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(head)

	# ─── BEAK (Curved, sharp) ────────────────────────────────────────────
	# Upper beak
	var upper_beak := MeshInstance3D.new()
	var ubeak_mesh := CylinderMesh.new()
	ubeak_mesh.top_radius = 0.0; ubeak_mesh.bottom_radius = 0.04 * sf
	ubeak_mesh.height = 0.14 * sf
	upper_beak.mesh = ubeak_mesh
	upper_beak.material_override = beak_mat
	upper_beak.position = Vector3(0, 0.96 * sf, 0.30 * sf)
	upper_beak.rotation.x = deg_to_rad(80.0)
	group.add_child(upper_beak)
	# Lower beak
	var lower_beak := MeshInstance3D.new()
	var lbeak_mesh := CylinderMesh.new()
	lbeak_mesh.top_radius = 0.0; lbeak_mesh.bottom_radius = 0.03 * sf
	lbeak_mesh.height = 0.10 * sf
	lower_beak.mesh = lbeak_mesh
	lower_beak.material_override = beak_mat
	lower_beak.position = Vector3(0, 0.93 * sf, 0.30 * sf)
	lower_beak.rotation.x = deg_to_rad(90.0)
	group.add_child(lower_beak)

	# ─── EYES ─────────────────────────────────────────────────────────────
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.025 * sf; eye_mesh.height = 0.03 * sf
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.08 * sf, 1.00 * sf, 0.25 * sf)
		group.add_child(eye)

	# ─── WINGS (Folded against body — layered feather panels) ─────────────
	for side in [-1, 1]:
		var wing := _make_raven_wing(sf, plumage_mat, side, is_evolved)
		wing.name = "Wing_L" if side == -1 else "Wing_R"
		group.add_child(wing)

	# ─── TAIL FEATHERS (Fan of flat panels) ──────────────────────────────
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = plumage_mat.albedo_color.darkened(0.05)
	tail_mat.metallic = 0.3; tail_mat.roughness = 0.4
	for i in range(5):
		var feather := MeshInstance3D.new()
		var f_mesh := BoxMesh.new()
		f_mesh.size = Vector3(0.04 * sf, 0.008 * sf, 0.18 * sf)
		feather.mesh = f_mesh
		feather.material_override = tail_mat
		var spread_angle = -0.3 + i * 0.15
		feather.position = Vector3(spread_angle * 0.3 * sf, 0.78 * sf, -0.22 * sf)
		feather.rotation.y = spread_angle
		feather.rotation.x = deg_to_rad(10.0)
		feather.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(feather)

	# ─── LEGS & TALONS (Thin bird legs with grip talons) ──────────────────
	for side in [-1, 1]:
		var leg := _make_bird_leg(sf, claw_mat, plumage_mat, Vector3(side * 0.06 * sf, 0, 0))
		leg.name = "Leg_L" if side == -1 else "Leg_R"
		group.add_child(leg)

	# ─── EVOLVED: Storm crackling + glowing feather tips ─────────────────
	if is_evolved:
		var storm_mat := StandardMaterial3D.new()
		storm_mat.albedo_color = Color(0.5, 0.3, 1.0, 0.5)
		storm_mat.emission_enabled = true
		storm_mat.emission = Color(0.5, 0.3, 1.0)
		storm_mat.emission_energy_multiplier = 2.0
		storm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Lightning crackle arcs around body
		for i in range(4):
			var arc := MeshInstance3D.new()
			var arc_mesh := BoxMesh.new()
			arc_mesh.size = Vector3(0.008, 0.008, 0.15 * sf)
			arc.mesh = arc_mesh
			arc.material_override = storm_mat
			var ang = (i / 4.0) * TAU
			arc.position = Vector3(cos(ang) * 0.22 * sf, 0.85 * sf, sin(ang) * 0.22 * sf)
			arc.rotation = Vector3(randf() * PI, randf() * PI, randf() * PI)
			group.add_child(arc)

	return group


static func _make_raven_wing(sf: float, plumage_mat: Material, side: int, is_evolved: bool) -> Node3D:
	var wing := Node3D.new()
	# 3 feather layers (primary, secondary, covert)
	var layer_sizes = [
		Vector3(0.06, 0.008, 0.30),  # Primary (longest)
		Vector3(0.06, 0.008, 0.24),  # Secondary
		Vector3(0.05, 0.008, 0.18),  # Covert
	]
	for i in range(3):
		var panel := MeshInstance3D.new()
		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(layer_sizes[i].x * sf, layer_sizes[i].y * sf, layer_sizes[i].z * sf)
		panel.mesh = panel_mesh
		var layer_mat := StandardMaterial3D.new()
		if plumage_mat is StandardMaterial3D:
			layer_mat.albedo_color = plumage_mat.albedo_color.darkened(i * 0.03)
		else:
			layer_mat.albedo_color = Color(0.08, 0.08, 0.10).darkened(i * 0.03)
		layer_mat.metallic = 0.4; layer_mat.roughness = 0.35
		if is_evolved:
			layer_mat.emission_enabled = true
			layer_mat.emission = Color(0.2, 0.1, 0.5)
			layer_mat.emission_energy_multiplier = 0.3
		panel.material_override = layer_mat
		panel.position = Vector3(side * (0.20 + i * 0.03) * sf, (0.84 - i * 0.04) * sf, -(i * 0.06) * sf)
		panel.rotation.z = side * deg_to_rad(-5.0 - i * 8.0)
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		wing.add_child(panel)
	return wing


static func _make_bird_leg(sf: float, claw_mat: Material, body_mat: Material, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos

	# Thin scaled leg
	var leg := MeshInstance3D.new()
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.025 * sf; leg_mesh.bottom_radius = 0.018 * sf
	leg_mesh.height = 0.35 * sf
	leg.mesh = leg_mesh
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.25, 0.22, 0.18)
	leg_mat.roughness = 0.6
	leg.material_override = leg_mat
	leg.position.y = 0.44 * sf
	pivot.add_child(leg)

	# Foot/ankle
	var foot := MeshInstance3D.new()
	var foot_mesh := SphereMesh.new()
	foot_mesh.radius = 0.025 * sf; foot_mesh.height = 0.03 * sf
	foot.mesh = foot_mesh
	foot.material_override = leg_mat
	foot.position.y = 0.26 * sf
	pivot.add_child(foot)

	# Talons (3 forward + 1 back)
	for ti in range(3):
		var talon := MeshInstance3D.new()
		var talon_mesh := CylinderMesh.new()
		talon_mesh.top_radius = 0.008 * sf; talon_mesh.bottom_radius = 0.0
		talon_mesh.height = 0.06 * sf
		talon.mesh = talon_mesh
		talon.material_override = claw_mat
		talon.position = Vector3((-0.02 + ti * 0.02) * sf, 0.24 * sf, 0.03 * sf)
		talon.rotation.x = deg_to_rad(55.0)
		pivot.add_child(talon)
	# Back talon
	var back_talon := MeshInstance3D.new()
	var bt_mesh := CylinderMesh.new()
	bt_mesh.top_radius = 0.006 * sf; bt_mesh.bottom_radius = 0.0
	bt_mesh.height = 0.04 * sf
	back_talon.mesh = bt_mesh
	back_talon.material_override = claw_mat
	back_talon.position = Vector3(0, 0.25 * sf, -0.03 * sf)
	back_talon.rotation.x = deg_to_rad(-55.0)
	pivot.add_child(back_talon)

	return pivot


# ═══════════════════════════════════════════════════════════════════════════════
#  BOAR / WAR BOAR
#  Normal: Bristly brown hide, tusks, broad shoulders, small angry eyes
#  Evolved: Red war paint, iron tusk caps, spiked shoulder armor, larger
# ═══════════════════════════════════════════════════════════════════════════════
static func _build_boar(is_evolved: bool) -> Node3D:
	var group := Node3D.new()
	group.name = "War_Boar" if is_evolved else "Boar"
	var sf = 1.3 if is_evolved else 1.0

	# ─── PBR Materials ─────────────────────────────────────────────────────
	var hide_mat := StandardMaterial3D.new()
	hide_mat.albedo_color = Color(0.28, 0.20, 0.16) if is_evolved else Color(0.38, 0.28, 0.20)
	hide_mat.roughness = 0.95

	var belly_mat := StandardMaterial3D.new()
	belly_mat.albedo_color = Color(0.42, 0.32, 0.26) if is_evolved else Color(0.48, 0.38, 0.30)
	belly_mat.roughness = 0.90

	var tusk_mat := StandardMaterial3D.new()
	tusk_mat.albedo_color = Color(0.88, 0.84, 0.74)
	tusk_mat.roughness = 0.4
	tusk_mat.metallic = 0.15

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.85, 0.25, 0.10) if is_evolved else Color(0.65, 0.35, 0.12)
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_mat.albedo_color
	eye_mat.emission_energy_multiplier = 0.8

	var hoof_mat := StandardMaterial3D.new()
	hoof_mat.albedo_color = Color(0.10, 0.08, 0.06)
	hoof_mat.roughness = 0.5

	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.55, 0.38, 0.32)
	nose_mat.roughness = 0.5

	# ─── BODY (Massive barrel torso) ──────────────────────────────────────
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.62 * sf, 0.52 * sf, 0.90 * sf)
	body.mesh = body_mesh
	body.material_override = hide_mat
	body.position = Vector3(0, 0.46 * sf, 0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(body)

	# Shoulder hump (boars have massive shoulders)
	var hump := MeshInstance3D.new()
	var hump_mesh := SphereMesh.new()
	hump_mesh.radius = 0.32 * sf; hump_mesh.height = 0.38 * sf
	hump.mesh = hump_mesh
	hump.material_override = hide_mat
	hump.position = Vector3(0, 0.60 * sf, 0.22 * sf)
	hump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(hump)

	# Belly
	var belly := MeshInstance3D.new()
	var belly_mesh := BoxMesh.new()
	belly_mesh.size = Vector3(0.48 * sf, 0.14 * sf, 0.65 * sf)
	belly.mesh = belly_mesh
	belly.material_override = belly_mat
	belly.position = Vector3(0, 0.22 * sf, -0.05 * sf)
	group.add_child(belly)

	# Bristle ridge along spine (coarse hair)
	var bristle_mat := StandardMaterial3D.new()
	bristle_mat.albedo_color = hide_mat.albedo_color.darkened(0.20)
	bristle_mat.roughness = 1.0
	for i in range(7):
		var bristle := MeshInstance3D.new()
		var b_mesh := CylinderMesh.new()
		b_mesh.top_radius = 0.0; b_mesh.bottom_radius = 0.015 * sf
		b_mesh.height = 0.08 * sf
		bristle.mesh = b_mesh
		bristle.material_override = bristle_mat
		bristle.position = Vector3(0, 0.72 * sf, 0.30 * sf - i * 0.10 * sf)
		group.add_child(bristle)

	# ─── HEAD (Broad, flat-fronted) ──────────────────────────────────────
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.38 * sf, 0.32 * sf, 0.34 * sf)
	head.mesh = head_mesh
	head.material_override = hide_mat
	head.position = Vector3(0, 0.52 * sf, 0.55 * sf)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(head)

	# Snout (flat disk-like pig nose)
	var snout := MeshInstance3D.new()
	var snout_mesh := CylinderMesh.new()
	snout_mesh.top_radius = 0.10 * sf; snout_mesh.bottom_radius = 0.10 * sf
	snout_mesh.height = 0.08 * sf
	snout.mesh = snout_mesh
	snout.material_override = nose_mat
	snout.position = Vector3(0, 0.48 * sf, 0.74 * sf)
	snout.rotation.x = deg_to_rad(90.0)
	group.add_child(snout)

	# Nostrils
	var nostril_mat := StandardMaterial3D.new()
	nostril_mat.albedo_color = Color(0.18, 0.12, 0.10)
	for side in [-1, 1]:
		var nostril := MeshInstance3D.new()
		var n_mesh := SphereMesh.new()
		n_mesh.radius = 0.02 * sf; n_mesh.height = 0.015 * sf
		nostril.mesh = n_mesh
		nostril.material_override = nostril_mat
		nostril.position = Vector3(side * 0.04 * sf, 0.48 * sf, 0.79 * sf)
		group.add_child(nostril)

	# ─── TUSKS (Curved ivory) ────────────────────────────────────────────
	for side in [-1, 1]:
		var tusk := MeshInstance3D.new()
		var tusk_mesh := CylinderMesh.new()
		tusk_mesh.top_radius = 0.0; tusk_mesh.bottom_radius = 0.025 * sf
		tusk_mesh.height = 0.18 * sf
		tusk.mesh = tusk_mesh
		tusk.material_override = tusk_mat
		tusk.position = Vector3(side * 0.14 * sf, 0.46 * sf, 0.68 * sf)
		tusk.rotation.z = side * deg_to_rad(25.0)
		tusk.rotation.x = deg_to_rad(-15.0)
		group.add_child(tusk)

		# Evolved: Iron tusk caps
		if is_evolved:
			var cap := MeshInstance3D.new()
			var cap_mesh := CylinderMesh.new()
			cap_mesh.top_radius = 0.0; cap_mesh.bottom_radius = 0.03 * sf
			cap_mesh.height = 0.06 * sf
			cap.mesh = cap_mesh
			var iron_mat := StandardMaterial3D.new()
			iron_mat.albedo_color = Color(0.30, 0.32, 0.35)
			iron_mat.metallic = 0.80; iron_mat.roughness = 0.35
			cap.material_override = iron_mat
			cap.position = Vector3(side * 0.16 * sf, 0.56 * sf, 0.66 * sf)
			cap.rotation.z = side * deg_to_rad(25.0)
			group.add_child(cap)

	# ─── EYES (Small, angry, deep-set) ───────────────────────────────────
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.028 * sf; eye_mesh.height = 0.035 * sf
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.14 * sf, 0.58 * sf, 0.66 * sf)
		group.add_child(eye)

	# ─── EARS (Small, floppy) ────────────────────────────────────────────
	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var ear_mesh := BoxMesh.new()
		ear_mesh.size = Vector3(0.08 * sf, 0.06 * sf, 0.05 * sf)
		ear.mesh = ear_mesh
		ear.material_override = hide_mat
		ear.position = Vector3(side * 0.16 * sf, 0.68 * sf, 0.48 * sf)
		ear.rotation.z = side * deg_to_rad(-25.0)
		group.add_child(ear)

	# ─── LEGS (4 short, stocky legs with hooves) ─────────────────────────
	var leg_positions = [
		Vector3(-0.22 * sf, 0, 0.25 * sf),
		Vector3(0.22 * sf, 0, 0.25 * sf),
		Vector3(-0.22 * sf, 0, -0.28 * sf),
		Vector3(0.22 * sf, 0, -0.28 * sf),
	]
	var leg_names = ["LimbPivot_FL", "LimbPivot_FR", "LimbPivot_BL", "LimbPivot_BR"]
	for i in range(4):
		var leg := _make_boar_leg(sf, hide_mat, hoof_mat, leg_positions[i])
		leg.name = leg_names[i]
		group.add_child(leg)

	# ─── TAIL (Curly pig tail) ───────────────────────────────────────────
	var tail := MeshInstance3D.new()
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.015 * sf; tail_mesh.bottom_radius = 0.01 * sf
	tail_mesh.height = 0.12 * sf
	tail.mesh = tail_mesh
	tail.material_override = hide_mat
	tail.position = Vector3(0, 0.52 * sf, -0.46 * sf)
	tail.rotation.x = deg_to_rad(-35.0)
	tail.name = "Tail"
	group.add_child(tail)

	# ─── EVOLVED: War paint + spiked shoulder armor ──────────────────────
	if is_evolved:
		# Red war paint stripes
		var paint_mat := StandardMaterial3D.new()
		paint_mat.albedo_color = Color(0.72, 0.12, 0.08)
		paint_mat.emission_enabled = true
		paint_mat.emission = Color(0.5, 0.08, 0.05)
		paint_mat.emission_energy_multiplier = 0.4
		for i in range(3):
			var stripe := MeshInstance3D.new()
			var s_mesh := BoxMesh.new()
			s_mesh.size = Vector3(0.65 * sf, 0.02 * sf, 0.03 * sf)
			stripe.mesh = s_mesh
			stripe.material_override = paint_mat
			stripe.position = Vector3(0, 0.55 * sf - i * 0.08 * sf, 0.10 * sf)
			group.add_child(stripe)

		# Spiked shoulder armor
		var armor_mat := StandardMaterial3D.new()
		armor_mat.albedo_color = Color(0.25, 0.25, 0.28)
		armor_mat.metallic = 0.70; armor_mat.roughness = 0.40
		for side in [-1, 1]:
			var plate := MeshInstance3D.new()
			var plate_mesh := BoxMesh.new()
			plate_mesh.size = Vector3(0.12 * sf, 0.18 * sf, 0.28 * sf)
			plate.mesh = plate_mesh
			plate.material_override = armor_mat
			plate.position = Vector3(side * 0.34 * sf, 0.58 * sf, 0.20 * sf)
			group.add_child(plate)
			# Spikes on armor
			for j in range(2):
				var spike := MeshInstance3D.new()
				var sp_mesh := CylinderMesh.new()
				sp_mesh.top_radius = 0.0; sp_mesh.bottom_radius = 0.02 * sf
				sp_mesh.height = 0.10 * sf
				spike.mesh = sp_mesh
				spike.material_override = armor_mat
				spike.position = Vector3(side * 0.40 * sf, 0.64 * sf, 0.15 * sf + j * 0.12 * sf)
				spike.rotation.z = side * deg_to_rad(-45.0)
				group.add_child(spike)

	return group


static func _make_boar_leg(sf: float, hide_mat: Material, hoof_mat: Material, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos

	# Upper leg (thick)
	var upper := MeshInstance3D.new()
	var upper_mesh := CylinderMesh.new()
	upper_mesh.top_radius = 0.09 * sf; upper_mesh.bottom_radius = 0.07 * sf
	upper_mesh.height = 0.22 * sf
	upper.mesh = upper_mesh
	upper.material_override = hide_mat
	upper.position.y = 0.30 * sf
	upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(upper)

	# Lower leg
	var lower := MeshInstance3D.new()
	var lower_mesh := CylinderMesh.new()
	lower_mesh.top_radius = 0.065 * sf; lower_mesh.bottom_radius = 0.05 * sf
	lower_mesh.height = 0.18 * sf
	lower.mesh = lower_mesh
	lower.material_override = hide_mat
	lower.position.y = 0.14 * sf
	lower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(lower)

	# Hoof (cloven)
	var hoof := MeshInstance3D.new()
	var hoof_mesh := BoxMesh.new()
	hoof_mesh.size = Vector3(0.09 * sf, 0.05 * sf, 0.10 * sf)
	hoof.mesh = hoof_mesh
	hoof.material_override = hoof_mat
	hoof.position = Vector3(0, 0.025, 0.01 * sf)
	hoof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(hoof)

	# Hoof split detail
	var split := MeshInstance3D.new()
	var split_mesh := BoxMesh.new()
	split_mesh.size = Vector3(0.008 * sf, 0.055 * sf, 0.10 * sf)
	split.mesh = split_mesh
	var split_mat := StandardMaterial3D.new()
	split_mat.albedo_color = Color(0.04, 0.03, 0.02)
	split.material_override = split_mat
	split.position = Vector3(0, 0.025, 0.01 * sf)
	pivot.add_child(split)

	return pivot


# ═══════════════════════════════════════════════════════════════════════════════
#  STAG / GREAT STAG
#  Normal: Elegant tawny hide, graceful antlers, long legs, doe eyes
#  Evolved: Golden glow, massive crystal-tipped antlers, floral aura, larger
# ═══════════════════════════════════════════════════════════════════════════════
static func _build_stag(is_evolved: bool) -> Node3D:
	var group := Node3D.new()
	group.name = "Great_Stag" if is_evolved else "Stag"
	var sf = 1.3 if is_evolved else 1.0

	# ─── PBR Materials ─────────────────────────────────────────────────────
	var hide_mat := StandardMaterial3D.new()
	hide_mat.albedo_color = Color(0.48, 0.38, 0.28) if is_evolved else Color(0.58, 0.44, 0.32)
	hide_mat.roughness = 0.82
	if is_evolved:
		hide_mat.emission_enabled = true
		hide_mat.emission = Color(0.5, 0.38, 0.12)
		hide_mat.emission_energy_multiplier = 0.2

	var belly_mat := StandardMaterial3D.new()
	belly_mat.albedo_color = Color(0.72, 0.62, 0.50) if is_evolved else Color(0.75, 0.65, 0.52)
	belly_mat.roughness = 0.80

	var antler_mat := StandardMaterial3D.new()
	antler_mat.albedo_color = Color(0.72, 0.58, 0.32) if is_evolved else Color(0.55, 0.42, 0.28)
	antler_mat.roughness = 0.50
	antler_mat.metallic = 0.15
	if is_evolved:
		antler_mat.emission_enabled = true
		antler_mat.emission = Color(0.7, 0.55, 0.2)
		antler_mat.emission_energy_multiplier = 0.5

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.65, 0.50, 0.15) if is_evolved else Color(0.35, 0.25, 0.10)
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_mat.albedo_color
	eye_mat.emission_energy_multiplier = 0.6

	var hoof_mat := StandardMaterial3D.new()
	hoof_mat.albedo_color = Color(0.12, 0.10, 0.08)
	hoof_mat.roughness = 0.5

	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.08, 0.06, 0.05)
	nose_mat.roughness = 0.3

	# ─── BODY (Graceful, elongated) ──────────────────────────────────────
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.48 * sf, 0.45 * sf, 1.0 * sf)
	body.mesh = body_mesh
	body.material_override = hide_mat
	body.position = Vector3(0, 0.82 * sf, 0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(body)

	# Chest (slightly broader)
	var chest := MeshInstance3D.new()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(0.50 * sf, 0.48 * sf, 0.40 * sf)
	chest.mesh = chest_mesh
	chest.material_override = hide_mat
	chest.position = Vector3(0, 0.84 * sf, 0.28 * sf)
	group.add_child(chest)

	# Belly (lighter)
	var belly := MeshInstance3D.new()
	var belly_mesh := BoxMesh.new()
	belly_mesh.size = Vector3(0.38 * sf, 0.10 * sf, 0.75 * sf)
	belly.mesh = belly_mesh
	belly.material_override = belly_mat
	belly.position = Vector3(0, 0.58 * sf, 0)
	group.add_child(belly)

	# White rump patch (tail area)
	var rump := MeshInstance3D.new()
	var rump_mesh := SphereMesh.new()
	rump_mesh.radius = 0.14 * sf; rump_mesh.height = 0.12 * sf
	rump.mesh = rump_mesh
	var rump_mat := StandardMaterial3D.new()
	rump_mat.albedo_color = Color(0.88, 0.82, 0.72)
	rump_mat.roughness = 0.80
	rump.material_override = rump_mat
	rump.position = Vector3(0, 0.88 * sf, -0.48 * sf)
	group.add_child(rump)

	# ─── NECK (Long, elegant) ────────────────────────────────────────────
	var neck := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.12 * sf; neck_mesh.bottom_radius = 0.18 * sf
	neck_mesh.height = 0.45 * sf
	neck.mesh = neck_mesh
	neck.material_override = hide_mat
	neck.position = Vector3(0, 1.02 * sf, 0.45 * sf)
	neck.rotation.x = deg_to_rad(20.0)
	neck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(neck)

	# ─── HEAD (Refined, narrow) ──────────────────────────────────────────
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.24 * sf, 0.22 * sf, 0.30 * sf)
	head.mesh = head_mesh
	head.material_override = hide_mat
	head.position = Vector3(0, 1.22 * sf, 0.56 * sf)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(head)

	# Muzzle
	var muzzle := MeshInstance3D.new()
	var muzzle_mesh := BoxMesh.new()
	muzzle_mesh.size = Vector3(0.16 * sf, 0.14 * sf, 0.18 * sf)
	muzzle.mesh = muzzle_mesh
	muzzle.material_override = hide_mat
	muzzle.position = Vector3(0, 1.18 * sf, 0.74 * sf)
	group.add_child(muzzle)

	# Nose
	var nose := MeshInstance3D.new()
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.035 * sf; nose_mesh.height = 0.04 * sf
	nose.mesh = nose_mesh
	nose.material_override = nose_mat
	nose.position = Vector3(0, 1.20 * sf, 0.84 * sf)
	group.add_child(nose)

	# ─── EYES (Large, gentle doe eyes) ───────────────────────────────────
	var pupil_mat := StandardMaterial3D.new()
	pupil_mat.albedo_color = Color(0.02, 0.02, 0.02)
	var sclera_mat := StandardMaterial3D.new()
	sclera_mat.albedo_color = Color(0.92, 0.90, 0.85)
	for side in [-1, 1]:
		# Sclera
		var sclera := MeshInstance3D.new()
		var sc_mesh := SphereMesh.new()
		sc_mesh.radius = 0.04 * sf; sc_mesh.height = 0.035 * sf
		sclera.mesh = sc_mesh
		sclera.material_override = sclera_mat
		sclera.position = Vector3(side * 0.10 * sf, 1.26 * sf, 0.66 * sf)
		group.add_child(sclera)
		# Iris
		var iris := MeshInstance3D.new()
		var iris_mesh := SphereMesh.new()
		iris_mesh.radius = 0.028 * sf; iris_mesh.height = 0.025 * sf
		iris.mesh = iris_mesh
		iris.material_override = eye_mat
		iris.position = Vector3(side * 0.10 * sf, 1.26 * sf, 0.68 * sf)
		group.add_child(iris)
		# Pupil
		var pupil := MeshInstance3D.new()
		var pup_mesh := SphereMesh.new()
		pup_mesh.radius = 0.014 * sf; pup_mesh.height = 0.015 * sf
		pupil.mesh = pup_mesh
		pupil.material_override = pupil_mat
		pupil.position = Vector3(side * 0.10 * sf, 1.26 * sf, 0.70 * sf)
		group.add_child(pupil)

	# ─── EARS (Long, leaf-shaped) ────────────────────────────────────────
	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var ear_mesh := BoxMesh.new()
		ear_mesh.size = Vector3(0.05 * sf, 0.12 * sf, 0.08 * sf)
		ear.mesh = ear_mesh
		ear.material_override = hide_mat
		ear.position = Vector3(side * 0.12 * sf, 1.34 * sf, 0.50 * sf)
		ear.rotation.z = side * deg_to_rad(-30.0)
		ear.rotation.x = deg_to_rad(-10.0)
		group.add_child(ear)

	# ─── ANTLERS (Complex branching antler structure) ─────────────────────
	for side in [-1, 1]:
		var antler := _make_antler(sf, antler_mat, side, is_evolved)
		antler.name = "Antler_L" if side == -1 else "Antler_R"
		group.add_child(antler)

	# ─── LEGS (4 tall, slender deer legs with hooves) ────────────────────
	var leg_positions = [
		Vector3(-0.16 * sf, 0, 0.28 * sf),
		Vector3(0.16 * sf, 0, 0.28 * sf),
		Vector3(-0.16 * sf, 0, -0.32 * sf),
		Vector3(0.16 * sf, 0, -0.32 * sf),
	]
	var leg_names = ["LimbPivot_FL", "LimbPivot_FR", "LimbPivot_BL", "LimbPivot_BR"]
	for i in range(4):
		var leg := _make_stag_leg(sf, hide_mat, hoof_mat, leg_positions[i])
		leg.name = leg_names[i]
		group.add_child(leg)

	# ─── TAIL (Short, fluffy) ───────────────────────────────────────────
	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.06 * sf, 0.08 * sf, 0.10 * sf)
	tail.mesh = tail_mesh
	tail.material_override = rump_mat
	tail.position = Vector3(0, 0.92 * sf, -0.54 * sf)
	tail.name = "Tail"
	group.add_child(tail)

	# ─── EVOLVED: Crystal antler tips + golden particle aura ─────────────
	if is_evolved:
		# Vine/moss decoration on body
		var vine_mat := StandardMaterial3D.new()
		vine_mat.albedo_color = Color(0.18, 0.48, 0.22)
		vine_mat.roughness = 0.9
		for i in range(3):
			var vine := MeshInstance3D.new()
			var v_mesh := CylinderMesh.new()
			v_mesh.top_radius = 0.01 * sf; v_mesh.bottom_radius = 0.008 * sf
			v_mesh.height = 0.20 * sf
			vine.mesh = v_mesh
			vine.material_override = vine_mat
			vine.position = Vector3(0.18 * sf, 0.82 * sf, 0.20 * sf - i * 0.18 * sf)
			vine.rotation.z = deg_to_rad(60.0 + i * 15.0)
			group.add_child(vine)

		# Golden leaf aura particles
		var aura_mat := StandardMaterial3D.new()
		aura_mat.albedo_color = Color(0.95, 0.80, 0.25, 0.4)
		aura_mat.emission_enabled = true
		aura_mat.emission = Color(0.95, 0.80, 0.25)
		aura_mat.emission_energy_multiplier = 1.0
		aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for i in range(6):
			var leaf := MeshInstance3D.new()
			var l_mesh := SphereMesh.new()
			l_mesh.radius = 0.02 * sf; l_mesh.height = 0.015 * sf
			leaf.mesh = l_mesh
			leaf.material_override = aura_mat
			var ang = (i / 6.0) * TAU
			leaf.position = Vector3(cos(ang) * 0.50 * sf, 0.90 * sf + sin(ang * 2) * 0.15, sin(ang) * 0.50 * sf)
			group.add_child(leaf)

	return group


static func _make_antler(sf: float, antler_mat: Material, side: int, is_evolved: bool) -> Node3D:
	var antler := Node3D.new()

	# Main beam (central trunk going up)
	var beam := MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.015 * sf; beam_mesh.bottom_radius = 0.035 * sf
	beam_mesh.height = 0.40 * sf
	beam.mesh = beam_mesh
	beam.material_override = antler_mat
	beam.position = Vector3(side * 0.10 * sf, 1.50 * sf, 0.48 * sf)
	beam.rotation.z = side * deg_to_rad(-18.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	antler.add_child(beam)

	# Tine 1 (brow tine — forward pointing)
	var tine1 := MeshInstance3D.new()
	var t1_mesh := CylinderMesh.new()
	t1_mesh.top_radius = 0.0; t1_mesh.bottom_radius = 0.02 * sf
	t1_mesh.height = 0.16 * sf
	tine1.mesh = t1_mesh
	tine1.material_override = antler_mat
	tine1.position = Vector3(side * 0.12 * sf, 1.42 * sf, 0.52 * sf)
	tine1.rotation.x = deg_to_rad(-45.0)
	tine1.rotation.z = side * deg_to_rad(-10.0)
	antler.add_child(tine1)

	# Tine 2 (bez tine — upward and out)
	var tine2 := MeshInstance3D.new()
	var t2_mesh := CylinderMesh.new()
	t2_mesh.top_radius = 0.0; t2_mesh.bottom_radius = 0.018 * sf
	t2_mesh.height = 0.20 * sf
	tine2.mesh = t2_mesh
	tine2.material_override = antler_mat
	tine2.position = Vector3(side * 0.14 * sf, 1.58 * sf, 0.46 * sf)
	tine2.rotation.z = side * deg_to_rad(-35.0)
	antler.add_child(tine2)

	# Tine 3 (trez tine — for evolved, adds extra point)
	var tine3 := MeshInstance3D.new()
	var t3_mesh := CylinderMesh.new()
	t3_mesh.top_radius = 0.0; t3_mesh.bottom_radius = 0.015 * sf
	t3_mesh.height = 0.14 * sf
	tine3.mesh = t3_mesh
	tine3.material_override = antler_mat
	tine3.position = Vector3(side * 0.16 * sf, 1.65 * sf, 0.44 * sf)
	tine3.rotation.z = side * deg_to_rad(-50.0)
	antler.add_child(tine3)

	# Evolved: Crystal tips on each tine
	if is_evolved:
		var crystal_mat := StandardMaterial3D.new()
		crystal_mat.albedo_color = Color(0.85, 0.70, 0.30, 0.8)
		crystal_mat.emission_enabled = true
		crystal_mat.emission = Color(0.95, 0.80, 0.35)
		crystal_mat.emission_energy_multiplier = 1.8
		crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var crystal_positions = [
			Vector3(side * 0.12 * sf, 1.56 * sf, 0.56 * sf),
			Vector3(side * 0.18 * sf, 1.68 * sf, 0.44 * sf),
			Vector3(side * 0.20 * sf, 1.74 * sf, 0.42 * sf),
		]
		for cp in crystal_positions:
			var crystal := MeshInstance3D.new()
			var c_mesh := CylinderMesh.new()
			c_mesh.top_radius = 0.0; c_mesh.bottom_radius = 0.018 * sf
			c_mesh.height = 0.08 * sf
			crystal.mesh = c_mesh
			crystal.material_override = crystal_mat
			crystal.position = cp
			antler.add_child(crystal)

	return antler


static func _make_stag_leg(sf: float, hide_mat: Material, hoof_mat: Material, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos

	# Upper leg (slender thigh)
	var upper := MeshInstance3D.new()
	var upper_mesh := CylinderMesh.new()
	upper_mesh.top_radius = 0.07 * sf; upper_mesh.bottom_radius = 0.055 * sf
	upper_mesh.height = 0.32 * sf
	upper.mesh = upper_mesh
	upper.material_override = hide_mat
	upper.position.y = 0.52 * sf
	upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(upper)

	# Lower leg (thin shin)
	var lower := MeshInstance3D.new()
	var lower_mesh := CylinderMesh.new()
	lower_mesh.top_radius = 0.048 * sf; lower_mesh.bottom_radius = 0.035 * sf
	lower_mesh.height = 0.30 * sf
	lower.mesh = lower_mesh
	lower.material_override = hide_mat
	lower.position.y = 0.22 * sf
	lower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(lower)

	# Hoof
	var hoof := MeshInstance3D.new()
	var hoof_mesh := CylinderMesh.new()
	hoof_mesh.top_radius = 0.04 * sf; hoof_mesh.bottom_radius = 0.035 * sf
	hoof_mesh.height = 0.06 * sf
	hoof.mesh = hoof_mesh
	hoof.material_override = hoof_mat
	hoof.position.y = 0.03
	hoof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(hoof)

	return pivot


# ═══════════════════════════════════════════════════════════════════════════════
#  SHARED UTILITY — Contact Shadow
# ═══════════════════════════════════════════════════════════════════════════════
## REMOVED: _make_contact_shadow().
##
## It added a flat PlaneMesh with alpha 0.35 to each beast root as a fake
## grounding shadow. Two things were wrong with it:
##
##   1. ActorBaker already gives every rig a GroundShadow quad with a dedicated
##      soft-edged shader, so this was a second shadow on top of the real one.
##   2. It was part of the raw node tree, so ActorBaker.bake() welded it INTO
##      the body mesh. The baker groups surfaces by roughness and metallic and
##      does not carry transparency across, so the quad came out opaque — a grey
##      slab through every quadruped's torso, clearly visible in a render.
##
## If a beast ever needs a bigger shadow, pass a larger value through
## SHADOW_SIZE instead of adding geometry.
