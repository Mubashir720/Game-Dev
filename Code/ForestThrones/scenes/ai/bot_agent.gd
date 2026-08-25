extends Actor
class_name BotAgent

## ═══════════════════════════════════════════════════════════════════════════════
##  BOT AGENT — one AI-controlled squad member.
##
##  A Battle Siege match is 32 players (GDD §1). Anything short of 32 bodies
##  behaving plausibly is not the game described in the design document, so this
##  is what fills the other 31 slots.
##
##  Design constraints that shaped it:
##
##  • It must be CHEAP. 31 brains re-planning every frame would eat the frame
##    budget on its own, so decisions run on a staggered 0.4 s tick and each
##    bot's think slot is offset by its index — the cost is spread, never spiky.
##
##  • It must be ROLE-SHAPED, not generic. GDD §4 says losing a role creates a
##    specific weakness, which only means something if each role actually plays
##    differently: the Queen holds the base and generates income, Soldier B
##    ranges out for resources, Soldier A screens the base, the King fights.
##
##  • It must be LEGIBLE. A player has to be able to look at an enemy squad and
##    read what it is doing, otherwise the Traitor, ransom and raid systems have
##    nothing to hang off. Bots telegraph: they walk to a node and chop it, they
##    carry resources home, they converge on a raid.
## ═══════════════════════════════════════════════════════════════════════════════

enum Goal {
	IDLE,
	GATHER,          ## Walk to a resource node and harvest it
	DELIVER,         ## Carry a full load back to base
	BUILD,           ## Spend resources on the next structure in the build order
	GUARD,           ## Hold position near the base / the Queen
	ENGAGE,          ## Close on an enemy and fight
	FLEE,            ## Break contact when badly hurt
	RESCUE,          ## Move to a downed squadmate
	DRINK,           ## Go to water when thirst is low
	FORAGE,          ## Go to food when hunger is low
	MIGRATE,         ## Move toward the shrinking zone centre
	HUNT,            ## Finish a downed enemy — execute, or capture and carry home
}

const THINK_INTERVAL := 0.40
const VISION_RADIUS := 22.0
const HARVEST_RANGE := 2.4
const DELIVER_RANGE := 3.0
const STUCK_EPSILON := 0.35

var goal: Goal = Goal.IDLE
var goal_target: Vector3 = Vector3.ZERO
var target_actor: Actor = null
var target_resource_id: int = -1

var squad_brain = null           ## SquadBrain
var world = null                 ## World node (queries + resource field)
var director = null              ## MatchDirector (actor registry)

var _think_timer := 0.0
var _bot_index := 0
var _stuck_timer := 0.0
var _last_position := Vector3.ZERO
var _detour := Vector3.ZERO
var _detour_timer := 0.0
var _harvest_cooldown := 0.0

## A downed enemy this bot has slung over its shoulder and is carrying to its cage.
var _prisoner: Actor = null
var _capture_intent := ""   ## "" | "execute" | "capture" — decided on reaching the body

## Personality — small per-bot variance so a squad doesn't move as one organism.
var aggression := 0.5
var caution := 0.5


func setup(index: int, brain, world_node, match_director) -> void:
	_bot_index = index
	squad_brain = brain
	world = world_node
	director = match_director
	is_bot = true
	# Stagger the first think so 32 bots never plan on the same frame.
	_think_timer = (float(index) / 32.0) * THINK_INTERVAL
	var r := RandomNumberGenerator.new()
	r.seed = hash(display_name) + index
	aggression = r.randf_range(0.30, 0.85)
	caution = r.randf_range(0.25, 0.80)


func _physics_process(delta: float) -> void:
	# A captor that goes down drops its prisoner — the body can't be carried by
	# someone who is themselves crawling or dead (GDD §10: rescue window).
	if _prisoner != null and (hp_state == HPState.DOWNED or hp_state == HPState.DEAD):
		_drop_prisoner()

	if hp_state == HPState.DEAD:
		move_intent = Vector3.ZERO
		super._physics_process(delta)
		return

	if _harvest_cooldown > 0.0:
		_harvest_cooldown -= delta

	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = THINK_INTERVAL
		_decide()

	_act(delta)
	# Carrying a prisoner slows the captor to 60% and keeps the body on the shoulder.
	if _prisoner != null:
		_update_prisoner_carry()
	super._physics_process(delta)


