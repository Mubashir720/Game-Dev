extends Node
class_name SquadBrain

## ═══════════════════════════════════════════════════════════════════════════════
##  SQUAD BRAIN — the shared state and shared goals of one squad of four.
##
##  Individual bots decide what THEY do; this decides what the SQUAD is trying to
##  do, and owns everything the GDD treats as squad-level property:
##
##    • The treasury and the resource stockpile (GDD §7)
##    • Queen passive coin income, and the emergency rate when she is captured
##    • The recommended build order (GDD §6) and progress through it
##    • Which member holds the Traitor Token, and whether it has activated
##    • Whether the squad should be migrating for the zone shrink (GDD §12)
##
##  Keeping this here rather than on each bot means four bots reach the same
##  conclusion without four copies of the reasoning, and means a squad reads as
##  a coordinated group rather than four individuals who happen to match.
## ═══════════════════════════════════════════════════════════════════════════════

const StructureFactory = preload("res://scenes/structures/structure_factory.gd")

signal treasury_changed(amount: int)
signal structure_built(type: String, position: Vector3)
signal member_downed(member)

## GDD §6 recommended build order, with costs.
const BUILD_ORDER := [
	{"type": "hut",        "wood": 8,  "stone": 0, "metal": 0},
	{"type": "wood_wall",  "wood": 4,  "stone": 0, "metal": 0},
	{"type": "fire_pit",   "wood": 4,  "stone": 0, "metal": 0},
	{"type": "cage",       "wood": 10, "stone": 0, "metal": 0},
	{"type": "watchtower", "wood": 10, "stone": 4, "metal": 0},
	{"type": "well",       "wood": 4,  "stone": 8, "metal": 0},
	{"type": "workshop",   "wood": 10, "stone": 6, "metal": 0},
	{"type": "mint",       "wood": 12, "stone": 8, "metal": 4},
]

var squad_id: String = "squad_1"
var squad_index: int = 0
var squad_color: Color = Color(0.85, 0.25, 0.20)
var base_position: Vector3 = Vector3.ZERO
var is_player_squad: bool = false

var members: Array[Actor] = []
var king: Actor = null
var queen: Actor = null

var treasury: int = 0
var stock: Dictionary = {}

var traitor: Actor = null
var traitor_active: bool = false

var build_index: int = 0
var structures: Array = []
var _pending_build_site: Vector3 = Vector3.ZERO

var world = null
var director = null

## Squad posture drives what the whole squad is trying to do right now. Without
## it every squad sits on its own drop zone farming wood for 25 minutes and the
## match never actually happens — eight bases 400 units apart with 22-unit
## vision will simply never meet.
##
## Mirrors the GDD §12 match timeline:
##   ECONOMY  (0-8 min)   gather, build, establish
##   EXPAND   (8-17 min)  raid a neighbour, contest the Black Market and crates
##   CONVERGE (17+ min)   zone shrink; everyone moves to the Cursed Throne
enum Posture { ECONOMY, EXPAND, CONVERGE }
var posture: Posture = Posture.ECONOMY
var raid_target: SquadBrain = null
var _posture_timer := 0.0

var _coin_timer := 0.0
var _has_mint := false
var _queen_captured := false


func _ready() -> void:
	for t in [Constants.ResourceType.WOOD, Constants.ResourceType.STONE,
			Constants.ResourceType.FOOD, Constants.ResourceType.WATER,
			Constants.ResourceType.METAL, Constants.ResourceType.HERBS]:
		stock[t] = 0
	_pending_build_site = base_position


func _process(delta: float) -> void:
	if GameManager.game_state != Constants.GameState.PLAYING:
		return
	_tick_income(delta)
	_tick_posture(delta)


func _tick_posture(delta: float) -> void:
	_posture_timer -= delta
	if _posture_timer > 0.0:
		return
	_posture_timer = 2.0

	var t: float = GameManager.match_time
	if t >= Constants.ZONE_SHRINK_START:
		posture = Posture.CONVERGE
		raid_target = null
		return

	if t >= Constants.TRAITOR_ACTIVATION_UNLOCK_TIME:
		posture = Posture.EXPAND
		# Pick the nearest surviving rival and commit. Nearest keeps travel time
		# sane on a 400-unit map, so a raid actually lands instead of becoming a
		# five-minute walk.
		if raid_target == null or not raid_target.is_alive():
			raid_target = _nearest_rival()
		return

	posture = Posture.ECONOMY


func _nearest_rival() -> SquadBrain:
	if director == null:
		return null
	var best: SquadBrain = null
	var best_d := INF
	for s in director.squads:
		if s == self or not s.is_alive():
			continue
		var d: float = base_position.distance_to(s.base_position)
		if d < best_d:
			best_d = d
			best = s
	return best


