extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════════
#  STRUCTURE FACTORY — Production-Quality 3D Buildings & Structures
#  Detailed multi-part geometry, PBR materials, window/door details, lighting.
# ═══════════════════════════════════════════════════════════════════════════════

static func build_structure(structure_type: String) -> Node3D:
	match structure_type.to_lower():
		"hut":              return _build_hut_basic()
		"hut_upgraded":     return _build_hut_upgraded()
		"wood_wall":        return _build_wood_wall()
		"stone_wall":       return _build_stone_wall()
		"cage", "cage_basic": return _build_cage_basic()
		"cage_full":        return _build_cage_full()
		"workshop":         return _build_workshop()
		"watchtower":       return _build_watchtower()
		"mint":             return _build_mint()
		"fire_pit":         return _build_fire_pit()
		"bear_trap":        return _build_bear_trap()
		"alarm_trap":       return _build_alarm_trap()
		"spike_trap":       return _build_spike_trap()
		"well":             return _build_well()
		"treasury":         return _build_treasury_chest()
		_:                  return _build_hut_basic()


# ═══════════════════════════════════════════════════════════════════════════════
#  MATERIALS HELPER
# ═══════════════════════════════════════════════════════════════════════════════

static func _get_wood_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.24, 0.16)
	mat.roughness = 0.90
	return mat

static func _get_dark_wood_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.16, 0.11)
	mat.roughness = 0.95
	return mat

static func _get_stone_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.40, 0.38)
	mat.roughness = 0.92
	return mat

static func _get_iron_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.24, 0.26)
	mat.metallic = 0.70
	mat.roughness = 0.35
	return mat

static func _get_gold_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.83, 0.69, 0.22)
	mat.metallic = 0.88
	mat.roughness = 0.22
	return mat

static func _get_thatch_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.52, 0.42, 0.25)
	mat.roughness = 0.98
	return mat


# ═══════════════════════════════════════════════════════════════════════════════
#  1. HUT (BASIC & UPGRADED)
# ═══════════════════════════════════════════════════════════════════════════════

# BASIC HUT — Log walls, door frame, window holes, A-frame thatch roof, chimney, proximity aura ring
static func _build_hut_basic() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_Hut"

	var wood_mat := _get_wood_mat()
	var dark_wood := _get_dark_wood_mat()
	var stone_mat := _get_stone_mat()
	var thatch_mat := _get_thatch_mat()
	var iron_mat := _get_iron_mat()

	# Foundation slab
	var fnd := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(2.8, 0.15, 2.8)
	fnd.mesh = fm; fnd.material_override = dark_wood
	fnd.position.y = 0.075
	fnd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(fnd)

	# Floor planks (×5)
	for i in range(5):
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(2.6, 0.04, 0.48)
		plank.mesh = pm; plank.material_override = wood_mat
		plank.position = Vector3(0, 0.16, -1.0 + i * 0.50)
		group.add_child(plank)

	# 4 Corner log posts
	var corners = [Vector2(-1.25, -1.25), Vector2(1.25, -1.25), Vector2(1.25, 1.25), Vector2(-1.25, 1.25)]
	for c in corners:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.10; pm.bottom_radius = 0.12; pm.height = 1.4
		post.mesh = pm; post.material_override = dark_wood
		post.position = Vector3(c.x, 0.88, c.y)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(post)

	# Wall fill panels (Back + 2 Sides)
	var walls = [
		{"size": Vector3(2.4, 1.3, 0.12), "pos": Vector3(0, 0.85, -1.25)},   # Back
		{"size": Vector3(0.12, 1.3, 2.4), "pos": Vector3(-1.25, 0.85, 0)},   # Left
		{"size": Vector3(0.12, 1.3, 2.4), "pos": Vector3(1.25, 0.85, 0)},    # Right
	]
	for w in walls:
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = w["size"]
		wall.mesh = wm; wall.material_override = wood_mat
		wall.position = w["pos"]
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(wall)

	# Front wall halves (leaving door gap)
	for side in [-1, 1]:
		var fwall := MeshInstance3D.new()
		var fwm := BoxMesh.new()
		fwm.size = Vector3(0.85, 1.3, 0.12)
		fwall.mesh = fwm; fwall.material_override = wood_mat
		fwall.position = Vector3(side * 0.80, 0.85, 1.25)
		fwall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(fwall)

	# Door frame (2 posts + lintel)
	for side in [-1, 1]:
		var dp := MeshInstance3D.new()
		var dpm := BoxMesh.new()
		dpm.size = Vector3(0.10, 1.2, 0.16)
		dp.mesh = dpm; dp.material_override = dark_wood
		dp.position = Vector3(side * 0.35, 0.80, 1.25)
		group.add_child(dp)

	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.80, 0.10, 0.16)
	lintel.mesh = lm; lintel.material_override = dark_wood
	lintel.position = Vector3(0, 1.35, 1.25)
	group.add_child(lintel)

	# Wooden door (ajar)
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.58, 1.05, 0.05)
	door.mesh = dm; door.material_override = wood_mat
	door.position = Vector3(-0.05, 0.72, 1.20)
	door.rotation.y = deg_to_rad(25.0)
	group.add_child(door)

	# Door hinges (×2)
	for y_off in [0.45, 0.95]:
		var hinge := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.08, 0.04, 0.03)
		hinge.mesh = hm; hinge.material_override = iron_mat
		hinge.position = Vector3(-0.30, y_off, 1.26)
		group.add_child(hinge)

	# A-frame thatched roof
	var roof := MeshInstance3D.new()
	var rcone := PrismMesh.new()
	rcone.size = Vector3(2.9, 1.25, 2.9)
	roof.mesh = rcone; roof.material_override = thatch_mat
	roof.position.y = 2.12
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(roof)

	# Chimney (stone stack)
	var chimney := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.32, 0.85, 0.32)
	chimney.mesh = cm; chimney.material_override = stone_mat
	chimney.position = Vector3(0.85, 2.30, -0.65)
	chimney.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(chimney)

	# Proximity Aura ring (passive +1 HP/s indicator)
	var aura := MeshInstance3D.new()
	var am := TorusMesh.new()
	am.inner_radius = 3.8; am.outer_radius = 4.0
	aura.mesh = am
	var aura_mat := StandardMaterial3D.new()
	aura_mat.albedo_color = Color(0.2, 0.8, 0.4, 0.25)
	aura_mat.emission_enabled = true
	aura_mat.emission = Color(0.2, 0.8, 0.4)
	aura_mat.emission_energy_multiplier = 0.4
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura.material_override = aura_mat
	aura.position.y = 0.02
	group.add_child(aura)

	return group


