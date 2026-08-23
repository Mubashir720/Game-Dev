extends RefCounted
class_name PropBaker

## ═══════════════════════════════════════════════════════════════════════════════
##  PROP BAKER — Collapses a hand-authored prop node tree into one shared mesh.
##
##  The prop factories build beautiful, detailed objects out of many small
##  MeshInstance3D nodes (a pine tree is 11 separate meshes + 6 materials).
##  That is a great way to AUTHOR a prop and a terrible way to SHIP one:
##  placing 4,000 of them meant 44,000 nodes and 44,000 draw calls.
##
##  bake() runs the authoring code exactly once, then welds the whole tree into
##  a single ArrayMesh — albedo colours baked into vertex colours so parts that
##  only differ by colour collapse into the same surface. A detailed pine goes
##  from 11 meshes / 6 materials to 1 mesh / 1-2 surfaces, and every copy on the
##  map is then a MultiMesh instance costing one matrix, not one node.
##
##  Visual fidelity is unchanged. Only the cost changes.
## ═══════════════════════════════════════════════════════════════════════════════

const Registry = preload("res://scripts/render/visual_registry.gd")

## key -> { mesh: ArrayMesh, collision: Array, bounds: AABB, part_count: int }
static var _templates: Dictionary = {}
static var _bake_ms: float = 0.0


## Returns a baked template for `key`. `builder` is a Callable returning Node3D.
## Built once, cached forever. `variant` lets a randomised builder produce
## several distinct bakes so a forest doesn't look cloned.
static func get_template(key: String, builder: Callable, variant: int = 0,
		style: String = "solid") -> Dictionary:
	var full_key := "%s#%d#%s" % [key, variant, style]
	if _templates.has(full_key):
		return _templates[full_key]

	var t0 := Time.get_ticks_usec()
	var root = builder.call()
	if root == null:
		var empty := {"mesh": null, "collision": [], "lights": [], "bounds": AABB(), "part_count": 0}
		_templates[full_key] = empty
		return empty

	var tpl := bake(root, full_key, style)
	root.queue_free()
	_bake_ms += (Time.get_ticks_usec() - t0) / 1000.0
	_templates[full_key] = tpl
	return tpl


## Weld a live node tree into a single multi-surface ArrayMesh + collision list.
static func bake(root: Node3D, cache_key: String = "", style: String = "solid") -> Dictionary:
	# group_key -> SurfaceTool
	var groups: Dictionary = {}
	var group_mats: Dictionary = {}
	var collision: Array = []
	var lights: Array = []
	var part_count := 0
	var bounds := AABB()
	var has_bounds := false

	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry = stack.pop_back()
		var node: Node = entry[0]
		var parent_xf: Transform3D = entry[1]

		var local_xf := parent_xf
		if node is Node3D and node != root:
			local_xf = parent_xf * node.transform
		elif node == root and node is Node3D:
			local_xf = parent_xf  # root transform is applied by the placer, not baked

		if node is MeshInstance3D and node.mesh != null:
			var src_mesh: Mesh = _normalise_poly(node.mesh)
			# Swap plain boxes for chamfered ones so nothing in the game has a
			# razor-sharp 90-degree edge. See bevelled_box() for why.
			if src_mesh is BoxMesh:
				var bs: Vector3 = (src_mesh as BoxMesh).size
				if min(bs.x, min(bs.y, bs.z)) >= BEVEL_MIN_DIMENSION:
					src_mesh = bevelled_box(bs)
			for si in range(src_mesh.get_surface_count()):
				var srf_mat: Material = node.get_active_material(si)
				var props := _material_props(srf_mat)
				var gkey: String = props.group
				if not groups.has(gkey):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					groups[gkey] = st
					group_mats[gkey] = props
				var appended := _append_surface(groups[gkey], src_mesh, si, local_xf, props.albedo)
				if appended.count > 0:
					part_count += 1
					if has_bounds:
						bounds = bounds.merge(appended.aabb)
					else:
						bounds = appended.aabb
						has_bounds = true

		elif node is CollisionShape3D and node.shape != null:
			collision.append({"shape": node.shape, "xform": local_xf})

		elif node is OmniLight3D:
			# Lights can't be baked into geometry, so record them and let the
			# placer decide whether this instance is close enough to deserve one.
			var l := node as OmniLight3D
			lights.append({
				"xform": local_xf,
				"color": l.light_color,
				"energy": l.light_energy,
				"range": l.omni_range,
			})

		for c in node.get_children():
			stack.push_back([c, local_xf])

	if groups.is_empty():
		return {"mesh": null, "collision": collision, "lights": lights, "bounds": bounds, "part_count": 0}

	var out := ArrayMesh.new()
	var surf_index := 0
	for gkey in groups.keys():
		var st: SurfaceTool = groups[gkey]
		st.generate_normals()
		var arrays = st.commit_to_arrays()
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_VERTEX].size() == 0:
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(surf_index, _shared_material_for(group_mats[gkey], style))
		surf_index += 1

	if cache_key != "":
		out.resource_name = cache_key

	return {"mesh": out, "collision": collision, "lights": lights, "bounds": bounds, "part_count": part_count}