# ═══════════════════════════════════════════════════════════════════════════════
#  DECIDE — runs at 2.5 Hz, not per frame
# ═══════════════════════════════════════════════════════════════════════════════

func _decide() -> void:
	if hp_state == HPState.DOWNED:
		goal = Goal.IDLE
		return

	var threat := _nearest_enemy()
	var hp_ratio := hp / max_hp()

	# 1. Survival overrides everything. A bot that starves in a corner is not a
	#    plausible opponent.
	if hp_ratio < 0.30 and threat != null and caution > 0.35:
		goal = Goal.FLEE
		goal_target = _flee_position(threat)
		return
	if thirst < 22.0:
		goal = Goal.DRINK
		goal_target = _nearest_water()
		return
	if hunger < 20.0:
		goal = Goal.FORAGE
		target_resource_id = _find_resource(Constants.ResourceType.FOOD)
		if target_resource_id >= 0:
			goal = Goal.FORAGE
			goal_target = world.resource_field.position_of(target_resource_id)
			return

	# 2. Zone shrink beats everything else once it starts (GDD §12, minute 17).
	if squad_brain and squad_brain.should_migrate():
		var centre: Vector3 = squad_brain.migration_target()
		if global_position.distance_to(centre) > squad_brain.zone_radius() * 0.75:
			goal = Goal.MIGRATE
			goal_target = centre
			return

	# 2.5 A downed enemy nearby is a free kill or a prisoner worth coins — fighters
	#     break off to secure it (GDD §10). Already carrying one? Keep hauling home.
	if _prisoner != null:
		goal = Goal.HUNT
		return
	if role == Constants.Role.KING or role == Constants.Role.SOLDIER_A:
		var prey := _downed_enemy()
		if prey != null and aggression > 0.35:
			goal = Goal.HUNT
			target_actor = prey
			# Decide once: capture the enemy for ransom, or execute for the loot.
			# The player is only ever executed (→ clean respawn), never jailed, so a
			# human is never soft-locked in a cage with no escape UI.
			if prey.is_bot and randf() < 0.55:
				_capture_intent = "capture"
			else:
				_capture_intent = "execute"
			return

	# 3. Combat, weighted by role and personality.
	if threat != null:
		var d := global_position.distance_to(threat.global_position)
		var want_fight := false
		match role:
			Constants.Role.KING:
				want_fight = d < VISION_RADIUS * (0.6 + aggression * 0.4)
			Constants.Role.SOLDIER_A:
				# Screens the base: fights anything that comes near home.
				want_fight = d < VISION_RADIUS * 0.8 or _near_base(threat.global_position, 14.0)
			Constants.Role.SOLDIER_B:
				want_fight = d < 8.0 and hp_ratio > 0.55
			Constants.Role.QUEEN:
				# GDD §4: the Queen is income, not a duelist. She only swings
				# when something is already on top of her.
				want_fight = d < 4.0
		if want_fight and hp_ratio > 0.25:
			goal = Goal.ENGAGE
			target_actor = threat
			return

	# 4. A downed squadmate is worth more than any resource node.
	var fallen := _downed_ally()
	if fallen != null and role != Constants.Role.QUEEN:
		goal = Goal.RESCUE
		target_actor = fallen
		goal_target = fallen.global_position
		return

	# 5. Role economy loop.
	match role:
		Constants.Role.QUEEN:
			# Holds the base — that is literally where the coins come from.
			# During the zone shrink she has to move with everyone else or the
			# squad loses its whole economy to the border.
			if squad_brain and squad_brain.posture == 2:
				goal = Goal.MIGRATE
				goal_target = squad_brain.objective_position() + _ring_offset(3.0)
			else:
				goal = Goal.GUARD
				goal_target = _base_position() + _ring_offset(2.2)
		Constants.Role.SOLDIER_A:
			# Builds when the squad can afford the next structure — paid from the
			# squad stockpile, not from this bot's pockets.
			# Finishing the build order beats raiding — the Mint is the squad's
			# whole economy, and walking away from an affordable structure to go
			# hit a neighbour is how a squad ends the match rich in wood and
			# poor in coins.
			if squad_brain and squad_brain.wants_builder():
				goal = Goal.BUILD
				goal_target = squad_brain.next_build_site()
			elif squad_brain and squad_brain.posture != 0:
				# Once the squad is raiding or converging, the screen moves too.
				goal = Goal.MIGRATE
				goal_target = squad_brain.objective_position() + _ring_offset(5.0)
			else:
				# Nothing to build and nothing to fight: help gather rather than
				# standing at the base doing nothing for eight minutes.
				var rid_a := _find_resource(_wanted_resource())
				if total_carried() >= max_carry - 2:
					goal = Goal.DELIVER
					goal_target = _base_position()
				elif rid_a >= 0:
					target_resource_id = rid_a
					goal = Goal.GATHER
					goal_target = world.resource_field.position_of(rid_a)
				else:
					goal = Goal.GUARD
					goal_target = _base_position() + _ring_offset(6.0)
		_:
			# King and Soldier B run the gather loop — until the squad commits
			# to a raid or the zone forces everyone inward.
			if squad_brain and squad_brain.posture != 0 and role == Constants.Role.KING:
				goal = Goal.MIGRATE
				goal_target = squad_brain.objective_position() + _ring_offset(6.0)
			elif total_carried() >= max_carry - 2:
				goal = Goal.DELIVER
				goal_target = _base_position()
			else:
				var want := _wanted_resource()
				var rid := _find_resource(want)
				if rid < 0:
					rid = _find_resource(-1)
				if rid >= 0:
					target_resource_id = rid
					goal = Goal.GATHER
					goal_target = world.resource_field.position_of(rid)
				else:
					goal = Goal.GUARD
					goal_target = _base_position() + _ring_offset(8.0)


