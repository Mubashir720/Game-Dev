extends RefCounted
class_name ChunkBatcher

## ═══════════════════════════════════════════════════════════════════════════════
##  CHUNK BATCHER — Turns thousands of prop placements into a handful of nodes.
##
##  Feed it (baked mesh, transform, tint) triples; it groups by mesh and emits
##  one MultiMeshInstance3D per distinct mesh. 2,000 pine trees stop being
##  2,000 nodes and become 1 node holding 2,000 matrices — one draw call per
##  surface, culled as a unit, streamed as a unit.
##
##  Collision is batched the same way: every prop shape in the chunk hangs off
##  a single StaticBody3D instead of one body per tree.
## ═══════════════════════════════════════════════════════════════════════════════

var _batches: Dictionary = {}     # mesh RID key -> { mesh, xforms, colors }
var _collision: Array = []        # [{ shape, xform }]
var _instance_count: int = 0


func add(mesh: Mesh, xform: Transform3D, tint: Color = Color.WHITE) -> void:
	if mesh == null:
		return
	var key := str(mesh.get_instance_id())
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "xforms": [], "colors": PackedColorArray()}
	_batches[key].xforms.append(xform)
	_batches[key].colors.append(tint)
	_instance_count += 1


## Place a full baked template (mesh + its collision shapes) at `xform`.
func add_template(tpl: Dictionary, xform: Transform3D, tint: Color = Color.WHITE,
		with_collision: bool = true) -> void:
	if tpl.is_empty():
		return
	if tpl.get("mesh") != null:
		add(tpl.mesh, xform, tint)
	if with_collision:
		for c in tpl.get("collision", []):
			_collision.append({"shape": c.shape, "xform": xform * c.xform})


func add_collision(shape: Shape3D, xform: Transform3D) -> void:
	if shape != null:
		_collision.append({"shape": shape, "xform": xform})


func instance_count() -> int:
	return _instance_count


func batch_count() -> int:
	return _batches.size()


func collision_count() -> int:
	return _collision.size()


func is_empty() -> bool:
	return _batches.is_empty() and _collision.is_empty()


## Emit the batched geometry under `parent`.
##   near_range   — distance at which the full-density batch stops drawing
##   fade         — soft fade band so pop-in isn't a hard snap
##   far_range    — if > near_range, a thinned second batch covers near..far so
##                  the horizon still reads as forest at a fraction of the tris
##   far_fraction — how much of the batch survives into the far band
## Returns the number of MultiMeshInstance3D nodes created.
func flush_visuals(parent: Node3D, near_range: float = 0.0, fade: float = 0.0,
		cast_shadows: bool = true, far_range: float = 0.0,
		far_fraction: float = 0.35) -> int:
	var made := 0
	for key in _batches.keys():
		var b: Dictionary = _batches[key]
		var count: int = b.xforms.size()
		if count == 0:
			continue

		# Near band — everything, full density, this is what the player sees.
		var near_mmi := _make_mmi(b.mesh, b.xforms, b.colors, count)
		if near_range > 0.0:
			near_mmi.visibility_range_end = near_range
			near_mmi.visibility_range_end_margin = fade
			near_mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		near_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(near_mmi)
		made += 1

		# Far band — a deterministic subset, no shadows. Keeps the silhouette of
		# a full forest on the horizon for a third of the geometry cost.
		if far_range > near_range and near_range > 0.0 and count >= 4:
			var step := int(round(1.0 / clamp(far_fraction, 0.05, 1.0)))
			var fx: Array = []
			var fc := PackedColorArray()
			for i in range(0, count, step):
				fx.append(b.xforms[i])
				fc.append(b.colors[i])
			if fx.size() > 0:
				var far_mmi := _make_mmi(b.mesh, fx, fc, fx.size())
				far_mmi.name = "MM_far_" + far_mmi.name
				far_mmi.visibility_range_begin = near_range
				far_mmi.visibility_range_begin_margin = fade
				far_mmi.visibility_range_end = far_range
				far_mmi.visibility_range_end_margin = fade
				far_mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				far_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				parent.add_child(far_mmi)
				made += 1
	return made


func _make_mmi(mesh: Mesh, xforms: Array, colors: PackedColorArray, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	for i in range(count):
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "MM_%s_%d" % [_short_name(mesh), count]
	return mmi


## Emit all batched collision shapes as ONE StaticBody3D. Returns it, or null.
func flush_collision(parent: Node3D, layer: int = 1, mask: int = 1) -> StaticBody3D:
	if _collision.is_empty():
		return null
	var body := StaticBody3D.new()
	body.name = "ChunkCollision_%d" % _collision.size()
	body.collision_layer = layer
	body.collision_mask = mask
	for c in _collision:
		var cs := CollisionShape3D.new()
		cs.shape = c.shape
		cs.transform = c.xform
		body.add_child(cs)
	parent.add_child(body)
	return body


func clear() -> void:
	_batches.clear()
	_collision.clear()
	_instance_count = 0


static func _short_name(m: Mesh) -> String:
	if m == null:
		return "null"
	if m.resource_name != "":
		return m.resource_name.replace("#", "_")
	return m.get_class()