## Where the squad should be pushing right now.
func objective_position() -> Vector3:
	match posture:
		Posture.CONVERGE:
			return Vector3.ZERO                       # the Cursed Throne
		Posture.EXPAND:
			if raid_target != null and raid_target.is_alive():
				return raid_target.base_position
			return Vector3.ZERO
		_:
			return base_position


# ═══════════════════════════════════════════════════════════════════════════════
#  ECONOMY (GDD §7)
# ═══════════════════════════════════════════════════════════════════════════════

func _tick_income(delta: float) -> void:
	_coin_timer += delta
	var interval: float = Constants.QUEEN_COIN_RATE_MINT if _has_mint else Constants.QUEEN_COIN_RATE

	if _queen_captured or queen == null or not is_instance_valid(queen) or not queen.is_alive():
		# GDD §7 Emergency income: 0.25 coins per 20s per surviving member —
		# crippled, deliberately not dead, so a Queen capture is a setback and
		# not an unrecoverable death spiral.
		var alive := alive_count()
		if alive <= 0:
			return
		var emergency_interval: float = Constants.QUEEN_COIN_RATE / (Constants.QUEEN_EMERGENCY_RATE_MULTIPLIER * float(alive))
		if _coin_timer >= emergency_interval:
			_coin_timer = 0.0
			add_coins(1, "emergency_income")
		return

	# The Queen must actually be AT the base to mint. Otherwise the safest play
	# would be to hide her in a forest corner for 25 minutes, which is not a game.
	if queen.global_position.distance_to(base_position) > 12.0:
		return

	if _coin_timer >= interval:
		_coin_timer = 0.0
		add_coins(1, "queen_mint")


func add_coins(amount: int, source: String = "") -> void:
	treasury = max(0, treasury + amount)
	treasury_changed.emit(treasury)
	EventBus.coins_earned.emit(self, amount, source)


func spend_coins(amount: int) -> bool:
	if treasury < amount:
		return false
	treasury -= amount
	treasury_changed.emit(treasury)
	return true


func deposit(type: int, amount: int) -> void:
	stock[type] = int(stock.get(type, 0)) + amount


func stock_of(type: int) -> int:
	return int(stock.get(type, 0))


## What the squad is most short of for its next build step. Bots ask this so
## gathering is directed rather than random.
func most_needed_resource() -> int:
	if build_index >= BUILD_ORDER.size():
		return Constants.ResourceType.METAL
	var step: Dictionary = BUILD_ORDER[build_index]
	if stock_of(Constants.ResourceType.WOOD) < int(step.wood):
		return Constants.ResourceType.WOOD
	if stock_of(Constants.ResourceType.STONE) < int(step.stone):
		return Constants.ResourceType.STONE
	if stock_of(Constants.ResourceType.METAL) < int(step.metal):
		return Constants.ResourceType.METAL
	if stock_of(Constants.ResourceType.FOOD) < 6:
		return Constants.ResourceType.FOOD
	return Constants.ResourceType.WOOD


# ═══════════════════════════════════════════════════════════════════════════════
#  BUILDING (GDD §6)
# ═══════════════════════════════════════════════════════════════════════════════

## True when the squad has the materials for its next structure and just needs
## somebody to walk over and raise it.
##
## BUG FIXED: the bot side of this also required the builder to be personally
## carrying 6+ resources. Soldier A never gathers, so it never carried anything,
## so no squad ever built past its starting Hut for an entire match. Structures
## are paid for out of the SQUAD stockpile — that is what the stockpile is.
func wants_builder() -> bool:
	if build_index >= BUILD_ORDER.size():
		return false
	return can_afford(BUILD_ORDER[build_index])


func can_afford(step: Dictionary) -> bool:
	return stock_of(Constants.ResourceType.WOOD) >= int(step.wood) \
		and stock_of(Constants.ResourceType.STONE) >= int(step.stone) \
		and stock_of(Constants.ResourceType.METAL) >= int(step.metal)


func next_build_site() -> Vector3:
	return _pending_build_site


## A bot standing at the build site pays for and raises the next structure.
func contribute_build(_builder: Actor) -> void:
	if build_index >= BUILD_ORDER.size():
		return
	var step: Dictionary = BUILD_ORDER[build_index]
	if not can_afford(step):
		return

	stock[Constants.ResourceType.WOOD] = stock_of(Constants.ResourceType.WOOD) - int(step.wood)
	stock[Constants.ResourceType.STONE] = stock_of(Constants.ResourceType.STONE) - int(step.stone)
	stock[Constants.ResourceType.METAL] = stock_of(Constants.ResourceType.METAL) - int(step.metal)

	var pos := _pending_build_site
	if world:
		pos = world.on_ground(pos)
	place_structure(String(step.type), pos)

	build_index += 1
	_pending_build_site = _next_site()


