extends RefCounted
class_name ActorBaker

## ═══════════════════════════════════════════════════════════════════════════════
##  ACTOR BAKER — turns a hand-authored character rig into a shippable one.
##
##  CharacterFactory builds beautiful characters, but it builds them FLAT: torso,
##  belt, head, both eyes, both pupils, brows, nose, mouth, ears, crown, cape and
##  every weapon part are all direct siblings under one root. That has two costs.
##
##  1. Performance. A single archetype is ~60 MeshInstance3D nodes with ~25
##     unique materials. Thirty-two of them in a 32-player match is ~1,900 draw
##     calls for the characters ALONE, before a single tree is drawn.
##
##  2. Animation correctness. Because the face, crown and cape are SIBLINGS of
##     the head rather than children of it, turning the head left the eyes,
##     nose, mouth and crown behind. Leaning the torso left the belt behind.
##     The rig could never do more than twitch without falling apart.
##
##  This rebuilds the rig into a real hierarchy — Root > Torso > Head, arms on
##  the torso, legs on the root — inferring which part belongs to which joint
##  from where it sits on the body. Then it welds each joint's parts into ONE
##  mesh with the stylised actor material.
##
##  Result: ~7 draw calls per character instead of ~60, a head that turns with
##  its face on it, and a torso that leans with its belt and cape attached.
## ═══════════════════════════════════════════════════════════════════════════════

const Baker = preload("res://scripts/render/prop_baker.gd")
const Registry = preload("res://scripts/render/visual_registry.gd")
const BLOB_SHADER = preload("res://assets/shaders/blob_shadow.gdshader")

## Names the CharacterAnimator drives. These must survive baking.
const LIMB_NAMES := ["LimbPivot_RA", "LimbPivot_LA", "LimbPivot_RL", "LimbPivot_LL"]

## Body-space heights used to decide what belongs to which joint. Characters are
## built ~2.4 units tall with the neck around y = 1.82.
const NECK_Y := 1.88
const HIP_Y := 0.92

static var _cache: Dictionary = {}


## Bake `builder`'s output once and return a fresh instance of the rebuilt rig.
## Every call after the first is a cheap node clone, not a rebuild.
static func get_actor(key: String, builder: Callable) -> Node3D:
	if not _cache.has(key):
		var raw = builder.call()
		if raw == null:
			return null
		_cache[key] = _rebuild(raw, key)
		raw.queue_free()
	return _instantiate(_cache[key], key)


## Rebuild + weld. Returns a description, not a live node, so it can be cloned.
static func _rebuild(raw: Node3D, key: String) -> Dictionary:
	var head_parts: Array = []     # [{node, xform}]
	var torso_parts: Array = []
	var limbs: Dictionary = {}     # name -> {xform, parts}
	var shadow_found := false

	for child in raw.get_children():
		if child is Node3D and LIMB_NAMES.has(child.name):
			limbs[child.name] = {
				"xform": (child as Node3D).transform,
				"node": child,
			}
			continue

		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			# The old flat ground shadow is replaced by a proper soft blob.
			if mi.mesh is PlaneMesh and mi.position.y < 0.15:
				shadow_found = true
				continue
			var y := _part_height(mi)
			if y >= NECK_Y:
				head_parts.append(mi)
			else:
				torso_parts.append(mi)
		elif child is Node3D:
			# Accessory groups (capes, quivers, weapons, hats) — classify by the
			# group's own origin height.
			var n := child as Node3D
			if n.position.y >= NECK_Y:
				head_parts.append(n)
			else:
				torso_parts.append(n)

	return {
		"head": _weld(head_parts, Vector3(0, NECK_Y, 0), key + "_head"),
		"torso": _weld(torso_parts, Vector3(0, HIP_Y, 0), key + "_torso"),
		"limbs": _weld_limbs(limbs, key),
		"shadow": shadow_found,
	}


## Sum up a part's world-space height so we can tell head from body.
static func _part_height(n: Node3D) -> float:
	if n is MeshInstance3D and n.mesh != null:
		var aabb: AABB = n.mesh.get_aabb()
		return n.position.y + aabb.get_center().y * n.scale.y
	return n.position.y


## Weld a list of sibling nodes into one mesh, expressed relative to `pivot`.
static func _weld(parts: Array, pivot: Vector3, cache_key: String) -> Mesh:
	if parts.is_empty():
		return null
	var holder := Node3D.new()
	for p in parts:
		var original_parent := (p as Node).get_parent()
		if original_parent:
			original_parent.remove_child(p)
		holder.add_child(p)
		# Re-express the part relative to the joint pivot.
		(p as Node3D).position -= pivot
	var tpl := Baker.bake(holder, cache_key, "actor")
	holder.queue_free()
	return tpl.get("mesh")


static func _weld_limbs(limbs: Dictionary, key: String) -> Dictionary:
	var out := {}
	for name in limbs.keys():
		var entry: Dictionary = limbs[name]
		var node: Node3D = entry.node
		var original_parent := node.get_parent()
		if original_parent:
			original_parent.remove_child(node)
		# Bake the limb around its own pivot (the node's transform is applied by
		# the rig, so the bake must be pivot-relative — which is exactly what
		# PropBaker does with a root node).
		var saved := node.transform
		node.transform = Transform3D.IDENTITY
		var tpl := Baker.bake(node, key + "_" + name, "actor")
		node.transform = saved
		out[name] = {"mesh": tpl.get("mesh"), "xform": saved}
		node.queue_free()
	return out


