extends CharacterBody3D
class_name Actor

## ═══════════════════════════════════════════════════════════════════════════════
##  ACTOR — the shared body every combatant in a match runs on.
##
##  Before this existed, player.gd owned movement, stats, inventory, HP states
##  AND read the keyboard directly in _physics_process. That made it impossible
##  to reuse for the 31 other participants in a 32-player match without either
##  duplicating the whole file or giving bots fake input.
##
##  Actor owns everything a body does; it never reads input and never decides
##  anything. Controllers set `move_intent` and call the action methods:
##    • Player   — sets move_intent from touch/keyboard
##    • BotAgent — sets move_intent from its brain
##
##  Implements GDD §8 (survival stats) and §9 (HP states, downed, friendly fire).
## ═══════════════════════════════════════════════════════════════════════════════

const CharacterFactory = preload("res://scenes/player/character_factory.gd")
const CharacterAnimator = preload("res://scenes/player/character_animator.gd")
const RiggedCharacter = preload("res://scenes/player/rigged_character.gd")
const AbilityControllerScript = preload("res://scenes/roles/ability_controller.gd")

## Use the rigged KayKit models + real animations when the asset is present;
## fall back to the procedural factory otherwise so the game always runs.
const USE_RIGGED := true

signal hp_changed(current: float, maximum: float)
signal state_changed(new_state: int)
signal downed()
signal died(killer)
signal resource_gained(type: int, amount: int)

enum HPState { HEALTHY, WOUNDED, CRITICAL, DOWNED, DEAD }

# ── Identity ──────────────────────────────────────────────────────────────────
@export var role: Constants.Role = Constants.Role.KING
@export var archetype_id: String = "warlord"
@export var squad_id: String = "squad_1"
@export var squad_color: Color = Color(0.85, 0.25, 0.20)
@export var display_name: String = "Player"
@export var is_bot: bool = false

# ── Movement ──────────────────────────────────────────────────────────────────
@export var base_speed: float = 6.0
## Set by the controller each frame. Length 0..1; direction in world XZ.
var move_intent: Vector3 = Vector3.ZERO
## Extra multipliers from buffs/debuffs (Rally Cry, Frenzy, Hex, Adrenaline...).
var speed_multiplier: float = 1.0
var damage_multiplier: float = 1.0

# ── Survival stats (GDD §8) ───────────────────────────────────────────────────
var hp: float = Constants.MAX_HP
var hunger: float = Constants.MAX_HUNGER
var thirst: float = Constants.MAX_THIRST
var hp_state: HPState = HPState.HEALTHY

# ── Inventory (GDD §5) ────────────────────────────────────────────────────────
var inventory: Dictionary = {}
var max_carry: int = 20
var coins: int = 0

# ── Combat ────────────────────────────────────────────────────────────────────
var attack_damage: float = Constants.BASIC_SWORD_DAMAGE
var attack_range: float = 2.0
var attack_cooldown: float = 0.9
## Bow users (Archer, or anyone who buys a bow) fight at range with arrows.
var is_ranged: bool = false
const ArrowScript = preload("res://scenes/combat/weapons/arrow.gd")
var is_blocking: bool = false
var _attack_timer: float = 0.0

# Capture state (GDD §10). A captured prisoner is downed but held — it must not
# bleed out or wander. `captured` = slung on a captor; `imprisoned` = locked in a cage.
var is_captured: bool = false
var is_imprisoned: bool = false
var captor: Actor = null
var _imprison_time: float = 0.0

# ── Traitor / trust (GDD §11) ─────────────────────────────────────────────────
var has_traitor_token: bool = false
var traitor_activated: bool = false
var trust_score: float = 100.0

# ── Internals ─────────────────────────────────────────────────────────────────
var character_visual: Node3D = null
## The archetype's active + passive ability (GDD §4). Every actor has one.
var abilities = null   ## AbilityController
var _animator = null   ## CharacterAnimator (procedural) or RiggedCharacter (assets)
var _downed_bleed: float = 0.0
var _downed_time: float = 0.0
var _facing: float = 0.0
var _stat_accum: float = 0.0
var _last_attacker: Actor = null
var _was_blocking: bool = false
var _flash_timer: float = 0.0
static var _flash_mat: StandardMaterial3D = null