func place_structure(type: String, pos: Vector3) -> Node3D:
	var node := StructureFactory.build_structure(type)
	if node == null:
		return null
	node.position = pos
	node.set_meta("squad_id", squad_id)
	node.set_meta("structure_type", type)
	if world:
		world.add_child(node)
	structures.append(node)

	if type == "mint":
		_has_mint = true
	# GDD §6: the Proximity Aura is squad-only information, so the ring is only
	# attached for the squad that owns the hut.
	if (type == "hut" or type == "hut_upgraded") and is_player_squad:
		node.add_child(StructureFactory.make_aura_ring(8.0 * Constants.TILE_SIZE.x * 0.5, squad_color))

	structure_built.emit(type, pos)
	return node


## Ring the base with structures rather than stacking them on one point.
func _next_site() -> Vector3:
	var a := (float(build_index) / float(BUILD_ORDER.size())) * TAU + float(squad_index)
	var r: float = 3.4 + float(build_index) * 0.55
	var p := base_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
	return world.on_ground(p) if world else p


# ═══════════════════════════════════════════════════════════════════════════════
#  ZONE SHRINK (GDD §12, minute 17)
# ═══════════════════════════════════════════════════════════════════════════════

func should_migrate() -> bool:
	return GameManager.match_time >= Constants.ZONE_SHRINK_START


func migration_target() -> Vector3:
	return Vector3.ZERO   # the Cursed Throne sits at the map centre


func zone_radius() -> float:
	if GameManager.match_time < Constants.ZONE_SHRINK_START:
		return 9999.0
	var elapsed: float = GameManager.match_time - Constants.ZONE_SHRINK_START
	var tiles_closed: float = elapsed / Constants.ZONE_SHRINK_RATE
	var half: float = float(Constants.GRID_SIZE.x) * 0.5
	return max(12.0, (half - tiles_closed) * Constants.TILE_SIZE.x)


# ═══════════════════════════════════════════════════════════════════════════════
#  MEMBERSHIP
# ═══════════════════════════════════════════════════════════════════════════════

func register(member: Actor) -> void:
	if members.has(member):
		return
	members.append(member)
	member.squad_id = squad_id
	member.squad_color = squad_color
	match member.role:
		Constants.Role.KING: king = member
		Constants.Role.QUEEN: queen = member
		_: pass
	member.downed.connect(func(): _on_member_downed(member))


func _on_member_downed(member: Actor) -> void:
	if member == queen:
		_queen_captured = true
	member_downed.emit(member)


func alive_count() -> int:
	var n := 0
	for m in members:
		if is_instance_valid(m) and m.is_alive():
			n += 1
	return n


func is_alive() -> bool:
	return alive_count() > 0


## GDD §6: the Hut is the respawn anchor. A squad can respawn its dead members
## only while at least one Hut still stands. No Hut → deaths are permanent.
func has_standing_hut() -> bool:
	for s in structures:
		if not is_instance_valid(s):
			continue
		var t := String(s.get_meta("structure_type", ""))
		if t == "hut" or t == "hut_upgraded":
			return true
	return false


func assign_traitor(member: Actor) -> void:
	traitor = member
	member.has_traitor_token = true


## GDD §11: cannot activate before minute 8, and the reveal is delayed 30s.
func try_activate_traitor() -> bool:
	if traitor == null or traitor_active:
		return false
	if GameManager.match_time < Constants.TRAITOR_ACTIVATION_UNLOCK_TIME:
		return false
	traitor_active = true
	traitor.traitor_activated = true
	# The Traitor takes the treasury with them.
	var stolen := treasury
	treasury = 0
	treasury_changed.emit(treasury)
	traitor.coins += stolen
	EventBus.traitor_activated.emit(traitor)
	EventBus.treasury_stolen.emit(traitor, self, stolen)

	get_tree().create_timer(Constants.TRAITOR_DISGUISE_DURATION).timeout.connect(func():
		if is_instance_valid(traitor):
			EventBus.traitor_revealed.emit(traitor)
			_post_betrayal_rally())
	return true


## GDD §11 Phase 3: the betrayed squad gets a 60-second comeback buff.
func _post_betrayal_rally() -> void:
	for m in members:
		if is_instance_valid(m) and m != traitor and m.is_alive():
			m.apply_buff(
				1.0 + Constants.POST_BETRAYAL_RALLY_SPEED,
				1.0 + Constants.POST_BETRAYAL_RALLY_DAMAGE,
				Constants.POST_BETRAYAL_RALLY_DURATION)