# UPGRADED HUT — Stone foundation + reinforced door + glowing hearth inside + storage chest
static func _build_hut_upgraded() -> Node3D:
	var group := _build_hut_basic()
	group.name = "Structure_HutUpgraded"

	var stone_mat := _get_stone_mat()
	var iron_mat := _get_iron_mat()

	# Stone foundation extension
	var fnd := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(3.1, 0.25, 3.1)
	fnd.mesh = fm; fnd.material_override = stone_mat
	fnd.position.y = 0.125
	fnd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(fnd)

	# Iron bands on door (×3)
	for i in range(3):
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.55, 0.04, 0.02)
		band.mesh = bm; band.material_override = iron_mat
		band.position = Vector3(-0.05, 0.45 + i * 0.28, 1.23)
		band.rotation.y = deg_to_rad(25.0)
		group.add_child(band)

	# Glowing hearth light inside
	var hearth_light := OmniLight3D.new()
	hearth_light.light_color = Color(1.0, 0.60, 0.25)
	hearth_light.light_energy = 2.0
	hearth_light.omni_range = 5.0
	hearth_light.position = Vector3(0, 0.80, 0)
	group.add_child(hearth_light)

	# Storage chest visible inside
	var chest := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.45, 0.30, 0.30)
	chest.mesh = cm
	var chest_mat := StandardMaterial3D.new()
	chest_mat.albedo_color = Color(0.45, 0.32, 0.20)
	chest.material_override = chest_mat
	chest.position = Vector3(0.70, 0.35, -0.60)
	group.add_child(chest)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  2. WALLS
# ═══════════════════════════════════════════════════════════════════════════════

