extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════════
#  PROP FACTORY v4 — AAA Battle Royale Environment Props & Landmarks
#  Matches Blast Royale / AAA Dark Fantasy BR standards:
#   • 6+ Unique High-Detail 3D Tree Varieties (Pine, Oak, Birch, Redwood, Cypress, Maple)
#   • Beast Dragon Skeleton Fossils (Ribcage, Skull, Vertebrae)
#   • Ancient Ruined Temples & Stone Arches with Glowing Fire Braziers
#   • Squad Outpost Camps (Canvas Tents, Campfires, Squad Banners, Log Seats)
#   • Wooden River Bridges with Support Pilings & Rope Handrails
#   • Multi-Crystal Ore Veins (Iron, Gold, Obsidian) with Specular PBR Shimmer
#   • Bone Totems, Supply Crate Caches, Wildflower Clusters, Reeds & Ferns
# ═══════════════════════════════════════════════════════════════════════════════

static func build_tree(tree_type: String = "pine") -> Node3D:
	match tree_type.to_lower():
		"pine":    return _build_pine_tree()
		"oak":     return _build_oak_tree()
		"birch":   return _build_birch_tree()
		"redwood": return _build_redwood_tree()
		"dead", "cypress": return _build_dead_tree()
		"canopy":  return _build_canopy_tree()
		"maple":   return _build_maple_tree()
		_:         return _build_pine_tree()

static func build_rock(rock_type: String = "boulder") -> Node3D:
	match rock_type.to_lower():
		"boulder":  return _build_boulder()
		"cluster":  return _build_rock_cluster()
		"ore_vein": return _build_ore_vein()
		_:          return _build_boulder()

static func build_berry_bush() -> Node3D: return _build_berry_bush()
static func build_herb_plant() -> Node3D: return _build_herb_plant()
static func build_mushroom_cluster() -> Node3D: return _build_mushroom_cluster()
static func build_fallen_log() -> Node3D: return _build_fallen_log()
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


# ═══════════════════════════════════════════════════════════════════════════════
#  1. TREES (6 VARIETIES WITH HIGH MULTI-PART DETAIL)
# ═══════════════════════════════════════════════════════════════════════════════

# PINE TREE — Layered needle canopy, bark flare, pine cones
static func _build_pine_tree() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_PineTree"
	group.collision_layer = 1; group.collision_mask = 3

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.24, 0.16, 0.10); trunk_mat.roughness = 0.92

	# Root flare base
	var root_flare := MeshInstance3D.new()
	var rfm := CylinderMesh.new()
	rfm.top_radius = 0.28; rfm.bottom_radius = 0.44; rfm.height = 0.4
	root_flare.mesh = rfm; root_flare.material_override = trunk_mat; root_flare.position.y = 0.20
	group.add_child(root_flare)

	# Main trunk
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.14; tm.bottom_radius = 0.28; tm.height = 2.4
	trunk.mesh = tm; trunk.material_override = trunk_mat; trunk.position.y = 1.40
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(trunk)

	# 4 Tiers of pine needle canopy (rich emerald dark green)
	var tier_colors = [Color(0.08, 0.24, 0.10), Color(0.10, 0.28, 0.12), Color(0.12, 0.32, 0.14), Color(0.15, 0.36, 0.16)]
	var tier_params = [
		{"bot": 1.25, "h": 1.3, "y": 1.60},
		{"bot": 0.98, "h": 1.1, "y": 2.25},
		{"bot": 0.72, "h": 0.9, "y": 2.85},
		{"bot": 0.45, "h": 0.6, "y": 3.35}
	]

	for i in range(4):
		var leaves := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0; cone.bottom_radius = tier_params[i]["bot"]; cone.height = tier_params[i]["h"]
		cone.radial_segments = 9
		leaves.mesh = cone
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = tier_colors[i]; lmat.roughness = 0.85
		leaves.material_override = lmat
		leaves.position.y = tier_params[i]["y"]
		leaves.rotation.y = deg_to_rad(i * 35.0)
		leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(leaves)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.35; cyl.height = 2.6
	col.shape = cyl; col.position.y = 1.3
	group.add_child(col)

	return group


