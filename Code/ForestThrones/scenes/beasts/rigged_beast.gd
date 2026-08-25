extends Node3D
class_name RiggedBeast

## ═══════════════════════════════════════════════════════════════════════════════
##  RIGGED BEAST · real skinned animals + real animations
##
##  Each species uses a DIFFERENT real animated model so the four beasts read as
##  four different animals, not one re-tinted fox:
##    • Wolf / Dire Wolf → "Fox"   (canine, Walk/Run/Survey)  — Khronos, CC-BY 4.0
##    • Boar             → "Fox"   re-proportioned squat + dark, distinct silhouette
##    • Stag             → "Horse" (hoofed quadruped, gallop)  — three.js (MIT)
##    • Raven            → "Stork" (flying bird)               — three.js (MIT)
##
##  See assets/ASSET_CREDITS.md. Exposes animate(is_moving) / trigger_attack() /
##  set_dead() so beast_base drives every species the same way.
## ═══════════════════════════════════════════════════════════════════════════════

# model:  which GLB under assets/models/beasts
# scale:  per-axis base scale (Vector3) — also used to re-proportion the boar
# tint:   albedo multiply
# run/walk/idle: clip names in that model ("" idle → pause on a frame when still)
# face:   yaw offset so the nose points along movement (atan2(x,z))
# y:      height offset (birds fly above the ground)
const SPECIES := {
	"wolf":      {"model": "Fox",   "scale": Vector3(0.019, 0.019, 0.019), "tint": Color(0.62, 0.64, 0.70), "run": "Run", "walk": "Walk", "idle": "Survey", "face": PI, "y": 0.0},
	"boar":      {"model": "Fox",   "scale": Vector3(0.021, 0.015, 0.019), "tint": Color(0.34, 0.24, 0.18), "run": "Run", "walk": "Walk", "idle": "Survey", "face": PI, "y": 0.0},
	"stag":      {"model": "Horse", "scale": Vector3(0.011, 0.011, 0.011), "tint": Color(0.58, 0.42, 0.26), "run": "horse_A_", "walk": "horse_A_", "idle": "", "face": PI, "y": 0.0},
	"raven":     {"model": "Stork", "scale": Vector3(0.007, 0.007, 0.007), "tint": Color(0.13, 0.13, 0.17), "run": "storkFly_B_", "walk": "storkFly_B_", "idle": "storkFly_B_", "face": PI, "y": 1.4},
	"dire_wolf": {"model": "Fox",   "scale": Vector3(0.025, 0.025, 0.025), "tint": Color(0.40, 0.44, 0.55), "run": "Run", "walk": "Walk", "idle": "Survey", "face": PI, "y": 0.0},
}

var _ap: AnimationPlayer = null
var _clips := {}
var _cfg: Dictionary = {}
var _base := ""
var _busy := false
var _dead := false


func setup(species: String, evolved: bool = false) -> void:
	var key := species
	if evolved and species == "wolf":
		key = "dire_wolf"
	_cfg = SPECIES.get(key, SPECIES["wolf"])

	var packed = load("res://assets/models/beasts/%s.glb" % _cfg["model"])
	if packed == null:
		return
	var model: Node3D = packed.instantiate()
	model.name = "Model"
	model.scale = _cfg["scale"]
	model.rotation.y = _cfg["face"]
	model.position.y = _cfg["y"]
	add_child(model)

	_tint(model, _cfg["tint"])
	_ap = _find_ap(model)
	if _ap:
		for c in _ap.get_animation_list():
			_clips[c] = true
		for loopc in [_cfg["run"], _cfg["walk"], _cfg["idle"]]:
			if loopc != "" and _clips.has(loopc):
				var a := _ap.get_animation(loopc)
				if a: a.loop_mode = Animation.LOOP_LINEAR
		_play_state("idle")


## Called each physics frame by beast_base.
func animate(is_moving: bool) -> void:
	if _ap == null or _dead or _busy:
		return
	var want := "run" if is_moving else "idle"
	if want == _base:
		return
	_base = want
	_play_state(want)


func _play_state(state: String) -> void:
	var clip: String = _cfg.get(state, "")
	if state == "idle" and clip == "":
		# Models with only a locomotion clip (Horse, Stork): hold still on frame 0.
		if _ap.is_playing():
			_ap.pause()
		return
	if clip == "" or not _clips.has(clip):
		return
	_ap.play(clip, 0.15)


func trigger_attack() -> void:
	if _ap == null or _dead:
		return
	_busy = true
	_base = ""
	var clip: String = _cfg.get("run", "")
	if clip != "" and _clips.has(clip):
		_ap.play(clip, 0.08)
	var t := get_tree().create_timer(0.45) if get_tree() else null
	if t:
		t.timeout.connect(func(): _busy = false; _base = "")


func set_dead(b: bool) -> void:
	_dead = b
	if b and _ap:
		_ap.stop()


func _tint(root: Node, tint: Color) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh:
			var mi := n as MeshInstance3D
			for i in range(mi.mesh.get_surface_count()):
				var base_mat := mi.get_active_material(i)
				var m: StandardMaterial3D
				if base_mat and base_mat is StandardMaterial3D:
					m = base_mat.duplicate()
				else:
					m = StandardMaterial3D.new()
				m.albedo_color = tint
				mi.set_surface_override_material(i, m)
		for c in n.get_children():
			stack.push_back(c)


func _find_ap(n):
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r = _find_ap(c)
		if r:
			return r
	return null