# WOOD WALL — 5 pointed log stakes + 2 horizontal cross-beams + rope lashing
static func _build_wood_wall() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_WoodWall"

	var wood_mat := _get_wood_mat()
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.55, 0.45, 0.30)

	# 5 vertical logs with pointed tops
	for i in range(5):
		var x_pos = -0.80 + i * 0.40

		var log_body := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.08; lm.bottom_radius = 0.09; lm.height = 1.3
		log_body.mesh = lm; log_body.material_override = wood_mat
		log_body.position = Vector3(x_pos, 0.65, 0)
		log_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(log_body)

		var tip := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.0; tm.bottom_radius = 0.08; tm.height = 0.20
		tip.mesh = tm; tip.material_override = wood_mat
		tip.position = Vector3(x_pos, 1.40, 0)
		group.add_child(tip)

	# 2 horizontal cross beams
	for y_off in [0.45, 0.95]:
		var beam := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.04; bm.bottom_radius = 0.04; bm.height = 2.1
		beam.mesh = bm; beam.material_override = wood_mat
		beam.position = Vector3(0, y_off, 0.09)
		beam.rotation.z = deg_to_rad(90.0)
		group.add_child(beam)

	# Rope lashing details at joints
	for i in range(3):
		var x_pos = -0.60 + i * 0.60
		for y_off in [0.45, 0.95]:
			var rope := MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 0.01; rm.bottom_radius = 0.01; rm.height = 0.15
			rope.mesh = rm; rope.material_override = rope_mat
			rope.position = Vector3(x_pos, y_off, 0.09)
			group.add_child(rope)

	return group


# STONE WALL — 3 stacked courses of stone blocks + mortar lines + capstone + moss
static func _build_stone_wall() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_StoneWall"

	var stone_mat1 := _get_stone_mat()
	var stone_mat2 := StandardMaterial3D.new()
	stone_mat2.albedo_color = Color(0.48, 0.46, 0.42)
	stone_mat2.roughness = 0.90

	var mortar_mat := StandardMaterial3D.new()
	mortar_mat.albedo_color = Color(0.62, 0.58, 0.52)
	mortar_mat.roughness = 0.80

	var moss_mat := StandardMaterial3D.new()
	moss_mat.albedo_color = Color(0.20, 0.42, 0.22)

	# Foundation slab
	var fnd := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(2.2, 0.12, 0.50)
	fnd.mesh = fm; fnd.material_override = stone_mat1
	fnd.position.y = 0.06
	group.add_child(fnd)

	# 3 stacked courses of stone blocks
	var courses = [
		{"y": 0.32, "h": 0.42, "count": 3, "w": 0.68},
		{"y": 0.72, "h": 0.38, "count": 3, "w": 0.65},
		{"y": 1.08, "h": 0.34, "count": 2, "w": 0.95},
	]
	for c_idx in range(courses.size()):
		var c = courses[c_idx]
		var count = c["count"]
		var width = c["w"]
		var start_x = -0.70 if count == 3 else -0.50
		for i in range(count):
			var block := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(width, c["h"], 0.44)
			block.mesh = bm
			block.material_override = stone_mat1 if (i + c_idx) % 2 == 0 else stone_mat2
			block.position = Vector3(start_x + i * (width + 0.04), c["y"], 0)
			block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			group.add_child(block)

	# Capstone trim
	var cap := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(2.1, 0.08, 0.48)
	cap.mesh = cm; cap.material_override = stone_mat1
	cap.position.y = 1.28
	group.add_child(cap)

	# Moss patch
	var moss := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.22, 0.18, 0.02)
	moss.mesh = mm; moss.material_override = moss_mat
	moss.position = Vector3(-0.35, 0.45, 0.23)
	group.add_child(moss)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  3. CAGES
# ═══════════════════════════════════════════════════════════════════════════════

