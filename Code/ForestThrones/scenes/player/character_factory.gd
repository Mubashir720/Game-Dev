extends RefCounted

static func create_character_by_archetype(archetype_id: String) -> Node3D:
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
		_:          return create_warlord()

static func create_character(role: Constants.Role) -> Node3D:
	match role:
		Constants.Role.KING:      return create_warlord()
		Constants.Role.QUEEN:     return create_engineer()
		Constants.Role.SOLDIER_A: return create_guardian()
		Constants.Role.SOLDIER_B: return create_scout()
	return create_warlord()

# ═══════════════════════════════════════════════════════════════════════════════
#  PREMIUM BASE RIG — Detailed multi-part character body
# ═══════════════════════════════════════════════════════════════════════════════
static func _make_base_rig(tunic_color: Color, skin_color: Color = Color(0.86, 0.72, 0.53), build: String = "medium") -> Dictionary:
	var group := Node3D.new()
	
	# --- PBR Materials ---
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tunic_color
	mat.roughness = 0.72
	
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = skin_color
	skin_mat.roughness = 0.55
	
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.12, 0.12, 0.14)
	dark_mat.roughness = 0.80
	
	var boot_mat := StandardMaterial3D.new()
	boot_mat.albedo_color = Color(0.22, 0.16, 0.12)
	boot_mat.roughness = 0.85
	
	# --- Build Proportions ---
	var torso_w := 0.85; var torso_h := 0.95; var torso_d := 0.48
	var shoulder_w := 0.0; var leg_len := 0.85; var arm_len := 0.72
	match build:
		"heavy":
			torso_w = 1.0; torso_h = 1.0; torso_d = 0.55; shoulder_w = 0.10
			leg_len = 0.90; arm_len = 0.78
		"slim":
			torso_w = 0.72; torso_h = 0.90; torso_d = 0.40
			leg_len = 0.82; arm_len = 0.68
	
	# ─── TORSO (Tapered box — wider at shoulders) ─────────────────────────────
	var torso := MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(torso_w, torso_h, torso_d)
	torso.mesh = torso_mesh
	torso.material_override = mat
	torso.position.y = 1.32
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(torso)
	
	# ─── BELT ─────────────────────────────────────────────────────────────────
	var belt := MeshInstance3D.new()
	var belt_mesh := BoxMesh.new()
	belt_mesh.size = Vector3(torso_w + 0.04, 0.10, torso_d + 0.04)
	belt.mesh = belt_mesh
	var belt_mat := StandardMaterial3D.new()
	belt_mat.albedo_color = Color(0.28, 0.20, 0.14)
	belt_mat.roughness = 0.80
	belt.material_override = belt_mat
	belt.position.y = 0.88
	belt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(belt)
	
	# Belt buckle
	var buckle := MeshInstance3D.new()
	var buckle_mesh := BoxMesh.new()
	buckle_mesh.size = Vector3(0.10, 0.08, 0.04)
	buckle.mesh = buckle_mesh
	var buckle_mat := StandardMaterial3D.new()
	buckle_mat.albedo_color = Color(0.83, 0.69, 0.22)
	buckle_mat.metallic = 0.85
	buckle.material_override = buckle_mat
	buckle.position = Vector3(0, 0.88, torso_d / 2.0 + 0.02)
	group.add_child(buckle)
	
	# ─── HEAD (Rounded sphere with jaw) ───────────────────────────────────────
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.34
	head_mesh.height = 0.72
	head_mesh.radial_segments = 16
	head_mesh.rings = 12
	head.mesh = head_mesh
	head.material_override = skin_mat
	head.position.y = 2.12
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(head)
	
	# Neck
	var neck := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.14
	neck_mesh.bottom_radius = 0.18
	neck_mesh.height = 0.16
	neck.mesh = neck_mesh
	neck.material_override = skin_mat
	neck.position.y = 1.82
	group.add_child(neck)
	
	# ─── EYES (White sclera + dark iris + specular pupil) ─────────────────────
	var eye_white_mat := StandardMaterial3D.new()
	eye_white_mat.albedo_color = Color(0.95, 0.95, 0.95)
	var iris_mat := StandardMaterial3D.new()
	iris_mat.albedo_color = Color(0.20, 0.35, 0.55)
	var pupil_mat := StandardMaterial3D.new()
	pupil_mat.albedo_color = Color(0.02, 0.02, 0.02)
	
	for side in [-1, 1]:
		# Sclera
		var sclera := MeshInstance3D.new()
		var sclera_m := SphereMesh.new()
		sclera_m.radius = 0.055; sclera_m.height = 0.07
		sclera.mesh = sclera_m
		sclera.material_override = eye_white_mat
		sclera.position = Vector3(side * 0.12, 2.16, 0.30)
		group.add_child(sclera)
		# Iris
		var iris := MeshInstance3D.new()
		var iris_m := SphereMesh.new()
		iris_m.radius = 0.035; iris_m.height = 0.04
		iris.mesh = iris_m
		iris.material_override = iris_mat
		iris.position = Vector3(side * 0.12, 2.16, 0.335)
		group.add_child(iris)
		# Pupil
		var pupil := MeshInstance3D.new()
		var pupil_m := SphereMesh.new()
		pupil_m.radius = 0.018; pupil_m.height = 0.02
		pupil.mesh = pupil_m
		pupil.material_override = pupil_mat
		pupil.position = Vector3(side * 0.12, 2.16, 0.355)
		group.add_child(pupil)
	
	# Eyebrows
	var brow_mat := StandardMaterial3D.new()
	brow_mat.albedo_color = Color(0.18, 0.14, 0.12)
	for side in [-1, 1]:
		var brow := MeshInstance3D.new()
		var brow_m := BoxMesh.new()
		brow_m.size = Vector3(0.11, 0.025, 0.03)
		brow.mesh = brow_m
		brow.material_override = brow_mat
		brow.position = Vector3(side * 0.12, 2.23, 0.31)
		brow.rotation.z = side * deg_to_rad(-8.0)
		group.add_child(brow)
	
	# Nose
	var nose := MeshInstance3D.new()
	var nose_m := CylinderMesh.new()
	nose_m.top_radius = 0.02; nose_m.bottom_radius = 0.035; nose_m.height = 0.08
	nose.mesh = nose_m
	nose.material_override = skin_mat
	nose.position = Vector3(0, 2.10, 0.35)
	nose.rotation.x = deg_to_rad(-15.0)
	group.add_child(nose)
	
	# Mouth
	var mouth := MeshInstance3D.new()
	var mouth_m := BoxMesh.new()
	mouth_m.size = Vector3(0.12, 0.02, 0.015)
	mouth.mesh = mouth_m
	var mouth_mat := StandardMaterial3D.new()
	mouth_mat.albedo_color = Color(0.55, 0.30, 0.28)
	mouth.material_override = mouth_mat
	mouth.position = Vector3(0, 2.02, 0.33)
	group.add_child(mouth)
	
	# Ears
	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var ear_m := SphereMesh.new()
		ear_m.radius = 0.06; ear_m.height = 0.09
		ear.mesh = ear_m
		ear.material_override = skin_mat
		ear.position = Vector3(side * 0.33, 2.10, 0.04)
		ear.scale = Vector3(0.5, 1.0, 0.8)
		group.add_child(ear)
	
	# ─── ARMS (Upper arm + forearm + hand) ────────────────────────────────────
	var left_arm := _make_detailed_arm(arm_len, mat, skin_mat, Vector3(-torso_w / 2.0 - 0.08 - shoulder_w, 1.72, 0), false)
	left_arm.name = "LimbPivot_LA"
	var right_arm := _make_detailed_arm(arm_len, mat, skin_mat, Vector3(torso_w / 2.0 + 0.08 + shoulder_w, 1.72, 0), true)
	right_arm.name = "LimbPivot_RA"
	group.add_child(left_arm)
	group.add_child(right_arm)
	
	# ─── LEGS (Thigh + shin + boot) ──────────────────────────────────────────
	var left_leg := _make_detailed_leg(leg_len, dark_mat, boot_mat, Vector3(-0.20, 0.85, 0))
	left_leg.name = "LimbPivot_LL"
	var right_leg := _make_detailed_leg(leg_len, dark_mat, boot_mat, Vector3(0.20, 0.85, 0))
	right_leg.name = "LimbPivot_RL"
	group.add_child(left_leg)
	group.add_child(right_leg)
	
	# ─── CONTACT SHADOW ──────────────────────────────────────────────────────
	var shadow := MeshInstance3D.new()
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(1.15, 1.15)
	shadow.mesh = shadow_mesh
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0, 0, 0, 0.4)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material_override = shadow_mat
	shadow.position.y = 0.02
	group.add_child(shadow)
	
	return {
		"root": group,
		"head": head,
		"torso": torso,
		"left_arm": left_arm,
		"right_arm": right_arm,
	}

