extends RefCounted

## ═══════════════════════════════════════════════════════════════════════════════
##  CHARACTER FACTORY — the 12 GDD archetypes, built entirely from code.
##
##  The create_*() functions below are the DESIGN of each character and stay
##  hand-authored and readable. What ships is not the raw output though: every
##  archetype goes through ActorBaker, which rebuilds the flat rig into a proper
##  Root > Torso > Head hierarchy and welds ~60 MeshInstance3D nodes down to ~7.
##
##  That matters twice over. A 32-player match with raw rigs would be ~1,900 draw
##  calls for characters alone; baked it is ~220, and only the handful on screen
##  actually draw. And because the bake gives the head a real pivot with the face
##  and crown INSIDE it, the animator can finally turn a head without leaving the
##  eyes behind.
##
##  Use create_character_by_archetype() everywhere. create_*_raw() is only for
##  editing/previewing a design.
## ═══════════════════════════════════════════════════════════════════════════════

const ActorBaker = preload("res://scripts/render/actor_baker.gd")

const ARCHETYPE_IDS := [
	"warlord", "regent", "beastlord",
	"engineer", "witch", "herbalist",
	"guardian", "berserker", "sapper",
	"scout", "archer", "builder",
]

## Which role each archetype belongs to (GDD §4).
const ARCHETYPE_ROLE := {
	"warlord": Constants.Role.KING, "regent": Constants.Role.KING, "beastlord": Constants.Role.KING,
	"engineer": Constants.Role.QUEEN, "witch": Constants.Role.QUEEN, "herbalist": Constants.Role.QUEEN,
	"guardian": Constants.Role.SOLDIER_A, "berserker": Constants.Role.SOLDIER_A, "sapper": Constants.Role.SOLDIER_A,
	"scout": Constants.Role.SOLDIER_B, "archer": Constants.Role.SOLDIER_B, "builder": Constants.Role.SOLDIER_B,
}


## Ship-ready character: rebuilt hierarchy, welded meshes, stylised material.
static func create_character_by_archetype(archetype_id: String) -> Node3D:
	var id := archetype_id.to_lower()
	if not ARCHETYPE_IDS.has(id):
		id = "warlord"
	return ActorBaker.get_actor(id, func(): return create_raw(id))


## The un-baked design output. Use for editing and inspection, not for spawning.
static func create_raw(archetype_id: String) -> Node3D:
	match archetype_id.to_lower():
		"warlord":   return create_warlord()
		"regent":    return create_regent()
		"beastlord": return create_beastlord()
		"engineer":  return create_engineer()
		"witch":     return create_witch()
		"herbalist": return create_herbalist()
		"guardian":  return create_guardian()
		"berserker": return create_berserker()
		"sapper":    return create_sapper()
		"scout":     return create_scout()
		"archer":    return create_archer()
		"builder":   return create_builder()
		_:           return create_warlord()


static func create_character(role: Constants.Role) -> Node3D:
	return create_character_by_archetype(default_archetype_for(role))


static func default_archetype_for(role: Constants.Role) -> String:
	match role:
		Constants.Role.KING:      return "warlord"
		Constants.Role.QUEEN:     return "engineer"
		Constants.Role.SOLDIER_A: return "guardian"
		Constants.Role.SOLDIER_B: return "scout"
	return "warlord"


## All archetype ids available for a role — used by the character select screen.
static func archetypes_for_role(role: Constants.Role) -> Array:
	var out: Array = []
	for id in ARCHETYPE_IDS:
		if ARCHETYPE_ROLE[id] == role:
			out.append(id)
	return out

