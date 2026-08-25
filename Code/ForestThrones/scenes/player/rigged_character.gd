extends Node3D
class_name RiggedCharacter

# ═══════════════════════════════════════════════════════════════════════════════
#  RIGGED CHARACTER  ·  real skinned models + real animations
#
#  Replaces the procedural primitive rig with the KayKit Adventurers characters
#  (CC0), which ship rigged and skinned with 76 professional animation clips.
#  This node loads the right body for an archetype, drives its AnimationPlayer
#  from the Actor's gameplay state, and cross-fades between clips so movement,
#  attacks, hits and death read like a real mobile game.
#
#  It intentionally exposes the SAME method names the old CharacterAnimator did
#  (trigger_attack/trigger_hit/set_downed/…), so Actor drives it unchanged.
# ═══════════════════════════════════════════════════════════════════════════════

# Which KayKit body wears each archetype. Five bodies, themed by squad tint and
# weapon; a Beastlord and a Berserker both ride the Barbarian build, etc.
const BODY := {
	"warlord": "Knight", "regent": "Knight", "guardian": "Knight",
	"berserker": "Barbarian", "beastlord": "Barbarian", "sapper": "Barbarian",
	"witch": "Mage", "herbalist": "Mage", "engineer": "Mage",
	"scout": "Rogue_Hooded", "archer": "Rogue", "builder": "Rogue",
}

# Which weapon meshes (already skinned to the hand bones inside each body) to
# SHOW for each archetype. Everything else in WEAPON_MESHES is hidden, so a
# Warlord carries the two-hander, a Guardian a sword + shield, a Berserker dual
# axes, an Archer a crossbow, and so on — 12 distinct silhouettes from 5 bodies.
const LOADOUT := {
	"warlord":   ["2H_Sword"],
	"regent":    ["1H_Sword", "Badge_Shield"],
	"guardian":  ["1H_Sword", "Rectangle_Shield"],
	"beastlord": ["2H_Axe"],
	"berserker": ["1H_Axe", "1H_Axe_Offhand"],
	"sapper":    ["2H_Axe"],
	"witch":     ["2H_Staff"],
	"engineer":  ["1H_Wand", "Spellbook"],
	"herbalist": ["1H_Wand", "Spellbook_open"],
	"scout":     ["Knife", "Knife_Offhand"],
	"archer":    ["2H_Crossbow"],
	"builder":   ["1H_Crossbow"],
}

# Every weapon mesh across all bodies — hidden unless the archetype's loadout
# lists it.
const WEAPON_MESHES := [
	"1H_Sword", "1H_Sword_Offhand", "2H_Sword", "Badge_Shield", "Rectangle_Shield",
	"Round_Shield", "Spike_Shield", "1H_Axe", "1H_Axe_Offhand", "2H_Axe",
	"Barbarian_Round_Shield", "1H_Wand", "2H_Staff", "Spellbook", "Spellbook_open",
	"Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow",
]

# The attack clip that matches each archetype's weapon (2H swing, dual-wield,
# ranged shot, staff thrust…), so the motion fits what they're holding.
const ATTACK := {
	"warlord": "2H_Melee_Attack_Chop",
	"regent": "1H_Melee_Attack_Slice_Diagonal",
	"guardian": "1H_Melee_Attack_Slice_Horizontal",
	"berserker": "Dualwield_Melee_Attack_Slice",
	"beastlord": "2H_Melee_Attack_Spin",
	"sapper": "2H_Melee_Attack_Chop",
	"witch": "2H_Melee_Attack_Stab",
	"herbalist": "1H_Melee_Attack_Slice_Diagonal",
	"engineer": "1H_Melee_Attack_Chop",
	"scout": "Dualwield_Melee_Attack_Stab",
	"archer": "2H_Ranged_Shoot",
	"builder": "1H_Melee_Attack_Chop",
}