# ═══════════════════════════════════════════════════════════════════════════════
#  ACT — cheap per-frame execution of the current goal
# ═══════════════════════════════════════════════════════════════════════════════

func _act(delta: float) -> void:
	if hp_state == HPState.DOWNED or hp_state == HPState.DEAD:
		move_intent = Vector3.ZERO
		return

	match goal:
		Goal.ENGAGE:
			if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
				goal = Goal.IDLE
				move_intent = Vector3.ZERO
				return
			var to_target := target_actor.global_position - global_position
			var dist := to_target.length()
			if dist <= attack_range * 0.9:
				move_intent = Vector3.ZERO
				attack(target_actor)
			else:
				_steer_towards(target_actor.global_position, delta)

		Goal.GATHER, Goal.FORAGE:
			if target_resource_id < 0 or world == null or world.resource_field == null:
				goal = Goal.IDLE
				return
			if not world.resource_field.is_available(target_resource_id):
				target_resource_id = -1
				goal = Goal.IDLE
				return
			var rp: Vector3 = world.resource_field.position_of(target_resource_id)
			if global_position.distance_to(rp) <= HARVEST_RANGE:
				move_intent = Vector3.ZERO
				_face(rp)
				if _harvest_cooldown <= 0.0:
					_harvest_cooldown = 0.55
					if _animator:
						_animator.trigger_harvest()
					var depleted: bool = world.resource_field.harvest(target_resource_id, self)
					if depleted:
						target_resource_id = -1
			else:
				_steer_towards(rp, delta)

		Goal.DELIVER:
			var base := _base_position()
			if global_position.distance_to(base) <= DELIVER_RANGE:
				move_intent = Vector3.ZERO
				_deposit()
			else:
				_steer_towards(base, delta)

		Goal.RESCUE:
			if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_downed():
				goal = Goal.IDLE
				return
			if global_position.distance_to(target_actor.global_position) < 1.8:
				move_intent = Vector3.ZERO
				target_actor.revive(35.0)
				goal = Goal.IDLE
			else:
				_steer_towards(target_actor.global_position, delta)

		Goal.HUNT:
			_act_hunt(delta)

		Goal.FLEE, Goal.MIGRATE, Goal.DRINK, Goal.BUILD, Goal.GUARD:
			if global_position.distance_to(goal_target) > 1.6:
				_steer_towards(goal_target, delta)
			else:
				move_intent = Vector3.ZERO
				if goal == Goal.DRINK:
					drink(Constants.WATER_THIRST)
					goal = Goal.IDLE
				elif goal == Goal.BUILD and squad_brain:
					squad_brain.contribute_build(self)
					goal = Goal.IDLE

		_:
			move_intent = Vector3.ZERO