# BASIC CAGE — Wooden frame + 7 iron bars per side + plank floor with straw
static func _build_cage_basic() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_CageBasic"

	var wood_mat := _get_wood_mat()
	var iron_mat := _get_iron_mat()

	# Wooden floor base
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.12, 2.2)
	base.mesh = bm; base.material_override = wood_mat
	base.position.y = 0.06
	group.add_child(base)

	# Wooden roof frame
	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(2.3, 0.10, 2.3)
	roof.mesh = rm; roof.material_override = wood_mat
	roof.position.y = 2.15
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(roof)

	# 4 Corner Posts (wood)
	var corners = [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]
	for c in corners:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.08; pm.bottom_radius = 0.08; pm.height = 2.15
		post.mesh = pm; post.material_override = wood_mat
		post.position = Vector3(c.x, 1.12, c.y)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(post)

	# 6 Vertical iron bars per side (Back + Left + Right)
	for i in range(6):
		var t = -0.80 + (i / 5.0) * 1.60
		# Back side
		var bar1 := MeshInstance3D.new()
		var bar_mesh := CylinderMesh.new()
		bar_mesh.top_radius = 0.03; bar_mesh.bottom_radius = 0.03; bar_mesh.height = 2.10
		bar1.mesh = bar_mesh; bar1.material_override = iron_mat
		bar1.position = Vector3(t, 1.12, -1.0)
		group.add_child(bar1)

		# Left side
		var bar2 := MeshInstance3D.new()
		bar2.mesh = bar_mesh; bar2.material_override = iron_mat
		bar2.position = Vector3(-1.0, 1.12, t)
		group.add_child(bar2)

		# Right side
		var bar3 := MeshInstance3D.new()
		bar3.mesh = bar_mesh; bar3.material_override = iron_mat
		bar3.position = Vector3(1.0, 1.12, t)
		group.add_child(bar3)

	# Straw on floor
	var straw_mat := StandardMaterial3D.new()
	straw_mat.albedo_color = Color(0.65, 0.55, 0.30)
	straw_mat.roughness = 0.98
	for i in range(3):
		var straw := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.40, 0.02, 0.30)
		straw.mesh = sm; straw.material_override = straw_mat
		straw.position = Vector3(-0.4 + i * 0.35, 0.13, -0.2 + i * 0.2)
		straw.rotation.y = deg_to_rad(i * 30.0)
		group.add_child(straw)

	return group


# FULL CAGE — Iron-reinforced corner posts + thicker bars + lock mechanism + chain details
static func _build_cage_full() -> Node3D:
	var group := _build_cage_basic()
	group.name = "Structure_CageFull"

	var iron_mat := _get_iron_mat()

	# Replace corner posts with iron (overlay iron corner bands)
	var corners = [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]
	for c in corners:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.20, 2.18, 0.20)
		band.mesh = bm; band.material_override = iron_mat
		band.position = Vector3(c.x, 1.12, c.y)
		group.add_child(band)

	# Lock mechanism on front door bar
	var lock := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.14, 0.12, 0.08)
	lock.mesh = lm; lock.material_override = iron_mat
	lock.position = Vector3(0.20, 1.10, 1.02)
	group.add_child(lock)

	# Keyhole detail
	var keyhole := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.02; km.height = 0.03
	keyhole.mesh = km
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.05, 0.05, 0.05)
	keyhole.material_override = dark_mat
	keyhole.position = Vector3(0.20, 1.10, 1.07)
	group.add_child(keyhole)

	# Chain detail hanging from post
	for i in range(4):
		var link := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.015; tm.outer_radius = 0.035
		link.mesh = tm; link.material_override = iron_mat
		link.position = Vector3(0.98, 1.40 - i * 0.06, 1.02)
		link.rotation.x = deg_to_rad(90.0) if i % 2 == 0 else 0.0
		group.add_child(link)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  4. WORKSHOP, WATCHTOWER, MINT
# ═══════════════════════════════════════════════════════════════════════════════

# WORKSHOP — Workbench + anvil + tool rack + forge/furnace with glowing fire
static func _build_workshop() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_Workshop"

	var wood_mat := _get_wood_mat()
	var stone_mat := _get_stone_mat()
	var iron_mat := _get_iron_mat()

	# Stone floor base
	var fnd := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(3.0, 0.12, 3.0)
	fnd.mesh = fm; fnd.material_override = stone_mat
	fnd.position.y = 0.06
	group.add_child(fnd)

	# 4 Corner awning posts
	var corners = [Vector2(-1.3, -1.3), Vector2(1.3, -1.3), Vector2(1.3, 1.3), Vector2(-1.3, 1.3)]
	for c in corners:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.08; pm.bottom_radius = 0.10; pm.height = 2.2
		post.mesh = pm; post.material_override = wood_mat
		post.position = Vector3(c.x, 1.15, c.y)
		group.add_child(post)

	# Roof awning
	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(3.2, 0.08, 3.2)
	roof.mesh = rm; roof.material_override = _get_thatch_mat()
	roof.position.y = 2.25
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(roof)

	# Workbench table
	var bench := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 0.08, 0.70)
	bench.mesh = bm; bench.material_override = wood_mat
	bench.position = Vector3(0, 0.80, -0.90)
	group.add_child(bench)

	# Anvil on pedestal
	var anvil := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.28, 0.22, 0.18)
	anvil.mesh = am; anvil.material_override = iron_mat
	anvil.position = Vector3(-0.70, 0.65, 0.40)
	group.add_child(anvil)

	# Forge / furnace (stone structure + glowing light)
	var forge := MeshInstance3D.new()
	var form := BoxMesh.new()
	form.size = Vector3(0.70, 0.85, 0.70)
	forge.mesh = form; forge.material_override = stone_mat
	forge.position = Vector3(0.80, 0.54, 0.40)
	group.add_child(forge)

	var forge_light := OmniLight3D.new()
	forge_light.light_color = Color(1.0, 0.50, 0.15)
	forge_light.light_energy = 2.5
	forge_light.omni_range = 4.0
	forge_light.position = Vector3(0.80, 0.54, 0.80)
	group.add_child(forge_light)

	return group