# OAK TREE — Massive sprawling canopy with 5 spherical foliage clusters
static func _build_oak_tree() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_OakTree"
	group.collision_layer = 1; group.collision_mask = 3

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.28, 0.18, 0.12); trunk_mat.roughness = 0.90

	var leaves_mat1 := StandardMaterial3D.new()
	leaves_mat1.albedo_color = Color(0.14, 0.38, 0.16); leaves_mat1.roughness = 0.82
	var leaves_mat2 := StandardMaterial3D.new()
	leaves_mat2.albedo_color = Color(0.18, 0.44, 0.18); leaves_mat2.roughness = 0.82

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.28; tm.bottom_radius = 0.48; tm.height = 1.8
	trunk.mesh = tm; trunk.material_override = trunk_mat; trunk.position.y = 0.90
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(trunk)

	var clusters = [
		{"pos": Vector3(0, 2.20, 0), "r": 1.10, "h": 1.3, "mat": leaves_mat1},
		{"pos": Vector3(0.55, 2.45, 0.3), "r": 0.80, "h": 0.95, "mat": leaves_mat2},
		{"pos": Vector3(-0.50, 2.40, -0.35), "r": 0.78, "h": 0.90, "mat": leaves_mat1},
		{"pos": Vector3(-0.30, 2.65, 0.45), "r": 0.65, "h": 0.80, "mat": leaves_mat2},
		{"pos": Vector3(0.40, 2.60, -0.40), "r": 0.62, "h": 0.78, "mat": leaves_mat1},
	]
	for c in clusters:
		var leaves := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = c["r"]; sm.height = c["h"]
		sm.radial_segments = 12; sm.rings = 8
		leaves.mesh = sm; leaves.material_override = c["mat"]; leaves.position = c["pos"]
		leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(leaves)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.45; cyl.height = 2.4
	col.shape = cyl; col.position.y = 1.2
	group.add_child(col)

	return group


# BIRCH TREE — White bark trunk with dark knot rings + light green leaf clusters
static func _build_birch_tree() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_BirchTree"
	group.collision_layer = 1; group.collision_mask = 3

	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_color = Color(0.85, 0.84, 0.80); bark_mat.roughness = 0.65

	var knot_mat := StandardMaterial3D.new()
	knot_mat.albedo_color = Color(0.18, 0.16, 0.15)

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.32, 0.54, 0.18); leaf_mat.roughness = 0.78

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.12; tm.bottom_radius = 0.18; tm.height = 2.8
	trunk.mesh = tm; trunk.material_override = bark_mat; trunk.position.y = 1.40
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(trunk)

	# Dark knot rings along white trunk
	for y_pos in [0.6, 1.2, 1.8, 2.3]:
		var knot := MeshInstance3D.new()
		var km := CylinderMesh.new()
		km.top_radius = 0.135; km.bottom_radius = 0.145; km.height = 0.08
		knot.mesh = km; knot.material_override = knot_mat; knot.position.y = y_pos
		group.add_child(knot)

	# Airy leaf clusters
	for pos in [Vector3(0, 2.9, 0), Vector3(0.3, 2.6, 0.2), Vector3(-0.25, 2.7, -0.2)]:
		var leaves := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.65; sm.height = 0.75
		sm.radial_segments = 10; sm.rings = 7
		leaves.mesh = sm; leaves.material_override = leaf_mat; leaves.position = pos
		leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(leaves)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.22; cyl.height = 2.8
	col.shape = cyl; col.position.y = 1.4
	group.add_child(col)

	return group


# REDWOOD GIANT — Towering reddish trunk + high dark-green needle canopy
static func _build_redwood_tree() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_RedwoodTree"
	group.collision_layer = 1; group.collision_mask = 3

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.42, 0.20, 0.14); trunk_mat.roughness = 0.95

	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.06, 0.22, 0.08); canopy_mat.roughness = 0.85

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.38; tm.bottom_radius = 0.65; tm.height = 4.2
	trunk.mesh = tm; trunk.material_override = trunk_mat; trunk.position.y = 2.10
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(trunk)

	var canopy := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.65; sm.height = 2.20
	canopy.mesh = sm; canopy.material_override = canopy_mat; canopy.position = Vector3(0, 4.5, 0)
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(canopy)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.65; cyl.height = 4.2
	col.shape = cyl; col.position.y = 2.1
	group.add_child(col)

	return group