## Actors far from the camera skip animation and stat maths entirely. With 32
## bodies in a match this is the difference between a smooth frame and a stall.
var simulation_lod: int = 0     # 0 = full, 1 = reduced, 2 = minimal


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 0.4

	for t in [Constants.ResourceType.WOOD, Constants.ResourceType.STONE,
			Constants.ResourceType.FOOD, Constants.ResourceType.WATER,
			Constants.ResourceType.METAL, Constants.ResourceType.HERBS]:
		inventory[t] = 0

	_apply_role_stats()
	build_visual()
	_attach_abilities()
	add_to_group("actors")


## GDD §4: the archetype's ability is what makes the character-select screen
## mean anything. Bots get one too, so an enemy Guardian really does taunt.
func _attach_abilities() -> void:
	abilities = AbilityControllerScript.new()
	abilities.name = "AbilityController"
	add_child(abilities)
	abilities.setup(self)


func build_visual() -> void:
	if character_visual and is_instance_valid(character_visual):
		character_visual.queue_free()
	if USE_RIGGED and ResourceLoader.exists("res://assets/models/characters/Knight.glb"):
		var rc := RiggedCharacter.new()
		rc.setup(archetype_id, squad_color)
		character_visual = rc
		add_child(rc)
		_tint_squad_marker()
		_animator = rc
		rc.set_lod(simulation_lod)
	else:
		character_visual = CharacterFactory.create_character_by_archetype(archetype_id)
		if character_visual:
			add_child(character_visual)
			_tint_squad_marker()
		_animator = CharacterAnimator.new()


## A coloured band at the feet so eight squads are instantly tellable apart.
## GDD §4 gives every squad a colour; without a marker on the body, a 32-player
## fight is unreadable.
func _tint_squad_marker() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "SquadRing"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.50
	tm.outer_radius = 0.60
	tm.rings = 18
	tm.ring_segments = 4
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(squad_color.r, squad_color.g, squad_color.b, 0.70)
	m.emission_enabled = true
	m.emission = squad_color
	m.emission_energy_multiplier = 0.45
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.position.y = 0.06
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


func _apply_role_stats() -> void:
	match role:
		Constants.Role.KING:
			hp = 130.0; attack_damage = Constants.BASIC_SWORD_DAMAGE * 1.2; base_speed = 5.8
		Constants.Role.QUEEN:
			hp = 85.0; attack_damage = Constants.BASIC_SWORD_DAMAGE * 0.7; base_speed = 5.6
		Constants.Role.SOLDIER_A:
			hp = 115.0; attack_damage = Constants.BASIC_SWORD_DAMAGE; base_speed = 5.7
		Constants.Role.SOLDIER_B:
			hp = 95.0; attack_damage = Constants.BASIC_SWORD_DAMAGE * 0.9; base_speed = 6.6
	if archetype_id == "regent":
		max_carry = int(max_carry * 1.5)   # GDD §4 Stockpile passive

	# GDD §4/§9: the Archer is the bow role — fights at range with arrows rather
	# than a melee swing, trading raw per-hit damage for safe distance.
	if archetype_id == "archer":
		is_ranged = true
		attack_damage = Constants.BASIC_BOW_DAMAGE
		attack_range = Constants.BASIC_BOW_RANGE * Constants.TILE_SIZE.x
		attack_cooldown = 0.85


func max_hp() -> float:
	match role:
		Constants.Role.KING: return 130.0
		Constants.Role.QUEEN: return 85.0
		Constants.Role.SOLDIER_A: return 115.0
		Constants.Role.SOLDIER_B: return 95.0
	return Constants.MAX_HP


