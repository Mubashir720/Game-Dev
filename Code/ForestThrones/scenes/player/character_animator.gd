extends Node

# ═══════════════════════════════════════════════════════════════════════════════
#  CHARACTER ANIMATOR — Production-Quality Archetype-Specific Animations
#  Supports all 12 GDD Archetypes with specialized weapon stances, attack swings,
#  block guards, ability casts, and harvest animations.
#  Uses robust named node lookups: LimbPivot_RA/LA/RL/LL, Head, Torso.
# ═══════════════════════════════════════════════════════════════════════════════

enum AnimState { IDLE, WALK, ATTACK, HARVEST, BLOCK, ABILITY, DOWNED, DEAD }

var current_state: AnimState = AnimState.IDLE
var anim_t: float = 0.0
var idle_t: float = 0.0

func animate_character(character_node: Node3D, archetype_id: String, is_moving: bool, delta: float) -> void:
	if not is_instance_valid(character_node):
		return

	# Robust named node lookups matching character_factory.gd
	var right_arm := _find_child(character_node, "LimbPivot_RA")
	var left_arm  := _find_child(character_node, "LimbPivot_LA")
	var right_leg := _find_child(character_node, "LimbPivot_RL")
	var left_leg  := _find_child(character_node, "LimbPivot_LL")
	var torso     := _find_child(character_node, "Torso")
	var head      := _find_child(character_node, "Head")

	idle_t += delta * 2.0

	# 1. Base Locomotion / Idle Breathing
	if is_moving:
		anim_t += delta * 8.0
		_animate_locomotion(right_leg, left_leg, right_arm, left_arm, torso, anim_t)
	else:
		_animate_idle(right_leg, left_leg, right_arm, left_arm, torso, head, archetype_id, idle_t, delta)

	# 2. State Overlays
	match current_state:
		AnimState.ATTACK:
			anim_t += delta * 12.0
			_play_archetype_attack(right_arm, left_arm, torso, head, archetype_id, anim_t)
			if anim_t >= PI:
				current_state = AnimState.IDLE
				anim_t = 0.0

		AnimState.HARVEST:
			anim_t += delta * 9.0
			_play_harvest_swing(right_arm, left_arm, torso, anim_t)
			if anim_t >= TAU:
				current_state = AnimState.IDLE
				anim_t = 0.0

		AnimState.BLOCK:
			_play_archetype_block(right_arm, left_arm, torso, archetype_id)

		AnimState.ABILITY:
			anim_t += delta * 6.0
			_play_archetype_ability(right_arm, left_arm, torso, head, archetype_id, anim_t)
			if anim_t >= PI:
				current_state = AnimState.IDLE
				anim_t = 0.0


func trigger_attack() -> void:
	current_state = AnimState.ATTACK
	anim_t = 0.0

func trigger_harvest() -> void:
	current_state = AnimState.HARVEST
	anim_t = 0.0

func trigger_ability() -> void:
	current_state = AnimState.ABILITY
	anim_t = 0.0

func set_blocking(blocking: bool) -> void:
	current_state = AnimState.BLOCK if blocking else AnimState.IDLE


# ─── IDLE & WEAPON READY STANCES ─────────────────────────────────────────────
func _animate_idle(rl: Node3D, ll: Node3D, ra: Node3D, la: Node3D, torso: Node3D, head: Node3D,
		archetype_id: String, t: float, delta: float) -> void:
	# Legs return to rest
	if rl: rl.rotation.x = move_toward(rl.rotation.x, 0.0, delta * 4.0)
	if ll: ll.rotation.x = move_toward(ll.rotation.x, 0.0, delta * 4.0)

	# Torso gentle breathing sway
	if torso:
		torso.rotation.x = sin(t) * 0.015

	# Archetype weapon idle stances
	match archetype_id.to_lower():
		"warlord":
			# Heavy broadsword low ready
			if ra: ra.rotation = Vector3(deg_to_rad(-25.0), deg_to_rad(-15.0), 0)
			if la: la.rotation = Vector3(deg_to_rad(-15.0), deg_to_rad(15.0), 0)

		"archer":
			# Bow held forward, string pulled slightly back
			if la: la.rotation = Vector3(deg_to_rad(-65.0), deg_to_rad(20.0), 0)
			if ra: ra.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(-30.0), 0)

		"guardian":
			# Shield held forward in guard position
			if la: la.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(25.0), 0)
			if ra: ra.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(-10.0), 0)

		"berserker":
			# Dual axes flared outward aggressively
			if ra: ra.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(-30.0), deg_to_rad(15.0))
			if la: la.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(30.0), deg_to_rad(-15.0))

		"witch":
			# Staff held upright, subtle levitation sway
			if ra: ra.rotation = Vector3(deg_to_rad(-40.0), 0, 0)
			if torso: torso.rotation.z = sin(t * 1.5) * 0.02

		_:
			# Default standard stance
			if ra: ra.rotation.x = move_toward(ra.rotation.x, 0.0, delta * 3.0)
			if la: la.rotation.x = move_toward(la.rotation.x, 0.0, delta * 3.0)


