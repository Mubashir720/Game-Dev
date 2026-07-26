extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════════
#  PROP FACTORY — Production-Quality 3D Environment Props & Landmarks
#  Matches reference artwork: Dense canopy trees, beast skeletons, wooden bridges,
#  squad camps, ruined stone arches, boulders, flora, landmarks.
# ═══════════════════════════════════════════════════════════════════════════════

static func build_tree(tree_type: String = "pine") -> Node3D:
	match tree_type.to_lower():
		"pine":   return _build_pine_tree()
		"oak":    return _build_oak_tree()
		"birch":  return _build_birch_tree()
		"willow": return _build_willow_tree()
		"dead":   return _build_dead_tree()
		"canopy": return _build_canopy_tree()
		_:        return _build_pine_tree()

static func build_rock(rock_type: String = "boulder") -> Node3D:
	match rock_type.to_lower():
		"boulder":  return _build_boulder()
		"cluster":  return _build_rock_cluster()
		"mossy":    return _build_mossy_rock()
		"ore_vein": return _build_ore_vein()
		_:          return _build_boulder()

static func build_berry_bush() -> Node3D: return _build_berry_bush()
static func build_dense_bush() -> Node3D: return _build_dense_bush()
static func build_herb_plant() -> Node3D: return _build_herb_plant()
static func build_mushroom_cluster() -> Node3D: return _build_mushroom_cluster()
static func build_fallen_log() -> Node3D: return _build_fallen_log()
static func build_vine_stump() -> Node3D: return _build_vine_stump()
static func build_tall_grass() -> Node3D: return _build_tall_grass_patch()
static func build_mossy_rock() -> Node3D: return _build_mossy_rock()

static func build_crate() -> Node3D: return _build_shipment_crate()
static func build_cursed_throne() -> Node3D: return _build_cursed_throne_landmark()
static func build_vendor_stall(is_black_market: bool = false) -> Node3D: return _build_vendor_stall(is_black_market)
static func build_beast_skeleton() -> Node3D: return _build_beast_skeleton()
static func build_wooden_bridge(span_length: float = 4.2) -> Node3D: return _build_wooden_bridge(span_length)
static func build_squad_camp(squad_color: Color = Color(0.8, 0.3, 0.2)) -> Node3D: return _build_squad_camp(squad_color)
static func build_ruined_arch() -> Node3D: return _build_ruined_arch()
static func build_reed_cluster() -> Node3D: return _build_reed_cluster()
static func build_lily_pad() -> Node3D: return _build_lily_pad()
static func build_fern_cluster() -> Node3D: return _build_fern_cluster()
static func build_hill_rock_pile() -> Node3D: return _build_hill_rock_pile()
static func build_trail_marker() -> Node3D: return _build_trail_marker()

# Environmental Storytelling Props
static func build_abandoned_cart() -> Node3D: return _build_abandoned_cart()
static func build_animal_skull() -> Node3D: return _build_animal_skull()
static func build_torch_post() -> Node3D: return _build_torch_post()
static func build_stone_circle() -> Node3D: return _build_stone_circle()
static func build_broken_weapons() -> Node3D: return _build_broken_weapons()
static func build_hanging_lantern_post() -> Node3D: return _build_hanging_lantern_post()
static func build_warning_sign() -> Node3D: return _build_warning_sign()
static func build_bone_pile() -> Node3D: return _build_bone_pile()
static func build_fallen_banner() -> Node3D: return _build_fallen_banner()
static func build_vine_archway() -> Node3D: return _build_vine_archway()


# ═══════════════════════════════════════════════════════════════════════════════
#  1. TREES
# ═══════════════════════════════════════════════════════════════════════════════

# PINE TREE — Multi-stage trunk + 4-tier layered cone canopy
static func _build_pine_tree() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_PineTree"
	group.collision_layer = 1; group.collision_mask = 3

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.30, 0.20, 0.14); trunk_mat.roughness = 0.92

	var bark_dark := StandardMaterial3D.new()
	bark_dark.albedo_color = Color(0.22, 0.15, 0.10); bark_dark.roughness = 1.0

	var t1 := MeshInstance3D.new()
	var tm1 := CylinderMesh.new()
	tm1.top_radius = 0.18; tm1.bottom_radius = 0.28; tm1.height = 0.6
	t1.mesh = tm1; t1.material_override = trunk_mat; t1.position.y = 0.30
	t1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(t1)

	var t2 := MeshInstance3D.new()
	var tm2 := CylinderMesh.new()
	tm2.top_radius = 0.12; tm2.bottom_radius = 0.18; tm2.height = 0.8
	t2.mesh = tm2; t2.material_override = trunk_mat; t2.position.y = 0.90
	t2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(t2)

	for i in range(4):
		var ang = (i / 4.0) * TAU
		var ridge := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.04, 0.6, 0.02)
		ridge.mesh = rm; ridge.material_override = bark_dark
		ridge.position = Vector3(cos(ang) * 0.20, 0.40, sin(ang) * 0.20)
		ridge.rotation.y = ang
		group.add_child(ridge)

	var tier_colors = [Color(0.14, 0.34, 0.18), Color(0.16, 0.38, 0.20), Color(0.18, 0.42, 0.22), Color(0.20, 0.46, 0.24)]
	var tier_params = [
		{"bot": 1.15, "h": 1.2, "y": 1.50},
		{"bot": 0.90, "h": 1.0, "y": 2.10},
		{"bot": 0.68, "h": 0.85, "y": 2.65},
		{"bot": 0.42, "h": 0.60, "y": 3.10}
	]

	for i in range(4):
		var leaves := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0; cone.bottom_radius = tier_params[i]["bot"]; cone.height = tier_params[i]["h"]
		cone.radial_segments = 8
		leaves.mesh = cone
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = tier_colors[i]; lmat.roughness = 0.88
		leaves.material_override = lmat
		leaves.position.y = tier_params[i]["y"]
		leaves.rotation.y = deg_to_rad(i * 35.0)
		leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(leaves)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.32; cyl.height = 2.2
	col.shape = cyl; col.position.y = 1.1
	group.add_child(col)

	return group


