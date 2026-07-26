extends Node

var squad_treasuries: Dictionary = {} # squad_id -> int (coin balance)
var _queen_mint_timers: Dictionary = {} # squad_id -> float

func register_squad(squad_id: String) -> void:
	squad_treasuries[squad_id] = 0
	_queen_mint_timers[squad_id] = 0.0

func _process(delta: float) -> void:
	if GameManager.game_state != Constants.GameState.PLAYING:
		return
		
	# Queen passive coin minting (GDD §7: 1 coin per 20s, doubled with Mint = 1 coin per 10s)
	for squad_id in squad_treasuries.keys():
		var timer = _queen_mint_timers.get(squad_id, 0.0) + delta
		var interval = Constants.QUEEN_COIN_RATE # default 20s
		
		# Check if squad has active Mint
		if has_active_mint(squad_id):
			interval = Constants.QUEEN_COIN_RATE_MINT # 10s
			
		if timer >= interval:
			timer -= interval
			add_coins(squad_id, 1, "queen_mint")
			
		_queen_mint_timers[squad_id] = timer

func add_coins(squad_id: String, amount: int, source: String) -> void:
	var current = squad_treasuries.get(squad_id, 0)
	squad_treasuries[squad_id] = current + amount
	EventBus.coins_earned.emit(squad_id, amount, source)

func spend_coins(squad_id: String, amount: int, target: String) -> bool:
	var current = squad_treasuries.get(squad_id, 0)
	if current >= amount:
		squad_treasuries[squad_id] = current - amount
		EventBus.coins_spent.emit(squad_id, amount, target)
		return true
	return false

func has_active_mint(squad_id: String) -> bool:
	# GDD §7: Mint doubles Queen coin rate — query scene for active Mint structures
	var tree = Engine.get_main_loop()
	if not tree:
		return false
	var mints: Array = tree.get_nodes_in_group("mints")
	for m in mints:
		if m.has_method("get") and m.get("squad_id") == squad_id:
			var state = m.get("current_state")
			if state != null and str(state) != "DESTROYED":
				return true
	return false

func scatter_treasury(squad_id: String, position: Vector3) -> void:
	var current = squad_treasuries.get(squad_id, 0)
	var scatter_amount = int(current * 0.50) # GDD §7: 50% scatter
	squad_treasuries[squad_id] = current - scatter_amount
	EventBus.treasury_destroyed.emit(squad_id, scatter_amount)
	print("Treasury destroyed! Scattered ", scatter_amount, " coins at ", position)