# ═══════════════════════════════════════════════════════════════════════════════
#  BASE RIG — stylised hero anatomy.
#
#  The previous rig was a stack of unconnected boxes: a flat slab torso, arms
#  floating in the air beside it with a visible gap at the shoulder, and a hand
#  made of a box plus four cylinders that read as a blob at any real distance.
#
#  This version keeps the exact same body-space anchor points (head 2.12,
#  shoulders 1.72, belt 0.88, ground 0.0) so all forty-odd accessory builders
#  below still line up, but rebuilds the anatomy itself:
#
#    • Torso is three stacked tapered sections, squashed front-to-back, so it
#      reads as a chest narrowing into a waist instead of a cardboard box.
#    • Shoulder balls physically bridge torso and arm, so limbs are attached.
#    • Hands are single rounded mittens. Four finger cylinders each were 90% of
#      the hand's triangle count and invisible past two metres.
#    • Legs get a hip joint, a knee, and a boot with a real toe.
#    • The head gets a jaw, a hair cap and a proper brow line, which is what
#      makes a character look like a character rather than a ball.
# ═══════════════════════════════════════════════════════════════════════════════
static func _make_base_rig(tunic_color: Color, skin_color: Color = Color(0.86, 0.72, 0.53), build: String = "medium") -> Dictionary:
	var group := Node3D.new()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = tunic_color
	mat.roughness = 0.72

	var tunic_dark := StandardMaterial3D.new()
	tunic_dark.albedo_color = tunic_color.darkened(0.22)
	tunic_dark.roughness = 0.75

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = skin_color
	skin_mat.roughness = 0.55

	var skin_shade := StandardMaterial3D.new()
	skin_shade.albedo_color = skin_color.darkened(0.14)
	skin_shade.roughness = 0.58

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.14, 0.14, 0.17)
	dark_mat.roughness = 0.80

	var boot_mat := StandardMaterial3D.new()
	boot_mat.albedo_color = Color(0.24, 0.17, 0.12)
	boot_mat.roughness = 0.85

	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = Color(0.26, 0.17, 0.10)
	hair_mat.roughness = 0.88

	# ── Build proportions ────────────────────────────────────────────────────
	var chest_r := 0.42
	var waist_r := 0.30
	var torso_squash := 0.60      # front-to-back flattening; humans aren't round
	## Half the shoulder span. The arm pivot MUST clear chest_r or the whole arm
	## renders inside the ribcage — which is exactly what happened before, and
	## why the characters looked armless. These values also match the fixed x
	## positions the pauldron / spiked-shoulder accessories were authored to.
	var arm_x := 0.51
	var leg_len := 0.85
	var arm_len := 0.72
	var limb_r := 0.135
	match build:
		"heavy":
			chest_r = 0.50; waist_r = 0.36; arm_x = 0.63
			leg_len = 0.88; arm_len = 0.78; limb_r = 0.155; torso_squash = 0.64
		"slim":
			chest_r = 0.36; waist_r = 0.26; arm_x = 0.45
			leg_len = 0.86; arm_len = 0.70; limb_r = 0.118; torso_squash = 0.56

	# ── TORSO — three tapered sections, squashed front-to-back ───────────────
	var torso := _seg(chest_r, chest_r * 0.94, 0.34, mat, Vector3(0, 1.56, 0))
	torso.scale = Vector3(1.0, 1.0, torso_squash)
	torso.name = "TorsoCore"
	group.add_child(torso)

	var ribs := _seg(chest_r * 0.94, waist_r * 1.06, 0.34, mat, Vector3(0, 1.24, 0))
	ribs.scale = Vector3(1.0, 1.0, torso_squash)
	group.add_child(ribs)

	var waist := _seg(waist_r * 1.06, waist_r, 0.22, tunic_dark, Vector3(0, 1.00, 0))
	waist.scale = Vector3(1.0, 1.0, torso_squash + 0.04)
	group.add_child(waist)

	# Chest highlight panel — a lighter facing plane gives the flat-shaded torso
	# a readable front, which matters a lot on an isometric camera.
	var chest_panel := MeshInstance3D.new()
	var cp := BoxMesh.new()
	cp.size = Vector3(chest_r * 1.15, 0.46, 0.04)
	chest_panel.mesh = cp
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = tunic_color.lightened(0.10)
	panel_mat.roughness = 0.72
	chest_panel.material_override = panel_mat
	chest_panel.position = Vector3(0, 1.48, chest_r * torso_squash - 0.01)
	group.add_child(chest_panel)

	# ── PELVIS + BELT ────────────────────────────────────────────────────────
	var pelvis := _seg(waist_r, waist_r * 1.02, 0.20, dark_mat, Vector3(0, 0.82, 0))
	pelvis.scale = Vector3(1.0, 1.0, torso_squash + 0.06)
	group.add_child(pelvis)

	var belt := _seg(waist_r * 1.10, waist_r * 1.10, 0.11, _quick_mat(Color(0.28, 0.20, 0.14), 0.80), Vector3(0, 0.92, 0))
	belt.scale = Vector3(1.0, 1.0, torso_squash + 0.06)
	group.add_child(belt)

	var buckle := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.13, 0.10, 0.05)
	buckle.mesh = bm
	buckle.material_override = _quick_mat(Color(0.85, 0.71, 0.26), 0.30, 0.85)
	buckle.position = Vector3(0, 0.92, waist_r * (torso_squash + 0.06) + 0.01)
	group.add_child(buckle)

	# ── SHOULDER BALLS — bridge torso and arms so limbs are attached ─────────
	for side in [-1.0, 1.0]:
		var ball := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = limb_r * 1.45; bs.height = limb_r * 2.9
		bs.radial_segments = 10; bs.rings = 6
		ball.mesh = bs
		ball.material_override = mat
		ball.position = Vector3(side * arm_x, 1.70, 0)
		group.add_child(ball)

	# Trapezius wedge — bridges the neck to the shoulder balls so the upper body
	# reads as one shape instead of a torso with two balls floating beside it.
	var traps := MeshInstance3D.new()
	var trm := SphereMesh.new()
	trm.radius = 0.5; trm.height = 1.0
	trm.radial_segments = 12; trm.rings = 6
	traps.mesh = trm
	traps.material_override = mat
	traps.position = Vector3(0, 1.66, 0)
	traps.scale = Vector3(arm_x * 1.90, 0.42, chest_r * torso_squash * 1.75)
	group.add_child(traps)

	# ── NECK & HEAD ──────────────────────────────────────────────────────────
	var neck := _seg(0.145, 0.185, 0.20, skin_shade, Vector3(0, 1.84, 0))
	group.add_child(neck)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.345
	head_mesh.height = 0.70
	head_mesh.radial_segments = 14
	head_mesh.rings = 8
	head.mesh = head_mesh
	head.material_override = skin_mat
	head.position.y = 2.12
	head.name = "HeadCore"
	group.add_child(head)

	# Jaw — a slightly narrower box under the skull. Turns a ball into a face.
	var jaw := MeshInstance3D.new()
	var jm := BoxMesh.new(); jm.size = Vector3(0.44, 0.20, 0.42)
	jaw.mesh = jm
	jaw.material_override = skin_mat
	jaw.position = Vector3(0, 1.98, 0.02)
	group.add_child(jaw)

	# Hair cap — covers the crown so hats and crowns sit on hair, not on scalp.
	var hair := MeshInstance3D.new()
	var hm2 := SphereMesh.new()
	hm2.radius = 0.355; hm2.height = 0.62
	hm2.radial_segments = 14; hm2.rings = 7
	hair.mesh = hm2
	hair.material_override = hair_mat
	hair.position = Vector3(0, 2.20, -0.02)
	hair.scale = Vector3(1.0, 0.72, 1.0)
	group.add_child(hair)

	# ── FACE ─────────────────────────────────────────────────────────────────
	var eye_white := _quick_mat(Color(0.96, 0.96, 0.97), 0.35)
	var iris_mat := _quick_mat(Color(0.16, 0.30, 0.50), 0.30)
	var pupil_mat := _quick_mat(Color(0.03, 0.03, 0.04), 0.25)
	var brow_mat := _quick_mat(Color(0.20, 0.14, 0.10), 0.90)

	for side2 in [-1.0, 1.0]:
		var sclera := MeshInstance3D.new()
		var sm2 := SphereMesh.new(); sm2.radius = 0.072; sm2.height = 0.10
		sm2.radial_segments = 8; sm2.rings = 5
		sclera.mesh = sm2
		sclera.material_override = eye_white
		sclera.position = Vector3(side2 * 0.135, 2.15, 0.275)
		sclera.scale = Vector3(1.0, 1.15, 0.55)
		group.add_child(sclera)

		var iris := MeshInstance3D.new()
		var im := SphereMesh.new(); im.radius = 0.042; im.height = 0.05
		im.radial_segments = 8; im.rings = 4
		iris.mesh = im
		iris.material_override = iris_mat
		iris.position = Vector3(side2 * 0.135, 2.14, 0.318)
		group.add_child(iris)

		var pupil := MeshInstance3D.new()
		var pm2 := SphereMesh.new(); pm2.radius = 0.021; pm2.height = 0.026
		pm2.radial_segments = 6; pm2.rings = 3
		pupil.mesh = pm2
		pupil.material_override = pupil_mat
		pupil.position = Vector3(side2 * 0.135, 2.14, 0.338)
		group.add_child(pupil)

		var brow := MeshInstance3D.new()
		var brm := BoxMesh.new(); brm.size = Vector3(0.14, 0.035, 0.05)
		brow.mesh = brm
		brow.material_override = brow_mat
		brow.position = Vector3(side2 * 0.135, 2.255, 0.295)
		brow.rotation.z = side2 * deg_to_rad(-9.0)
		group.add_child(brow)

	var nose := MeshInstance3D.new()
	var nm := PrismMesh.new(); nm.size = Vector3(0.07, 0.11, 0.09)
	nose.mesh = nm
	nose.material_override = skin_shade
	nose.position = Vector3(0, 2.055, 0.31)
	nose.rotation.x = deg_to_rad(90.0)
	group.add_child(nose)

	var mouth := MeshInstance3D.new()
	var mm := BoxMesh.new(); mm.size = Vector3(0.15, 0.030, 0.02)
	mouth.mesh = mm
	mouth.material_override = _quick_mat(Color(0.50, 0.26, 0.24), 0.60)
	mouth.position = Vector3(0, 1.965, 0.315)
	group.add_child(mouth)

	for side3 in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var em := SphereMesh.new(); em.radius = 0.075; em.height = 0.12
		em.radial_segments = 8; em.rings = 4
		ear.mesh = em
		ear.material_override = skin_mat
		ear.position = Vector3(side3 * 0.335, 2.10, 0.02)
		ear.scale = Vector3(0.45, 1.0, 0.85)
		group.add_child(ear)

	# ── LIMBS ────────────────────────────────────────────────────────────────
	var left_arm := _make_detailed_arm(arm_len, mat, skin_mat, Vector3(-arm_x, 1.70, 0), false, limb_r)
	left_arm.name = "LimbPivot_LA"
	var right_arm := _make_detailed_arm(arm_len, mat, skin_mat, Vector3(arm_x, 1.70, 0), true, limb_r)
	right_arm.name = "LimbPivot_RA"
	group.add_child(left_arm)
	group.add_child(right_arm)

	var left_leg := _make_detailed_leg(leg_len, dark_mat, boot_mat, Vector3(-waist_r * 0.55, 0.85, 0), limb_r)
	left_leg.name = "LimbPivot_LL"
	var right_leg := _make_detailed_leg(leg_len, dark_mat, boot_mat, Vector3(waist_r * 0.55, 0.85, 0), limb_r)
	right_leg.name = "LimbPivot_RL"
	group.add_child(left_leg)
	group.add_child(right_leg)

	return {
		"root": group,
		"head": head,
		"torso": torso,
		"left_arm": left_arm,
		"right_arm": right_arm,
	}