# OAK TREE — Gnarled trunk + 3-cluster canopy
static func _build_oak_tree() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_OakTree"
	group.collision_layer = 1; group.collision_mask = 3

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.32, 0.22, 0.15); trunk_mat.roughness = 0.90

	var leaves_mat1 := StandardMaterial3D.new()
	leaves_mat1.albedo_color = Color(0.18, 0.42, 0.22); leaves_mat1.roughness = 0.85
	var leaves_mat2 := StandardMaterial3D.new()
	leaves_mat2.albedo_color = Color(0.22, 0.48, 0.26); leaves_mat2.roughness = 0.85

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.24; tm.bottom_radius = 0.38; tm.height = 1.4
	trunk.mesh = tm; trunk.material_override = trunk_mat; trunk.position.y = 0.70
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(trunk)

	var clusters = [
		{"pos": Vector3(0, 1.85, 0), "r": 0.90, "h": 1.1, "mat": leaves_mat1},
		{"pos": Vector3(0.42, 2.10, 0.2), "r": 0.68, "h": 0.85, "mat": leaves_mat2},
		{"pos": Vector3(-0.38, 2.05, -0.25), "r": 0.65, "h": 0.80, "mat": leaves_mat1},
	]
	for c in clusters:
		var leaves := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = c["r"]; sm.height = c["h"]
		sm.radial_segments = 10; sm.rings = 7
		leaves.mesh = sm; leaves.material_override = c["mat"]; leaves.position = c["pos"]
		leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(leaves)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.38; cyl.height = 2.2
	col.shape = cyl; col.position.y = 1.1
	group.add_child(col)

	return group


# TALL CANOPY TREE (For forest borders & path framing)
static func _build_canopy_tree() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_CanopyTree"
	group.collision_layer = 1; group.collision_mask = 3

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.24, 0.16, 0.12); trunk_mat.roughness = 0.92

	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.12, 0.30, 0.15); canopy_mat.roughness = 0.88

	# Tall trunk
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.28; tm.bottom_radius = 0.45; tm.height = 2.6
	trunk.mesh = tm; trunk.material_override = trunk_mat; trunk.position.y = 1.30
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(trunk)

	# Huge overhead canopy sphere cluster
	var main_canopy := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.45; sm.height = 1.80
	sm.radial_segments = 12; sm.rings = 8
	main_canopy.mesh = sm; main_canopy.material_override = canopy_mat
	main_canopy.position = Vector3(0, 3.20, 0)
	main_canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(main_canopy)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.45; cyl.height = 3.0
	col.shape = cyl; col.position.y = 1.5
	group.add_child(col)

	return group


# DEAD TREE (Swamp)
static func _build_dead_tree() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_DeadTree"
	group.collision_layer = 1; group.collision_mask = 3

	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_color = Color(0.18, 0.14, 0.12); bark_mat.roughness = 1.0

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.10; tm.bottom_radius = 0.25; tm.height = 1.8
	trunk.mesh = tm; trunk.material_override = bark_mat; trunk.position = Vector3(0.08, 0.90, 0)
	trunk.rotation.z = deg_to_rad(10.0)
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(trunk)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.28; cyl.height = 2.0
	col.shape = cyl; col.position.y = 1.0
	group.add_child(col)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  2. ROCKS & ORE
# ═══════════════════════════════════════════════════════════════════════════════

static func _build_boulder() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_Boulder"
	group.collision_layer = 1; group.collision_mask = 3

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.50, 0.48, 0.44); rock_mat.roughness = 0.92

	var main_rock := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.55; sm.height = 0.80
	sm.radial_segments = 6; sm.rings = 4
	main_rock.mesh = sm; main_rock.material_override = rock_mat; main_rock.position.y = 0.40
	main_rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(main_rock)

	var col := CollisionShape3D.new()
	var sc := SphereShape3D.new(); sc.radius = 0.55
	col.shape = sc; col.position.y = 0.40
	group.add_child(col)

	return group


static func _build_rock_cluster() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_RockCluster"
	group.collision_layer = 1; group.collision_mask = 3

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.45, 0.44, 0.42); rock_mat.roughness = 0.90

	var positions = [Vector3(-0.25, 0.30, -0.15), Vector3(0.20, 0.25, 0.20), Vector3(-0.10, 0.18, 0.30)]
	for i in range(3):
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.35 - i * 0.08; sm.height = sm.radius * 1.5
		sm.radial_segments = 5; sm.rings = 4
		rock.mesh = sm; rock.material_override = rock_mat; rock.position = positions[i]
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(rock)

	var col := CollisionShape3D.new()
	var sc := SphereShape3D.new(); sc.radius = 0.55
	col.shape = sc; col.position.y = 0.35
	group.add_child(col)

	return group


static func _build_ore_vein() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_OreVein"
	group.collision_layer = 1; group.collision_mask = 3

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.28, 0.28, 0.28); rock_mat.roughness = 0.92

	var vein_mat := StandardMaterial3D.new()
	vein_mat.albedo_color = Color(0.88, 0.72, 0.15); vein_mat.metallic = 0.88; vein_mat.roughness = 0.20
	vein_mat.emission_enabled = true; vein_mat.emission = Color(0.70, 0.55, 0.10); vein_mat.emission_energy_multiplier = 0.6

	var rock := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.50; sm.height = 0.75
	sm.radial_segments = 6; sm.rings = 4
	rock.mesh = sm; rock.material_override = rock_mat; rock.position.y = 0.38
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(rock)

	var vein := MeshInstance3D.new()
	var vm := BoxMesh.new(); vm.size = Vector3(0.22, 0.02, 0.04)
	vein.mesh = vm; vein.material_override = vein_mat; vein.position = Vector3(0, 0.40, 0.38)
	group.add_child(vein)

	var col := CollisionShape3D.new()
	var sc := SphereShape3D.new(); sc.radius = 0.52
	col.shape = sc; col.position.y = 0.38
	group.add_child(col)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  3. FLORA & FOOD
# ═══════════════════════════════════════════════════════════════════════════════