# ═══════════════════════════════════════════════════════════════════════════════
#  SIMULATION
# ═══════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if hp_state == HPState.DEAD:
		return

	if hp_state == HPState.DOWNED:
		_process_downed(delta)
		return

	if _attack_timer > 0.0:
		_attack_timer -= delta

	# Survival decay is batched — running six float ops per actor per frame for
	# 32 actors is pure waste when the values change by 0.125 per second.
	_stat_accum += delta
	if _stat_accum >= 0.25:
		_tick_survival(_stat_accum)
		_stat_accum = 0.0

	var speed := base_speed * speed_multiplier
	match hp_state:
		HPState.WOUNDED:  speed *= 0.80    # GDD §9
		HPState.CRITICAL: speed *= 0.60
		_: pass

	# Wading penalty — deep water slows you, which is what makes the river a
	# real tactical barrier instead of a texture.
	if global_position.y < -0.15:
		speed *= 0.60

	if not is_on_floor():
		velocity.y -= 25.0 * delta
	else:
		velocity.y = -0.1

	var intent := move_intent
	if intent.length_squared() > 1.0:
		intent = intent.normalized()
	var moving := intent.length_squared() > 0.01

	if moving:
		velocity.x = intent.x * speed
		velocity.z = intent.z * speed
		_facing = atan2(intent.x, intent.z)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 2.0 * delta * 60.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * 2.0 * delta * 60.0)

	move_and_slide()

	if character_visual and simulation_lod < 2:
		character_visual.rotation.y = lerp_angle(character_visual.rotation.y, _facing, 14.0 * delta)
		if simulation_lod == 0 and _animator:
			if is_blocking != _was_blocking:
				_animator.set_blocking(is_blocking)
				_was_blocking = is_blocking
			_animator.animate_character(character_visual, archetype_id, moving, delta)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_clear_hit_flash()


func _tick_survival(dt: float) -> void:
	hunger = max(0.0, hunger - Constants.HUNGER_DECAY_RATE * dt)
	thirst = max(0.0, thirst - Constants.THIRST_DECAY_RATE * dt)
	var drain := 0.0
	if hunger <= 0.0:
		drain += Constants.HUNGER_ZERO_HP_DRAIN * dt
	if thirst <= 0.0:
		drain += Constants.THIRST_ZERO_HP_DRAIN * dt
	if drain > 0.0:
		take_damage(drain, null, false)


func _process_downed(delta: float) -> void:
	# A held prisoner does NOT bleed out, cannot crawl, and does not move on its
	# own — the captor carries it, or the cage holds it. Just keep its pose alive.
	if is_captured or is_imprisoned:
		# GDD §10: a caged prisoner works the lock and eventually breaks free. With
		# no lock-pick mini-game wired yet, this timer stands in for it so a captured
		# player (or bot) is neutralised for a while but never soft-locked forever.
		if is_imprisoned:
			_imprison_time += delta
			if _imprison_time >= Constants.IMPRISON_ESCAPE_TIME:
				EventBus.prisoner_escaped.emit(self, "lockpick")
				release_prisoner()
				return
		if character_visual and simulation_lod == 0 and _animator:
			_animator.animate_character(character_visual, archetype_id, false, delta)
		return

	# GDD §9: a downed player can CRAWL — very slow, no attacking. The controller
	# (player joystick or bot) still fills move_intent; here it is honoured at a
	# fraction of walking speed so the downed body drags itself along the ground.
	var intent := move_intent
	if intent.length_squared() > 1.0:
		intent = intent.normalized()
	var crawling := intent.length_squared() > 0.01

	if not is_on_floor():
		velocity.y -= 25.0 * delta
	else:
		velocity.y = -0.1
	if crawling:
		velocity.x = intent.x * Constants.DOWNED_CRAWL_SPEED
		velocity.z = intent.z * Constants.DOWNED_CRAWL_SPEED
		_facing = atan2(intent.x, intent.z)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	move_and_slide()

	if character_visual and simulation_lod < 2:
		character_visual.rotation.y = lerp_angle(character_visual.rotation.y, _facing, 8.0 * delta)
		if simulation_lod == 0 and _animator:
			if _animator.has_method("set_crawling"):
				_animator.set_crawling(crawling)
			_animator.animate_character(character_visual, archetype_id, false, delta)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_clear_hit_flash()
	_downed_bleed += delta
	_downed_time += delta
	if _downed_bleed >= 3.0:
		_downed_bleed = 0.0
		hp = max(0.0, hp - 1.0)
	# GDD §9: 30 seconds downed before bleeding out.
	# Credit the last attacker so a bleed-out still counts as their kill.
	if _downed_time >= Constants.DOWNED_BLEED_TIME:
		kill(_last_attacker)