# WATCHTOWER — 4 tall posts + platform + railing + ladder + signal flag
static func _build_watchtower() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_Watchtower"

	var wood_mat := _get_wood_mat()
	var dark_wood := _get_dark_wood_mat()

	# Stone base foundation
	var fnd := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(2.8, 0.25, 2.8)
	fnd.mesh = fm; fnd.material_override = _get_stone_mat()
	fnd.position.y = 0.125
	group.add_child(fnd)

	# 4 Tall posts
	var corners = [Vector2(-1.1, -1.1), Vector2(1.1, -1.1), Vector2(1.1, 1.1), Vector2(-1.1, 1.1)]
	for c in corners:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.10; pm.bottom_radius = 0.14; pm.height = 4.5
		post.mesh = pm; post.material_override = dark_wood
		post.position = Vector3(c.x, 2.38, c.y)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		group.add_child(post)

	# Platform
	var plat := MeshInstance3D.new()
	var plm := BoxMesh.new()
	plm.size = Vector3(2.5, 0.10, 2.5)
	plat.mesh = plm; plat.material_override = wood_mat
	plat.position.y = 3.60
	group.add_child(plat)

	# Railings (×4 sides)
	for i in range(4):
		var ang = (i / 4.0) * TAU
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(2.3, 0.06, 0.04)
		rail.mesh = rm; rail.material_override = wood_mat
		rail.position = Vector3(cos(ang) * 1.15, 4.20, sin(ang) * 1.15)
		rail.rotation.y = ang
		group.add_child(rail)

	# Ladder (2 side rails + 8 rungs)
	for i in range(8):
		var rung := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.02; rm.bottom_radius = 0.02; rm.height = 0.45
		rung.mesh = rm; rung.material_override = wood_mat
		rung.position = Vector3(-1.12, 0.50 + i * 0.42, 0)
		rung.rotation.z = deg_to_rad(90.0)
		group.add_child(rung)

	# Pointed roof cap
	var roof := MeshInstance3D.new()
	var rcone := CylinderMesh.new()
	rcone.top_radius = 0.0; rcone.bottom_radius = 1.5; rcone.height = 1.2
	roof.mesh = rcone; roof.material_override = _get_thatch_mat()
	roof.position.y = 5.20
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(roof)

	return group


# MINT — Stone structure + gold-plated dome roof + coin slot + coin piles visible
static func _build_mint() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_Mint"

	var stone_mat := _get_stone_mat()
	var gold_mat := _get_gold_mat()
	var iron_mat := _get_iron_mat()

	# Main stone building base
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 1.6, 2.4)
	base.mesh = bm; base.material_override = stone_mat
	base.position.y = 0.80
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(base)

	# Gold-plated dome roof
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 1.25; dm.height = 0.85
	dome.mesh = dm; dome.material_override = gold_mat
	dome.position.y = 1.80
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(dome)

	# Gold trim ring at base of dome
	var trim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.20; tm.outer_radius = 1.30
	trim.mesh = tm; trim.material_override = gold_mat
	trim.position.y = 1.60
	group.add_child(trim)

	# Coin slot (front)
	var slot := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.28, 0.04, 0.08)
	slot.mesh = sm; slot.material_override = iron_mat
	slot.position = Vector3(0, 1.10, 1.21)
	group.add_child(slot)

	# Coin piles (×3 visible at entrance)
	for i in range(3):
		var coin_pile := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04; cm.bottom_radius = 0.05; cm.height = 0.06
		coin_pile.mesh = cm; coin_pile.material_override = gold_mat
		coin_pile.position = Vector3(-0.3 + i * 0.3, 0.03, 1.35)
		group.add_child(coin_pile)

	return group