static func _build_berry_bush() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_BerryBush"
	group.collision_layer = 1; group.collision_mask = 3

	var bush_mat := StandardMaterial3D.new()
	bush_mat.albedo_color = Color(0.20, 0.45, 0.22); bush_mat.roughness = 0.85
	var berry_mat := StandardMaterial3D.new()
	berry_mat.albedo_color = Color(0.85, 0.15, 0.18); berry_mat.roughness = 0.4

	var bush := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.50; sm.height = 0.80
	bush.mesh = sm; bush.material_override = bush_mat; bush.position.y = 0.45
	bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(bush)

	for i in range(5):
		var berry := MeshInstance3D.new()
		var bm := SphereMesh.new(); bm.radius = 0.04; bm.height = 0.07
		berry.mesh = bm; berry.material_override = berry_mat
		var ang = (i / 5.0) * TAU
		berry.position = Vector3(cos(ang) * 0.40, 0.45, sin(ang) * 0.40)
		group.add_child(berry)

	var col := CollisionShape3D.new()
	var sc := SphereShape3D.new(); sc.radius = 0.52
	col.shape = sc; col.position.y = 0.45
	group.add_child(col)

	return group


static func _build_herb_plant() -> Node3D:
	var group := Node3D.new()
	group.name = "Prop_HerbPlant"

	var flower_mat := StandardMaterial3D.new()
	flower_mat.albedo_color = Color(0.65, 0.22, 0.75)
	flower_mat.emission_enabled = true; flower_mat.emission = Color(0.50, 0.15, 0.65)
	flower_mat.emission_energy_multiplier = 0.6

	var flower := MeshInstance3D.new()
	var fm := SphereMesh.new(); fm.radius = 0.12; fm.height = 0.22
	flower.mesh = fm; flower.material_override = flower_mat; flower.position.y = 0.35
	group.add_child(flower)

	return group


static func _build_mushroom_cluster() -> Node3D:
	var group := Node3D.new()
	group.name = "Prop_MushroomCluster"

	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.72, 0.18, 0.15); cap_mat.roughness = 0.5

	for i in range(3):
		var cap := MeshInstance3D.new()
		var cm := SphereMesh.new(); cm.radius = 0.08 - i * 0.02; cm.height = cm.radius * 0.8
		cap.mesh = cm; cap.material_override = cap_mat
		cap.position = Vector3(-0.08 + i * 0.08, 0.12, i * 0.05)
		group.add_child(cap)

	return group


static func _build_fallen_log() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_FallenLog"
	group.collision_layer = 1; group.collision_mask = 3

	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.28, 0.20, 0.14); log_mat.roughness = 0.95

	var log_inst := MeshInstance3D.new()
	var lm := CylinderMesh.new(); lm.top_radius = 0.18; lm.bottom_radius = 0.22; lm.height = 1.8
	log_inst.mesh = lm; log_inst.material_override = log_mat; log_inst.position.y = 0.20
	log_inst.rotation.z = deg_to_rad(90.0)
	log_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(log_inst)

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new(); box_col.size = Vector3(1.8, 0.40, 0.44)
	col.shape = box_col; col.position.y = 0.20
	group.add_child(col)

	return group


# REED CLUSTER (Riverbank & pond edges)
static func _build_reed_cluster() -> Node3D:
	var group := Node3D.new()
	group.name = "Prop_ReedCluster"

	var reed_mat := StandardMaterial3D.new()
	reed_mat.albedo_color = Color(0.30, 0.42, 0.18); reed_mat.roughness = 0.85

	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.42, 0.30, 0.14); tip_mat.roughness = 0.9

	for i in range(6):
		var reed := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.012; rm.bottom_radius = 0.02
		rm.height = 0.55 + randf() * 0.45
		reed.mesh = rm; reed.material_override = reed_mat
		var ang = randf() * TAU
		var dist = randf() * 0.35
		reed.position = Vector3(cos(ang) * dist, rm.height * 0.5, sin(ang) * dist)
		reed.rotation.x = (randf() - 0.5) * 0.25
		reed.rotation.z = (randf() - 0.5) * 0.25
		group.add_child(reed)

		var tip := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.0; tm.bottom_radius = 0.03; tm.height = 0.12
		tip.mesh = tm; tip.material_override = tip_mat
		tip.position = Vector3(0, rm.height * 0.5 + 0.06, 0)
		reed.add_child(tip)

	return group


# LILY PAD CLUSTER (floats on ponds/river shallows)
static func _build_lily_pad() -> Node3D:
	var group := Node3D.new()
	group.name = "Prop_LilyPad"

	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.16, 0.40, 0.20); pad_mat.roughness = 0.5

	var flower_mat := StandardMaterial3D.new()
	flower_mat.albedo_color = Color(0.95, 0.85, 0.90); flower_mat.roughness = 0.4

	for i in range(3):
		var pad := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22 - i * 0.03; cm.bottom_radius = cm.top_radius
		cm.height = 0.02; cm.radial_segments = 8
		pad.mesh = cm; pad.material_override = pad_mat
		pad.position = Vector3((randf() - 0.5) * 0.6, 0.0, (randf() - 0.5) * 0.6)
		group.add_child(pad)

		if randf() < 0.4:
			var flower := MeshInstance3D.new()
			var fm := SphereMesh.new(); fm.radius = 0.05; fm.height = 0.08
			flower.mesh = fm; flower.material_override = flower_mat
			flower.position = pad.position + Vector3(0, 0.04, 0)
			group.add_child(flower)

	return group


# FERN CLUSTER (dense forest floor understory detail)
static func _build_fern_cluster() -> Node3D:
	var group := Node3D.new()
	group.name = "Prop_FernCluster"

	var fern_mat := StandardMaterial3D.new()
	fern_mat.albedo_color = Color(0.14, 0.36, 0.16); fern_mat.roughness = 0.88

	for i in range(5):
		var frond := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.30 + randf() * 0.15, 0.02)
		frond.mesh = bm; frond.material_override = fern_mat
		var ang = (i / 5.0) * TAU
		frond.position = Vector3(cos(ang) * 0.10, bm.size.y * 0.5, sin(ang) * 0.10)
		frond.rotation.y = ang
		frond.rotation.z = deg_to_rad(18.0)
		frond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(frond)

	return group


# HILL ROCK PILE (loose scree detail on rolling hillsides & highland slopes)
static func _build_hill_rock_pile() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_HillRockPile"
	group.collision_layer = 1; group.collision_mask = 3

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.42, 0.40, 0.36); rock_mat.roughness = 0.92

	for i in range(4):
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14 + randf() * 0.12; sm.height = sm.radius * 1.4
		sm.radial_segments = 5; sm.rings = 3
		rock.mesh = sm; rock.material_override = rock_mat
		rock.position = Vector3((randf() - 0.5) * 0.5, sm.radius * 0.5, (randf() - 0.5) * 0.5)
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(rock)

	var col := CollisionShape3D.new()
	var sc := SphereShape3D.new(); sc.radius = 0.35
	col.shape = sc; col.position.y = 0.20
	group.add_child(col)

	return group