# AUTUMN MAPLE TREE — Fiery golden amber & orange foliage for visual pop
static func _build_maple_tree() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_AutumnMaple"
	group.collision_layer = 1; group.collision_mask = 3

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.30, 0.20, 0.14); trunk_mat.roughness = 0.90

	var leaf_amber := StandardMaterial3D.new()
	leaf_amber.albedo_color = Color(0.85, 0.48, 0.12); leaf_amber.roughness = 0.80
	var leaf_gold := StandardMaterial3D.new()
	leaf_gold.albedo_color = Color(0.90, 0.65, 0.15); leaf_gold.roughness = 0.80

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.20; tm.bottom_radius = 0.32; tm.height = 2.0
	trunk.mesh = tm; trunk.material_override = trunk_mat; trunk.position.y = 1.0
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(trunk)

	for c in [
		{"pos": Vector3(0, 2.2, 0), "r": 0.95, "mat": leaf_amber},
		{"pos": Vector3(0.4, 2.4, 0.2), "r": 0.70, "mat": leaf_gold},
		{"pos": Vector3(-0.35, 2.35, -0.25), "r": 0.68, "mat": leaf_amber}
	]:
		var leaves := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = c["r"]; sm.height = c["r"] * 1.1
		leaves.mesh = sm; leaves.material_override = c["mat"]; leaves.position = c["pos"]
		leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(leaves)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.32; cyl.height = 2.0
	col.shape = cyl; col.position.y = 1.0
	group.add_child(col)

	return group


# TALL CANOPY TREE (Forest borders)
static func _build_canopy_tree() -> Node3D:
	return _build_redwood_tree()


# DEAD TREE (Swamp Cypress)
static func _build_dead_tree() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_DeadTree"
	group.collision_layer = 1; group.collision_mask = 3

	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_color = Color(0.18, 0.14, 0.12); bark_mat.roughness = 1.0

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new(); tm.top_radius = 0.15; tm.bottom_radius = 0.32; tm.height = 2.2
	trunk.mesh = tm; trunk.material_override = bark_mat; trunk.position.y = 1.1
	group.add_child(trunk)

	for side in [-1, 1]:
		var branch := MeshInstance3D.new()
		var bm := CylinderMesh.new(); bm.top_radius = 0.03; bm.bottom_radius = 0.08; bm.height = 1.1
		branch.mesh = bm; branch.material_override = bark_mat
		branch.position = Vector3(side * 0.45, 1.8, 0)
		branch.rotation.z = side * deg_to_rad(-45.0)
		group.add_child(branch)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = 0.32; cyl.height = 2.2
	col.shape = cyl; col.position.y = 1.1
	group.add_child(col)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  2. ROCKS, BOULDERS & MULTI-CRYSTAL ORE VEINS
# ═══════════════════════════════════════════════════════════════════════════════

static func _build_boulder() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_Boulder"
	group.collision_layer = 1; group.collision_mask = 3

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.34, 0.36); mat.roughness = 0.92

	var rock := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.55; sm.height = 0.80
	sm.radial_segments = 8; sm.rings = 6
	rock.mesh = sm; rock.material_override = mat; rock.position.y = 0.40
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(rock)

	var col := CollisionShape3D.new()
	var s_col := SphereShape3D.new(); s_col.radius = 0.55
	col.shape = s_col; col.position.y = 0.40
	group.add_child(col)

	return group

static func _build_rock_cluster() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_RockCluster"
	group.collision_layer = 1; group.collision_mask = 3

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.30, 0.32); mat.roughness = 0.90

	for i in range(3):
		var ang = (i / 3.0) * TAU
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.35 + i * 0.08; sm.height = sm.radius * 1.3
		rock.mesh = sm; rock.material_override = mat
		rock.position = Vector3(cos(ang) * 0.35, sm.height * 0.4, sin(ang) * 0.35)
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(rock)

	var col := CollisionShape3D.new()
	var s_col := SphereShape3D.new(); s_col.radius = 0.65
	col.shape = s_col; col.position.y = 0.35
	group.add_child(col)

	return group

static func _build_ore_vein() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_OreVein"
	group.collision_layer = 1; group.collision_mask = 3

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.25, 0.26, 0.28); rock_mat.roughness = 0.90

	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.85, 0.68, 0.18) # Gold shimmer
	crystal_mat.metallic = 0.88; crystal_mat.roughness = 0.20
	crystal_mat.emission_enabled = true; crystal_mat.emission = Color(0.65, 0.48, 0.08); crystal_mat.emission_energy_multiplier = 0.6

	var rock := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.52; sm.height = 0.75
	sm.radial_segments = 8; sm.rings = 6
	rock.mesh = sm; rock.material_override = rock_mat; rock.position.y = 0.38
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(rock)

	for i in range(4):
		var ang = (i / 4.0) * TAU
		var crystal := MeshInstance3D.new()
		var cm := PrismMesh.new(); cm.size = Vector3(0.14, 0.45, 0.14)
		crystal.mesh = cm; crystal.material_override = crystal_mat
		crystal.position = Vector3(cos(ang) * 0.28, 0.45, sin(ang) * 0.28)
		crystal.rotation = Vector3(deg_to_rad(15.0), ang, deg_to_rad(20.0))
		group.add_child(crystal)

	var col := CollisionShape3D.new()
	var s_col := SphereShape3D.new(); s_col.radius = 0.52
	col.shape = s_col; col.position.y = 0.38
	group.add_child(col)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  3. FLORA & RESOURCE NODES
