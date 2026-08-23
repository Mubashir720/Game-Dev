extends Node
class_name MatchDirector

## ═══════════════════════════════════════════════════════════════════════════════
##  MATCH DIRECTOR — sets up and runs one Battle Siege match.
##
##  GDD §1: 32 players, 8 squads of 4, 25 minutes. GDD §11: exactly 6 Traitor
##  Tokens spread across 6 of the 8 squads, so two squads are provably clean and
##  nobody knows which. This is the file that actually makes those numbers true.
##
##  It owns:
##    • Spawning 8 squads at the 8 equidistant drop zones
##    • The player's own actor, and 31 bots
##    • Traitor Token distribution and the minute-8 activation window
##    • Simulation LOD — the single most important thing for holding frame rate
##      with 32 bodies, because most of them are nowhere near the camera
##    • Win-condition evaluation (last squad standing, else highest treasury)
##
##  Simulation LOD, specifically: full physics + animation only for actors near
##  the local player; reduced for the mid ring; minimal (position only, hidden)
##  for the far ring. A 32-player match on a 400x400 map has most participants
##  off-screen at any moment, and animating a character nobody can see is the
##  purest kind of wasted frame time.
## ═══════════════════════════════════════════════════════════════════════════════

const BotAgent = preload("res://scenes/ai/bot_agent.gd")
const SquadBrain = preload("res://scenes/ai/squad_brain.gd")
const CharacterFactory = preload("res://scenes/player/character_factory.gd")

signal match_ready()
signal squad_eliminated(squad)
signal match_over(winning_squad)

const SQUAD_COUNT := 8
const SQUAD_SIZE := 4
const TRAITOR_TOKENS := Constants.TOTAL_TRAITOR_TOKENS   # 6 of 8 squads

const SQUAD_COLORS := [
	Color(0.88, 0.26, 0.20), Color(0.20, 0.55, 0.92),
	Color(0.26, 0.82, 0.36), Color(0.94, 0.78, 0.16),
	Color(0.80, 0.30, 0.86), Color(0.16, 0.86, 0.80),
	Color(0.94, 0.52, 0.14), Color(0.62, 0.66, 0.72),
]

const SQUAD_NAMES := [
	"Ember", "Tidewatch", "Thornguard", "Sunspear",
	"Nightbloom", "Frostwake", "Ashfoot", "Greymoor",
]

const ROLE_ORDER := [
	Constants.Role.KING, Constants.Role.QUEEN,
	Constants.Role.SOLDIER_A, Constants.Role.SOLDIER_B,
]

## Simulation LOD ring radii, in world units.
@export var lod_full_radius: float = 55.0
@export var lod_reduced_radius: float = 110.0
@export var lod_interval: float = 0.5

## Set false for a solo sandbox; true for a real 32-entity match.
@export var spawn_full_roster: bool = true

var world = null
var actors: Array[Actor] = []
var squads: Array[SquadBrain] = []
var player_actor: Actor = null
var player_squad: SquadBrain = null

var _lod_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _ended := false

var stats := {"actors": 0, "squads": 0, "lod_full": 0, "lod_reduced": 0, "lod_minimal": 0}


func setup(world_node, player_archetype: String, seed_value: int = 20250820) -> void:
	world = world_node
	_rng.seed = seed_value

	var drops: Array[Vector3] = world.drop_zone_world_positions()
	if drops.is_empty():
		push_error("MatchDirector: world has no drop zones — cannot start a match.")
		return

	var squad_total: int = SQUAD_COUNT if spawn_full_roster else 1
	var player_squad_index := 0

	for s in range(squad_total):
		var brain := SquadBrain.new()
		brain.name = "SquadBrain_%d" % s
		brain.squad_id = "squad_%d" % (s + 1)
		brain.squad_index = s
		brain.squad_color = SQUAD_COLORS[s % SQUAD_COLORS.size()]
		brain.base_position = drops[s % drops.size()]
		brain.world = world
		brain.director = self
		brain.is_player_squad = (s == player_squad_index)
		add_child(brain)
		squads.append(brain)

		for r in range(SQUAD_SIZE):
			var role: Constants.Role = ROLE_ORDER[r]
			var is_player := (s == player_squad_index and r == 0)
			var actor := _spawn_actor(brain, role, r, is_player, player_archetype)
			brain.register(actor)
			if is_player:
				player_actor = actor
				player_squad = brain

	_distribute_traitor_tokens()
	stats.actors = actors.size()
	stats.squads = squads.size()

	EventBus.match_started.connect(_on_match_started)
	EventBus.match_tick.connect(_on_match_tick)
	match_ready.emit()


func _spawn_actor(brain: SquadBrain, role: Constants.Role, slot: int,
		is_player: bool, player_archetype: String) -> Actor:
	var choices: Array = CharacterFactory.archetypes_for_role(role)
	var archetype: String = player_archetype if is_player else choices[_rng.randi() % choices.size()]
	if is_player and not choices.has(archetype):
		archetype = choices[0]

	var actor: Actor
	if is_player:
		actor = preload("res://scenes/player/player.gd").new()
	else:
		actor = BotAgent.new()

	actor.role = role
	actor.archetype_id = archetype
	actor.squad_id = brain.squad_id
	actor.squad_color = brain.squad_color
	actor.is_bot = not is_player
	actor.display_name = "You" if is_player else "%s %s" % [
		SQUAD_NAMES[brain.squad_index % SQUAD_NAMES.size()], _role_short(role)]
	actor.name = "%s_%s" % [brain.squad_id, _role_short(role)]

	# Fan the four members out around their drop point so they don't spawn
	# inside each other and get shoved across the map by depenetration.
	var angle := (float(slot) / float(SQUAD_SIZE)) * TAU
	var offset := Vector3(cos(angle) * 2.4, 0.0, sin(angle) * 2.4)
	var spawn := brain.base_position + offset
	spawn.y = world.ground_height(spawn) + 1.0

	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.9
	collider.shape = capsule
	collider.position.y = 0.95
	actor.add_child(collider)

	world.add_child(actor)
	actor.global_position = spawn

	if actor is BotAgent:
		(actor as BotAgent).setup(actors.size(), brain, world, self)

	world.add_stream_anchor(actor)
	actors.append(actor)
	return actor