# ═══════════════════════════════════════════════════════════════════════════════
#  HUNT — finish or capture a downed enemy (GDD §10)
# ═══════════════════════════════════════════════════════════════════════════════

func _act_hunt(delta: float) -> void:
	# Already carrying someone → haul them to the cage and lock them up.
	if _prisoner != null:
		if not is_instance_valid(_prisoner) or not _prisoner.is_captured:
			_drop_prisoner()
			goal = Goal.IDLE
			return
		var cage := _cage_position()
		if global_position.distance_to(cage) <= DELIVER_RANGE:
			move_intent = Vector3.ZERO
			_imprison_carried()
			goal = Goal.IDLE
		else:
			_steer_towards(cage, delta)
		return

	# Target must still be a capturable downed enemy.
	if target_actor == null or not is_instance_valid(target_actor) \
			or not target_actor.is_downed() or target_actor.is_captured or target_actor.is_imprisoned:
		goal = Goal.IDLE
		target_actor = null
		return

	if global_position.distance_to(target_actor.global_position) > 1.6:
		_steer_towards(target_actor.global_position, delta)
		return

	# In reach — commit the decision made when the hunt started.
	move_intent = Vector3.ZERO
	_face(target_actor.global_position)
	if _capture_intent == "capture" and target_actor.is_bot:
		_capture(target_actor)
	else:
		_execute(target_actor)
		target_actor = null
		goal = Goal.IDLE


func _execute(enemy: Actor) -> void:
	if _animator:
		_animator.trigger_attack()
	EventBus.prisoner_executed.emit(self, enemy)
	EventBus.forest_curse_triggered.emit(squad_id, 2)
	enemy.kill(self)
	if squad_brain and squad_brain.has_method("add_coins"):
		squad_brain.add_coins(10, "execution_loot")


func _capture(enemy: Actor) -> void:
	_prisoner = enemy
	enemy.set_captured(self)
	set_carry_state(true, false)
	if _animator:
		_animator.trigger_interact()
	EventBus.player_handcuffed.emit(self, enemy)


func _update_prisoner_carry() -> void:
	if not is_instance_valid(_prisoner) or not _prisoner.is_captured:
		_drop_prisoner()
		return
	_prisoner.global_position = global_position + Vector3(0.0, 1.05, 0.0)
	_prisoner.velocity = Vector3.ZERO
	# Arms full: move at 60% (GDD §10). Applied as a soft cap on the intent.
	move_intent *= 0.6


func _imprison_carried() -> void:
	if not is_instance_valid(_prisoner):
		_prisoner = null
		return
	var p := _prisoner
	_prisoner = null
	set_carry_state(false, false)
	p.global_position = _cage_position() + Vector3(1.2, 0.0, 0.0)
	p.set_imprisoned_state()
	EventBus.player_imprisoned.emit(self, p, squad_brain)
	# A captured enemy Queen is a real prize — post a ransom for the coins.
	if squad_brain:
		var amount := 40 if p.role == Constants.Role.QUEEN else 25
		EventBus.ransom_posted.emit(squad_id, p, amount)
		squad_brain.add_coins(amount, "ransom")


func _drop_prisoner() -> void:
	if is_instance_valid(_prisoner):
		_prisoner.release_prisoner()
	_prisoner = null
	set_carry_state(false, false)


## Where this squad locks prisoners: its Cage if one is built, else the Hut/base.
func _cage_position() -> Vector3:
	if squad_brain:
		for s in squad_brain.structures:
			if is_instance_valid(s) and String(s.get_meta("structure_type", "")).begins_with("cage"):
				return s.global_position
	return _base_position()


func _downed_enemy() -> Actor:
	if director == null:
		return null
	var best: Actor = null
	var best_d := (VISION_RADIUS * 0.7) * (VISION_RADIUS * 0.7)
	for a in director.actors:
		if a == self or not is_instance_valid(a):
			continue
		var hostile: bool = a.squad_id != squad_id or traitor_activated or a.traitor_activated
		if not hostile:
			continue
		if not a.is_downed() or a.is_captured or a.is_imprisoned:
			continue
		var d: float = global_position.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


