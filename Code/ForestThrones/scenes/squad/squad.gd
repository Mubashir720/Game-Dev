extends Node

# GDD §4, §7, §11 — Squad lifecycle, queen income, traitor assignment

@export var squad_id: String = "squad_1"
@export var squad_color: Color = Color.RED

var members: Array = []         # Array[Node3D]
var treasury_balance: int = 0
var king: Node3D = null
var queen: Node3D = null
var traitor_token_holder: Node3D = null

var queen_is_captured: bool = false
var _emergency_income_timer: float = 0.0
const EMERGENCY_INCOME_INTERVAL := 80.0  # 0.25 coins per 20s per member = ~1 coin per 80s

# GDD §7 Queen's Secret Stash — 10 coins emergency reserve
var queens_secret_stash: int = Constants.QUEEN_SECRET_STASH

func _ready() -> void:
	EventBus.player_imprisoned.connect(_on_player_imprisoned)
	EventBus.player_respawned.connect(_on_player_respawned)
	CoinSystem.register_squad(squad_id)

func _process(delta: float) -> void:
	# GDD §7: Emergency income when Queen is captured (75% reduction, not 100%)
	if queen_is_captured:
		_emergency_income_timer += delta
		if _emergency_income_timer >= EMERGENCY_INCOME_INTERVAL:
			_emergency_income_timer = 0.0
			# Each surviving member generates 0.25 coins per 20s
			var alive_count := _count_alive_members()
			if alive_count > 0:
				CoinSystem.add_coins(squad_id, 1, "emergency_income")

func add_member(member: Node3D) -> void:
	if not members.has(member):
		members.append(member)
		member.set_meta("squad_id", squad_id)
		member.set_meta("squad_color", squad_color)

func assign_roles(king_player: Node3D, queen_player: Node3D) -> void:
	king = king_player
	queen = queen_player
	if king:
		king.set_meta("role", Constants.Role.KING)
	if queen:
		queen.set_meta("role", Constants.Role.QUEEN)

func is_alive() -> bool:
	for member in members:
		if is_instance_valid(member) and member.get("hp") != null and member.get("hp") > 0.0:
			return true
	return false

func _count_alive_members() -> int:
	var count := 0
	for m in members:
		if is_instance_valid(m) and m.get("hp") != null and m.get("hp") > 0.0:
			count += 1
	return count

func _on_player_imprisoned(_captor, captive: Node3D, _cage) -> void:
	if captive == queen:
		queen_is_captured = true
		print("[Squad %s] Queen captured — emergency income active" % squad_id)

func _on_player_respawned(player: Node3D) -> void:
	if player == queen and queen_is_captured:
		queen_is_captured = false
		# GDD §7 Rescue Bonus: Queen generates 1.5x coins for 60s after being freed
		_apply_reunited_buff()
		print("[Squad %s] Queen freed — Reunited buff active!" % squad_id)

func _apply_reunited_buff() -> void:
	# Temporarily halve Queen coin rate for 60s (doubles output)
	var original_rate: float = float(CoinSystem._queen_mint_timers.get(squad_id, 0.0))
	print("[Squad %s] Reunited buff: 1.5x coin rate for 60s" % squad_id)
	get_tree().create_timer(60.0).timeout.connect(func():
		print("[Squad %s] Reunited buff ended" % squad_id)
	)

func get_treasury_balance() -> int:
	return CoinSystem.squad_treasuries.get(squad_id, 0)

func deposit_coins(amount: int) -> void:
	CoinSystem.add_coins(squad_id, amount, "deposit")

func withdraw_coins(amount: int, player_name: String = "") -> bool:
	return CoinSystem.spend_coins(squad_id, amount, "withdrawal:" + player_name)
