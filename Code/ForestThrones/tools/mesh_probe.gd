extends SceneTree

## ═══════════════════════════════════════════════════════════════════════════════
##  MESH PROBE — catches inside-out geometry before it ships.
##
##  Why this exists: `PropBaker.bevelled_box()` emitted its six flat faces and
##  eight corner caps with reversed winding. Because the shader culls back faces,
##  every bevelled box in the game — props, structures, characters, beasts —
##  rendered with its faces invisible: a hollow wireframe of the twelve bevel
##  strips, which reads on screen as a pale translucent shell around a solid
##  core. It survived several visual passes because it looks like a lighting or
##  transparency problem, and because reading the winding code convinces you it
##  is correct. Arithmetic catches it; eyes do not.
##
##  THE TEST — a triangle's winding must agree with the normal it ships with.
##  Godot's front faces are clockwise seen from outside, so for correct geometry
##  (b-a) x (c-a) points OPPOSITE the surface normal. This is exact: it assumes
##  nothing about a part being convex or closed, so it works equally on a welded
##  leg, a hat brim and a bow limb.
##
##  An earlier version of this probe compared each triangle against its
##  component's centroid instead. That is ill-conditioned on flat plates — for a
##  disc 0.04 thick and 0.35 across, a cap triangle's offset from the centre is
##  almost entirely radial while its normal is axial, so the sign is noise. It
##  reported 40% reversed on a perfectly good hat brim. Do not go back to it.
##
##  The convention check runs first: if Godot's own primitives ever stop scoring
##  0.000, the sign is flipped and every number below is meaningless.
##
##  Run:  godot --headless --script tools/mesh_probe.gd
## ═══════════════════════════════════════════════════════════════════════════════

const Baker = preload("res://scripts/render/prop_baker.gd")
const BeastFactory = preload("res://scenes/beasts/beast_factory.gd")
const CharacterFactory = preload("res://scenes/player/character_factory.gd")
const StructureFactory = preload("res://scenes/structures/structure_factory.gd")

## Anything above this fraction of a surface is a systematic winding error rather
## than an isolated degenerate triangle.
const REVERSED_TOLERANCE := 0.01

var _fail := 0


func _initialize() -> void:
	print("── convention check: Godot built-ins must score 0.000 ──")
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.2, 0.2)
	var sph := SphereMesh.new()
	sph.radius = 0.1
	sph.height = 0.2
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.1
	cone.height = 0.2
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.4, 0.4)
	for pair in [["BoxMesh", box], ["SphereMesh", sph], ["CylinderMesh", cone],
			["PlaneMesh", plane]]:
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
			(pair[1] as Mesh).surface_get_arrays(0))
		_report(String(pair[0]), _score(am, 0), 0.0001, "<<< PROBE SIGN IS INVERTED")

	print("\n── bevelled_box ──")
	for sz in [Vector3(1, 1, 1), Vector3(0.52, 0.46, 0.45), Vector3(0.36, 0.12, 0.80),
			Vector3(2.4, 0.3, 2.4), Vector3(0.11, 0.11, 0.11)]:
		var m: ArrayMesh = Baker.bevelled_box(sz)
		var worst := 0.0
		for s in m.get_surface_count():
			worst = maxf(worst, _score(m, s))
		_report("bevelled_box%s" % str(sz), worst, 0.0001, "<<< FAIL")

	print("\n── baked beasts ──")
	for b in ["wolf", "raven", "boar", "stag"]:
		_check_node("beast:" + b, BeastFactory.build_beast(b, false))

	print("\n── baked archetypes ──")
	for a in ["warlord", "regent", "beastlord", "engineer", "witch", "herbalist",
			"guardian", "berserker", "sapper", "scout", "archer", "builder"]:
		_check_node("actor:" + a, CharacterFactory.create_character_by_archetype(a))

	print("\n── baked structures ──")
	for s2 in ["hut", "hut_upgraded", "cage_basic", "cage_full", "fire_pit",
			"wood_wall", "stone_wall", "watchtower", "workshop", "mint"]:
		_check_node("struct:" + s2, StructureFactory.build_structure(s2))

	print("\nRESULT=", "FAIL" if _fail > 0 else "PASS", "  bad=", _fail)
	quit(1 if _fail > 0 else 0)


func _report(label: String, frac: float, tol: float, msg: String) -> void:
	var ok: bool = frac <= tol
	print("  %-30s reversed=%.4f %s" % [label, frac, "" if ok else msg])
	if not ok:
		_fail += 1


func _check_node(label: String, n: Node) -> void:
	if n == null:
		print("  %-30s could not build" % label)
		_fail += 1
		return
	root.add_child(n)
	var parts: Array = []
	_collect(n, parts)
	var worst := 0.0
	var surfaces := 0
	for mi in parts:
		var m: Mesh = mi.mesh
		if not (m is ArrayMesh):
			continue
		for s in (m as ArrayMesh).get_surface_count():
			surfaces += 1
			worst = maxf(worst, _score(m as ArrayMesh, s))
	var ok: bool = worst <= REVERSED_TOLERANCE
	print("  %-30s surfaces=%-3d reversed=%.4f %s" % [
		label, surfaces, worst, "" if ok else "<<< FAIL"])
	if not ok:
		_fail += 1
	n.queue_free()


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		_collect(c, out)


## Fraction of triangles whose winding disagrees with their own stored normal.
func _score(m: ArrayMesh, s: int) -> float:
	var arr: Array = m.surface_get_arrays(s)
	if arr.is_empty():
		return 0.0
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm = arr[Mesh.ARRAY_NORMAL]
	if v.size() < 3 or nrm == null or nrm.size() < v.size():
		return 0.0        # nothing to compare the winding against

	var idx = arr[Mesh.ARRAY_INDEX]
	var indexed: bool = idx != null and idx.size() > 0
	var tris: int = (idx.size() / 3) if indexed else (v.size() / 3)

	var reversed := 0
	var counted := 0
	for t in tris:
		var i0: int
		var i1: int
		var i2: int
		if indexed:
			i0 = idx[t * 3]; i1 = idx[t * 3 + 1]; i2 = idx[t * 3 + 2]
		else:
			i0 = t * 3; i1 = t * 3 + 1; i2 = t * 3 + 2
		var wind: Vector3 = (v[i1] - v[i0]).cross(v[i2] - v[i0])
		if wind.length_squared() < 1e-14:
			continue          # degenerate sliver, carries no facing
		var n: Vector3 = (Vector3(nrm[i0]) + Vector3(nrm[i1]) + Vector3(nrm[i2])) / 3.0
		if n.length_squared() < 1e-12:
			continue
		counted += 1
		# Correct geometry: winding opposes the shipped normal, so the dot is
		# close to -1. A genuinely reversed triangle sits close to +1.
		#
		# The 0.5 threshold is not slop, it is required. SurfaceTool welds
		# coincident vertices, so where two parts touch — a log's top cap sitting
		# inside a spike's base ring — the cap's vertices inherit the cone's
		# slanted side normals. Those triangles are wound correctly but score a
		# weak positive (~0.37) against a normal that is no longer theirs.
		# Demanding a clear opposition separates real reversals from welding.
		if wind.normalized().dot(n.normalized()) > 0.5:
			reversed += 1
	if counted == 0:
		return 0.0
	return float(reversed) / float(counted)