## Tapered 10-sided section — the building block of every rounded body part.
static func _seg(top_r: float, bottom_r: float, height: float, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


static func _quick_mat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


# ═══════════════════════════════════════════════════════════════════════════════
#  ARM — shoulder ball, tapered upper arm, forearm, rounded mitten hand.
# ═══════════════════════════════════════════════════════════════════════════════
static func _make_detailed_arm(total_len: float, sleeve_mat: Material, skin_mat: Material,
		pos: Vector3, is_right: bool, r: float = 0.135) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos

	var upper := _seg(r, r * 0.86, total_len * 0.52, sleeve_mat, Vector3(0, -total_len * 0.26, 0))
	pivot.add_child(upper)

	# Elbow ball — stops the arm reading as one straight tube when it bends.
	var elbow := MeshInstance3D.new()
	var em := SphereMesh.new(); em.radius = r * 0.88; em.height = r * 1.76
	em.radial_segments = 8; em.rings = 5
	elbow.mesh = em
	elbow.material_override = sleeve_mat
	elbow.position.y = -total_len * 0.52
	pivot.add_child(elbow)

	var fore := _seg(r * 0.84, r * 0.70, total_len * 0.44, skin_mat, Vector3(0, -total_len * 0.74, 0))
	pivot.add_child(fore)

	# Mitten hand. Four finger cylinders each used to cost more triangles than
	# the entire forearm and were invisible past two metres.
	var hand := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = r * 0.92; hm.height = r * 2.0
	hm.radial_segments = 8; hm.rings = 5
	hand.mesh = hm
	hand.material_override = skin_mat
	hand.position.y = -total_len - r * 0.35
	hand.scale = Vector3(0.85, 1.0, 1.15)
	hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(hand)

	var thumb := MeshInstance3D.new()
	var tm := SphereMesh.new(); tm.radius = r * 0.36; tm.height = r * 0.9
	tm.radial_segments = 6; tm.rings = 3
	thumb.mesh = tm
	thumb.material_override = skin_mat
	thumb.position = Vector3((r * 0.75) * (1.0 if is_right else -1.0), -total_len - r * 0.15, r * 0.30)
	pivot.add_child(thumb)

	return pivot


# ═══════════════════════════════════════════════════════════════════════════════
#  LEG — hip, thigh, knee, shin, boot with a real toe.
# ═══════════════════════════════════════════════════════════════════════════════
static func _make_detailed_leg(total_len: float, pants_mat: Material, boot_mat: Material,
		pos: Vector3, r: float = 0.135) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos

	var hip := MeshInstance3D.new()
	var hm := SphereMesh.new(); hm.radius = r * 1.25; hm.height = r * 2.4
	hm.radial_segments = 8; hm.rings = 5
	hip.mesh = hm
	hip.material_override = pants_mat
	hip.position.y = -0.02
	pivot.add_child(hip)

	var thigh := _seg(r * 1.20, r * 1.00, total_len * 0.46, pants_mat, Vector3(0, -total_len * 0.25, 0))
	pivot.add_child(thigh)

	var knee := MeshInstance3D.new()
	var km := SphereMesh.new(); km.radius = r * 1.0; km.height = r * 2.0
	km.radial_segments = 8; km.rings = 5
	knee.mesh = km
	knee.material_override = pants_mat
	knee.position.y = -total_len * 0.48
	pivot.add_child(knee)

	var shin := _seg(r * 0.98, r * 0.85, total_len * 0.36, pants_mat, Vector3(0, -total_len * 0.67, 0))
	pivot.add_child(shin)

	# Boot: chunky ankle + a toe box that gives the silhouette a real footprint.
	var boot := _seg(r * 1.05, r * 1.15, total_len * 0.20, boot_mat, Vector3(0, -total_len * 0.90, 0))
	pivot.add_child(boot)

	var toe := MeshInstance3D.new()
	var tm := BoxMesh.new(); tm.size = Vector3(r * 2.1, r * 0.75, r * 2.5)
	toe.mesh = tm
	toe.material_override = boot_mat
	toe.position = Vector3(0, -total_len + r * 0.30, r * 0.85)
	toe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(toe)

	var sole := MeshInstance3D.new()
	var sm := BoxMesh.new(); sm.size = Vector3(r * 2.25, r * 0.28, r * 3.0)
	sole.mesh = sm
	sole.material_override = _quick_mat(Color(0.11, 0.09, 0.07), 0.95)
	sole.position = Vector3(0, -total_len + r * 0.02, r * 0.55)
	pivot.add_child(sole)

	return pivot


# ═══════════════════════════════════════════════════════════════════════════════
#  KING ARCHETYPES
# ═══════════════════════════════════════════════════════════════════════════════

# 1. WARLORD — Spiky Gold Crown, Blood-Red Cape, Back Scabbard, Broadsword, Heavy build
static func create_warlord() -> Node3D:
	var rig = _make_base_rig(Color(0.29, 0.18, 0.45), Color(0.86, 0.72, 0.53), "heavy")
	rig.root.name = "Warlord"
	rig.root.add_child(_make_crown(Color(0.83, 0.69, 0.22), true))
	rig.root.add_child(_make_cape(Color(0.52, 0.08, 0.12)))
	rig.root.add_child(_make_chest_plate(Color(0.29, 0.18, 0.45)))
	rig.root.add_child(_make_back_scabbard())
	rig.right_arm.add_child(_make_sword())
	return rig.root

# 2. REGENT — Gold Laurel, Emerald Cape, Royal Scepter, Medium build
static func create_regent() -> Node3D:
	var rig = _make_base_rig(Color(0.54, 0.41, 0.16), Color(0.88, 0.74, 0.56), "medium")
	rig.root.name = "Regent"
	rig.root.add_child(_make_laurel_wreath())
	rig.root.add_child(_make_cape(Color(0.08, 0.38, 0.18)))
	rig.root.add_child(_make_royal_collar())
	rig.right_arm.add_child(_make_scepter())
	return rig.root

# 3. BEASTLORD — Horned Bone Crown, Fur Collar, Bone Spear, Heavy build
static func create_beastlord() -> Node3D:
	var rig = _make_base_rig(Color(0.24, 0.17, 0.12), Color(0.80, 0.65, 0.48), "heavy")
	rig.root.name = "Beastlord"
	rig.root.add_child(_make_horned_crown())
	rig.root.add_child(_make_fur_collar())
	rig.root.add_child(_make_animal_pelt())
	rig.root.add_child(_make_beast_skull_shoulder(1))
	rig.right_arm.add_child(_make_beast_glaive())
	return rig.root

# ═══════════════════════════════════════════════════════════════════════════════
#  QUEEN ARCHETYPES
# ═══════════════════════════════════════════════════════════════════════════════

# 4. ENGINEER — Brass Goggles, Leather Apron, Layered Dress, Heavy Wrench, Medium build
static func create_engineer() -> Node3D:
	var rig = _make_base_rig(Color(0.48, 0.28, 0.62), Color(0.86, 0.72, 0.53), "medium")
	rig.root.name = "Engineer"
	rig.root.add_child(_make_dress(Color(0.42, 0.22, 0.50), Color(0.36, 0.18, 0.44)))
	rig.root.add_child(_make_goggles())
	rig.root.add_child(_make_leather_apron())
	rig.right_arm.add_child(_make_wrench())
	return rig.root

# 5. WITCH — Pointed Hat, Layered Robe, Magic Staff with glowing orb, Slim build
static func create_witch() -> Node3D:
	var rig = _make_base_rig(Color(0.22, 0.06, 0.28), Color(0.78, 0.68, 0.58), "slim")
	rig.root.name = "Witch"
	rig.root.add_child(_make_witch_hat())
	rig.root.add_child(_make_robe(Color(0.14, 0.05, 0.18)))
	rig.right_arm.add_child(_make_magic_staff())
	return rig.root

# 6. HERBALIST — Flower Crown, Flowing Dress, Herb Satchel, Potion Flask, Slim build
static func create_herbalist() -> Node3D:
	var rig = _make_base_rig(Color(0.15, 0.32, 0.19), Color(0.88, 0.76, 0.60), "slim")
	rig.root.name = "Herbalist"
	rig.root.add_child(_make_flower_crown())
	rig.root.add_child(_make_dress(Color(0.18, 0.38, 0.23), Color(0.14, 0.30, 0.18)))
	rig.root.add_child(_make_herb_satchel())
	rig.right_arm.add_child(_make_flask())
	return rig.root

# ═══════════════════════════════════════════════════════════════════════════════
#  SOLDIER A ARCHETYPES
# ═══════════════════════════════════════════════════════════════════════════════

# 7. GUARDIAN — Full Steel Helmet, Plate Pauldrons, Tower Shield + Mace, Heavy build
static func create_guardian() -> Node3D:
	var rig = _make_base_rig(Color(0.32, 0.40, 0.28), Color(0.84, 0.70, 0.52), "heavy")
	rig.root.name = "Guardian"
	rig.root.add_child(_make_helmet())
	rig.root.add_child(_make_pauldron(-1, Color(0.35, 0.38, 0.42)))
	rig.root.add_child(_make_pauldron(1, Color(0.35, 0.38, 0.42)))
	rig.root.add_child(_make_chest_plate(Color(0.30, 0.33, 0.38)))
	rig.left_arm.add_child(_make_tower_shield())
	rig.right_arm.add_child(_make_mace())
	return rig.root

# 8. BERSERKER — Viking Horned Helmet, Spiked Shoulder Armor, Dual Axes, Heavy build
static func create_berserker() -> Node3D:
	var rig = _make_base_rig(Color(0.43, 0.11, 0.11), Color(0.82, 0.66, 0.48), "heavy")
	rig.root.name = "Berserker"
	rig.root.add_child(_make_viking_helmet())
	rig.root.add_child(_make_spiked_shoulder(-1))
	rig.root.add_child(_make_spiked_shoulder(1))
	rig.root.add_child(_make_war_paint())
	rig.root.add_child(_make_back_axe_sheaths())
	rig.left_arm.add_child(_make_axe())
	rig.right_arm.add_child(_make_axe())
	return rig.root

# 9. SAPPER — Demolition Visor, Bomb Backpack, Heavy Pickaxe, Medium build
static func create_sapper() -> Node3D:
	var rig = _make_base_rig(Color(0.35, 0.28, 0.17), Color(0.84, 0.70, 0.52), "medium")
	rig.root.name = "Sapper"
	rig.root.add_child(_make_sapper_visor())
	rig.root.add_child(_make_bomb_pack())
	rig.right_arm.add_child(_make_pickaxe())
	return rig.root

# ═══════════════════════════════════════════════════════════════════════════════
#  SOLDIER B ARCHETYPES
# ═══════════════════════════════════════════════════════════════════════════════

# 10. SCOUT — Recon Leather Hood, Cloak, Dagger, Slim build
static func create_scout() -> Node3D:
	var rig = _make_base_rig(Color(0.26, 0.28, 0.19), Color(0.82, 0.68, 0.50), "slim")
	rig.root.name = "Scout"
	rig.root.add_child(_make_scout_hood())
	rig.root.add_child(_make_cloak(Color(0.22, 0.24, 0.17)))
	rig.right_arm.add_child(_make_dagger())
	return rig.root

# 11. ARCHER — Feathered Ranger Cap, Quiver, Longbow, Slim build
static func create_archer() -> Node3D:
	var rig = _make_base_rig(Color(0.16, 0.31, 0.20), Color(0.84, 0.70, 0.52), "slim")
	rig.root.name = "Archer"
	rig.root.add_child(_make_ranger_cap())
	rig.root.add_child(_make_quiver())
	rig.root.add_child(_make_arm_guard())
	rig.right_arm.add_child(_make_longbow())
	return rig.root

# 12. BUILDER — Hard Cap, Blueprint Roll, Tool Belt, Construction Hammer, Medium build
static func create_builder() -> Node3D:
	var rig = _make_base_rig(Color(0.43, 0.35, 0.24), Color(0.84, 0.70, 0.52), "medium")
	rig.root.name = "Builder"
	rig.root.add_child(_make_builder_cap())
	rig.root.add_child(_make_blueprint_roll())
	rig.root.add_child(_make_tool_belt())
	rig.right_arm.add_child(_make_construction_hammer())
	return rig.root

# ═══════════════════════════════════════════════════════════════════════════════
#  HEADGEAR & ACCESSORIES
# ═══════════════════════════════════════════════════════════════════════════════

static func _make_crown(color: Color, spiky: bool) -> Node3D:
	var group := Node3D.new()
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = color
	cmat.metallic = 0.80
	cmat.roughness = 0.25
	# Crown band
	var band := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.30; cyl.bottom_radius = 0.33; cyl.height = 0.14
	band.mesh = cyl; band.material_override = cmat
	group.add_child(band)
	# Gem inlays on band
	var gem_mat := StandardMaterial3D.new()
	gem_mat.albedo_color = Color(0.85, 0.12, 0.18)
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(0.6, 0.08, 0.12)
	gem_mat.emission_energy_multiplier = 0.8
	for i in range(4):
		var ang = (i / 4.0) * TAU
		var gem := MeshInstance3D.new()
		var gem_m := SphereMesh.new()
		gem_m.radius = 0.03; gem_m.height = 0.04
		gem.mesh = gem_m; gem.material_override = gem_mat
		gem.position = Vector3(cos(ang) * 0.31, 0.0, sin(ang) * 0.31)
		group.add_child(gem)
	if spiky:
		for i in range(6):
			var ang = (i / 6.0) * TAU
			var spike := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0; cone.bottom_radius = 0.045; cone.height = 0.22
			spike.mesh = cone; spike.material_override = cmat
			spike.position = Vector3(cos(ang) * 0.28, 0.16, sin(ang) * 0.28)
			group.add_child(spike)
	group.position.y = 2.42
	return group

static func _make_laurel_wreath() -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.83, 0.69, 0.22)
	mat.metallic = 0.88; mat.roughness = 0.20
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.29; torus.outer_radius = 0.35
	ring.mesh = torus; ring.material_override = mat
	ring.position.y = 2.38
	group.add_child(ring)
	# Leaf details
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.18, 0.50, 0.22)
	for i in range(8):
		var ang = (i / 8.0) * TAU
		var leaf := MeshInstance3D.new()
		var leaf_m := BoxMesh.new()
		leaf_m.size = Vector3(0.06, 0.015, 0.03)
		leaf.mesh = leaf_m; leaf.material_override = leaf_mat
		leaf.position = Vector3(cos(ang) * 0.33, 2.42, sin(ang) * 0.33)
		leaf.rotation.y = ang
		group.add_child(leaf)
	return group