# ═══════════════════════════════════════════════════════════════════════════════
#  DETAILED ARM — Upper arm + forearm + hand with fingers
# ═══════════════════════════════════════════════════════════════════════════════
static func _make_detailed_arm(total_len: float, sleeve_mat: Material, skin_mat: Material, pos: Vector3, is_right: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	
	# Upper arm (sleeved)
	var upper := MeshInstance3D.new()
	var upper_m := CylinderMesh.new()
	upper_m.top_radius = 0.13; upper_m.bottom_radius = 0.11
	upper_m.height = total_len * 0.55
	upper.mesh = upper_m
	upper.material_override = sleeve_mat
	upper.position.y = -total_len * 0.28
	upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(upper)
	
	# Forearm (skin)
	var forearm := MeshInstance3D.new()
	var fore_m := CylinderMesh.new()
	fore_m.top_radius = 0.10; fore_m.bottom_radius = 0.08
	fore_m.height = total_len * 0.45
	forearm.mesh = fore_m
	forearm.material_override = skin_mat
	forearm.position.y = -total_len * 0.72
	forearm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(forearm)
	
	# Hand (box with rounded feel)
	var hand := MeshInstance3D.new()
	var hand_m := BoxMesh.new()
	hand_m.size = Vector3(0.12, 0.08, 0.10)
	hand.mesh = hand_m
	hand.material_override = skin_mat
	hand.position.y = -total_len - 0.02
	hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(hand)
	
	# Fingers (3 small cylinders)
	for fi in range(3):
		var finger := MeshInstance3D.new()
		var finger_m := CylinderMesh.new()
		finger_m.top_radius = 0.015; finger_m.bottom_radius = 0.013
		finger_m.height = 0.08
		finger.mesh = finger_m
		finger.material_override = skin_mat
		var fx = -0.03 + fi * 0.03
		finger.position = Vector3(fx, -total_len - 0.08, 0.025)
		pivot.add_child(finger)
	
	# Thumb
	var thumb := MeshInstance3D.new()
	var thumb_m := CylinderMesh.new()
	thumb_m.top_radius = 0.018; thumb_m.bottom_radius = 0.015
	thumb_m.height = 0.06
	thumb.mesh = thumb_m
	thumb.material_override = skin_mat
	var tx = 0.06 if is_right else -0.06
	thumb.position = Vector3(tx, -total_len - 0.02, 0.04)
	thumb.rotation.z = deg_to_rad(30.0) * (1 if is_right else -1)
	pivot.add_child(thumb)
	
	return pivot

# ═══════════════════════════════════════════════════════════════════════════════
#  DETAILED LEG — Thigh + shin + boot with sole
# ═══════════════════════════════════════════════════════════════════════════════
static func _make_detailed_leg(total_len: float, pants_mat: Material, boot_mat: Material, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	
	# Thigh
	var thigh := MeshInstance3D.new()
	var thigh_m := CylinderMesh.new()
	thigh_m.top_radius = 0.16; thigh_m.bottom_radius = 0.13
	thigh_m.height = total_len * 0.50
	thigh.mesh = thigh_m
	thigh.material_override = pants_mat
	thigh.position.y = -total_len * 0.25
	thigh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(thigh)
	
	# Shin
	var shin := MeshInstance3D.new()
	var shin_m := CylinderMesh.new()
	shin_m.top_radius = 0.12; shin_m.bottom_radius = 0.10
	shin_m.height = total_len * 0.40
	shin.mesh = shin_m
	shin.material_override = pants_mat
	shin.position.y = -total_len * 0.68
	shin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(shin)
	
	# Boot (tapered cylinder + sole box)
	var boot := MeshInstance3D.new()
	var boot_m := CylinderMesh.new()
	boot_m.top_radius = 0.12; boot_m.bottom_radius = 0.11
	boot_m.height = total_len * 0.22
	boot.mesh = boot_m
	boot.material_override = boot_mat
	boot.position.y = -total_len * 0.88
	boot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(boot)
	
	# Boot sole (flat box extending forward)
	var sole := MeshInstance3D.new()
	var sole_m := BoxMesh.new()
	sole_m.size = Vector3(0.22, 0.04, 0.28)
	sole.mesh = sole_m
	var sole_mat := StandardMaterial3D.new()
	sole_mat.albedo_color = Color(0.10, 0.08, 0.06)
	sole.material_override = sole_mat
	sole.position = Vector3(0, -total_len + 0.02, 0.04)
	sole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(sole)
	
	# Boot strap detail
	var strap := MeshInstance3D.new()
	var strap_m := BoxMesh.new()
	strap_m.size = Vector3(0.26, 0.03, 0.24)
	strap.mesh = strap_m
	var strap_mat := StandardMaterial3D.new()
	strap_mat.albedo_color = Color(0.30, 0.22, 0.16)
	strap.material_override = strap_mat
	strap.position.y = -total_len * 0.82
	pivot.add_child(strap)
	
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
	rig.right_arm.add_child(_make_spear())
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

static func _make_cape(color: Color) -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.83, 0.69, 0.22)
	gold_mat.metallic = 0.85
	# Gold clasp bar across shoulders
	var clasp := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(0.88, 0.07, 0.12)
	clasp.mesh = cbox; clasp.material_override = gold_mat
	clasp.position = Vector3(0, 1.82, -0.18)
	group.add_child(clasp)
	# Clasp gem center
	var gem := MeshInstance3D.new()
	var gem_m := SphereMesh.new()
	gem_m.radius = 0.04; gem_m.height = 0.05
	gem.mesh = gem_m
	var gem_mat := StandardMaterial3D.new()
	gem_mat.albedo_color = Color(0.15, 0.55, 0.85)
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(0.15, 0.55, 0.85)
	gem.material_override = gem_mat
	gem.position = Vector3(0, 1.82, -0.10)
	group.add_child(gem)
	# Cape: 4 layered box segments that naturally drape down the back
	var cape_widths = [0.82, 0.78, 0.72, 0.65]
	var cape_heights = [0.32, 0.32, 0.30, 0.28]
	var y_start := 1.68
	for i in range(cape_widths.size()):
		var seg := MeshInstance3D.new()
		var seg_m := BoxMesh.new()
		seg_m.size = Vector3(cape_widths[i], cape_heights[i], 0.06)
		seg.mesh = seg_m
		# Slightly darken lower segments for depth
		var seg_mat := StandardMaterial3D.new()
		seg_mat.albedo_color = color.darkened(i * 0.06)
		seg_mat.roughness = 0.75
		seg.material_override = seg_mat
		seg.position = Vector3(0, y_start - i * cape_heights[i], -0.28 - i * 0.02)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(seg)
	return group

static func _make_cloak(color: Color) -> Node3D:
	var group := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.80
	# Cloak: 5 layered box segments wrapping behind the body
	var widths = [0.90, 0.88, 0.85, 0.80, 0.72]
	var heights = [0.28, 0.28, 0.26, 0.26, 0.24]
	var y_start := 1.72
	for i in range(widths.size()):
		var seg := MeshInstance3D.new()
		var seg_m := BoxMesh.new()
		seg_m.size = Vector3(widths[i], heights[i], 0.05)
		seg.mesh = seg_m
		var seg_mat := StandardMaterial3D.new()
		seg_mat.albedo_color = color.darkened(i * 0.04)
		seg_mat.roughness = 0.80
		seg.material_override = seg_mat
		seg.position = Vector3(0, y_start - i * heights[i], -0.26 - i * 0.015)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(seg)
	return group

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

static func _make_chest_plate(color: Color) -> Node3D:
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.88, 0.55, 0.52)
	plate.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lightened(0.15)
	mat.metallic = 0.55; mat.roughness = 0.45
	plate.material_override = mat
	plate.position = Vector3(0, 1.50, 0)
	return plate

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
	bm.size = Vector3(0.07, 0.72, 0.02)
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
		wm.top_radius = 0.032; wm.bottom_radius = 0.032; wm.height = 0.03
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
	hm.size = Vector3(0.30, 0.04, 0.02)
	h_bar.mesh = hm; h_bar.material_override = emblem_mat
	h_bar.position = Vector3(0, -0.22, 0.27)
	group.add_child(h_bar)
	var v_bar := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.04, 0.40, 0.02)
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
	bm.size = Vector3(0.26, 0.28, 0.035)
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
	em.size = Vector3(0.01, 0.26, 0.04)
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
	bm.size = Vector3(0.04, 0.38, 0.015)
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
	gm.size = Vector3(0.10, 0.025, 0.03)
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
	torus.inner_radius = 0.38; torus.outer_radius = 0.42
	bow.mesh = torus; bow.material_override = bow_mat
	bow.position.y = -0.22
	bow.rotation.z = deg_to_rad(90.0)
	group.add_child(bow)
	# Bowstring
	var string := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.005; sm.bottom_radius = 0.005; sm.height = 0.78
	string.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.85, 0.80, 0.70)
	string.material_override = smat
	string.position = Vector3(0.38, -0.22, 0)
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