# ═══════════════════════════════════════════════════════════════════════════════
#  COMBAT
# ═══════════════════════════════════════════════════════════════════════════════

func can_attack() -> bool:
	return _attack_timer <= 0.0 and hp_state != HPState.DOWNED and hp_state != HPState.DEAD


func attack(target: Actor) -> bool:
	if not can_attack() or target == null or not is_instance_valid(target):
		return false
	if global_position.distance_to(target.global_position) > attack_range:
		return false

	_attack_timer = attack_cooldown

	# GDD §9: bow users loose an arrow instead of swinging. Eagle-Eye style range
	# bonus is folded in here so the basic shot rewards keeping your distance.
	if is_ranged:
		if _animator:
			if _animator.has_method("trigger_ranged"):
				_animator.trigger_ranged()
			else:
				_animator.trigger_attack()
		var rdmg := attack_damage * damage_multiplier
		var tiles: float = global_position.distance_to(target.global_position) / Constants.TILE_SIZE.x
		if tiles >= Constants.ARCHER_EAGLE_EYE_RANGE_THRESHOLD:
			rdmg *= 1.0 + Constants.ARCHER_EAGLE_EYE_DAMAGE_BUFF
		_fire_arrow(target, rdmg)
		return true

	if _animator:
		_animator.trigger_attack()
	var dmg := attack_damage * damage_multiplier
	# GDD §9: friendly fire is ALWAYS on, at 50% damage.
	var friendly := target.squad_id == squad_id and not traitor_activated
	if target.squad_id == squad_id:
		dmg *= Constants.FRIENDLY_FIRE_DAMAGE_MODIFIER
	target.take_damage(dmg, self, friendly)
	return true


## Spawn a homing arrow toward a target and let it apply the damage on impact.
func _fire_arrow(target: Actor, dmg: float) -> void:
	var origin := global_position + Vector3(0, 1.0, 0)
	var dir := (target.global_position + Vector3(0, 1.0, 0)) - origin
	var arrow := ArrowScript.new()
	arrow.max_range = attack_range + 6.0
	arrow.setup(dir, dmg, self, target)
	var host: Node = get_parent()   # actors live under the World node
	if host == null:
		host = self
	host.add_child(arrow)
	arrow.global_position = origin


func take_damage(amount: float, attacker: Actor = null, _friendly: bool = false) -> void:
	if hp_state == HPState.DEAD:
		return
	if attacker != null:
		_last_attacker = attacker
	if is_blocking and attacker != null:
		amount *= 0.40      # GDD §9: block reduces melee damage 60%
	hp = max(0.0, hp - amount)
	hp_changed.emit(hp, max_hp())
	# Visual feedback so a hit READS as a hit: flinch + white impact flash.
	if hp_state != HPState.DOWNED and _animator and simulation_lod == 0:
		_animator.trigger_hit()
	if amount > 0.0 and simulation_lod == 0:
		_flash_hit()
	_update_hp_state()
	if attacker:
		EventBus.player_damaged.emit(attacker, self, amount)


func heal(amount: float) -> void:
	if hp_state == HPState.DEAD:
		return
	hp = min(max_hp(), hp + amount)
	hp_changed.emit(hp, max_hp())
	_update_hp_state()


func _update_hp_state() -> void:
	var previous := hp_state
	var ratio := hp / max_hp()
	if hp <= 0.0:
		hp_state = HPState.DOWNED
		_downed_bleed = 0.0
		_downed_time = 0.0
		velocity = Vector3.ZERO
		if _animator:
			_animator.set_downed(true)
		downed.emit()
		EventBus.player_downed.emit(self)
	elif ratio <= Constants.CRITICAL_HP_THRESHOLD / Constants.MAX_HP:
		hp_state = HPState.CRITICAL
	elif ratio <= Constants.WOUNDED_HP_THRESHOLD / Constants.MAX_HP:
		hp_state = HPState.WOUNDED
	else:
		hp_state = HPState.HEALTHY
	# GDD §9 HP-state locomotion: swap to a wounded/critical gait so injury reads.
	if _animator != null and simulation_lod == 0 and _animator.has_method("set_hp_band"):
		var band := 0
		if hp_state == HPState.CRITICAL:
			band = 2
		elif hp_state == HPState.WOUNDED:
			band = 1
		_animator.set_hp_band(band)
	if previous != hp_state:
		state_changed.emit(int(hp_state))