# Several attack clips per weapon so the same swing isn't repeated every hit —
# trigger_attack() picks one at random. Casters cast, dual-wielders scissor,
# two-handers cleave/spin, the archer shoots.
const ATTACK_SET := {
	"warlord":   ["2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice", "2H_Melee_Attack_Spin"],
	"beastlord": ["2H_Melee_Attack_Spin", "2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice"],
	"sapper":    ["2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice", "2H_Melee_Attack_Stab"],
	"regent":    ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Stab"],
	"guardian":  ["1H_Melee_Attack_Slice_Horizontal", "Block_Attack", "1H_Melee_Attack_Chop"],
	"berserker": ["Dualwield_Melee_Attack_Slice", "Dualwield_Melee_Attack_Chop", "Dualwield_Melee_Attack_Stab"],
	"scout":     ["Dualwield_Melee_Attack_Stab", "Dualwield_Melee_Attack_Slice"],
	"witch":     ["Spellcast_Shoot", "Spellcast_Long"],
	"herbalist": ["Spellcast_Shoot", "Throw"],
	"engineer":  ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Stab"],
	"archer":    ["2H_Ranged_Shoot"],
	"builder":   ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal"],
}

# Per-archetype resting stance: two-handers hold their weapon ready, casters
# hold a casting stance, everyone else a neutral idle.
const BASE_IDLE := {
	"warlord": "2H_Melee_Idle", "beastlord": "2H_Melee_Idle", "sapper": "2H_Melee_Idle",
	"witch": "Spellcasting", "herbalist": "Spellcasting",
}

# Archetypes that carry a CUSTOM tool attached to the hand bone (the KayKit set
# has no hammer/pickaxe). Their built-in weapons are hidden and this is attached
# to handslot.r instead — so a Builder swings a hammer and a Sapper a pickaxe,
# no longer look-alikes of the Archer and Beastlord.
const TOOL := {
	"builder": "hammer",
	"sapper": "pickaxe",
	"engineer": "wrench",
}

const MODEL_SCALE := 1.35      # KayKit bodies are ~1.8u; scale to match the world
const FACE_OFFSET := 0.0       # KayKit models face +Z natively, matching atan2(x,z)

# Per-archetype identity: a distinct body palette + which headgear/cape to show,
# so the three archetypes sharing a body read as three different characters
# (helmet vs bare head vs hood, plus a unique colour). Squad identity stays on
# the cape + the feet ring, so squads are still tellable apart.
#   headgear: show the body's Helmet/Hat/Hood mesh?   cape: show the cape?
const STYLE := {
	# Knight body
	"warlord":   {"color": Color(0.72, 0.16, 0.14), "headgear": true,  "cape": true},   # crimson, helmed
	"regent":    {"color": Color(0.42, 0.20, 0.62), "headgear": false, "cape": true},   # royal purple, bareheaded
	"guardian":  {"color": Color(0.24, 0.44, 0.30), "headgear": true,  "cape": false},  # steel-green, helmed
	# Barbarian body (Hat = bear hood)
	"beastlord": {"color": Color(0.45, 0.32, 0.20), "headgear": true,  "cape": true},   # earthy brown, hooded
	"berserker": {"color": Color(0.55, 0.12, 0.10), "headgear": false, "cape": false},  # blood red, bare wild
	"sapper":    {"color": Color(0.66, 0.40, 0.14), "headgear": false, "cape": false},  # ochre, bare-headed
	# Mage body (Hat = wizard hat)
	"witch":     {"color": Color(0.30, 0.12, 0.42), "headgear": true,  "cape": true},   # deep violet, hatted
	"engineer":  {"color": Color(0.14, 0.44, 0.48), "headgear": true,  "cape": false},  # teal, hatted
	"herbalist": {"color": Color(0.20, 0.50, 0.28), "headgear": false, "cape": false},  # herb green, bareheaded
	# Rogue body
	"scout":     {"color": Color(0.20, 0.30, 0.20), "headgear": true,  "cape": false},  # dark green (hooded body)
	"archer":    {"color": Color(0.16, 0.46, 0.26), "headgear": false, "cape": true},   # emerald, caped
	"builder":   {"color": Color(0.70, 0.58, 0.20), "headgear": false, "cape": false},  # tan/yellow
}

const HEADGEAR_MESHES := ["Knight_Helmet", "Barbarian_Hat", "Mage_Hat"]
const CAPE_MESHES := ["Knight_Cape", "Barbarian_Cape", "Mage_Cape", "Rogue_Cape"]

var _ap: AnimationPlayer = null
var _archetype := "warlord"
var _clips: Dictionary = {}
var _base := "idle"            # current locomotion clip name resolved
var _busy := false             # a one-shot action is playing
var _vital := ""               # "" | "downed" | "dead"
var _blocking := false
var _carrying := false         # hauling a prisoner
var _carried := false          # being hauled by a captor
var _hp_band := 0              # 0 healthy · 1 wounded · 2 critical (GDD §9 HP states)
var _lod := 0