static func _make_horned_crown() -> Node3D:
	var group := _make_crown(Color(0.35, 0.24, 0.16), false)
	var horn_mat := StandardMaterial3D.new()
	horn_mat.albedo_color = Color(0.92, 0.88, 0.78)
	horn_mat.roughness = 0.5
	for side in [-1, 1]:
		var horn := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0; cone.bottom_radius = 0.06; cone.height = 0.40
		horn.mesh = cone; horn.material_override = horn_mat
		horn.position = Vector3(side * 0.30, 2.52, 0)
		horn.rotation.z = side * deg_to_rad(-28.0)
		group.add_child(horn)
	return group

## Cape — a curved shell that wraps the shoulders and flares out at the hem.
## The old version was four flat boxes wider than the character, which read as
## rectangular wings sticking out either side rather than cloth.
static func _make_cape(color: Color) -> Node3D:
	var group := Node3D.new()
	var gold_mat := _quick_mat(Color(0.85, 0.71, 0.26), 0.28, 0.85)

	var clasp := MeshInstance3D.new()
	var cbox := BoxMesh.new(); cbox.size = Vector3(0.46, 0.07, 0.14)
	clasp.mesh = cbox; clasp.material_override = gold_mat
	clasp.position = Vector3(0, 1.80, -0.10)
	group.add_child(clasp)

	var gem := MeshInstance3D.new()
	var gem_m := SphereMesh.new()
	gem_m.radius = 0.05; gem_m.height = 0.06
	gem_m.radial_segments = 8; gem_m.rings = 4
	gem.mesh = gem_m
	var gem_mat := StandardMaterial3D.new()
	gem_mat.albedo_color = Color(0.18, 0.58, 0.88)
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(0.18, 0.58, 0.88)
	gem_mat.emission_energy_multiplier = 1.2
	gem.material_override = gem_mat
	gem.position = Vector3(0, 1.80, -0.02)
	group.add_child(gem)

	_build_cloth_shell(group, color, 1.74, 0.62, 0.36, 0.58, 7, -0.20)
	return group


## Cloak — same wrapping shell, longer and without the clasp.
static func _make_cloak(color: Color) -> Node3D:
	var group := Node3D.new()
	_build_cloth_shell(group, color, 1.76, 0.70, 0.40, 0.62, 8, -0.18)
	return group


## Shared cloth builder. Lays a ring of narrow panels around the BACK of the
## body, each angled outward and getting wider toward the hem, so the result
## reads as fabric hanging off the shoulders and flaring at the bottom.
##   y_top       — shoulder height the cloth hangs from
##   length      — how far it falls
##   top_spread  — half-width at the shoulders
##   hem_spread  — half-width at the hem (larger = more flare)
##   panels      — horizontal resolution across the back
##   z_offset    — how far behind the spine the cloth sits
static func _build_cloth_shell(group: Node3D, color: Color, y_top: float, length: float,
		top_spread: float, hem_spread: float, panels: int, z_offset: float) -> void:
	var rows := 4
	for row in range(rows):
		var t0: float = float(row) / float(rows)
		var t1: float = float(row + 1) / float(rows)
		var y0: float = y_top - length * t0
		var y1: float = y_top - length * t1
		var spread0: float = lerp(top_spread, hem_spread, t0 * t0)
		var spread1: float = lerp(top_spread, hem_spread, t1 * t1)
		var row_mat := _quick_mat(color.darkened(t0 * 0.16), 0.78)

		for i in range(panels):
			var u: float = (float(i) + 0.5) / float(panels) - 0.5     # -0.5 .. 0.5
			# Wrap the panels around an arc so the cloth curves around the body.
			var ang: float = u * PI * 0.92
			var seg := MeshInstance3D.new()
			var sm := BoxMesh.new()
			var w: float = (spread1 * 2.0) / float(panels) * 1.25
			sm.size = Vector3(w, abs(y0 - y1) * 1.06, 0.05)
			seg.mesh = sm
			seg.material_override = row_mat
			var mid_spread: float = (spread0 + spread1) * 0.5
			seg.position = Vector3(
				sin(ang) * mid_spread,
				(y0 + y1) * 0.5,
				z_offset - cos(ang) * mid_spread * 0.45)
			seg.rotation.y = -ang
			seg.rotation.x = deg_to_rad(lerp(2.0, 10.0, t0))
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			group.add_child(seg)


static func _make_fur_collar() -> Node3D:
	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.30; torus.outer_radius = 0.52
	mesh_inst.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.40, 0.32)
	mat.roughness = 1.0
	mesh_inst.material_override = mat
	mesh_inst.position.y = 1.82
	return mesh_inst

static func _make_royal_collar() -> Node3D:
	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28; torus.outer_radius = 0.42
	mesh_inst.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.90, 0.85, 0.75)
	mat.roughness = 0.3
	mesh_inst.material_override = mat
	mesh_inst.position.y = 1.82
	return mesh_inst

static func _make_animal_pelt() -> Node3D:
	var pelt := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 0.35, 0.55)
	pelt.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.30, 0.22)
	mat.roughness = 1.0
	pelt.material_override = mat
	pelt.position = Vector3(0, 1.55, -0.02)
	return pelt