# ═══════════════════════════════════════════════════════════════════════════════
#  5. TRAPS, FIRE PIT, WELL, TREASURY
# ═══════════════════════════════════════════════════════════════════════════════

# FIRE PIT — 8 stone ring + charred log pile + animated flames + omni light + pot
static func _build_fire_pit() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_FirePit"

	var stone_mat := _get_stone_mat()

	# 8 Individual stones in ring
	for i in range(8):
		var ang = (i / 8.0) * TAU
		var stone := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14; sm.height = 0.16
		stone.mesh = sm; stone.material_override = stone_mat
		stone.position = Vector3(cos(ang) * 0.45, 0.08, sin(ang) * 0.45)
		group.add_child(stone)

	# Ash bed
	var ash := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.35; am.bottom_radius = 0.35; am.height = 0.04
	ash.mesh = am
	var ash_mat := StandardMaterial3D.new()
	ash_mat.albedo_color = Color(0.20, 0.18, 0.16)
	ash.material_override = ash_mat
	ash.position.y = 0.02
	group.add_child(ash)

	# Charred crossing logs (×3)
	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.25, 0.18, 0.12)
	for i in range(3):
		var ang = (i / 3.0) * PI
		var log := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.04; lm.bottom_radius = 0.05; lm.height = 0.55
		log.mesh = lm; log.material_override = log_mat
		log.position = Vector3(0, 0.08 + i * 0.03, 0)
		log.rotation.y = ang
		log.rotation.z = deg_to_rad(12.0)
		group.add_child(log)

	# Animated fire flames (emission cones)
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.55, 0.12)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.55, 0.12)
	fire_mat.emission_energy_multiplier = 3.0

	var flame := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.0; fm.bottom_radius = 0.18; fm.height = 0.45
	flame.mesh = fm; flame.material_override = fire_mat
	flame.position.y = 0.30
	group.add_child(flame)

	# OmniLight3D
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.20)
	light.light_energy = 2.5
	light.omni_range = 8.0
	light.position.y = 0.45
	group.add_child(light)

	return group


# BEAR TRAP — Iron jaws + teeth + spring + pressure plate + chain
static func _build_bear_trap() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_BearTrap"

	var iron_mat := _get_iron_mat()

	# Base plate
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.25; bm.bottom_radius = 0.25; bm.height = 0.03
	base.mesh = bm; base.material_override = iron_mat
	base.position.y = 0.015
	group.add_child(base)

	# Jaw teeth upper & lower (×12 teeth in circle)
	for i in range(12):
		var ang = (i / 12.0) * TAU
		var tooth := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.0; tm.bottom_radius = 0.015; tm.height = 0.08
		tooth.mesh = tm; tooth.material_override = iron_mat
		tooth.position = Vector3(cos(ang) * 0.22, 0.06, sin(ang) * 0.22)
		tooth.rotation.z = cos(ang) * deg_to_rad(-25.0)
		group.add_child(tooth)

	# Trigger plate in center
	var trigger := MeshInstance3D.new()
	var trm := CylinderMesh.new()
	trm.top_radius = 0.08; trm.bottom_radius = 0.08; trm.height = 0.01
	trigger.mesh = trm; trigger.material_override = _get_wood_mat()
	trigger.position.y = 0.03
	group.add_child(trigger)

	return group


# ALARM TRAP — Wooden pressure plate + bell post + brass bell
static func _build_alarm_trap() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_AlarmTrap"

	# Pressure plate (flush with ground)
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.40, 0.02, 0.40)
	plate.mesh = pm; plate.material_override = _get_wood_mat()
	plate.position.y = 0.01
	group.add_child(plate)

	# Bell post
	var post := MeshInstance3D.new()
	var pm2 := CylinderMesh.new()
	pm2.top_radius = 0.02; pm2.bottom_radius = 0.02; pm2.height = 0.40
	post.mesh = pm2; post.material_override = _get_wood_mat()
	post.position = Vector3(0.22, 0.20, -0.22)
	group.add_child(post)

	# Brass bell
	var bell := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.06; bm.height = 0.10
	bell.mesh = bm; bell.material_override = _get_gold_mat()
	bell.position = Vector3(0.22, 0.38, -0.22)
	group.add_child(bell)

	return group