# ─── internals ────────────────────────────────────────────────────────────────

## Reduce a material down to (surface-group, albedo). Two materials that differ
## only by colour land in the SAME group; the colour rides along in the vertex
## colour channel. That is what turns a 6-material tree into a 1-surface tree.
static func _material_props(m: Material) -> Dictionary:
	if m == null:
		return {"group": "o_9_0", "albedo": Color.WHITE, "rough": 0.9,
				"metal": 0.0, "mode": "opaque", "emission": Color.BLACK, "energy": 0.0}

	if m is StandardMaterial3D:
		var sm := m as StandardMaterial3D
		# Coarse buckets on purpose. Every distinct bucket becomes its own surface
		# and therefore its own draw call, so quantising roughness to 4 steps and
		# metallic to 3 collapses a 25-surface character to about 12 with no
		# visible difference on a stylised, untextured look.
		var rough := int(round(sm.roughness * 3.0))
		var metal := int(round(sm.metallic * 2.0))
		var mode := "o"
		if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			mode = "t"
		elif sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			mode = "u"
		var emis_key := ""
		if sm.emission_enabled and sm.emission_energy_multiplier > 0.0:
			# Emissive parts must keep their own colour, so key by it.
			emis_key = "_e%d%d%d%d" % [
				int(sm.emission.r * 15), int(sm.emission.g * 15),
				int(sm.emission.b * 15), int(sm.emission_energy_multiplier * 4)]
		return {
			"group": "%s_%d_%d%s" % [mode, rough, metal, emis_key],
			"albedo": sm.albedo_color,
			"rough": sm.roughness,
			"metal": sm.metallic,
			"mode": mode,
			"emission": sm.emission if sm.emission_enabled else Color.BLACK,
			"energy": sm.emission_energy_multiplier if sm.emission_enabled else 0.0,
		}

	# ShaderMaterial or anything exotic keeps its own dedicated group.
	return {"group": "shader_%d" % m.get_instance_id(), "albedo": Color.WHITE,
			"rough": 0.9, "metal": 0.0, "mode": "shader",
			"emission": Color.BLACK, "energy": 0.0, "raw": m}


## Every baked surface resolves to a SHARED stylised material. Two props that
## differ only in colour therefore share a material — and with MultiMesh that
## means they share a draw call.
static func _shared_material_for(props: Dictionary, style: String) -> Material:
	if props.get("mode", "") == "shader" and props.has("raw"):
		return props.raw

	var mode: String = props.get("mode", "o")
	# Unshaded parts (glow cores, markers) keep the simple unshaded path — the
	# stylised shader's lighting model would fight them.
	if mode == "u":
		return Registry.mat_unshaded("vc_" + str(props.group), Color.WHITE)

	var energy: float = float(props.get("energy", 0.0))
	return Registry.stylized(style, float(props.get("rough", 0.9)), energy, mode == "t",
			float(props.get("metal", 0.0)))