# TRAIL MARKER (carved wooden signpost placed along path junctions for wayfinding detail)
static func _build_trail_marker() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_TrailMarker"
	group.collision_layer = 1; group.collision_mask = 3

	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.32, 0.22, 0.14); post_mat.roughness = 0.9

	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.06; pm.bottom_radius = 0.09; pm.height = 1.4
	post.mesh = pm; post.material_override = post_mat; post.position.y = 0.70
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(post)

	for i in range(2):
		var sign := MeshInstance3D.new()
		var sm := BoxMesh.new(); sm.size = Vector3(0.55, 0.16, 0.03)
		sign.mesh = sm; sign.material_override = post_mat
		sign.position = Vector3(0, 1.05 - i * 0.22, 0)
		sign.rotation.y = deg_to_rad(20.0 - i * 55.0)
		sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(sign)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.10; cyl.height = 1.4
	col.shape = cyl; col.position.y = 0.70
	group.add_child(col)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  4. NEW REFERENCE ART LANDMARKS (BEAST SKELETON, WOODEN BRIDGE, SQUAD CAMP)
# ═══════════════════════════════════════════════════════════════════════════════

# BEAST SKELETON (Giant ribcage & fossil skull matching concept art)
static func _build_beast_skeleton() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Landmark_BeastSkeleton"
	group.collision_layer = 1; group.collision_mask = 3

	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.85, 0.82, 0.72)
	bone_mat.roughness = 0.75

	# Fossil Skull (Large predatory skull)
	var skull := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.80, 0.65, 1.30)
	skull.mesh = sm; skull.material_override = bone_mat
	skull.position = Vector3(0, 0.45, 1.20)
	skull.rotation.x = deg_to_rad(15.0)
	skull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(skull)

	# Eye sockets (dark gaps)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.10, 0.08, 0.06)
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new(); em.radius = 0.14; em.height = 0.10
		eye.mesh = em; eye.material_override = eye_mat
		eye.position = Vector3(side * 0.32, 0.55, 1.10)
		group.add_child(eye)

	# Ribcage arch bones (×6 curved arch ribs)
	for i in range(6):
		var z_pos = 0.40 - i * 0.45
		for side in [-1, 1]:
			var rib := MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 0.04; rm.bottom_radius = 0.07; rm.height = 1.40
			rib.mesh = rm; rib.material_override = bone_mat
			rib.position = Vector3(side * 0.55, 0.70, z_pos)
			rib.rotation.z = side * deg_to_rad(35.0)
			rib.rotation.x = deg_to_rad(10.0)
			rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			group.add_child(rib)

	# Spine ridge beam
	var spine := MeshInstance3D.new()
	var sp_m := CylinderMesh.new()
	sp_m.top_radius = 0.08; sp_m.bottom_radius = 0.10; sp_m.height = 2.80
	spine.mesh = sp_m; spine.material_override = bone_mat
	spine.position = Vector3(0, 1.25, -0.40)
	spine.rotation.x = deg_to_rad(90.0)
	group.add_child(spine)

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new(); box_col.size = Vector3(1.6, 1.4, 3.2)
	col.shape = box_col; col.position = Vector3(0, 0.7, 0)
	group.add_child(col)

	return group


# WOODEN BRIDGE (Spans across the winding river at computed path crossings.
# The bridge's local +Z axis is its walking/crossing direction; span_length is
# sized dynamically per-crossing so it always fully clears the river's water,
# and the whole node is rotated to face the actual crossing direction.)
static func _build_wooden_bridge(span_length: float = 4.2) -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_WoodenBridge"
	group.collision_layer = 1; group.collision_mask = 3

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.38, 0.26, 0.16)
	wood_mat.roughness = 0.88

	var dark_wood := StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.24, 0.16, 0.10)

	var half := span_length * 0.5
	var plank_count: int = max(6, int(span_length / 0.30))

	# Stone footing piers at both ends (visually anchors the bridge into the bank)
	var pier_mat := StandardMaterial3D.new()
	pier_mat.albedo_color = Color(0.34, 0.32, 0.30); pier_mat.roughness = 0.95
	for end in [-1, 1]:
		var pier := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(2.4, 0.30, 0.60)
		pier.mesh = pm; pier.material_override = pier_mat
		pier.position = Vector3(0, 0.0, end * (half - 0.1))
		pier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(pier)

	# 2 Support beams spanning the full crossing
	for side in [-1, 1]:
		var beam := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 0.20, span_length)
		beam.mesh = bm; beam.material_override = dark_wood
		beam.position = Vector3(side * 0.90, 0.10, 0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(beam)

	# Support pilings driven into the riverbed every ~2 units along the span
	var piling_count: int = max(2, int(span_length / 2.0))
	for i in range(piling_count):
		var t = (float(i) / float(max(1, piling_count - 1))) - 0.5
		for side in [-1, 1]:
			var piling := MeshInstance3D.new()
			var plm := CylinderMesh.new()
			plm.top_radius = 0.10; plm.bottom_radius = 0.12; plm.height = 0.9
			piling.mesh = plm; piling.material_override = dark_wood
			piling.position = Vector3(side * 0.90, -0.25, t * span_length)
			group.add_child(piling)

	# Plank walkway, dynamically packed across the full span
	for i in range(plank_count):
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(2.1, 0.08, 0.26)
		plank.mesh = pm; plank.material_override = wood_mat
		var pt = (float(i) / float(max(1, plank_count - 1))) - 0.5
		plank.position = Vector3(0, 0.20, pt * (span_length - 0.3))
		plank.rotation.y = deg_to_rad((i % 2) * 2.0)
		plank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(plank)

	# Handrails (side posts + top rails), spaced along the full span
	var post_count: int = max(3, int(span_length / 1.4))
	for side in [-1, 1]:
		for p_i in range(post_count):
			var pt2 = (float(p_i) / float(max(1, post_count - 1))) - 0.5
			var post := MeshInstance3D.new()
			var pm2 := CylinderMesh.new()
			pm2.top_radius = 0.04; pm2.bottom_radius = 0.05; pm2.height = 0.85
			post.mesh = pm2; post.material_override = dark_wood
			post.position = Vector3(side * 1.0, 0.60, pt2 * (span_length - 0.6))
			group.add_child(post)

		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.08, 0.06, span_length - 0.2)
		rail.mesh = rm; rail.material_override = wood_mat
		rail.position = Vector3(side * 1.0, 0.95, 0)
		group.add_child(rail)

	# Solid physics collision for bridge walking deck surface
	var deck_col := CollisionShape3D.new()
	var deck_box := BoxShape3D.new(); deck_box.size = Vector3(2.0, 0.20, span_length)
	deck_col.shape = deck_box; deck_col.position = Vector3(0, 0.15, 0)
	group.add_child(deck_col)

	# Solid physics collision for side guardrails (prevents walking off bridge borders)
	for side in [-1, 1]:
		var rail_col := CollisionShape3D.new()
		var rail_box := BoxShape3D.new(); rail_box.size = Vector3(0.20, 0.80, span_length)
		rail_col.shape = rail_box; rail_col.position = Vector3(side * 1.05, 0.65, 0)
		group.add_child(rail_col)

	return group