## Breastplate — a curved shell over the chest plus a gorget, instead of a
## single 0.88 x 0.55 x 0.52 cube that swallowed the whole torso.
static func _make_chest_plate(color: Color) -> Node3D:
	var group := Node3D.new()
	var plate_mat := _quick_mat(color.lightened(0.16), 0.42, 0.55)
	var trim_mat := _quick_mat(color.lightened(0.34), 0.35, 0.70)

	# Chest shell — angled slats riding on the OUTSIDE of the ribcage. Sitting
	# them inside the torso radius made the armour disappear into the body and
	# the character read as one rounded block.
	for i in range(5):
		var u: float = (float(i) - 2.0) / 2.0        # -1 .. 1
		var ang: float = u * deg_to_rad(46.0)
		var slat := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.19, 0.38, 0.06)
		slat.mesh = sm
		slat.material_override = plate_mat
		slat.position = Vector3(sin(ang) * 0.34, 1.52, 0.10 + cos(ang) * 0.24)
		slat.rotation.y = -ang
		slat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(slat)

	# Gorget collar
	for i in range(6):
		var a2: float = (float(i) - 2.5) / 2.5 * deg_to_rad(70.0)
		var ring := MeshInstance3D.new()
		var rm := BoxMesh.new(); rm.size = Vector3(0.16, 0.09, 0.06)
		ring.mesh = rm
		ring.material_override = trim_mat
		ring.position = Vector3(sin(a2) * 0.33, 1.78, 0.06 + cos(a2) * 0.20)
		ring.rotation.y = -a2
		group.add_child(ring)

	# Centre boss
	var boss := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.09; bm.height = 0.11
	bm.radial_segments = 8; bm.rings = 4
	boss.mesh = bm
	boss.material_override = trim_mat
	boss.position = Vector3(0, 1.54, 0.37)
	group.add_child(boss)

	return group


static func _make_leather_apron() -> Node3D:
	var apron := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.72, 0.65, 0.06)
	apron.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.22, 0.14)
	mat.roughness = 0.9
	apron.material_override = mat
	apron.position = Vector3(0, 1.10, 0.26)
	return apron

static func _make_herb_satchel() -> Node3D:
	var satchel := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.28, 0.22, 0.18)
	satchel.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.24, 0.16)
	mat.roughness = 0.85
	satchel.material_override = mat
	satchel.position = Vector3(-0.45, 0.92, 0.10)
	return satchel

static func _make_skirt(_color: Color) -> Node3D:
	# Deprecated — use _make_dress() instead
	return _make_dress(_color, _color.darkened(0.1))

# Premium layered dress: hip-band + flared mid-section + flowing hem
static func _make_dress(color: Color, accent_color: Color) -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.70
	# Hip band (snug fit at waist)
	var hip := MeshInstance3D.new()
	var hip_m := CylinderMesh.new()
	hip_m.top_radius = 0.38; hip_m.bottom_radius = 0.42; hip_m.height = 0.22
	hip.mesh = hip_m; hip.material_override = mat
	hip.position.y = 0.78
	hip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(hip)
	# Mid-skirt (flared)
	var mid := MeshInstance3D.new()
	var mid_m := CylinderMesh.new()
	mid_m.top_radius = 0.42; mid_m.bottom_radius = 0.52; mid_m.height = 0.30
	mid.mesh = mid_m; mid.material_override = mat
	mid.position.y = 0.52
	mid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(mid)
	# Hem (wide, flowing bottom)
	var hem := MeshInstance3D.new()
	var hem_m := CylinderMesh.new()
	hem_m.top_radius = 0.52; hem_m.bottom_radius = 0.58; hem_m.height = 0.18
	hem.mesh = hem_m
	var hem_mat := StandardMaterial3D.new()
	hem_mat.albedo_color = accent_color
	hem_mat.roughness = 0.70
	hem.material_override = hem_mat
	hem.position.y = 0.28
	hem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(hem)
	# Waist sash / ribbon
	var sash := MeshInstance3D.new()
	var sash_m := BoxMesh.new()
	sash_m.size = Vector3(0.86, 0.06, 0.44)
	sash.mesh = sash_m
	var sash_mat := StandardMaterial3D.new()
	sash_mat.albedo_color = accent_color.lightened(0.15)
	sash.material_override = sash_mat
	sash.position.y = 0.88
	group.add_child(sash)
	return group

# Full-body robe for Witch — wraps around front and back
static func _make_robe(color: Color) -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.80
	# Upper robe (torso wrap)
	var upper := MeshInstance3D.new()
	var upper_m := CylinderMesh.new()
	upper_m.top_radius = 0.42; upper_m.bottom_radius = 0.44; upper_m.height = 0.50
	upper.mesh = upper_m; upper.material_override = mat
	upper.position.y = 1.12
	upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(upper)
	# Lower robe (flowing)
	var lower := MeshInstance3D.new()
	var lower_m := CylinderMesh.new()
	lower_m.top_radius = 0.44; lower_m.bottom_radius = 0.55; lower_m.height = 0.65
	lower.mesh = lower_m
	var lower_mat := StandardMaterial3D.new()
	lower_mat.albedo_color = color.darkened(0.08)
	lower_mat.roughness = 0.80
	lower.material_override = lower_mat
	lower.position.y = 0.52
	lower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(lower)
	# Hem trim
	var trim := MeshInstance3D.new()
	var trim_m := CylinderMesh.new()
	trim_m.top_radius = 0.55; trim_m.bottom_radius = 0.56; trim_m.height = 0.06
	trim.mesh = trim_m
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.50, 0.20, 0.55)
	trim.material_override = trim_mat
	trim.position.y = 0.22
	group.add_child(trim)
	return group

static func _make_goggles() -> Node3D:
	var group := Node3D.new()
	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.72, 0.53, 0.04)
	brass_mat.metallic = 0.82; brass_mat.roughness = 0.30
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.4, 0.7, 0.9, 0.6)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for side in [-1, 1]:
		# Brass frame ring
		var frame := MeshInstance3D.new()
		var frame_m := TorusMesh.new()
		frame_m.inner_radius = 0.065; frame_m.outer_radius = 0.10
		frame.mesh = frame_m; frame.material_override = brass_mat
		frame.position = Vector3(side * 0.14, 2.28, 0.30)
		frame.rotation.x = deg_to_rad(90.0)
		group.add_child(frame)
		# Glass lens
		var lens := MeshInstance3D.new()
		var lens_m := CylinderMesh.new()
		lens_m.top_radius = 0.065; lens_m.bottom_radius = 0.065; lens_m.height = 0.02
		lens.mesh = lens_m; lens.material_override = glass_mat
		lens.position = Vector3(side * 0.14, 2.28, 0.32)
		lens.rotation.x = deg_to_rad(90.0)
		group.add_child(lens)
	# Strap
	var strap := MeshInstance3D.new()
	var strap_m := BoxMesh.new()
	strap_m.size = Vector3(0.06, 0.03, 0.70)
	strap.mesh = strap_m; strap.material_override = brass_mat
	strap.position = Vector3(0, 2.32, 0.0)
	group.add_child(strap)
	return group

static func _make_witch_hat() -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.04, 0.14)
	# Wide brim
	var brim := MeshInstance3D.new()
	var brim_m := CylinderMesh.new()
	brim_m.top_radius = 0.55; brim_m.bottom_radius = 0.58; brim_m.height = 0.04
	brim.mesh = brim_m; brim.material_override = mat
	brim.position.y = 2.40
	group.add_child(brim)
	# Tall cone
	var cone := MeshInstance3D.new()
	var cone_m := CylinderMesh.new()
	cone_m.top_radius = 0.0; cone_m.bottom_radius = 0.28; cone_m.height = 0.72
	cone.mesh = cone_m; cone.material_override = mat
	cone.position.y = 2.74
	cone.rotation.z = deg_to_rad(8.0) # Slight tilt
	group.add_child(cone)
	# Hat band
	var band := MeshInstance3D.new()
	var band_m := CylinderMesh.new()
	band_m.top_radius = 0.30; band_m.bottom_radius = 0.30; band_m.height = 0.05
	band.mesh = band_m
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.50, 0.20, 0.55)
	band.material_override = band_mat
	band.position.y = 2.46
	group.add_child(band)
	return group

static func _make_flower_crown() -> Node3D:
	var group := Node3D.new()
	var vine_mat := StandardMaterial3D.new()
	vine_mat.albedo_color = Color(0.18, 0.55, 0.22)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.30; torus.outer_radius = 0.35
	ring.mesh = torus; ring.material_override = vine_mat
	ring.position.y = 2.38
	group.add_child(ring)
	# Colorful flowers
	var flower_colors = [Color(0.90, 0.25, 0.30), Color(0.95, 0.75, 0.20), Color(0.85, 0.40, 0.70), Color(0.50, 0.30, 0.85), Color(0.95, 0.55, 0.25)]
	for i in range(flower_colors.size()):
		var ang = (i / float(flower_colors.size())) * TAU
		var flower := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.05; fm.height = 0.06
		flower.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = flower_colors[i]
		flower.material_override = fmat
		flower.position = Vector3(cos(ang) * 0.33, 2.42, sin(ang) * 0.33)
		group.add_child(flower)
	return group