# Locomotion clip per HP band — a wounded fighter drops from a run to a laboured
# walk, a critical one to the slowest, heaviest gait. Readable injury at a glance,
# which the GDD flags as core combat info, not flavour.
const RUN_BY_BAND := {0: "Running_A", 1: "Walking_A", 2: "Walking_C"}
const IDLE_HURT := {1: "Idle", 2: "Idle"}


func setup(archetype_id: String, squad_color: Color) -> void:
	_archetype = archetype_id.to_lower()
	var body: String = BODY.get(_archetype, "Knight")
	var packed = load("res://assets/models/characters/%s.glb" % body)
	if packed == null:
		return
	var model: Node3D = packed.instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * MODEL_SCALE
	model.rotation.y = FACE_OFFSET
	add_child(model)
	_ap = _find_ap(model)
	if _ap:
		for c in _ap.get_animation_list():
			_clips[c] = true
		_config_loops()
		_play("Idle", 0.0)
	_apply_loadout(model)
	_apply_style(model, squad_color)
	_apply_tool(model)


# Attach a custom hand tool (hammer/pickaxe/wrench) to handslot.r and hide the
# body's built-in weapons, so tool-using roles look right.
func _apply_tool(model: Node) -> void:
	var kind: String = TOOL.get(_archetype, "")
	if kind == "":
		return
	# Hide every built-in weapon so the custom tool is the only thing in hand.
	var stack: Array = [model]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and WEAPON_MESHES.has(n.name):
			n.visible = false
		for c in n.get_children():
			stack.push_back(c)
	var skel = _find_skeleton(model)
	if skel == null:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = "handslot.r"
	skel.add_child(ba)
	var tool := _build_tool(kind)
	# Orient the handle to sit naturally in the fist (tuned against the KayKit
	# hand bone) and rotate it forward like the built-in weapons.
	tool.rotation = Vector3(deg_to_rad(90.0), 0, 0)
	tool.position = Vector3(0, 0.02, 0)
	ba.add_child(tool)

func _find_skeleton(n: Node):
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r = _find_skeleton(c)
		if r:
			return r
	return null


func _build_tool(kind: String) -> Node3D:
	var g := Node3D.new()
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.42, 0.28, 0.16); wood.roughness = 0.8
	var metal := StandardMaterial3D.new(); metal.albedo_color = Color(0.55, 0.57, 0.62); metal.metallic = 0.8; metal.roughness = 0.35
	# Handle — shared by all tools.
	var handle := MeshInstance3D.new()
	var hc := CylinderMesh.new(); hc.top_radius = 0.028; hc.bottom_radius = 0.032; hc.height = 0.62
	handle.mesh = hc; handle.material_override = wood; handle.position.y = 0.20
	g.add_child(handle)
	match kind:
		"hammer":
			var head := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(0.24, 0.14, 0.15)
			head.mesh = bm; head.material_override = metal; head.position.y = 0.50
			g.add_child(head)
		"pickaxe":
			for s in [-1, 1]:
				var spike := MeshInstance3D.new()
				var cc := CylinderMesh.new(); cc.top_radius = 0.0; cc.bottom_radius = 0.045; cc.height = 0.26
				spike.mesh = cc; spike.material_override = metal
				spike.position = Vector3(0.13 * s, 0.50, 0)
				spike.rotation = Vector3(0, 0, deg_to_rad(90.0 - 18.0 * s))
				g.add_child(spike)
		"wrench":
			var jaw := MeshInstance3D.new()
			var tm := TorusMesh.new(); tm.inner_radius = 0.05; tm.outer_radius = 0.10; tm.rings = 8; tm.ring_segments = 5
			jaw.mesh = tm; jaw.material_override = metal; jaw.position.y = 0.50
			jaw.rotation.x = deg_to_rad(90.0)
			g.add_child(jaw)
	return g

# Show only this archetype's weapons; hide every other weapon mesh in the body.
func _apply_loadout(model: Node) -> void:
	var show: Array = LOADOUT.get(_archetype, [])
	var stack: Array = [model]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and WEAPON_MESHES.has(n.name):
			n.visible = show.has(n.name)
		for c in n.get_children():
			stack.push_back(c)