# SQUAD CAMP (Tent + campfire + log seats + banner — matching reference art camps)
static func _build_squad_camp(squad_color: Color) -> Node3D:
	var group := Node3D.new()
	group.name = "Landmark_SquadCamp"

	var tent_mat := StandardMaterial3D.new()
	tent_mat.albedo_color = Color(0.68, 0.58, 0.42) # Canvas
	tent_mat.roughness = 0.90

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.35, 0.24, 0.16)

	var banner_mat := StandardMaterial3D.new()
	banner_mat.albedo_color = squad_color
	banner_mat.emission_enabled = true; banner_mat.emission = squad_color; banner_mat.emission_energy_multiplier = 0.4

	# 2 Canvas Tents (A-frame shape with solid collision)
	for side in [-1, 1]:
		var tent_body := StaticBody3D.new()
		tent_body.collision_layer = 1
		tent_body.collision_mask = 1
		tent_body.position = Vector3(side * 1.8, 0, -0.5)
		tent_body.rotation.y = deg_to_rad(side * 15.0)

		var tent := MeshInstance3D.new()
		var tm := PrismMesh.new()
		tm.size = Vector3(1.6, 1.2, 2.0)
		tent.mesh = tm; tent.material_override = tent_mat
		tent.position.y = 0.60
		tent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		tent_body.add_child(tent)

		var tent_col := CollisionShape3D.new()
		var tbox := BoxShape3D.new()
		tbox.size = Vector3(1.6, 1.2, 2.0)
		tent_col.shape = tbox; tent_col.position.y = 0.60
		tent_body.add_child(tent_col)
		group.add_child(tent_body)

	# Central Campfire
	const StructureFactory = preload("res://scenes/structures/structure_factory.gd")
	var fire = StructureFactory.build_structure("fire_pit")
	fire.position = Vector3(0, 0, 0.4)
	group.add_child(fire)

	# Log seats (×2)
	for side in [-1, 1]:
		var seat := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.12; sm.bottom_radius = 0.14; sm.height = 1.2
		seat.mesh = sm; seat.material_override = wood_mat
		seat.position = Vector3(side * 1.1, 0.12, 0.4)
		seat.rotation.z = deg_to_rad(90.0)
		group.add_child(seat)

	# Squad Banner Pole
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.03; pm.bottom_radius = 0.04; pm.height = 2.4
	pole.mesh = pm; pole.material_override = wood_mat
	pole.position = Vector3(0, 1.2, -1.4)
	group.add_child(pole)

	var banner := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.40, 0.70, 0.02)
	banner.mesh = bm; banner.material_override = banner_mat
	banner.position = Vector3(0.20, 1.8, -1.4)
	group.add_child(banner)

	return group


# RUINED STONE ARCHWAY (Concept art landmark)
static func _build_ruined_arch() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Landmark_RuinedArch"
	group.collision_layer = 1; group.collision_mask = 3

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.38, 0.36, 0.34); stone_mat.roughness = 0.90

	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = Color(0.2, 0.8, 0.4)
	rune_mat.emission_enabled = true; rune_mat.emission = Color(0.2, 0.8, 0.4); rune_mat.emission_energy_multiplier = 1.2

	# 2 Stone pillars
	for side in [-1, 1]:
		var pillar := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.60, 2.8, 0.60)
		pillar.mesh = pm; pillar.material_override = stone_mat
		pillar.position = Vector3(side * 1.2, 1.4, 0)
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(pillar)

	# Curved lintel arch top
	var arch := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(3.0, 0.50, 0.65)
	arch.mesh = am; arch.material_override = stone_mat
	arch.position = Vector3(0, 2.9, 0)
	arch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(arch)

	# Glowing green rune in center
	var rune := MeshInstance3D.new()
	var rm := SphereMesh.new(); rm.radius = 0.12; rm.height = 0.08
	rune.mesh = rm; rune.material_override = rune_mat
	rune.position = Vector3(0, 2.9, 0.34)
	group.add_child(rune)

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new(); box_col.size = Vector3(3.2, 3.2, 0.8)
	col.shape = box_col; col.position.y = 1.6
	group.add_child(col)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  5. LANDMARKS & SPECIAL STRUCTURES (CRATED / THRONE / VENDOR)
# ═══════════════════════════════════════════════════════════════════════════════

static func _build_shipment_crate() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_ShipmentCrate"
	group.collision_layer = 1; group.collision_mask = 3

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.54, 0.41, 0.22); wood_mat.roughness = 0.80

	var crate := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(1.0, 0.90, 1.0)
	crate.mesh = bm; crate.material_override = wood_mat; crate.position.y = 0.45
	crate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(crate)

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new(); box_col.size = Vector3(1.0, 0.90, 1.0)
	col.shape = box_col; col.position.y = 0.45
	group.add_child(col)

	return group


