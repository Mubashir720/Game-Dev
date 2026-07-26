extends Node

var assigned_traitors: Dictionary = {} # player -> bool
var is_activated: Dictionary = {} # player -> bool
var trust_scores: Dictionary = {} # player -> float (0.0 to 100.0)

func assign_tokens(all_players: Array) -> void:
	assigned_traitors.clear()
	is_activated.clear()
	trust_scores.clear()
	
	for p in all_players:
		trust_scores[p] = 100.0
		assigned_traitors[p] = false
		is_activated[p] = false
		
	# Distribute 6 tokens randomly across available squads (2 clean squads per GDD §11)
	var count = min(6, all_players.size())
	all_players.shuffle()
	for i in range(count):
		assigned_traitors[all_players[i]] = true

func can_activate() -> bool:
	return GameManager.match_time >= Constants.TRAITOR_ACTIVATION_UNLOCK_TIME

func activate_traitor(player: Node3D) -> bool:
	if not can_activate():
		print("Traitor activation locked until minute 8:00!")
		return false
		
	if assigned_traitors.get(player, false):
		is_activated[player] = true
		EventBus.traitor_activated.emit(player)
		
		# 30s Disguise timer before red icon reveal
		get_tree().create_timer(Constants.TRAITOR_DISGUISE_DURATION).timeout.connect(func():
			EventBus.traitor_revealed.emit(player)
		)
		return true
	return false

func get_trust_color(player: Node3D) -> Color:
	var score = trust_scores.get(player, 100.0)
	if score > 70.0:
		return Color(0.30, 0.69, 0.31) # Green #4CAF50
	elif score > 40.0:
		return Color(1.0, 0.76, 0.03)  # Yellow #FFC107
	else:
		return Color(1.0, 0.60, 0.0)   # Orange #FF9800 (Never red!)