static func _append_surface(st: SurfaceTool, src: Mesh, surface: int,
		xf: Transform3D, albedo: Color) -> Dictionary:
	var arrays := src.surface_get_arrays(surface)
	if arrays.is_empty():
		return {"count": 0, "aabb": AABB()}

	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts == null or verts.size() == 0:
		return {"count": 0, "aabb": AABB()}

	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

	var basis := xf.basis
	var normal_basis := basis.inverse().transposed()

	var aabb := AABB()
	var first := true

	var emit_vertex := func(i: int) -> void:
		st.set_color(albedo)
		if norms.size() > i:
			st.set_normal((normal_basis * norms[i]).normalized())
		if uvs.size() > i:
			st.set_uv(uvs[i])
		st.add_vertex(xf * verts[i])

	if idx.size() > 0:
		for k in range(idx.size()):
			emit_vertex.call(idx[k])
	else:
		for k in range(verts.size()):
			emit_vertex.call(k)

	for v in verts:
		var wv := xf * v
		if first:
			aabb = AABB(wv, Vector3.ZERO)
			first = false
		else:
			aabb = aabb.expand(wv)

	return {"count": verts.size(), "aabb": aabb}




# ─── Poly budget ──────────────────────────────────────────────────────────────

## Godot's primitive meshes default to 64 radial segments and 32 rings. A single
## SphereMesh at defaults is ~4,000 triangles, so a detailed tree built from a
## dozen primitives came out at ~3,900 triangles and a forest of them measured
## 25.4 MILLION triangles on screen — roughly 40x a mobile GPU's budget.
##
## At the scale these props are actually viewed (an orthographic isometric
## camera, props a few pixels to a few hundred pixels tall) the extra segments
## are invisible. Normalising them here fixes every existing prop at once,
## without touching a single line of the prop designs.
const SPHERE_SEGMENTS := 8
const SPHERE_RINGS := 4
const CYLINDER_SEGMENTS := 8
const TORUS_RINGS := 8
const TORUS_SIDES := 5
const CAPSULE_SEGMENTS := 8
const CAPSULE_RINGS := 2

# ─── Bevelled boxes ───────────────────────────────────────────────────────────

## Boxes are everywhere in this project — torsos, belts, boots, walls, roofs,
## crates, beast bodies. A raw BoxMesh has perfectly sharp 90-degree edges, and
## sharp edges are the single loudest "this is untextured programmer geometry"
## signal there is: they catch a hard specular line and read as cardboard.
##
## Every box above a minimum size is swapped for a chamfered box at bake time.
## The bevel catches light as a thin bright edge, which is exactly the soft
## moulded look expensive stylised mobile games have. It costs 44 triangles
## instead of 12, so tiny detail boxes (grass blades, eyebrows, straps) are left
## alone — at their size the bevel would be sub-pixel anyway.
const BEVEL_MIN_DIMENSION := 0.10
const BEVEL_RATIO := 0.16
const BEVEL_MAX := 0.09

static var _bevel_cache: Dictionary = {}