static func _build_cursed_throne_landmark() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Landmark_CursedThrone"
	group.collision_layer = 1; group.collision_mask = 3

	var obsidian_mat := StandardMaterial3D.new()
	obsidian_mat.albedo_color = Color(0.12, 0.06, 0.18); obsidian_mat.roughness = 0.25; obsidian_mat.metallic = 0.35

	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.55, 0.15, 0.75)
	crystal_mat.emission_enabled = true; crystal_mat.emission = Color(0.55, 0.15, 0.75); crystal_mat.emission_energy_multiplier = 1.5

	var step := MeshInstance3D.new()
	var sm := BoxMesh.new(); sm.size = Vector3(4.0, 0.40, 4.0)
	step.mesh = sm; step.material_override = obsidian_mat; step.position.y = 0.20
	step.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(step)

	var seat := MeshInstance3D.new()
	var seat_m := BoxMesh.new(); seat_m.size = Vector3(0.9, 0.50, 0.8)
	seat.mesh = seat_m; seat.material_override = obsidian_mat; seat.position = Vector3(0, 0.65, 0)
	group.add_child(seat)

	var back := MeshInstance3D.new()
	var back_m := BoxMesh.new(); back_m.size = Vector3(0.9, 1.8, 0.15)
	back.mesh = back_m; back.material_override = obsidian_mat; back.position = Vector3(0, 1.30, -0.32)
	group.add_child(back)

	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.15, 0.75); light.light_energy = 2.5; light.omni_range = 10.0
	light.position.y = 1.5
	group.add_child(light)

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new(); box_col.size = Vector3(4.0, 2.5, 4.0)
	col.shape = box_col; col.position.y = 1.25
	group.add_child(col)

	return group


static func _build_vendor_stall(is_black_market: bool = false) -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Vendor_BlackMarket" if is_black_market else "Vendor_Stall"
	group.collision_layer = 1; group.collision_mask = 3

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.18, 0.14, 0.12) if is_black_market else Color(0.42, 0.30, 0.18)

	var counter := MeshInstance3D.new()
	var cm := BoxMesh.new(); cm.size = Vector3(2.2, 0.85, 0.80)
	counter.mesh = cm; counter.material_override = wood_mat; counter.position.y = 0.425
	counter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(counter)

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new(); box_col.size = Vector3(2.5, 2.4, 1.2)
	col.shape = box_col; col.position.y = 1.2
	group.add_child(col)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  NEW TREE VARIETIES & PLANTS
# ═══════════════════════════════════════════════════════════════════════════════

static func _build_birch_tree() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_BirchTree"
	group.collision_layer = 1; group.collision_mask = 3

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.92, 0.90, 0.86); trunk_mat.roughness = 0.65

	var notch_mat := StandardMaterial3D.new()
	notch_mat.albedo_color = Color(0.12, 0.10, 0.08); notch_mat.roughness = 0.95

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.38, 0.62, 0.18); leaf_mat.roughness = 0.75

	# Slender white trunk
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new(); tm.top_radius = 0.12; tm.bottom_radius = 0.18; tm.height = 3.6
	trunk.mesh = tm; trunk.material_override = trunk_mat; trunk.position.y = 1.8
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(trunk)

	# Black bark notches
	for i in range(5):
		var notch := MeshInstance3D.new()
		var nm := BoxMesh.new(); nm.size = Vector3(0.28, 0.04, 0.28)
		notch.mesh = nm; notch.material_override = notch_mat
		notch.position = Vector3(0, 0.6 + i * 0.6, 0)
		notch.rotation.y = (i * 1.3)
		group.add_child(notch)

	# Golden/lime leaf clusters
	for i in range(3):
		var canopy := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 1.1 - i * 0.2; cm.height = 1.4 - i * 0.25
		canopy.mesh = cm; canopy.material_override = leaf_mat
		canopy.position = Vector3((i % 2 - 0.5) * 0.4, 2.6 + i * 0.7, 0)
		canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(canopy)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.25; cyl.height = 3.6
	col.shape = cyl; col.position.y = 1.8
	group.add_child(col)

	return group


static func _build_willow_tree() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_WillowTree"
	group.collision_layer = 1; group.collision_mask = 3

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.24, 0.16, 0.10); trunk_mat.roughness = 0.95

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.18, 0.42, 0.20); leaf_mat.roughness = 0.80

	# Thick gnarled trunk
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new(); tm.top_radius = 0.32; tm.bottom_radius = 0.48; tm.height = 2.8
	trunk.mesh = tm; trunk.material_override = trunk_mat; trunk.position.y = 1.4
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(trunk)

	# Wide canopy dome
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new(); dm.radius = 2.2; dm.height = 1.8
	dome.mesh = dm; dome.material_override = leaf_mat; dome.position.y = 2.8
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(dome)

	# Drooping leaf curtain strands
	for i in range(8):
		var ang = (i / 8.0) * TAU
		var strand := MeshInstance3D.new()
		var sm := CylinderMesh.new(); sm.top_radius = 0.15; sm.bottom_radius = 0.05; sm.height = 2.2
		strand.mesh = sm; strand.material_override = leaf_mat
		strand.position = Vector3(cos(ang) * 1.8, 1.8, sin(ang) * 1.8)
		group.add_child(strand)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.45; cyl.height = 2.8
	col.shape = cyl; col.position.y = 1.4
	group.add_child(col)

	return group


static func _build_dense_bush() -> Node3D:
	var group := Node3D.new()
	group.name = "Prop_DenseBush"

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.14, 0.38, 0.16); leaf_mat.roughness = 0.85

	for i in range(4):
		var lobe := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.45 + randf() * 0.15; sm.height = sm.radius * 1.6
		lobe.mesh = sm; lobe.material_override = leaf_mat
		var ang = (i / 4.0) * TAU
		lobe.position = Vector3(cos(ang) * 0.25, sm.radius * 0.8, sin(ang) * 0.25)
		lobe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(lobe)

	return group


static func _build_tall_grass_patch() -> Node3D:
	var group := Node3D.new()
	group.name = "Prop_TallGrass"

	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.28, 0.52, 0.22); grass_mat.roughness = 0.80

	for i in range(10):
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(0.03, 0.45 + randf() * 0.25, 0.015)
		blade.mesh = bm; blade.material_override = grass_mat
		var ang = (i / 10.0) * TAU
		var r = 0.08 + randf() * 0.12
		blade.position = Vector3(cos(ang) * r, bm.size.y * 0.5, sin(ang) * r)
		blade.rotation.y = randf() * TAU
		blade.rotation.z = deg_to_rad(randf_range(-12.0, 12.0))
		group.add_child(blade)

	return group