static func _make_helmet() -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.38, 0.42)
	mat.metallic = 0.75; mat.roughness = 0.35
	# Dome
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.38; sphere.height = 0.48
	dome.mesh = sphere; dome.material_override = mat
	dome.position.y = 2.22
	group.add_child(dome)
	# Nose guard
	var guard := MeshInstance3D.new()
	var guard_m := BoxMesh.new()
	guard_m.size = Vector3(0.04, 0.22, 0.06)
	guard.mesh = guard_m; guard.material_override = mat
	guard.position = Vector3(0, 2.12, 0.35)
	group.add_child(guard)
	# Cheek plates
	for side in [-1, 1]:
		var cheek := MeshInstance3D.new()
		var cheek_m := BoxMesh.new()
		cheek_m.size = Vector3(0.06, 0.18, 0.14)
		cheek.mesh = cheek_m; cheek.material_override = mat
		cheek.position = Vector3(side * 0.34, 2.08, 0.12)
		group.add_child(cheek)
	return group

static func _make_viking_helmet() -> Node3D:
	var group := _make_helmet()
	var horn_mat := StandardMaterial3D.new()
	horn_mat.albedo_color = Color(0.92, 0.88, 0.78)
	horn_mat.roughness = 0.5
	for side in [-1, 1]:
		var horn := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0; cone.bottom_radius = 0.055; cone.height = 0.35
		horn.mesh = cone; horn.material_override = horn_mat
		horn.position = Vector3(side * 0.36, 2.38, 0)
		horn.rotation.z = side * deg_to_rad(-35.0)
		group.add_child(horn)
	return group

static func _make_sapper_visor() -> Node3D:
	var group := _make_helmet()
	var visor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.50, 0.14, 0.08)
	visor.mesh = box
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.88, 0.48, 0.12)
	vmat.emission_enabled = true
	vmat.emission = Color(0.88, 0.48, 0.12)
	vmat.emission_energy_multiplier = 0.4
	visor.material_override = vmat
	visor.position = Vector3(0, 2.15, 0.34)
	group.add_child(visor)
	return group

static func _make_bomb_pack() -> Node3D:
	var group := Node3D.new()
	# Main pack
	var pack := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.60, 0.30)
	pack.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.18)
	pack.material_override = mat
	pack.position = Vector3(0, 1.38, -0.34)
	group.add_child(pack)
	# Bomb spheres sticking out
	var bomb_mat := StandardMaterial3D.new()
	bomb_mat.albedo_color = Color(0.12, 0.12, 0.12)
	for i in range(3):
		var bomb := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.08; bm.height = 0.16
		bomb.mesh = bm; bomb.material_override = bomb_mat
		bomb.position = Vector3(-0.15 + i * 0.15, 1.72, -0.40)
		group.add_child(bomb)
		# Fuse
		var fuse := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = 0.008; fm.bottom_radius = 0.008; fm.height = 0.10
		fuse.mesh = fm
		var fuse_mat := StandardMaterial3D.new()
		fuse_mat.albedo_color = Color(0.8, 0.6, 0.2)
		fuse.material_override = fuse_mat
		fuse.position = Vector3(-0.15 + i * 0.15, 1.82, -0.40)
		group.add_child(fuse)
	return group

static func _make_spiked_shoulder(side: int) -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.08, 0.08)
	mat.metallic = 0.6
	var pad := MeshInstance3D.new()
	var pad_m := SphereMesh.new()
	pad_m.radius = 0.22; pad_m.height = 0.22
	pad.mesh = pad_m; pad.material_override = mat
	pad.position = Vector3(side * 0.58, 1.82, 0)
	group.add_child(pad)
	# Spikes
	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color = Color(0.75, 0.78, 0.82)
	spike_mat.metallic = 0.85
	for i in range(3):
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0; sm.bottom_radius = 0.025; sm.height = 0.14
		spike.mesh = sm; spike.material_override = spike_mat
		var ang = (i / 3.0) * PI - PI / 2.0
		spike.position = Vector3(side * (0.58 + cos(ang) * 0.15), 1.82 + sin(ang) * 0.12, 0)
		spike.rotation.z = side * deg_to_rad(-60.0 + i * 30.0)
		group.add_child(spike)
	return group

static func _make_war_paint() -> Node3D:
	var group := Node3D.new()
	var paint_mat := StandardMaterial3D.new()
	paint_mat.albedo_color = Color(0.60, 0.08, 0.08)
	# Two war paint stripes across face
	for i in range(2):
		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.30, 0.03, 0.015)
		stripe.mesh = sm; stripe.material_override = paint_mat
		stripe.position = Vector3(0, 2.12 + i * 0.08, 0.36)
		group.add_child(stripe)
	return group

static func _make_scout_hood() -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.24, 0.18)
	mat.roughness = 0.85
	# Hood dome
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.40; dm.height = 0.50
	dome.mesh = dm; dome.material_override = mat
	dome.position.y = 2.22
	group.add_child(dome)
	# Hood drape behind head
	var drape := MeshInstance3D.new()
	var drape_m := BoxMesh.new()
	drape_m.size = Vector3(0.35, 0.30, 0.06)
	drape.mesh = drape_m; drape.material_override = mat
	drape.position = Vector3(0, 2.0, -0.30)
	group.add_child(drape)
	return group

static func _make_ranger_cap() -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.28, 0.18)
	# Cap body
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0; cm.bottom_radius = 0.38; cm.height = 0.30
	cap.mesh = cm; cap.material_override = mat
	cap.position.y = 2.44
	group.add_child(cap)
	# Feather
	var feather := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.03, 0.22, 0.06)
	feather.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.85, 0.25, 0.15)
	feather.material_override = fmat
	feather.position = Vector3(0.28, 2.52, -0.05)
	feather.rotation.z = deg_to_rad(-15.0)
	group.add_child(feather)
	return group

static func _make_quiver() -> Node3D:
	var group := Node3D.new()
	# Quiver tube
	var tube := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09; cyl.bottom_radius = 0.08; cyl.height = 0.65
	tube.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.24, 0.16)
	tube.material_override = mat
	tube.position = Vector3(0.22, 1.50, -0.28)
	tube.rotation.z = deg_to_rad(-18.0)
	group.add_child(tube)
	# Arrow tips poking out
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.albedo_color = Color(0.8, 0.78, 0.7)
	arrow_mat.metallic = 0.6
	for i in range(4):
		var tip := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.0; tm.bottom_radius = 0.015; tm.height = 0.08
		tip.mesh = tm; tip.material_override = arrow_mat
		tip.position = Vector3(0.18 + i * 0.03, 1.88, -0.28)
		group.add_child(tip)
	return group

static func _make_arm_guard() -> Node3D:
	var guard := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.18, 0.14)
	guard.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.20, 0.14)
	mat.roughness = 0.8
	guard.material_override = mat
	guard.position = Vector3(-0.50, 1.28, 0.06)
	return guard

static func _make_builder_cap() -> Node3D:
	var group := Node3D.new()
	# Hard hat dome
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.38; dm.height = 0.34
	dome.mesh = dm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.68, 0.15)
	mat.roughness = 0.5
	dome.material_override = mat
	dome.position.y = 2.32
	group.add_child(dome)
	# Brim
	var brim := MeshInstance3D.new()
	var brim_m := CylinderMesh.new()
	brim_m.top_radius = 0.42; brim_m.bottom_radius = 0.42; brim_m.height = 0.03
	brim.mesh = brim_m; brim.material_override = mat
	brim.position.y = 2.22
	group.add_child(brim)
	return group

static func _make_tool_belt() -> Node3D:
	var group := Node3D.new()
	# Small tools hanging from belt
	var tool_mat := StandardMaterial3D.new()
	tool_mat.albedo_color = Color(0.3, 0.32, 0.35)
	tool_mat.metallic = 0.7
	for i in range(3):
		var tool := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.04, 0.14, 0.03)
		tool.mesh = tm; tool.material_override = tool_mat
		tool.position = Vector3(-0.25 + i * 0.20, 0.78, 0.25)
		group.add_child(tool)
	return group

static func _make_blueprint_roll() -> Node3D:
	var group := Node3D.new()
	var tube := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06; cyl.bottom_radius = 0.06; cyl.height = 0.70
	tube.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.88, 0.78) # Parchment
	tube.material_override = mat
	tube.position = Vector3(-0.22, 1.42, -0.30)
	tube.rotation.z = deg_to_rad(28.0)
	group.add_child(tube)
	# Blue cap ends
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.15, 0.35, 0.75)
	for y_off in [-0.35, 0.35]:
		var cap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07; cm.bottom_radius = 0.07; cm.height = 0.04
		cap.mesh = cm; cap.material_override = cap_mat
		cap.position = Vector3(-0.22, 1.42 + y_off * 0.8, -0.30)
		cap.rotation.z = deg_to_rad(28.0)
		group.add_child(cap)
	return group