func revive(at_hp: float = 40.0) -> void:
	hp_state = HPState.HEALTHY
	hp = at_hp
	_downed_time = 0.0
	if _animator:
		if _animator.has_method("trigger_revive"):
			_animator.trigger_revive()      # GDD: "rise up" on respawn/revive
		else:
			_animator.set_downed(false)
			_animator.set_dead(false)
	if character_visual:
		character_visual.visible = true
		character_visual.rotation = Vector3(0, character_visual.rotation.y, 0)
		character_visual.position = Vector3.ZERO
		character_visual.scale = Vector3.ONE
	visible = true
	hp_changed.emit(hp, max_hp())
	_update_hp_state()


func kill(killer: Actor) -> void:
	if hp_state == HPState.DEAD:
		return
	hp_state = HPState.DEAD
	hp = 0.0
	velocity = Vector3.ZERO
	_play_death()
	# Kill-triggered passives (Berserker Bloodlust, GDD §4) live on the killer.
	if killer != null and is_instance_valid(killer) and killer.abilities != null:
		killer.abilities.notify_kill(self)
	died.emit(killer)
	EventBus.player_killed.emit(self, killer)


## Topple over and sink instead of popping out of existence. GDD §9 death.
func _play_death() -> void:
	# The rigged character plays a real Death_A clip via set_dead(); the procedural
	# fallback has no death clip, so it gets a topple tween instead.
	if _animator:
		_animator.set_dead(true)
	if character_visual == null or not is_instance_valid(character_visual):
		visible = false
		return
	if simulation_lod == 2:
		visible = false
		return
	var tree := get_tree()
	if tree == null:
		visible = false
		return
	if character_visual is RiggedCharacter:
		# Let the death animation play out, then sink and hide the corpse.
		var vis := character_visual
		var tw := tree.create_tween()
		tw.tween_interval(2.2)
		tw.tween_property(vis, "position:y", -1.2, 0.7)
		tw.tween_callback(func():
			if is_instance_valid(self): visible = false)
		return
	var vis2 := character_visual
	var fall_dir := -1.0 if (int(_facing * 100.0) % 2 == 0) else 1.0
	var tw2 := tree.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(vis2, "rotation:x", deg_to_rad(88.0) * fall_dir, 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(vis2, "position:y", -0.25, 0.55).set_delay(0.15)
	tw2.chain().tween_interval(1.4)
	tw2.chain().tween_property(vis2, "position:y", -1.2, 0.6)
	tw2.chain().tween_callback(func():
		if is_instance_valid(self): visible = false)


# ── Hit flash ────────────────────────────────────────────────────────────────
func _flash_hit() -> void:
	if character_visual == null or not is_instance_valid(character_visual):
		return
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.albedo_color = Color(1, 1, 1)
		_flash_mat.emission_enabled = true
		_flash_mat.emission = Color(1, 0.85, 0.8)
		_flash_mat.emission_energy_multiplier = 2.2
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_timer = 0.09
	_apply_flash_override(character_visual, _flash_mat)

func _clear_hit_flash() -> void:
	if character_visual and is_instance_valid(character_visual):
		_apply_flash_override(character_visual, null)

func _apply_flash_override(root: Node, mat: Material) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.name != "GroundShadow" and n.name != "SquadRing":
			(n as MeshInstance3D).material_override = mat
		for c in n.get_children():
			stack.push_back(c)


func is_alive() -> bool:
	return hp_state != HPState.DEAD


func is_downed() -> bool:
	return hp_state == HPState.DOWNED


# ═══════════════════════════════════════════════════════════════════════════════
#  INVENTORY
# ═══════════════════════════════════════════════════════════════════════════════

func add_resource(type: int, amount: int) -> void:
	var current: int = inventory.get(type, 0)
	inventory[type] = min(current + amount, max_carry)
	resource_gained.emit(type, amount)


func spend_resource(type: int, amount: int) -> bool:
	var current: int = inventory.get(type, 0)
	if current < amount:
		return false
	inventory[type] = current - amount
	return true


func get_resource(type: int) -> int:
	return inventory.get(type, 0)


func total_carried() -> int:
	var t := 0
	for v in inventory.values():
		t += int(v)
	return t


func eat(hunger_restore: float) -> void:
	hunger = min(Constants.MAX_HUNGER, hunger + hunger_restore)
	play_anim("use")


func drink(thirst_restore: float) -> void:
	thirst = min(Constants.MAX_THIRST, thirst + thirst_restore)
	play_anim("use")


# ═══════════════════════════════════════════════════════════════════════════════
#  BUFFS
# ═══════════════════════════════════════════════════════════════════════════════

## Timed multiplier buff — Rally Cry, Frenzy, Adrenaline, Post-Betrayal Rally.
func apply_buff(speed_mult: float, damage_mult: float, duration: float) -> void:
	speed_multiplier *= speed_mult
	damage_multiplier *= damage_mult
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(duration).timeout.connect(func():
		if is_instance_valid(self):
			speed_multiplier /= speed_mult
			damage_multiplier /= damage_mult)


func set_simulation_lod(level: int) -> void:
	if simulation_lod == level:
		return
	simulation_lod = level
	if character_visual:
		if character_visual is RiggedCharacter:
			character_visual.set_lod(level)
		else:
			character_visual.visible = level < 2


## Public animation hooks so game systems (build, capture, abilities, items) can
## drive the right clip without knowing which animator backs the actor.
func play_anim(action: String) -> void:
	if _animator == null or simulation_lod != 0:
		return
	match action:
		"build":
			if _animator.has_method("trigger_build"): _animator.trigger_build()
			elif _animator.has_method("trigger_gather"): _animator.trigger_gather()
		"interact":
			if _animator.has_method("trigger_interact"): _animator.trigger_interact()
			elif _animator.has_method("trigger_gather"): _animator.trigger_gather()
		"throw":
			if _animator.has_method("trigger_throw"): _animator.trigger_throw()
			elif _animator.has_method("trigger_attack"): _animator.trigger_attack()
		"use":
			if _animator.has_method("trigger_use_item"): _animator.trigger_use_item()
			elif _animator.has_method("trigger_interact"): _animator.trigger_interact()
		"ability":
			if _animator.has_method("trigger_ability"): _animator.trigger_ability()
		"gather":
			if _animator.has_method("trigger_gather"): _animator.trigger_gather()
		"attack":
			if _animator.has_method("trigger_attack"): _animator.trigger_attack()

## Prisoner carry poses — carrier holds, prisoner hangs limp.
func set_carry_state(is_carrying: bool, is_carried: bool) -> void:
	if _animator == null:
		return
	if _animator.has_method("set_carrying"): _animator.set_carrying(is_carrying)
	if _animator.has_method("set_carried"): _animator.set_carried(is_carried)


# ── Prisoner lifecycle (GDD §10) ───────────────────────────────────────────────
func set_captured(by: Actor) -> void:
	is_captured = true
	is_imprisoned = false
	captor = by
	velocity = Vector3.ZERO
	set_carry_state(false, true)     # hang limp over the captor's shoulder

func set_imprisoned_state() -> void:
	is_captured = false
	is_imprisoned = true
	captor = null
	_imprison_time = 0.0
	velocity = Vector3.ZERO
	set_carry_state(false, false)    # slumped in the cage (downed pose)

func release_prisoner() -> void:
	is_captured = false
	is_imprisoned = false
	captor = null
	set_carry_state(false, false)
	# Freed prisoners get back up on low HP so they can flee.
	if hp_state == HPState.DOWNED:
		revive(30.0)