static func _build_vine_stump() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_VineStump"
	group.collision_layer = 1; group.collision_mask = 3

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.28, 0.18, 0.12); wood_mat.roughness = 0.95

	var vine_mat := StandardMaterial3D.new()
	vine_mat.albedo_color = Color(0.18, 0.44, 0.16); vine_mat.roughness = 0.80

	# Hollow stump body
	var stump := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.40; cm.bottom_radius = 0.52; cm.height = 0.70
	stump.mesh = cm; stump.material_override = wood_mat; stump.position.y = 0.35
	stump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(stump)

	# Ivy vines wrapped around stump
	for i in range(5):
		var vine := MeshInstance3D.new()
		var vm := BoxMesh.new(); vm.size = Vector3(0.12, 0.55, 0.04)
		vine.mesh = vm; vine.material_override = vine_mat
		var ang = (i / 5.0) * TAU
		vine.position = Vector3(cos(ang) * 0.46, 0.35, sin(ang) * 0.46)
		vine.rotation.y = ang
		group.add_child(vine)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.50; cyl.height = 0.70
	col.shape = cyl; col.position.y = 0.35
	group.add_child(col)

	return group


static func _build_mossy_rock() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_MossyRock"
	group.collision_layer = 1; group.collision_mask = 3

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.38, 0.36, 0.34); stone_mat.roughness = 0.90

	var moss_mat := StandardMaterial3D.new()
	moss_mat.albedo_color = Color(0.22, 0.46, 0.18); moss_mat.roughness = 0.92

	# Main rock
	var rock := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.75; sm.height = 1.1
	rock.mesh = sm; rock.material_override = stone_mat; rock.position.y = 0.45
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(rock)

	# Moss layer on top
	var moss := MeshInstance3D.new()
	var mm := SphereMesh.new(); mm.radius = 0.65; mm.height = 0.50
	moss.mesh = mm; moss.material_override = moss_mat; moss.position.y = 0.75
	group.add_child(moss)

	var col := CollisionShape3D.new()
	var sp := SphereShape3D.new(); sp.radius = 0.75
	col.shape = sp; col.position.y = 0.45
	group.add_child(col)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  ENVIRONMENTAL STORYTELLING PROPS
# ═══════════════════════════════════════════════════════════════════════════════

static func _build_abandoned_cart() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Story_AbandonedCart"
	group.collision_layer = 1; group.collision_mask = 3

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.35, 0.22, 0.14); wood_mat.roughness = 0.90

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.22, 0.22, 0.24); iron_mat.metallic = 0.80

	# Cart bed
	var bed := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(1.4, 0.35, 2.2)
	bed.mesh = bm; bed.material_override = wood_mat; bed.position.y = 0.50
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(bed)

	# Cargo crates in cart
	for i in range(2):
		var crate := MeshInstance3D.new()
		var cm := BoxMesh.new(); cm.size = Vector3(0.55, 0.55, 0.55)
		crate.mesh = cm; crate.material_override = wood_mat
		crate.position = Vector3((i - 0.5) * 0.6, 0.90, (i - 0.5) * 0.6)
		group.add_child(crate)

	# 2 Large wheels
	for side in [-1, 1]:
		var wheel := MeshInstance3D.new()
		var wm := CylinderMesh.new(); wm.top_radius = 0.50; wm.bottom_radius = 0.50; wm.height = 0.08
		wheel.mesh = wm; wheel.material_override = iron_mat
		wheel.position = Vector3(side * 0.80, 0.50, 0.0)
		wheel.rotation.z = deg_to_rad(90.0)
		group.add_child(wheel)

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new(); box_col.size = Vector3(1.8, 1.2, 2.4)
	col.shape = box_col; col.position.y = 0.60
	group.add_child(col)

	return group


static func _build_animal_skull() -> Node3D:
	var group := Node3D.new()
	group.name = "Story_AnimalSkull"

	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.88, 0.84, 0.74); bone_mat.roughness = 0.60

	# Skull base
	var skull := MeshInstance3D.new()
	var sm := BoxMesh.new(); sm.size = Vector3(0.35, 0.28, 0.55)
	skull.mesh = sm; skull.material_override = bone_mat; skull.position.y = 0.14
	group.add_child(skull)

	# Antler horns
	for side in [-1, 1]:
		var horn := MeshInstance3D.new()
		var hm := CylinderMesh.new(); hm.top_radius = 0.01; hm.bottom_radius = 0.04; hm.height = 0.75
		horn.mesh = hm; horn.material_override = bone_mat
		horn.position = Vector3(side * 0.22, 0.45, -0.15)
		horn.rotation.z = side * deg_to_rad(35.0)
		group.add_child(horn)

	return group


static func _build_torch_post() -> Node3D:
	var group := Node3D.new()
	group.name = "Story_TorchPost"

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.28, 0.18, 0.12); wood_mat.roughness = 0.90

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.20, 0.20, 0.22); iron_mat.metallic = 0.85

	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.55, 0.12)
	fire_mat.emission_enabled = true; fire_mat.emission = Color(1.0, 0.50, 0.10); fire_mat.emission_energy_multiplier = 2.2

	# Post
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 0.06; pm.bottom_radius = 0.08; pm.height = 1.8
	post.mesh = pm; post.material_override = wood_mat; post.position.y = 0.90
	group.add_child(post)

	# Iron bowl
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new(); bm.top_radius = 0.18; bm.bottom_radius = 0.10; bm.height = 0.18
	bowl.mesh = bm; bowl.material_override = iron_mat; bowl.position.y = 1.85
	group.add_child(bowl)

	# Fire embers
	var fire := MeshInstance3D.new()
	var fm := SphereMesh.new(); fm.radius = 0.12; fm.height = 0.22
	fire.mesh = fm; fire.material_override = fire_mat; fire.position.y = 1.98
	group.add_child(fire)

	# Soft warm point light
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.25); light.light_energy = 2.2; light.omni_range = 7.0
	light.position.y = 2.0
	group.add_child(light)

	return group


static func _build_stone_circle() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Story_StoneCircle"
	group.collision_layer = 1; group.collision_mask = 3

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.35, 0.34, 0.32); stone_mat.roughness = 0.92

	# 6 Standing megalith stones in a circle
	for i in range(6):
		var ang = (i / 6.0) * TAU
		var stone := MeshInstance3D.new()
		var sm := BoxMesh.new(); sm.size = Vector3(0.55, 1.8 + randf() * 0.4, 0.35)
		stone.mesh = sm; stone.material_override = stone_mat
		stone.position = Vector3(cos(ang) * 2.2, sm.size.y * 0.5, sin(ang) * 2.2)
		stone.rotation.y = ang + deg_to_rad(randf_range(-15.0, 15.0))
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(stone)

	var col := CollisionShape3D.new()
	var sp := SphereShape3D.new(); sp.radius = 2.4
	col.shape = sp; col.position.y = 0.9
	group.add_child(col)

	return group