static func _make_pauldron(side: float, color: Color) -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.60; mat.roughness = 0.40
	# Main shoulder dome
	var pad := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.22; pm.height = 0.22
	pad.mesh = pm; pad.material_override = mat
	pad.position = Vector3(side * 0.58, 1.82, 0)
	group.add_child(pad)
	# Rivet details
	var rivet_mat := StandardMaterial3D.new()
	rivet_mat.albedo_color = Color(0.83, 0.69, 0.22)
	rivet_mat.metallic = 0.9
	for i in range(3):
		var rivet := MeshInstance3D.new()
		var rm := SphereMesh.new()
		rm.radius = 0.02; rm.height = 0.03
		rivet.mesh = rm; rivet.material_override = rivet_mat
		var ang = (i / 3.0) * PI
		rivet.position = Vector3(side * (0.58 + cos(ang) * 0.16), 1.82 + sin(ang) * 0.10, 0.08)
		group.add_child(rivet)
	return group

# ═══════════════════════════════════════════════════════════════════════════════
#  WEAPONS
# ═══════════════════════════════════════════════════════════════════════════════

static func _make_sword() -> Node3D:
	var group := Node3D.new()
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.88, 0.90, 0.92)
	blade_mat.metallic = 0.88; blade_mat.roughness = 0.20
	# Blade
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.10, 0.72, 0.055)
	blade.mesh = bm; blade.material_override = blade_mat
	blade.position.y = -0.44
	group.add_child(blade)
	# Crossguard
	var guard := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.22, 0.04, 0.04)
	guard.mesh = gm
	var guard_mat := StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.83, 0.69, 0.22)
	guard_mat.metallic = 0.85
	guard.material_override = guard_mat
	guard.position.y = -0.06
	group.add_child(guard)
	# Handle wrap
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.025; hm.bottom_radius = 0.025; hm.height = 0.16
	handle.mesh = hm
	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.28, 0.18, 0.12)
	handle.material_override = handle_mat
	handle.position.y = 0.06
	group.add_child(handle)
	# Pommel
	var pommel := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.03; pm.height = 0.06
	pommel.mesh = pm; pommel.material_override = guard_mat
	pommel.position.y = 0.16
	group.add_child(pommel)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

static func _make_scepter() -> Node3D:
	var group := Node3D.new()
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.83, 0.69, 0.22)
	smat.metallic = 0.88; smat.roughness = 0.20
	var staff := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03; cyl.bottom_radius = 0.035; cyl.height = 0.82
	staff.mesh = cyl; staff.material_override = smat
	staff.position.y = -0.42
	group.add_child(staff)
	# Crown top
	var crown := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06; cm.bottom_radius = 0.08; cm.height = 0.08
	crown.mesh = cm; crown.material_override = smat
	crown.position.y = 0.02
	group.add_child(crown)
	# Emerald orb
	var orb := MeshInstance3D.new()
	var om := SphereMesh.new()
	om.radius = 0.10; om.height = 0.20
	orb.mesh = om
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Color(0.08, 0.65, 0.40)
	omat.emission_enabled = true
	omat.emission = Color(0.08, 0.65, 0.40)
	omat.emission_energy_multiplier = 1.5
	orb.material_override = omat
	orb.position.y = 0.12
	group.add_child(orb)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

## Beastlord signature weapon: a bone-hafted glaive crowned with a curved fang
## blade, claw hooks and a fur-wrapped grip. Reads as feral, not a plain spear.
static func _make_beast_glaive() -> Node3D:
	var group := Node3D.new()
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.90, 0.86, 0.74); bone.roughness = 0.5
	var dark_bone := StandardMaterial3D.new()
	dark_bone.albedo_color = Color(0.66, 0.60, 0.48); dark_bone.roughness = 0.55
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.30, 0.20, 0.13); fur.roughness = 0.95

	# Haft — a slightly tapered bone shaft.
	var haft := MeshInstance3D.new()
	var hc := CylinderMesh.new(); hc.top_radius = 0.028; hc.bottom_radius = 0.034; hc.height = 1.55
	haft.mesh = hc; haft.material_override = dark_bone; haft.position.y = -0.60
	group.add_child(haft)

	# Curved fang blade at the head — two angled bone prisms forming a hook.
	for i in range(2):
		var fang := MeshInstance3D.new()
		var fc := CylinderMesh.new(); fc.top_radius = 0.0; fc.bottom_radius = 0.07; fc.height = 0.42
		fang.mesh = fc; fang.material_override = bone
		fang.position = Vector3(0.03 * (1 if i == 0 else -1), 0.34, 0)
		fang.rotation = Vector3(0, 0, deg_to_rad(18.0 * (1 if i == 0 else -1)))
		group.add_child(fang)
	# Claw hooks jutting sideways below the blade.
	for s in [-1, 1]:
		var claw := MeshInstance3D.new()
		var cc := CylinderMesh.new(); cc.top_radius = 0.0; cc.bottom_radius = 0.03; cc.height = 0.16
		claw.mesh = cc; claw.material_override = bone
		claw.position = Vector3(0.07 * s, 0.14, 0)
		claw.rotation = Vector3(0, 0, deg_to_rad(70.0 * s))
		group.add_child(claw)
	# Fur binding just under the blade.
	for i in range(3):
		var wrap := MeshInstance3D.new()
		var wm := CylinderMesh.new(); wm.top_radius = 0.05; wm.bottom_radius = 0.05; wm.height = 0.06
		wrap.mesh = wm; wrap.material_override = fur
		wrap.position.y = 0.02 - i * 0.06
		group.add_child(wrap)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

## Beast-skull shoulder guard — a fanged animal skull worn as a pauldron.
static func _make_beast_skull_shoulder(side: int) -> Node3D:
	var group := Node3D.new()
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.88, 0.83, 0.70); bone.roughness = 0.5
	var skull := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.16; sm.height = 0.26
	skull.mesh = sm; skull.material_override = bone
	group.add_child(skull)
	# Snout.
	var snout := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.12, 0.10, 0.16)
	snout.mesh = bm; snout.material_override = bone
	snout.position = Vector3(0, -0.03, 0.14)
	group.add_child(snout)
	# Eye sockets (dark).
	var socket_mat := StandardMaterial3D.new(); socket_mat.albedo_color = Color(0.08, 0.06, 0.05)
	for s in [-1, 1]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new(); em.radius = 0.035; em.height = 0.05
		eye.mesh = em; eye.material_override = socket_mat
		eye.position = Vector3(0.06 * s, 0.02, 0.14)
		group.add_child(eye)
	# Horns curving up off the skull.
	for s in [-1, 1]:
		var horn := MeshInstance3D.new()
		var hm := CylinderMesh.new(); hm.top_radius = 0.0; hm.bottom_radius = 0.035; hm.height = 0.22
		horn.mesh = hm; horn.material_override = bone
		horn.position = Vector3(0.08 * s, 0.12, -0.02)
		horn.rotation = Vector3(deg_to_rad(-20), 0, deg_to_rad(24 * s))
		group.add_child(horn)
	group.position = Vector3(0.42 * side, 1.62, 0)
	group.scale = Vector3.ONE * 0.95
	return group

static func _make_spear() -> Node3D:
	var group := Node3D.new()
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025; cyl.bottom_radius = 0.028; cyl.height = 1.50
	pole.mesh = cyl
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.35, 0.24, 0.16)
	pole.material_override = pmat
	pole.position.y = -0.65
	group.add_child(pole)
	# Bone spear tip
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0; cone.bottom_radius = 0.055; cone.height = 0.28
	tip.mesh = cone
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.92, 0.88, 0.78)
	tmat.roughness = 0.5
	tip.material_override = tmat
	tip.position.y = 0.22
	group.add_child(tip)
	# Binding wraps
	var wrap_mat := StandardMaterial3D.new()
	wrap_mat.albedo_color = Color(0.28, 0.20, 0.14)
	for i in range(3):
		var wrap := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.040; wm.bottom_radius = 0.040; wm.height = 0.055
		wrap.mesh = wm; wrap.material_override = wrap_mat
		wrap.position.y = 0.05 - i * 0.06
		group.add_child(wrap)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

static func _make_wrench() -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.53, 0.04)
	mat.metallic = 0.82; mat.roughness = 0.30
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 0.62, 0.04)
	body.mesh = bm; body.material_override = mat
	body.position.y = -0.32
	group.add_child(body)
	# Wrench jaw
	var jaw := MeshInstance3D.new()
	var jm := BoxMesh.new()
	jm.size = Vector3(0.18, 0.10, 0.04)
	jaw.mesh = jm; jaw.material_override = mat
	jaw.position.y = -0.62
	group.add_child(jaw)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

static func _make_magic_staff() -> Node3D:
	var group := Node3D.new()
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03; cyl.bottom_radius = 0.035; cyl.height = 1.35
	pole.mesh = cyl
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.16, 0.10, 0.20)
	pole.material_override = pmat
	pole.position.y = -0.58
	group.add_child(pole)
	# Glowing orb
	var orb := MeshInstance3D.new()
	var om := SphereMesh.new()
	om.radius = 0.12; om.height = 0.24
	orb.mesh = om
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Color(0.68, 0.15, 0.80)
	omat.emission_enabled = true
	omat.emission = Color(0.68, 0.15, 0.80)
	omat.emission_energy_multiplier = 2.5
	orb.material_override = omat
	orb.position.y = 0.18
	group.add_child(orb)
	# Glow halo ring
	var halo := MeshInstance3D.new()
	var hm := TorusMesh.new()
	hm.inner_radius = 0.14; hm.outer_radius = 0.18
	halo.mesh = hm
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.68, 0.15, 0.80, 0.35)
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.emission_enabled = true
	hmat.emission = Color(0.68, 0.15, 0.80)
	halo.material_override = hmat
	halo.position.y = 0.18
	group.add_child(halo)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