static func _role_short(role: Constants.Role) -> String:
	match role:
		Constants.Role.KING: return "King"
		Constants.Role.QUEEN: return "Queen"
		Constants.Role.SOLDIER_A: return "Guard"
		Constants.Role.SOLDIER_B: return "Scout"
	return "Unit"


## GDD §11 Phase 1: exactly 6 tokens across 6 random squads. Two squads receive
## ZERO — and nobody is told which, which is the entire point of the mechanic.
func _distribute_traitor_tokens() -> void:
	var order: Array[int] = []
	for i in range(squads.size()):
		order.append(i)
	# Deterministic shuffle from the match seed, so a replay reproduces exactly.
	for i in range(order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp

	var tokens: int = min(TRAITOR_TOKENS, squads.size())
	for k in range(tokens):
		var brain: SquadBrain = squads[order[k]]
		var candidates: Array[Actor] = []
		for m in brain.members:
			candidates.append(m)
		if candidates.is_empty():
			continue
		brain.assign_traitor(candidates[_rng.randi() % candidates.size()])


# ═══════════════════════════════════════════════════════════════════════════════
#  RUNTIME
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = lod_interval
		_update_lod()
		_check_win_condition()


## The single biggest frame-rate lever in a 32-player match.
func _update_lod() -> void:
	if player_actor == null or not is_instance_valid(player_actor):
		return
	var origin := player_actor.global_position
	var full_sq := lod_full_radius * lod_full_radius
	var reduced_sq := lod_reduced_radius * lod_reduced_radius
	var counts := [0, 0, 0]

	for a in actors:
		if not is_instance_valid(a):
			continue
		var d: float = origin.distance_squared_to(a.global_position)
		var level := 2
		if d <= full_sq:
			level = 0
		elif d <= reduced_sq:
			level = 1
		a.set_simulation_lod(level)
		counts[level] += 1

	stats.lod_full = counts[0]
	stats.lod_reduced = counts[1]
	stats.lod_minimal = counts[2]


func _check_win_condition() -> void:
	if _ended or GameManager.game_state != Constants.GameState.PLAYING:
		return
	var alive: Array[SquadBrain] = []
	for s in squads:
		if s.is_alive():
			alive.append(s)
		elif not s.get_meta("eliminated", false):
			s.set_meta("eliminated", true)
			squad_eliminated.emit(s)

	if alive.size() <= 1 and squads.size() > 1:
		_end_match(alive[0] if alive.size() == 1 else null)


func _on_match_started() -> void:
	_ended = false


func _on_match_tick(time_seconds: float) -> void:
	# GDD §11: Traitors may activate from minute 8. Bots decide independently,
	# with a small per-tick chance so betrayals are spread through the window
	# rather than all firing on the same second.
	if time_seconds < Constants.TRAITOR_ACTIVATION_UNLOCK_TIME:
		return
	for s in squads:
		if s.traitor == null or s.traitor_active or s == player_squad:
			continue
		if not is_instance_valid(s.traitor) or not s.traitor.is_alive():
			continue
		# Richer treasuries are more tempting — the Traitor waits for a payday.
		var temptation: float = clamp(float(s.treasury) / 60.0, 0.0, 1.0)
		if _rng.randf() < 0.004 + temptation * 0.010:
			s.try_activate_traitor()

	# GDD §12: match ends at 25:00; highest treasury wins if anyone is left.
	if time_seconds >= Constants.MATCH_DURATION:
		_end_match(_richest_alive_squad())


func _richest_alive_squad() -> SquadBrain:
	var best: SquadBrain = null
	var best_coins := -1
	for s in squads:
		if s.is_alive() and s.treasury > best_coins:
			best_coins = s.treasury
			best = s
	return best


func _end_match(winner: SquadBrain) -> void:
	if _ended:
		return
	_ended = true
	GameManager.game_state = Constants.GameState.POST_MATCH
	match_over.emit(winner)
	EventBus.match_ended.emit(winner)


# ═══════════════════════════════════════════════════════════════════════════════
#  QUERIES (used by the HUD, minimap and ransom board)
# ═══════════════════════════════════════════════════════════════════════════════

func squad_by_id(id: String) -> SquadBrain:
	for s in squads:
		if s.squad_id == id:
			return s
	return null


func alive_squad_count() -> int:
	var n := 0
	for s in squads:
		if s.is_alive():
			n += 1
	return n


func alive_player_count() -> int:
	var n := 0
	for a in actors:
		if is_instance_valid(a) and a.is_alive():
			n += 1
	return n


func leaderboard() -> Array:
	var rows: Array = []
	for s in squads:
		rows.append({
			"id": s.squad_id,
			"name": SQUAD_NAMES[s.squad_index % SQUAD_NAMES.size()],
			"color": s.squad_color,
			"treasury": s.treasury,
			"alive": s.alive_count(),
		})
	rows.sort_custom(func(a, b): return a.treasury > b.treasury)
	return rows