# ─── LOCOMOTION (Leg swing + arm counter-swing + torso bob) ──────────────────
func _animate_locomotion(rl: Node3D, ll: Node3D, ra: Node3D, la: Node3D, torso: Node3D, t: float) -> void:
	var swing := sin(t) * 0.5

	if rl: rl.rotation.x = swing
	if ll: ll.rotation.x = -swing

	if ra: ra.rotation.x = -swing * 0.6
	if la: la.rotation.x = swing * 0.6

	if torso: torso.rotation.z = sin(t * 2.0) * 0.025


# ─── HARVEST SWING (Wood chop / Stone mine) ──────────────────────────────────
func _play_harvest_swing(ra: Node3D, la: Node3D, torso: Node3D, t: float) -> void:
	var swing = sin(t) * 1.4
	if ra: ra.rotation.x = -swing
	if la: la.rotation.x = -swing * 0.5
	if torso: torso.rotation.x = swing * 0.15


# ─── ARCHETYPE-SPECIFIC ATTACKS ──────────────────────────────────────────────
func _play_archetype_attack(ra: Node3D, la: Node3D, torso: Node3D, head: Node3D,
		archetype_id: String, t: float) -> void:
	match archetype_id.to_lower():
		"warlord":
			# Two-Handed Broadsword Heavy Overhead Cleave
			var slash = sin(t) * 2.0
			if ra: ra.rotation.x = -slash
			if la: la.rotation.x = -slash * 0.95
			if torso: torso.rotation.y = sin(t) * 0.35

		"archer":
			# Longbow Draw & Full Release Snap
			if t < PI * 0.6: # Drawing back
				if la: la.rotation = Vector3(deg_to_rad(-75.0), deg_to_rad(20.0), 0)
				if ra: ra.rotation = Vector3(deg_to_rad(-70.0), deg_to_rad(-45.0), 0)
			else: # Release snap
				if ra: ra.rotation = Vector3(deg_to_rad(-20.0), 0, 0)

		"berserker":
			# Dual Axe Cross-Scissor Chop
			var chop = sin(t * 1.5) * 1.6
			if ra: ra.rotation = Vector3(-chop, deg_to_rad(-35.0), 0)
			if la: la.rotation = Vector3(-chop, deg_to_rad(35.0), 0)
			if torso: torso.rotation.x = chop * 0.2

		"guardian":
			# Spear Thrust over Shield
			var thrust = sin(t) * 0.5
			if la: la.rotation = Vector3(deg_to_rad(-60.0), deg_to_rad(30.0), 0) # Shield held firm
			if ra:
				ra.position.z = thrust
				ra.rotation.x = deg_to_rad(-85.0)

		"witch":
			# Hex Staff Thrust & Spell Blast
			var cast = sin(t) * 1.2
			if ra: ra.rotation.x = -cast
			if head: head.rotation.x = deg_to_rad(-15.0)

		"sapper":
			# Demolition Pickaxe Strike
			var strike = sin(t) * 1.8
			if ra: ra.rotation.x = -strike
			if torso: torso.rotation.x = strike * 0.25

		"scout":
			# Quick Flare Gun Pistol Shot / Dagger Lunge
			if ra: ra.rotation = Vector3(deg_to_rad(-90.0) + sin(t) * 0.2, 0, 0)

		"herbalist":
			# Potion Splash Throw
			var throw = sin(t) * 1.4
			if ra: ra.rotation.x = -throw

		"engineer":
			# Wrench Overhead Hammering Strike
			var swing = sin(t) * 1.5
			if ra: ra.rotation.x = -swing

		"regent":
			# Royal Scepter Edict Wave
			if ra: ra.rotation = Vector3(deg_to_rad(-80.0), sin(t) * 0.5, 0)

		"beastlord":
			# Beast Whip Lash
			var whip = sin(t * 2.0) * 1.5
			if ra: ra.rotation = Vector3(-whip, deg_to_rad(-20.0), 0)

		"builder":
			# Construction Mallet Slam
			var slam = sin(t) * 1.7
			if ra: ra.rotation.x = -slam
			if torso: torso.rotation.x = slam * 0.3

		_:
			# Standard Melee Swing
			var slash = sin(t) * 1.5
			if ra: ra.rotation.x = -slash