static func _make_flask() -> Node3D:
	var group := Node3D.new()
	# Flask body
	var flask := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12; sm.height = 0.25
	flask.mesh = sm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.12, 0.78, 0.38)
	fmat.emission_enabled = true
	fmat.emission = Color(0.12, 0.78, 0.38)
	fmat.emission_energy_multiplier = 1.2
	flask.material_override = fmat
	flask.position.y = -0.22
	group.add_child(flask)
	# Flask neck
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.03; nm.bottom_radius = 0.04; nm.height = 0.08
	neck.mesh = nm; neck.material_override = fmat
	neck.position.y = -0.08
	group.add_child(neck)
	# Cork
	var cork := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025; cm.bottom_radius = 0.03; cm.height = 0.04
	cork.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.55, 0.38, 0.20)
	cork.material_override = cmat
	cork.position.y = -0.04
	group.add_child(cork)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

static func _make_tower_shield() -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.28, 0.34)
	mat.metallic = 0.78; mat.roughness = 0.35
	var shield := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.55, 0.95, 0.08)
	shield.mesh = sm; shield.material_override = mat
	shield.position = Vector3(0, -0.22, 0.22)
	group.add_child(shield)
	# Shield emblem (cross)
	var emblem_mat := StandardMaterial3D.new()
	emblem_mat.albedo_color = Color(0.83, 0.69, 0.22)
	emblem_mat.metallic = 0.85
	var h_bar := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.30, 0.065, 0.05)
	h_bar.mesh = hm; h_bar.material_override = emblem_mat
	h_bar.position = Vector3(0, -0.22, 0.27)
	group.add_child(h_bar)
	var v_bar := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.065, 0.40, 0.05)
	v_bar.mesh = vm; v_bar.material_override = emblem_mat
	v_bar.position = Vector3(0, -0.22, 0.27)
	group.add_child(v_bar)
	# Shield border
	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color = Color(0.60, 0.52, 0.38)
	border_mat.metallic = 0.7
	var top_edge := MeshInstance3D.new()
	var tem := BoxMesh.new()
	tem.size = Vector3(0.58, 0.04, 0.10)
	top_edge.mesh = tem; top_edge.material_override = border_mat
	top_edge.position = Vector3(0, 0.26, 0.22)
	group.add_child(top_edge)
	return group

static func _make_mace() -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.38, 0.42)
	mat.metallic = 0.82; mat.roughness = 0.30
	# Handle
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.03; hm.bottom_radius = 0.025; hm.height = 0.65
	handle.mesh = hm
	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.28, 0.18, 0.12)
	handle.material_override = handle_mat
	handle.position.y = -0.32
	group.add_child(handle)
	# Flanged head
	var head := MeshInstance3D.new()
	var head_m := SphereMesh.new()
	head_m.radius = 0.12; head_m.height = 0.20; head_m.radial_segments = 6
	head.mesh = head_m; head.material_override = mat
	head.position.y = 0.04
	group.add_child(head)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

static func _make_axe() -> Node3D:
	var group := Node3D.new()
	# Handle
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.025; hm.bottom_radius = 0.022; hm.height = 0.62
	handle.mesh = hm
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.35, 0.24, 0.16)
	handle.material_override = hmat
	handle.position.y = -0.32
	group.add_child(handle)
	# Axe blade
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.30, 0.065)
	blade.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.78, 0.80, 0.84)
	bmat.metallic = 0.88; bmat.roughness = 0.25
	blade.material_override = bmat
	blade.position = Vector3(0.12, 0.0, 0)
	group.add_child(blade)
	# Blade edge highlight
	var edge := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(0.05, 0.28, 0.075)
	edge.mesh = em
	var emat := StandardMaterial3D.new()
	emat.albedo_color = Color(0.95, 0.95, 0.98)
	emat.metallic = 0.95
	edge.material_override = emat
	edge.position = Vector3(0.26, 0.0, 0)
	group.add_child(edge)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

static func _make_pickaxe() -> Node3D:
	var group := Node3D.new()
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.025; hm.bottom_radius = 0.025; hm.height = 0.72
	handle.mesh = hm
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.35, 0.24, 0.16)
	handle.material_override = hmat
	handle.position.y = -0.36
	group.add_child(handle)
	# Pick head
	var head := MeshInstance3D.new()
	var head_m := BoxMesh.new()
	head_m.size = Vector3(0.48, 0.08, 0.05)
	head.mesh = head_m
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.42, 0.44, 0.48)
	bmat.metallic = 0.82
	head.material_override = bmat
	head.position.y = 0.0
	group.add_child(head)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

static func _make_dagger() -> Node3D:
	var group := Node3D.new()
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.38, 0.055)
	blade.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.88, 0.90, 0.92)
	bmat.metallic = 0.88
	blade.material_override = bmat
	blade.position.y = -0.22
	group.add_child(blade)
	# Guard
	var guard := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.13, 0.055, 0.06)
	guard.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.28, 0.20, 0.14)
	guard.material_override = gmat
	guard.position.y = -0.02
	group.add_child(guard)
	# Handle
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.022; hm.bottom_radius = 0.020; hm.height = 0.10
	handle.mesh = hm; handle.material_override = gmat
	handle.position.y = 0.06
	group.add_child(handle)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

static func _make_longbow() -> Node3D:
	var group := Node3D.new()
	var bow_mat := StandardMaterial3D.new()
	bow_mat.albedo_color = Color(0.32, 0.22, 0.14)
	bow_mat.roughness = 0.7
	# Bow arc
	var bow := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.375; torus.outer_radius = 0.465
	bow.mesh = torus; bow.material_override = bow_mat
	bow.position.y = -0.22
	bow.rotation.z = deg_to_rad(90.0)
	group.add_child(bow)
	# Bowstring
	var string := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.025; sm.bottom_radius = 0.025; sm.height = 0.80
	string.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.70, 0.66, 0.56)
	string.material_override = smat
	# The torus is rotated 90 degrees about Z, so its ring lies in the YZ plane
	# and its AXIS runs along X. The string was offset 0.38 along X, which is
	# along that axis — it floated beside the character instead of crossing the
	# bow. It belongs on a diameter of the ring: same centre, running vertically.
	string.position = Vector3(0, -0.22, 0)
	group.add_child(string)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

static func _make_construction_hammer() -> Node3D:
	var group := Node3D.new()
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.025; hm.bottom_radius = 0.025; hm.height = 0.52
	handle.mesh = hm
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.35, 0.24, 0.16)
	handle.material_override = hmat
	handle.position.y = -0.26
	group.add_child(handle)
	# Hammer head
	var head := MeshInstance3D.new()
	var head_m := BoxMesh.new()
	head_m.size = Vector3(0.22, 0.14, 0.12)
	head.mesh = head_m
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.28, 0.30, 0.34)
	bmat.metallic = 0.78
	head.material_override = bmat
	head.position.y = 0.0
	group.add_child(head)
	group.position = Vector3(0.02, -0.10, 0.05)
	return group

static func _make_back_scabbard() -> Node3D:
	var group := Node3D.new()
	group.name = "BackScabbard"

	var leather_mat := StandardMaterial3D.new()
	leather_mat.albedo_color = Color(0.28, 0.18, 0.12)
	leather_mat.roughness = 0.85

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.83, 0.69, 0.22)
	gold_mat.metallic = 0.85

	var scabbard := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.08, 0.95, 0.04)
	scabbard.mesh = sm
	scabbard.material_override = leather_mat
	scabbard.position = Vector3(0.12, 1.45, -0.26)
	scabbard.rotation.z = deg_to_rad(-35.0)
	group.add_child(scabbard)

	var top_trim := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.10, 0.08, 0.05)
	top_trim.mesh = tm
	top_trim.material_override = gold_mat
	top_trim.position = Vector3(0.38, 1.82, -0.26)
	top_trim.rotation.z = deg_to_rad(-35.0)
	group.add_child(top_trim)

	return group

static func _make_back_axe_sheaths() -> Node3D:
	var group := Node3D.new()
	group.name = "BackAxeSheaths"

	var leather_mat := StandardMaterial3D.new()
	leather_mat.albedo_color = Color(0.25, 0.16, 0.11)
	leather_mat.roughness = 0.90

	for side in [-1, 1]:
		var sheath := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.06, 0.65, 0.04)
		sheath.mesh = sm
		sheath.material_override = leather_mat
		sheath.position = Vector3(side * 0.18, 1.40, -0.26)
		sheath.rotation.z = side * deg_to_rad(30.0)
		group.add_child(sheath)

	return group