## Build a live, animatable node tree from a baked description.
static func _instantiate(desc: Dictionary, key: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Actor_" + key

	# Legs hang off the ROOT so a torso lean doesn't drag the feet.
	for leg_name in ["LimbPivot_LL", "LimbPivot_RL"]:
		var l = desc.limbs.get(leg_name, null)
		if l:
			root.add_child(_limb_node(leg_name, l))

	# Torso is a real pivot at the hip, so leaning bends the whole upper body
	# with its belt, cape and armour still attached.
	var torso := Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, HIP_Y, 0)
	root.add_child(torso)
	if desc.torso:
		var tm := MeshInstance3D.new()
		tm.name = "TorsoMesh"
		tm.mesh = desc.torso
		torso.add_child(tm)

	# Arms hang off the torso, so they swing with the lean.
	for arm_name in ["LimbPivot_LA", "LimbPivot_RA"]:
		var a = desc.limbs.get(arm_name, null)
		if a:
			var node := _limb_node(arm_name, a)
			node.position -= Vector3(0, HIP_Y, 0)
			torso.add_child(node)

	# Head is a pivot at the neck with the entire face, hair and crown inside it.
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, NECK_Y - HIP_Y, 0)
	torso.add_child(head)
	if desc.head:
		var hm := MeshInstance3D.new()
		hm.name = "HeadMesh"
		hm.mesh = desc.head
		head.add_child(hm)

	root.add_child(make_blob_shadow())
	return root


static func _limb_node(limb_name: String, data: Dictionary) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = limb_name
	pivot.transform = data.xform
	if data.mesh:
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = data.mesh
		pivot.add_child(mi)
	return pivot


# ═══════════════════════════════════════════════════════════════════════════════
#  GENERIC RIG BAKE — for anything animated that isn't a humanoid.
#
#  Beasts use a different joint set (Body, Head, Tail, Wing_L/R, four
#  LimbPivot_*), so instead of hard-coding a second humanoid path this bakes any
#  rig given the names its animator drives. Named joints survive as real pivots
#  with one welded mesh each; everything else welds into a single body mesh.
# ═══════════════════════════════════════════════════════════════════════════════

static var _rig_cache: Dictionary = {}


static func get_rig(key: String, builder: Callable, joint_names: Array,
		style: String = "actor", shadow_size: float = 0.0) -> Node3D:
	if not _rig_cache.has(key):
		var raw = builder.call()
		if raw == null:
			return null
		_rig_cache[key] = _bake_rig(raw, key, joint_names, style)
		raw.queue_free()
	return _instantiate_rig(_rig_cache[key], key, shadow_size)


static func _bake_rig(raw: Node3D, key: String, joint_names: Array, style: String) -> Dictionary:
	var joints := {}
	var body_parts: Array = []

	for child in raw.get_children():
		if child is Node3D and joint_names.has(child.name):
			joints[child.name] = child
		elif child is MeshInstance3D and child.mesh is PlaneMesh and child.position.y < 0.15:
			continue  # old flat contact shadow — replaced by the blob shader
		elif child is Node3D:
			body_parts.append(child)

	var baked_joints := {}
	for jname in joints.keys():
		var node: Node3D = joints[jname]
		var parent := node.get_parent()
		if parent:
			parent.remove_child(node)
		var saved := node.transform
		node.transform = Transform3D.IDENTITY
		var jt := Baker.bake(node, key + "_" + jname, style)
		node.transform = saved
		baked_joints[jname] = {"mesh": jt.get("mesh"), "xform": saved}
		node.queue_free()

	var holder := Node3D.new()
	for p in body_parts:
		var pp := (p as Node).get_parent()
		if pp:
			pp.remove_child(p)
		holder.add_child(p)
	var body := Baker.bake(holder, key + "_body", style)
	holder.queue_free()

	return {"body": body.get("mesh"), "joints": baked_joints}


static func _instantiate_rig(desc: Dictionary, key: String, shadow_size: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Rig_" + key

	if desc.body:
		var bm := MeshInstance3D.new()
		bm.name = "BodyMesh"
		bm.mesh = desc.body
		root.add_child(bm)

	for jname in desc.joints.keys():
		var j: Dictionary = desc.joints[jname]
		var pivot := Node3D.new()
		pivot.name = jname
		pivot.transform = j.xform
		if j.mesh:
			var mi := MeshInstance3D.new()
			mi.name = "Mesh"
			mi.mesh = j.mesh
			pivot.add_child(mi)
		root.add_child(pivot)

	if shadow_size > 0.0:
		root.add_child(make_blob_shadow(shadow_size))
	return root


## Soft grounding shadow. Shared material, so every actor on the map adds one
## quad and zero extra materials.
static var _blob_mat: ShaderMaterial = null

static func make_blob_shadow(size: float = 1.25) -> MeshInstance3D:
	if _blob_mat == null:
		_blob_mat = ShaderMaterial.new()
		_blob_mat.shader = BLOB_SHADER
	var mi := MeshInstance3D.new()
	mi.name = "GroundShadow"
	var q := PlaneMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = _blob_mat
	mi.position.y = 0.04
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func clear_cache() -> void:
	_cache.clear()