static func bevelled_box(size: Vector3) -> ArrayMesh:
	var key := "bev_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if _bevel_cache.has(key):
		return _bevel_cache[key]

	var min_dim: float = min(size.x, min(size.y, size.z))
	var b: float = min(min_dim * BEVEL_RATIO, BEVEL_MAX)
	var h := size * 0.5
	var a := Vector3(max(h.x - b, 0.001), max(h.y - b, 0.001), max(h.z - b, 0.001))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Six flat faces, inset by the bevel on their two tangent axes.
	var axes := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
	]
	for entry in axes:
		var n: Vector3 = entry[0]
		var u: Vector3 = entry[1]
		var v: Vector3 = entry[2]
		var centre := Vector3(n.x * h.x, n.y * h.y, n.z * h.z)
		var eu := Vector3(u.x * a.x, u.y * a.y, u.z * a.z)
		var ev := Vector3(v.x * a.x, v.y * a.y, v.z * a.z)
		# WINDING: Godot's front faces are CLOCKWISE seen from outside, so a
		# correctly wound triangle has (b-a)x(c-a) pointing INWARD. Godot's own
		# BoxMesh follows this. These six faces were emitted counter-clockwise,
		# so every one of them was culled: a bevelled box rendered as a hollow
		# wireframe of its twelve edge strips. tools/mesh_probe.gd checks this.
		_quad(st, centre - eu + ev, centre + eu + ev, centre + eu - ev, centre - eu - ev, n)

	# Twelve edge strips and eight corner caps, generated from the sign lattice.
	var signs := [-1.0, 1.0]
	for sx in signs:
		for sy in signs:
			for sz in signs:
				var corner := Vector3(sx * a.x, sy * a.y, sz * a.z)
				var px := corner + Vector3(sx * b, 0, 0)
				var py := corner + Vector3(0, sy * b, 0)
				var pz := corner + Vector3(0, 0, sz * b)
				var cn := Vector3(sx, sy, sz).normalized()
				# Corner cap — winding depends on the octant's handedness.
				if sx * sy * sz > 0.0:
					_tri(st, px, pz, py, cn)
				else:
					_tri(st, px, py, pz, cn)

	# Edge strips along each axis.
	for sy2 in signs:
		for sz2 in signs:
			var n1 := Vector3(0, sy2, sz2).normalized()
			var p0 := Vector3(-a.x, sy2 * a.y + sy2 * b, sz2 * a.z)
			var p1 := Vector3(a.x, sy2 * a.y + sy2 * b, sz2 * a.z)
			var p2 := Vector3(a.x, sy2 * a.y, sz2 * a.z + sz2 * b)
			var p3 := Vector3(-a.x, sy2 * a.y, sz2 * a.z + sz2 * b)
			if sy2 * sz2 > 0.0:
				_quad(st, p0, p1, p2, p3, n1)
			else:
				_quad(st, p3, p2, p1, p0, n1)

	for sx3 in signs:
		for sz3 in signs:
			var n2 := Vector3(sx3, 0, sz3).normalized()
			var q0 := Vector3(sx3 * a.x + sx3 * b, -a.y, sz3 * a.z)
			var q1 := Vector3(sx3 * a.x + sx3 * b, a.y, sz3 * a.z)
			var q2 := Vector3(sx3 * a.x, a.y, sz3 * a.z + sz3 * b)
			var q3 := Vector3(sx3 * a.x, -a.y, sz3 * a.z + sz3 * b)
			if sx3 * sz3 > 0.0:
				_quad(st, q3, q2, q1, q0, n2)
			else:
				_quad(st, q0, q1, q2, q3, n2)

	for sx4 in signs:
		for sy4 in signs:
			var n3 := Vector3(sx4, sy4, 0).normalized()
			var r0 := Vector3(sx4 * a.x + sx4 * b, sy4 * a.y, -a.z)
			var r1 := Vector3(sx4 * a.x + sx4 * b, sy4 * a.y, a.z)
			var r2 := Vector3(sx4 * a.x, sy4 * a.y + sy4 * b, a.z)
			var r3 := Vector3(sx4 * a.x, sy4 * a.y + sy4 * b, -a.z)
			if sx4 * sy4 > 0.0:
				_quad(st, r0, r1, r2, r3, n3)
			else:
				_quad(st, r3, r2, r1, r0, n3)

	var mesh := st.commit()
	_bevel_cache[key] = mesh
	return mesh