# ─── ARCHETYPE-SPECIFIC BLOCK / GUARD STANCES ────────────────────────────────
func _play_archetype_block(ra: Node3D, la: Node3D, torso: Node3D, archetype_id: String) -> void:
	match archetype_id.to_lower():
		"guardian":
			# Full Tower Shield Wall Stance
			if la: la.rotation = Vector3(deg_to_rad(-70.0), deg_to_rad(45.0), deg_to_rad(-20.0))
			if ra: ra.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-20.0), 0)
			if torso: torso.rotation.y = deg_to_rad(-15.0)

		"warlord":
			# Broadsword Cross-Parry
			if ra: ra.rotation = Vector3(deg_to_rad(-65.0), deg_to_rad(30.0), 0)
			if la: la.rotation = Vector3(deg_to_rad(-65.0), deg_to_rad(-20.0), 0)

		_:
			# Standard Bracing Guard
			if ra: ra.rotation.x = deg_to_rad(-45.0)
			if la: la.rotation.x = deg_to_rad(-60.0)


# ─── ARCHETYPE-SPECIFIC ABILITY CASTING ──────────────────────────────────────
func _play_archetype_ability(ra: Node3D, la: Node3D, torso: Node3D, head: Node3D,
		archetype_id: String, t: float) -> void:
	match archetype_id.to_lower():
		"warlord":
			# Rallying Cry — Flag Plant & Shout
			if ra: ra.rotation = Vector3(deg_to_rad(-170.0), 0, 0)
			if head: head.rotation.x = deg_to_rad(-35.0)

		"witch":
			# Dark Curse Spell Channeling — Floating Arms
			if ra: ra.rotation = Vector3(deg_to_rad(-150.0), deg_to_rad(-40.0), 0)
			if la: la.rotation = Vector3(deg_to_rad(-150.0), deg_to_rad(40.0), 0)
			if torso: torso.position.y = sin(t * 3.0) * 0.05

		"beastlord":
			# Pack Leader Horn Blow
			if ra: ra.rotation = Vector3(deg_to_rad(-120.0), deg_to_rad(-20.0), 0)
			if head: head.rotation.x = deg_to_rad(-30.0)

		"herbalist":
			# Healing Potion Drink / Mend Potion
			if ra: ra.rotation = Vector3(deg_to_rad(-130.0), deg_to_rad(-30.0), 0)
			if head: head.rotation.x = deg_to_rad(20.0)

		"engineer":
			# Overclock Device Key Turn
			if ra: ra.rotation = Vector3(deg_to_rad(-90.0), sin(t * 4.0) * 0.4, 0)

		_:
			# Overhead Victory Pose
			if ra: ra.rotation.x = deg_to_rad(-160.0)
			if la: la.rotation.x = deg_to_rad(-160.0)
			if head: head.rotation.x = deg_to_rad(-20.0)


# ─── UTILITY ─────────────────────────────────────────────────────────────────
func _find_child(parent: Node3D, child_name: String) -> Node3D:
	if parent.has_node(child_name):
		var child = parent.get_node(child_name)
		if child is Node3D:
			return child
	for child in parent.get_children():
		if child is Node3D and child.name == child_name:
			return child
	return null