## Move toward a point, with a short sidestep when we bump into scenery.
## The map is dense forest with thousands of tree colliders; without this, bots
## grind into a trunk forever and the whole match freezes into a tableau.
func _steer_towards(target: Vector3, delta: float) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		move_intent = Vector3.ZERO
		return
	dir = dir.normalized()

	if _detour_timer > 0.0:
		_detour_timer -= delta
		move_intent = (dir * 0.35 + _detour * 0.85).normalized()
		return

	# Stuck detection: moving much less than commanded means something solid.
	var travelled := global_position.distance_to(_last_position)
	_last_position = global_position
	if travelled < STUCK_EPSILON * delta * 60.0 * 0.016:
		_stuck_timer += delta
		if _stuck_timer > 0.45:
			_stuck_timer = 0.0
			_detour = Vector3(-dir.z, 0.0, dir.x)
			if (_bot_index + int(global_position.x)) % 2 == 0:
				_detour = -_detour
			_detour_timer = 0.6
	else:
		_stuck_timer = 0.0

	move_intent = dir


func _face(p: Vector3) -> void:
	var d := p - global_position
	if d.length_squared() > 0.001:
		_facing = atan2(d.x, d.z)


func _deposit() -> void:
	if squad_brain == null:
		return
	for t in inventory.keys():
		var amount: int = inventory[t]
		if amount > 0:
			squad_brain.deposit(t, amount)
			inventory[t] = 0


# ═══════════════════════════════════════════════════════════════════════════════
#  PERCEPTION
# ═══════════════════════════════════════════════════════════════════════════════

func _nearest_enemy() -> Actor:
	if director == null:
		return null
	var best: Actor = null
	var best_d := VISION_RADIUS * VISION_RADIUS
	for a in director.actors:
		if a == self or not is_instance_valid(a) or not a.is_alive():
			continue
		# The Traitor treats their own squad as enemies once activated (GDD §11).
		var hostile: bool = a.squad_id != squad_id
		if traitor_activated and a.squad_id == squad_id:
			hostile = true
		if a.traitor_activated and a.squad_id == squad_id:
			hostile = true
		if not hostile:
			continue
		var d: float = global_position.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _downed_ally() -> Actor:
	if director == null:
		return null
	for a in director.actors:
		if a == self or not is_instance_valid(a):
			continue
		if a.squad_id == squad_id and a.is_downed():
			if global_position.distance_to(a.global_position) < 26.0:
				return a
	return null


func _find_resource(type: int) -> int:
	if world == null or world.resource_field == null:
		return -1
	# Search outward in rings so a bot walks to something plausible rather than
	# sprinting across the map for a marginally closer node.
	for radius in [10.0, 22.0, 40.0]:
		var id: int = world.resource_field.find_nearest(global_position, radius, type)
		if id >= 0:
			return id
	return -1


## What the squad is short of right now (GDD §6 build order).
func _wanted_resource() -> int:
	if squad_brain:
		return squad_brain.most_needed_resource()
	return Constants.ResourceType.WOOD


func _nearest_water() -> Vector3:
	# Rivers run north-south at fixed grid columns (map_generator WEST/EAST).
	var half: float = world.map_half_extent() if world else 200.0
	var west_x: float = (30.0 - 100.0) * Constants.TILE_SIZE.x
	var east_x: float = (170.0 - 100.0) * Constants.TILE_SIZE.x
	var target_x: float = west_x if abs(global_position.x - west_x) < abs(global_position.x - east_x) else east_x
	return Vector3(clamp(target_x, -half, half), 0.0, global_position.z)


func _base_position() -> Vector3:
	if squad_brain:
		return squad_brain.base_position
	return Vector3.ZERO


func _near_base(p: Vector3, radius: float) -> bool:
	return p.distance_to(_base_position()) < radius


## Spread squadmates around the base instead of stacking them on one tile.
func _ring_offset(radius: float) -> Vector3:
	var a := (float(_bot_index) / 4.0) * TAU
	return Vector3(cos(a) * radius, 0.0, sin(a) * radius)


func _flee_position(threat: Actor) -> Vector3:
	var away := (global_position - threat.global_position).normalized()
	return global_position + away * 18.0