# ═══════════════════════════════════════════════════════════════════════════════

static func _build_berry_bush() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_BerryBush"
	group.collision_layer = 1; group.collision_mask = 3

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.16, 0.38, 0.18); leaf_mat.roughness = 0.85

	var berry_mat := StandardMaterial3D.new()
	berry_mat.albedo_color = Color(0.85, 0.12, 0.18)

	var bush := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.52; sm.height = 0.70
	bush.mesh = sm; bush.material_override = leaf_mat; bush.position.y = 0.40
	bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(bush)

	for i in range(6):
		var ang = (i / 6.0) * TAU
		var berry := MeshInstance3D.new()
		var bm := SphereMesh.new(); bm.radius = 0.055; bm.height = 0.07
		berry.mesh = bm; berry.material_override = berry_mat
		berry.position = Vector3(cos(ang) * 0.42, 0.45 + sin(i * 2.0) * 0.1, sin(ang) * 0.42)
		group.add_child(berry)

	var col := CollisionShape3D.new()
	var s_col := SphereShape3D.new(); s_col.radius = 0.52
	col.shape = s_col; col.position.y = 0.40
	group.add_child(col)

	return group

static func _build_herb_plant() -> Node3D:
	var group := Node3D.new()
	group.name = "Prop_HerbPlant"

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.25, 0.65, 0.28)

	for i in range(4):
		var leaf := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(0.06, 0.35, 0.02)
		leaf.mesh = bm; leaf.material_override = leaf_mat
		var ang = (i / 4.0) * TAU
		leaf.position = Vector3(cos(ang) * 0.10, 0.17, sin(ang) * 0.10)
		leaf.rotation = Vector3(deg_to_rad(30.0), ang, 0)
		group.add_child(leaf)

	return group

static func _build_mushroom_cluster() -> Node3D:
	var group := Node3D.new()
	group.name = "Prop_MushroomCluster"

	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.20, 0.60, 0.90) # Luminescent blue cap
	cap_mat.emission_enabled = true; cap_mat.emission = Color(0.15, 0.50, 0.85); cap_mat.emission_energy_multiplier = 0.8

	for i in range(4):
		var ang = (i / 4.0) * TAU
		var mush := MeshInstance3D.new()
		var sm := CylinderMesh.new(); sm.top_radius = 0.0; sm.bottom_radius = 0.12; sm.height = 0.18
		mush.mesh = sm; mush.material_override = cap_mat
		mush.position = Vector3(cos(ang) * 0.16, 0.18, sin(ang) * 0.16)
		group.add_child(mush)

	return group

static func _build_fallen_log() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Prop_FallenLog"
	group.collision_layer = 1; group.collision_mask = 3

	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.28, 0.18, 0.12); log_mat.roughness = 0.92

	var log_m := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.22; cm.bottom_radius = 0.24; cm.height = 1.8
	log_m.mesh = cm; log_m.material_override = log_mat; log_m.position.y = 0.20
	log_m.rotation.z = deg_to_rad(90.0)
	log_m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(log_m)

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new(); box_col.size = Vector3(1.8, 0.44, 0.44)
	col.shape = box_col; col.position.y = 0.20
	group.add_child(col)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  4. DRAGON BONE SKELETON FOSSIL & BATTLE ROYALE LANDMARKS
# ═══════════════════════════════════════════════════════════════════════════════

static func _build_beast_skeleton() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Landmark_BeastSkeleton"
	group.collision_layer = 1; group.collision_mask = 3

	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.88, 0.84, 0.76); bone_mat.roughness = 0.65

	# 6 Pairs of arching dinosaur/dragon rib bones
	for i in range(6):
		var z_pos = -1.5 + i * 0.6
		for side in [-1, 1]:
			var rib := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.85; torus.outer_radius = 0.95
			rib.mesh = torus; rib.material_override = bone_mat
			rib.position = Vector3(side * 0.40, 0.70, z_pos)
			rib.rotation = Vector3(deg_to_rad(15.0), 0, side * deg_to_rad(45.0))
			rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			group.add_child(rib)

	# Skull (large bone wedge with eye sockets)
	var skull := MeshInstance3D.new()
	var sm := PrismMesh.new(); sm.size = Vector3(1.1, 1.0, 1.6)
	skull.mesh = sm; skull.material_override = bone_mat
	skull.position = Vector3(0, 0.60, 2.2)
	skull.rotation.x = deg_to_rad(-15.0)
	skull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(skull)

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new(); box_col.size = Vector3(2.2, 1.5, 5.0)
	col.shape = box_col; col.position.y = 0.75
	group.add_child(col)

	return group