static func _build_broken_weapons() -> Node3D:
	var group := Node3D.new()
	group.name = "Story_BrokenWeapons"

	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.60, 0.62, 0.65); metal_mat.metallic = 0.85

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.35, 0.22, 0.14)

	# Sword stuck in ground at angle
	var sword := MeshInstance3D.new()
	var sm := BoxMesh.new(); sm.size = Vector3(0.08, 0.90, 0.02)
	sword.mesh = sm; sword.material_override = metal_mat
	sword.position = Vector3(0.10, 0.30, 0)
	sword.rotation = Vector3(deg_to_rad(25.0), deg_to_rad(15.0), deg_to_rad(-20.0))
	group.add_child(sword)

	# Broken wooden shield half
	var shield := MeshInstance3D.new()
	var shm := BoxMesh.new(); shm.size = Vector3(0.50, 0.04, 0.28)
	shield.mesh = shm; shield.material_override = wood_mat
	shield.position = Vector3(-0.25, 0.02, 0.15)
	shield.rotation.y = deg_to_rad(40.0)
	group.add_child(shield)

	return group


static func _build_hanging_lantern_post() -> Node3D:
	var group := Node3D.new()
	group.name = "Story_LanternPost"

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.18, 0.18, 0.20); iron_mat.metallic = 0.90

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(1.0, 0.80, 0.30)
	glass_mat.emission_enabled = true; glass_mat.emission = Color(1.0, 0.75, 0.20); glass_mat.emission_energy_multiplier = 2.0

	# Iron pole
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 0.04; pm.bottom_radius = 0.06; pm.height = 2.4
	pole.mesh = pm; pole.material_override = iron_mat; pole.position.y = 1.2
	group.add_child(pole)

	# Curved arm
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new(); am.size = Vector3(0.60, 0.05, 0.05)
	arm.mesh = am; arm.material_override = iron_mat; arm.position = Vector3(0.25, 2.35, 0)
	group.add_child(arm)

	# Hanging lantern
	var lantern := MeshInstance3D.new()
	var lm := BoxMesh.new(); lm.size = Vector3(0.18, 0.26, 0.18)
	lantern.mesh = lm; lantern.material_override = glass_mat; lantern.position = Vector3(0.50, 2.10, 0)
	group.add_child(lantern)

	# Point light
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.80, 0.35); light.light_energy = 2.0; light.omni_range = 8.0
	light.position = Vector3(0.50, 2.0, 0)
	group.add_child(light)

	return group


static func _build_warning_sign() -> Node3D:
	var group := Node3D.new()
	group.name = "Story_WarningSign"

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.38, 0.25, 0.16); wood_mat.roughness = 0.92

	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.55, 0.18, 0.14)

	# Post
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 0.05; pm.bottom_radius = 0.06; pm.height = 1.4
	post.mesh = pm; post.material_override = wood_mat; post.position.y = 0.70
	group.add_child(post)

	# Warning board
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.70, 0.35, 0.04)
	board.mesh = bm; board.material_override = sign_mat; board.position = Vector3(0, 1.2, 0)
	group.add_child(board)

	return group


static func _build_bone_pile() -> Node3D:
	var group := Node3D.new()
	group.name = "Story_BonePile"

	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.85, 0.82, 0.72); bone_mat.roughness = 0.65

	for i in range(6):
		var bone := MeshInstance3D.new()
		var bm := CylinderMesh.new(); bm.top_radius = 0.03; bm.bottom_radius = 0.03; bm.height = 0.45
		bone.mesh = bm; bone.material_override = bone_mat
		var ang = (i / 6.0) * TAU
		bone.position = Vector3(cos(ang) * 0.15, 0.04 + i * 0.02, sin(ang) * 0.15)
		bone.rotation = Vector3(deg_to_rad(randf_range(70.0, 90.0)), randf() * TAU, 0)
		group.add_child(bone)

	return group


static func _build_fallen_banner() -> Node3D:
	var group := Node3D.new()
	group.name = "Story_FallenBanner"

	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.30, 0.20, 0.12)

	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = Color(0.65, 0.15, 0.18); cloth_mat.roughness = 0.80

	# Broken pole
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 0.03; pm.bottom_radius = 0.03; pm.height = 1.5
	pole.mesh = pm; pole.material_override = pole_mat
	pole.position = Vector3(0, 0.15, 0)
	pole.rotation = Vector3(deg_to_rad(75.0), deg_to_rad(20.0), 0)
	group.add_child(pole)

	# Draped torn banner cloth
	var cloth := MeshInstance3D.new()
	var cm := BoxMesh.new(); cm.size = Vector3(0.55, 0.02, 1.1)
	cloth.mesh = cm; cloth.material_override = cloth_mat; cloth.position = Vector3(0.20, 0.03, 0.20)
	cloth.rotation.y = deg_to_rad(15.0)
	group.add_child(cloth)

	return group


static func _build_vine_archway() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Story_VineArchway"
	group.collision_layer = 1; group.collision_mask = 3

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.25, 0.16, 0.10); wood_mat.roughness = 0.95

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.18, 0.44, 0.16); leaf_mat.roughness = 0.80

	# 2 Curved trunk pillars
	for side in [-1, 1]:
		var trunk := MeshInstance3D.new()
		var tm := CylinderMesh.new(); tm.top_radius = 0.20; tm.bottom_radius = 0.28; tm.height = 3.2
		trunk.mesh = tm; trunk.material_override = wood_mat
		trunk.position = Vector3(side * 1.5, 1.6, 0)
		trunk.rotation.z = side * deg_to_rad(-15.0)
		group.add_child(trunk)

	# Overarching leaf canopy
	var arch := MeshInstance3D.new()
	var am := BoxMesh.new(); am.size = Vector3(3.4, 0.60, 0.80)
	arch.mesh = am; arch.material_override = leaf_mat; arch.position = Vector3(0, 3.1, 0)
	group.add_child(arch)

	return group