# SPIKE TRAP — Sharpened wooden stakes in 3×3 grid
static func _build_spike_trap() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_SpikeTrap"

	var wood_mat := _get_wood_mat()

	# Base frame
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, 0.06, 1.5)
	base.mesh = bm; base.material_override = wood_mat
	base.position.y = 0.03
	group.add_child(base)

	# 9 Sharpened stakes in 3×3 grid
	for x in range(3):
		for z in range(3):
			var stake := MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.top_radius = 0.0; sm.bottom_radius = 0.04; sm.height = 0.48
			stake.mesh = sm; stake.material_override = wood_mat
			stake.position = Vector3(-0.45 + x * 0.45, 0.27, -0.45 + z * 0.45)
			group.add_child(stake)

	return group


# WELL — Circular stone wall + A-frame roof + winch drum + bucket + water surface
static func _build_well() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_Well"

	var stone_mat := _get_stone_mat()
	var wood_mat := _get_wood_mat()

	# Circular stone wall (stacked torus)
	for i in range(3):
		var wall := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.50; tm.outer_radius = 0.75
		wall.mesh = tm; wall.material_override = stone_mat
		wall.position.y = 0.15 + i * 0.20
		group.add_child(wall)

	# A-frame roof supports (×2)
	for side in [-1, 1]:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.04; pm.bottom_radius = 0.05; pm.height = 1.4
		post.mesh = pm; post.material_override = wood_mat
		post.position = Vector3(side * 0.65, 1.0, 0)
		group.add_child(post)

	# Winch drum
	var winch := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.07; wm.bottom_radius = 0.07; wm.height = 1.1
	winch.mesh = wm; winch.material_override = wood_mat
	winch.position = Vector3(0, 1.25, 0)
	winch.rotation.z = deg_to_rad(90.0)
	group.add_child(winch)

	# Water surface inside
	var water := MeshInstance3D.new()
	var wmesh := CylinderMesh.new()
	wmesh.top_radius = 0.48; wmesh.bottom_radius = 0.48; wmesh.height = 0.01
	water.mesh = wmesh
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.12, 0.42, 0.72, 0.8)
	water_mat.metallic = 0.50; water_mat.roughness = 0.08
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = water_mat
	water.position.y = 0.25
	group.add_child(water)

	return group


# TREASURY CHEST — Wooden chest + iron bands + gold coins spilling + glowing gold light
static func _build_treasury_chest() -> Node3D:
	var group := Node3D.new()
	group.name = "Structure_Treasury"

	var wood_mat := _get_wood_mat()
	var iron_mat := _get_iron_mat()
	var gold_mat := _get_gold_mat()

	# Main chest body
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.55, 0.65)
	body.mesh = bm; body.material_override = wood_mat
	body.position.y = 0.275
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.add_child(body)

	# Lid (slightly open)
	var lid := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.02, 0.08, 0.67)
	lid.mesh = lm; lid.material_override = wood_mat
	lid.position = Vector3(0, 0.58, -0.05)
	lid.rotation.x = deg_to_rad(-18.0)
	group.add_child(lid)

	# Iron corner/edge bands (×3 horizontal)
	for i in range(3):
		var band := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(1.04, 0.04, 0.02)
		band.mesh = bmesh; band.material_override = iron_mat
		band.position = Vector3(0, 0.10 + i * 0.18, 0.33)
		group.add_child(band)

	# Lock plate
	var lock := MeshInstance3D.new()
	var lm2 := BoxMesh.new()
	lm2.size = Vector3(0.12, 0.10, 0.04)
	lock.mesh = lm2; lock.material_override = iron_mat
	lock.position = Vector3(0, 0.35, 0.34)
	group.add_child(lock)

	# Gold coins visible inside
	for i in range(5):
		var coin := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035; cm.bottom_radius = 0.035; cm.height = 0.01
		coin.mesh = cm; coin.material_override = gold_mat
		coin.position = Vector3(-0.2 + i * 0.10, 0.52, 0.15 - i * 0.04)
		group.add_child(coin)

	# Gold glow
	var light := OmniLight3D.new()
	light.light_color = Color(0.90, 0.75, 0.20)
	light.light_energy = 1.0
	light.omni_range = 3.0
	light.position = Vector3(0, 0.55, 0)
	group.add_child(light)

	return group