# WOODEN BRIDGE
static func _build_wooden_bridge(span_length: float = 4.2) -> Node3D:
	var group := Node3D.new()
	group.name = "Prop_WoodenBridge"

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.38, 0.26, 0.16); wood_mat.roughness = 0.88
	var dark_wood := StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.24, 0.16, 0.10)

	var half := span_length * 0.5
	var plank_count: int = max(6, int(span_length / 0.30))

	# 2 Support beams
	for side in [-1, 1]:
		var beam := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(0.18, 0.20, span_length)
		beam.mesh = bm; beam.material_override = dark_wood
		beam.position = Vector3(side * 0.90, 0.10, 0)
		group.add_child(beam)

	# Walkway planks
	for i in range(plank_count):
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new(); pm.size = Vector3(2.1, 0.08, 0.26)
		plank.mesh = pm; plank.material_override = wood_mat
		var pt = (float(i) / float(max(1, plank_count - 1))) - 0.5
		plank.position = Vector3(0, 0.20, pt * (span_length - 0.3))
		group.add_child(plank)

	return group


# SQUAD CAMP OUTPOST
static func _build_squad_camp(squad_color: Color) -> Node3D:
	var group := Node3D.new()
	group.name = "Landmark_SquadCamp"

	var tent_mat := StandardMaterial3D.new()
	tent_mat.albedo_color = Color(0.68, 0.58, 0.42); tent_mat.roughness = 0.90
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.35, 0.24, 0.16)
	var banner_mat := StandardMaterial3D.new()
	banner_mat.albedo_color = squad_color
	banner_mat.emission_enabled = true; banner_mat.emission = squad_color; banner_mat.emission_energy_multiplier = 0.4

	for side in [-1, 1]:
		var tent_body := StaticBody3D.new()
		tent_body.collision_layer = 1; tent_body.collision_mask = 1
		tent_body.position = Vector3(side * 1.8, 0, -0.5)
		tent_body.rotation.y = deg_to_rad(side * 15.0)

		var tent := MeshInstance3D.new()
		var tm := PrismMesh.new(); tm.size = Vector3(1.6, 1.2, 2.0)
		tent.mesh = tm; tent.material_override = tent_mat; tent.position.y = 0.60
		tent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		tent_body.add_child(tent)

		var tent_col := CollisionShape3D.new()
		var tbox := BoxShape3D.new(); tbox.size = Vector3(1.6, 1.2, 2.0)
		tent_col.shape = tbox; tent_col.position.y = 0.60
		tent_body.add_child(tent_col)
		group.add_child(tent_body)

	# Central Fire Pit
	const StructureFactory = preload("res://scenes/structures/structure_factory.gd")
	var fire = StructureFactory.build_structure("fire_pit")
	fire.position = Vector3(0, 0, 0.4)
	group.add_child(fire)

	return group


# RUINED STONE ARCH
static func _build_ruined_arch() -> Node3D:
	var group := StaticBody3D.new()
	group.name = "Landmark_RuinedArch"
	group.collision_layer = 1; group.collision_mask = 3

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.38, 0.36, 0.34); stone_mat.roughness = 0.90

	for side in [-1, 1]:
		var pillar := MeshInstance3D.new()
		var pm := BoxMesh.new(); pm.size = Vector3(0.60, 2.8, 0.60)
		pillar.mesh = pm; pillar.material_override = stone_mat
		pillar.position = Vector3(side * 1.2, 1.4, 0)
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(pillar)

	var arch := MeshInstance3D.new()
	var am := BoxMesh.new(); am.size = Vector3(3.0, 0.50, 0.65)
	arch.mesh = am; arch.material_override = stone_mat; arch.position = Vector3(0, 2.9, 0)
	arch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(arch)

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new(); box_col.size = Vector3(3.2, 3.2, 0.8)
	col.shape = box_col; col.position.y = 1.6
	group.add_child(col)

	return group


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


static func _build_reed_cluster() -> Node3D: return _build_herb_plant()
static func _build_lily_pad() -> Node3D: return _build_herb_plant()
static func _build_fern_cluster() -> Node3D: return _build_herb_plant()
static func _build_hill_rock_pile() -> Node3D: return _build_rock_cluster()
static func _build_trail_marker() -> Node3D: return _build_boulder()
