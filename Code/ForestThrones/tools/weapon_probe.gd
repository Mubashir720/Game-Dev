extends SceneTree

## ═══════════════════════════════════════════════════════════════════════════════
##  WEAPON PROBE — is the thing in the character's hand actually visible?
##
##  A sword blade 0.02 units thick and a bowstring 0.005 across are perfectly
##  reasonable numbers in a modelling app and completely invisible in this game.
##  The camera is orthographic and isometric, a character stands about 1.9 units
##  tall and renders roughly 150px on a 720p screen, so one world unit is about
##  79 pixels. A 0.02 dimension is 1.6 pixels — a shimmering hairline that
##  vanishes at half the viewing angles.
##
##  This lists every mesh a character carries in-hand or on-back, smallest
##  dimension first, and flags anything under the readable threshold.
## ═══════════════════════════════════════════════════════════════════════════════

const CharacterFactory = preload("res://scenes/player/character_factory.gd")

## World units per pixel at gameplay distance (see above).
const PIXELS_PER_UNIT := 79.0
## Below this a part shimmers or disappears. 3px is the practical floor.
const MIN_READABLE := 3.0 / PIXELS_PER_UNIT

const ARCHETYPES := ["warlord", "regent", "beastlord", "engineer", "witch",
	"herbalist", "guardian", "berserker", "sapper", "scout", "archer", "builder"]

var _thin: Array = []


func _initialize() -> void:
	print("readable floor = %.3f units (%.0f px)\n" % [MIN_READABLE, MIN_READABLE * PIXELS_PER_UNIT])
	for a in ARCHETYPES:
		var raw = CharacterFactory.create_raw(a)
		if raw == null:
			continue
		root.add_child(raw)
		var hits: Array = []
		_scan(raw, a, hits)
		if hits.is_empty():
			print("  %-11s ok" % a)
		else:
			print("  %-11s %d thin part(s)" % [a, hits.size()])
			for h in hits:
				print("      %-22s min=%.3f (%.1f px)  size=%s" % [
					h.name, h.min, h.min * PIXELS_PER_UNIT, str(h.size)])
		raw.queue_free()

	print("\nRESULT=", "FAIL" if _thin.size() > 0 else "PASS", "  thin_parts=", _thin.size())
	quit(1 if _thin.size() > 0 else 0)


## Only weapons and held gear are checked — a character's eyebrow is allowed to
## be small, the thing they fight with is not.
##
## Identifying gear: the arm rig attaches its own parts (upper arm, elbow,
## forearm, hand) as DIRECT children of `LimbPivot_RA` / `LimbPivot_LA`, while a
## weapon is added as a group node that is then filled with meshes. So anything
## two or more levels below a limb pivot is gear, and anything one level below is
## anatomy. Back-mounted gear is caught by name.
func _scan(n: Node, who: String, hits: Array) -> void:
	_scan_at(n, who, hits, -1)


func _scan_at(n: Node, who: String, hits: Array, depth_below_pivot: int) -> void:
	for c in n.get_children():
		var d := depth_below_pivot
		var nm: String = String(c.name).to_lower()
		if d < 0 and (nm.begins_with("limbpivot_ra") or nm.begins_with("limbpivot_la")):
			d = 0
		elif d >= 0:
			d = depth_below_pivot + 1

		var is_gear: bool = d >= 2
		if not is_gear:
			var p: Node = c
			while p != null:
				var pn: String = String(p.name).to_lower()
				if pn.contains("quiver") or pn.contains("scabbard") or pn.contains("back"):
					is_gear = true
					break
				p = p.get_parent()

		if c is MeshInstance3D and c.mesh != null and is_gear:
			var sz: Vector3 = c.mesh.get_aabb().size
			var m: float = min(sz.x, min(sz.y, sz.z))
			if m < MIN_READABLE:
				var e := {"name": who + "/" + _path_of(c), "min": m, "size": sz.snappedf(0.001)}
				hits.append(e)
				_thin.append(e)
		_scan_at(c, who, hits, d)


func _path_of(n: Node) -> String:
	var parts: Array = []
	var p: Node = n
	for i in 3:
		if p == null:
			break
		parts.push_front(String(p.name))
		p = p.get_parent()
	return "/".join(parts)