# ── Called by Actor every frame (signature matches the old animator) ──
func animate_character(_node, _archetype_id: String, is_moving: bool, _delta: float) -> void:
	if _ap == null:
		return
	if _vital != "":
		return
	# Being carried as a prisoner: hang limp regardless of anything else.
	if _carried:
		if _base != "carried":
			_base = "carried"
			_play(_pick(["Lie_Idle", "Lie_Pose"]), 0.2)
		return
	if _busy:
		return
	var want := "idle"
	if _carrying:
		want = "carry"
	elif _blocking:
		want = "block"
	elif is_moving:
		want = "run"
	if want != _base:
		_base = want
		match want:
			"carry": _play(_pick(["2H_Melee_Idle", "PickUp", "Idle"]), 0.2)
			"run": _play(_pick([RUN_BY_BAND.get(_hp_band, "Running_A"), "Running_A", "Walking_A"]), 0.18)
			"block": _play(_pick(["Blocking", "Block", "2H_Melee_Idle"]), 0.15)
			_: _play(_base_idle(), 0.2)

func _base_idle() -> String:
	return _pick([BASE_IDLE.get(_archetype, "Idle"), "Idle", "Idle_A"])


func trigger_attack() -> void:
	if _vital != "": return
	var set: Array = ATTACK_SET.get(_archetype, [ATTACK.get(_archetype, "1H_Melee_Attack_Chop")])
	_one_shot(set[randi() % set.size()] if set.size() > 0 else "1H_Melee_Attack_Chop")

func trigger_charge() -> void:
	if _vital != "": return
	_one_shot(_pick(["2H_Melee_Attack_Spinning", "2H_Melee_Attack_Spin",
			"Dualwield_Melee_Attack_Chop", "1H_Melee_Attack_Chop"]))

## Bow / crossbow loose — a real ranged shoot clip, not a melee swing.
func trigger_ranged() -> void:
	if _vital != "": return
	_one_shot(_pick(["2H_Ranged_Shoot", "1H_Ranged_Shoot", "2H_Ranged_Shooting",
			"1H_Ranged_Shooting", "Throw"]))

func trigger_harvest() -> void:
	if _vital != "": return
	# Chopping/mining reads as a repeated chop; casters just interact.
	_one_shot("1H_Melee_Attack_Chop" if not BASE_IDLE.has(_archetype) or _archetype in ["warlord","sapper","beastlord"] else "Interact")

func trigger_gather() -> void:
	trigger_harvest()

func trigger_build() -> void:
	if _vital != "": return
	_one_shot(_pick(["Interact", "PickUp", "Use_Item"]))

func trigger_interact() -> void:
	if _vital != "": return
	_one_shot(_pick(["Interact", "PickUp"]))

func trigger_throw() -> void:
	if _vital != "": return
	_one_shot(_pick(["Throw", "Spellcast_Shoot"]))

func trigger_use_item() -> void:
	if _vital != "": return
	_one_shot(_pick(["Use_Item", "Interact"]))

func trigger_ability() -> void:
	if _vital != "": return
	# Casters cast; martial archetypes rally; supports raise a spell.
	if BASE_IDLE.get(_archetype, "") == "Spellcasting":
		_one_shot(_pick(["Spellcast_Long", "Spellcast_Raise", "Spellcast_Shoot"]))
	else:
		_one_shot(_pick(["Cheer", "Spellcast_Raise", "2H_Melee_Attack_Spin"]))

func trigger_hit() -> void:
	if _vital == "dead": return
	if _blocking:
		_one_shot(_pick(["Block_Hit", "Hit_A"]))
	else:
		_one_shot(_pick(["Hit_A", "Hit_B"]))

func set_blocking(b: bool) -> void:
	_blocking = b
	_base = ""      # force a locomotion re-resolve next frame

var _crawling := false

func set_downed(b: bool) -> void:
	if b:
		_vital = "downed"
		_crawling = false
		_play(_pick(["Lie_Idle", "Death_A_Pose", "Death_A"]), 0.2)
	elif _vital == "downed":
		_vital = ""
		_base = ""

## Downed movement. KayKit has no dedicated crawl clip, so the ground pose stays
## Lie_Idle and the body physically dragging along sells the crawl. Kept as a hook
## so a real crawl clip can be swapped in later without touching Actor.
func set_crawling(b: bool) -> void:
	if b == _crawling:
		return
	_crawling = b