static func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3) -> void:
	st.set_normal(n); st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
	st.set_normal(n); st.set_uv(Vector2(1, 0)); st.add_vertex(p1)
	st.set_normal(n); st.set_uv(Vector2(1, 1)); st.add_vertex(p2)
	st.set_normal(n); st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
	st.set_normal(n); st.set_uv(Vector2(1, 1)); st.add_vertex(p2)
	st.set_normal(n); st.set_uv(Vector2(0, 1)); st.add_vertex(p3)


static func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, n: Vector3) -> void:
	st.set_normal(n); st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
	st.set_normal(n); st.set_uv(Vector2(1, 0)); st.add_vertex(p1)
	st.set_normal(n); st.set_uv(Vector2(0, 1)); st.add_vertex(p2)


static func _normalise_poly(m: Mesh) -> Mesh:
	if m is SphereMesh:
		var s := m as SphereMesh
		if s.radial_segments > SPHERE_SEGMENTS:
			s.radial_segments = SPHERE_SEGMENTS
		if s.rings > SPHERE_RINGS:
			s.rings = SPHERE_RINGS
	elif m is CylinderMesh:
		var c := m as CylinderMesh
		if c.radial_segments > CYLINDER_SEGMENTS:
			c.radial_segments = CYLINDER_SEGMENTS
		if c.rings > 1:
			c.rings = 1
	elif m is TorusMesh:
		var t := m as TorusMesh
		if t.rings > TORUS_RINGS:
			t.rings = TORUS_RINGS
		if t.ring_segments > TORUS_SIDES:
			t.ring_segments = TORUS_SIDES
	elif m is CapsuleMesh:
		var cap := m as CapsuleMesh
		if cap.radial_segments > CAPSULE_SEGMENTS:
			cap.radial_segments = CAPSULE_SEGMENTS
		if cap.rings > CAPSULE_RINGS:
			cap.rings = CAPSULE_RINGS
	elif m is BoxMesh:
		var b := m as BoxMesh
		b.subdivide_width = 0; b.subdivide_height = 0; b.subdivide_depth = 0
	elif m is PlaneMesh:
		var pl := m as PlaneMesh
		pl.subdivide_width = 0; pl.subdivide_depth = 0
	elif m is PrismMesh:
		var pr := m as PrismMesh
		pr.subdivide_width = 0; pr.subdivide_height = 0; pr.subdivide_depth = 0
	return m


## Public helper so live (non-baked) node trees — characters, beasts, structures
## — can get the same budget without being instanced.
static func normalise_tree(root: Node) -> int:
	var touched := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.mesh != null:
			_normalise_poly(n.mesh)
			touched += 1
		for c in n.get_children():
			stack.push_back(c)
	return touched


# ─── Diagnostics ──────────────────────────────────────────────────────────────

static func stats() -> Dictionary:
	return {"templates": _templates.size(), "bake_ms": _bake_ms}


static func clear() -> void:
	_templates.clear()
	_bake_ms = 0.0


## Instantiate a baked template as ONE real node (mesh + collision + optional
## lights). Used for hero landmarks and interactive objects that need to exist
## as individual nodes but should still cost one mesh instead of forty.
static func instantiate(tpl: Dictionary, with_collision: bool = true,
		with_lights: bool = true, node_name: String = "BakedProp") -> Node3D:
	var root: Node3D
	if with_collision and not tpl.get("collision", []).is_empty():
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		for c in tpl.collision:
			var cs := CollisionShape3D.new()
			cs.shape = c.shape
			cs.transform = c.xform
			body.add_child(cs)
		root = body
	else:
		root = Node3D.new()
	root.name = node_name

	if tpl.get("mesh") != null:
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = tpl.mesh
		root.add_child(mi)

	if with_lights:
		for l in tpl.get("lights", []):
			var light := OmniLight3D.new()
			light.transform = l.xform
			light.light_color = l.color
			light.light_energy = l.energy
			light.omni_range = l.range
			light.shadow_enabled = false
			light.distance_fade_enabled = true
			light.distance_fade_begin = 26.0
			light.distance_fade_length = 10.0
			root.add_child(light)

	return root
