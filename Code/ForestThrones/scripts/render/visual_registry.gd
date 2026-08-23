extends RefCounted
class_name VisualRegistry

## ═══════════════════════════════════════════════════════════════════════════════
##  VISUAL REGISTRY — Shared material & mesh cache.
##
##  Before this existed every single tree/rock/grass blade allocated brand-new
##  StandardMaterial3D and Mesh resources. A 200x200 map produced 13,510 unique
##  materials and 88,714 unique meshes, which meant zero GPU batching, ~1.7 GB
##  of RAM and a guaranteed out-of-memory crash on mobile.
##
##  Everything now goes through here. Identical visual descriptions collapse to
##  a single shared resource, so the same look costs a fraction of the memory
##  and lets MultiMesh batch thousands of instances into one draw call.
## ═══════════════════════════════════════════════════════════════════════════════

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _stats := {"mat_hits": 0, "mat_miss": 0, "mesh_hits": 0, "mesh_miss": 0}


# ─── Materials ────────────────────────────────────────────────────────────────

## Shared opaque surface. `key` should describe the look, not the object using it.
static func mat(key: String, albedo: Color, roughness: float = 0.9,
		metallic: float = 0.0, emission: Color = Color(0, 0, 0),
		emission_energy: float = 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		_stats.mat_hits += 1
		return _materials[key]
	_stats.mat_miss += 1
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	# Per-instance MultiMesh colours modulate albedo — this is what gives us
	# hundreds of tree shades from one shared material with no extra draw calls.
	m.vertex_color_use_as_albedo = true
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	_materials[key] = m
	return m


## Auto-keyed variant — use when you don't have a meaningful name for the look.
static func mat_auto(albedo: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "auto_%d_%d_%d_%d_%d" % [
		int(albedo.r * 255), int(albedo.g * 255), int(albedo.b * 255),
		int(roughness * 100), int(metallic * 100)]
	return mat(key, albedo, roughness, metallic)


## Shared transparent surface (foliage cards, water film, ghost previews).
static func mat_transparent(key: String, albedo: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var full_key := "tr_" + key
	if _materials.has(full_key):
		_stats.mat_hits += 1
		return _materials[full_key]
	_stats.mat_miss += 1
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	_materials[full_key] = m
	return m


## Shared unshaded surface — UI-ish highlights, markers, glow cores.
static func mat_unshaded(key: String, albedo: Color) -> StandardMaterial3D:
	var full_key := "un_" + key
	if _materials.has(full_key):
		_stats.mat_hits += 1
		return _materials[full_key]
	_stats.mat_miss += 1
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	_materials[full_key] = m
	return m


# ─── Stylised shader materials ────────────────────────────────────────────────

const STYLIZED_SHADER = preload("res://assets/shaders/stylized_prop.gdshader")
const STYLIZED_ALPHA_SHADER = preload("res://assets/shaders/stylized_prop_alpha.gdshader")

## Per-style tuning for the one prop shader. Keeping this table here (rather
## than per prop) is what lets thousands of objects share a handful of
## materials, which is what lets them share draw calls.
const STYLE_PRESETS := {
	# Rocks, wood, structures — planted and still.
	"solid":   {"sway": 0.00, "sway_base": 1.0, "speed": 1.0,
				"contact": 0.30, "contact_h": 1.20, "rim": 0.22, "rim_pow": 3.2, "top": 0.10},
	# Tree canopies and bushes — the trunk holds, the crown leans.
	"foliage": {"sway": 0.075, "sway_base": 1.20, "speed": 0.9,
				"contact": 0.38, "contact_h": 2.20, "rim": 0.26, "rim_pow": 2.8, "top": 0.16},
	# Ground cover — moves as a whole, from the root.
	"grass":   {"sway": 0.050, "sway_base": 0.05, "speed": 1.8,
				"contact": 0.45, "contact_h": 0.26, "rim": 0.18, "rim_pow": 3.4, "top": 0.08},
	# Reeds and tall grass at the waterline — the loosest movement on the map.
	"reed":    {"sway": 0.10, "sway_base": 0.12, "speed": 1.4,
				"contact": 0.40, "contact_h": 0.55, "rim": 0.20, "rim_pow": 3.0, "top": 0.10},
	# Characters and beasts — cel-banded so they pop against the terrain.
	"actor":   {"sway": 0.00, "sway_base": 1.0, "speed": 1.0,
				"contact": 0.16, "contact_h": 1.00, "rim": 0.24, "rim_pow": 3.6, "top": 0.14},
}


## Shared stylised material. `style` picks a preset; `roughness`, `emission` and
## `transparent` split it into a few sub-variants at most.
static func stylized(style: String, roughness: float = 0.92,
		emission_energy: float = 0.0, transparent: bool = false,
		metallic: float = 0.0) -> ShaderMaterial:
	var preset: Dictionary = STYLE_PRESETS.get(style, STYLE_PRESETS["solid"])
	var key := "sty_%s_%d_%d_%s_m%d" % [
		style, int(round(roughness * 10.0)),
		int(round(emission_energy * 4.0)), "t" if transparent else "o",
		int(round(metallic * 4.0))]
	if _materials.has(key):
		_stats.mat_hits += 1
		return _materials[key]
	_stats.mat_miss += 1

	var m := ShaderMaterial.new()
	if transparent:
		# Transparent parts (aura rings, water, glass, ember trails) need a
		# shader that actually reads the baked alpha. Using the opaque one here
		# is what turned every hut's proximity-aura ring into a solid green disc.
		m.shader = STYLIZED_ALPHA_SHADER
		m.set_shader_parameter("rim_strength", preset.rim * 0.6)
		m.set_shader_parameter("rim_power", preset.rim_pow)
		m.set_shader_parameter("roughness_value", roughness)
		m.set_shader_parameter("emission_energy", emission_energy)
		m.set_shader_parameter("rim_color", Vector3(0.62, 0.78, 0.92))
		m.render_priority = 1
		_materials[key] = m
		return m

	m.shader = STYLIZED_SHADER
	m.set_shader_parameter("sway_strength", preset.sway)
	m.set_shader_parameter("sway_base_height", preset.sway_base)
	m.set_shader_parameter("sway_speed", preset.speed)
	m.set_shader_parameter("contact_shade", preset.contact)
	m.set_shader_parameter("contact_height", preset.contact_h)
	m.set_shader_parameter("rim_strength", preset.rim)
	m.set_shader_parameter("rim_power", preset.rim_pow)
	m.set_shader_parameter("top_light", preset.top)
	m.set_shader_parameter("roughness_value", roughness)
	m.set_shader_parameter("metallic_value", metallic)
	m.set_shader_parameter("emission_energy", emission_energy)
	m.set_shader_parameter("rim_color", Vector3(0.66, 0.82, 0.98))
	# Per-style toon character. Actors band a touch softer and sit a touch
	# brighter than static world props so faces stay readable.
	if style == "actor":
		m.set_shader_parameter("band_sharpness", 0.4)
		m.set_shader_parameter("shade_floor", 0.52)
		m.set_shader_parameter("saturation", 1.12)
		m.set_shader_parameter("contrast", 1.03)
		m.set_shader_parameter("light_wrap", 0.28)
	else:
		m.set_shader_parameter("band_sharpness", 0.55)
		m.set_shader_parameter("shade_floor", 0.42)
		m.set_shader_parameter("saturation", 1.16)
		m.set_shader_parameter("contrast", 1.06)
		m.set_shader_parameter("light_wrap", 0.2)
	if transparent:
		m.render_priority = 1
	_materials[key] = m
	return m


# ─── Meshes ───────────────────────────────────────────────────────────────────

static func box(size: Vector3) -> BoxMesh:
	var key := "box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if _meshes.has(key):
		_stats.mesh_hits += 1
		return _meshes[key]
	_stats.mesh_miss += 1
	var m := BoxMesh.new()
	m.size = size
	_meshes[key] = m
	return m


static func cylinder(top_r: float, bottom_r: float, height: float, segments: int = 8) -> CylinderMesh:
	var key := "cyl_%.3f_%.3f_%.3f_%d" % [top_r, bottom_r, height, segments]
	if _meshes.has(key):
		_stats.mesh_hits += 1
		return _meshes[key]
	_stats.mesh_miss += 1
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bottom_r
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	_meshes[key] = m
	return m


static func sphere(radius: float, height: float = -1.0, segments: int = 8, rings: int = 4) -> SphereMesh:
	var h := height if height > 0.0 else radius * 2.0
	var key := "sph_%.3f_%.3f_%d_%d" % [radius, h, segments, rings]
	if _meshes.has(key):
		_stats.mesh_hits += 1
		return _meshes[key]
	_stats.mesh_miss += 1
	var m := SphereMesh.new()
	m.radius = radius
	m.height = h
	m.radial_segments = segments
	m.rings = rings
	_meshes[key] = m
	return m


static func prism(size: Vector3) -> PrismMesh:
	var key := "prism_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if _meshes.has(key):
		_stats.mesh_hits += 1
		return _meshes[key]
	_stats.mesh_miss += 1
	var m := PrismMesh.new()
	m.size = size
	_meshes[key] = m
	return m


static func torus(inner: float, outer: float, rings: int = 12, sides: int = 6) -> TorusMesh:
	var key := "tor_%.3f_%.3f_%d_%d" % [inner, outer, rings, sides]
	if _meshes.has(key):
		_stats.mesh_hits += 1
		return _meshes[key]
	_stats.mesh_miss += 1
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = rings
	m.ring_segments = sides
	_meshes[key] = m
	return m


static func quad(size: Vector2) -> QuadMesh:
	var key := "quad_%.3f_%.3f" % [size.x, size.y]
	if _meshes.has(key):
		_stats.mesh_hits += 1
		return _meshes[key]
	_stats.mesh_miss += 1
	var m := QuadMesh.new()
	m.size = size
	_meshes[key] = m
	return m


## Register an already-built ArrayMesh under a key so repeated bakes reuse it.
static func adopt_mesh(key: String, m: Mesh) -> Mesh:
	if _meshes.has(key):
		_stats.mesh_hits += 1
		return _meshes[key]
	_stats.mesh_miss += 1
	_meshes[key] = m
	return m


static func has_mesh(key: String) -> bool:
	return _meshes.has(key)


static func get_mesh(key: String) -> Mesh:
	return _meshes.get(key, null)


# ─── Diagnostics ──────────────────────────────────────────────────────────────

static func stats() -> Dictionary:
	return {
		"unique_materials": _materials.size(),
		"unique_meshes": _meshes.size(),
		"material_cache_hits": _stats.mat_hits,
		"mesh_cache_hits": _stats.mesh_hits,
	}


static func clear() -> void:
	_materials.clear()
	_meshes.clear()
	_stats = {"mat_hits": 0, "mat_miss": 0, "mesh_hits": 0, "mesh_miss": 0}