func set_dead(b: bool) -> void:
	if b:
		_vital = "dead"
		_play(_pick(["Death_A", "Death_B"]), 0.15)
	else:
		_vital = ""
		_base = ""

func set_hp_band(band: int) -> void:
	if band == _hp_band:
		return
	_hp_band = band
	_base = ""      # re-resolve locomotion so the injured gait swaps in

func trigger_revive() -> void:
	_vital = ""
	_carried = false
	_base = ""
	_one_shot(_pick(["Lie_StandUp", "Interact"]))

func set_carrying(b: bool) -> void:
	_carrying = b
	_base = ""

func set_carried(b: bool) -> void:
	_carried = b
	_base = ""

func set_lod(level: int) -> void:
	_lod = level
	if _ap:
		# Distant actors don't need to burn CPU skinning every frame.
		_ap.active = level == 0
	visible = level < 2


# ── internals ────────────────────────────────────────────────────────────────
func _one_shot(clip: String) -> void:
	clip = _resolve(clip)
	if clip == "" or _ap == null:
		return
	_busy = true
	_play(clip, 0.08)
	if not _ap.animation_finished.is_connected(_on_finished):
		_ap.animation_finished.connect(_on_finished)

func _on_finished(_anim_name: String) -> void:
	_busy = false
	if _vital == "":
		_base = ""      # re-resolve locomotion after the action

func _play(clip: String, blend: float) -> void:
	clip = _resolve(clip)
	if clip == "" or _ap == null:
		return
	if blend > 0.0:
		_ap.play(clip, blend)
	else:
		_ap.play(clip)

# Return the first clip name that exists in this model, from a candidate list.
func _pick(cands: Array) -> String:
	for c in cands:
		if _clips.has(c):
			return c
	return cands[0] if cands.size() > 0 else ""

func _resolve(clip: String) -> String:
	if _clips.has(clip):
		return clip
	return _pick([clip, "Idle"])

func _config_loops() -> void:
	for name in ["Idle", "Idle_A", "Running_A", "Running_B", "Walking_A",
			"Walking_B", "Walking_C", "Blocking", "Block", "2H_Melee_Idle",
			"Lie_Idle", "Lie_Pose", "Spellcasting", "PickUp"]:
		if _clips.has(name):
			var a := _ap.get_animation(name)
			if a: a.loop_mode = Animation.LOOP_LINEAR
	for name in ["Death_A", "Death_B", "Death_A_Pose"]:
		if _clips.has(name):
			var a := _ap.get_animation(name)
			if a: a.loop_mode = Animation.LOOP_NONE

func _find_ap(n):
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r = _find_ap(c)
		if r:
			return r
	return null

# Give the character its archetype identity: toggle headgear/cape for a distinct
# silhouette, recolour the body to the archetype palette, and put the SQUAD colour
# on the cape so squads stay readable. Body/arms/legs → archetype colour;
# cape → squad colour; headgear → a darker shade of the archetype colour; the
# head (skin) is left natural.
func _apply_style(root: Node, squad_color: Color) -> void:
	var s: Dictionary = STYLE.get(_archetype, {})
	var primary: Color = s.get("color", Color(0.5, 0.5, 0.5))
	var show_headgear: bool = s.get("headgear", true)
	var show_cape: bool = s.get("cape", true)

	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var nm := mi.name
			# Silhouette toggles.
			if HEADGEAR_MESHES.has(nm):
				mi.visible = show_headgear
			elif CAPE_MESHES.has(nm):
				mi.visible = show_cape
			# Recolour by body part.
			var role := ""
			if nm.contains("Body") or nm.contains("Arm") or nm.contains("Leg"):
				role = "primary"
			elif CAPE_MESHES.has(nm):
				role = "squad"
			elif HEADGEAR_MESHES.has(nm):
				role = "headgear"
			if role != "" and mi.mesh:
				for i in range(mi.mesh.get_surface_count()):
					var base_mat := mi.get_active_material(i)
					if base_mat and base_mat is StandardMaterial3D:
						var m: StandardMaterial3D = base_mat.duplicate()
						match role:
							"primary": m.albedo_color = m.albedo_color.lerp(primary, 0.72)
							"squad":   m.albedo_color = m.albedo_color.lerp(squad_color, 0.85)
							"headgear": m.albedo_color = m.albedo_color.lerp(primary.darkened(0.35), 0.6)
						mi.set_surface_override_material(i, m)
		for c in n.get_children():
			stack.push_back(c)
