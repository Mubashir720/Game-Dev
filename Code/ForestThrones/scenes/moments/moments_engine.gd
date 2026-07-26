extends Node

var rolling_buffer: Array = [] # Stores recent game events for 15s clip capture

func _ready() -> void:
	EventBus.traitor_revealed.connect(_on_traitor_revealed)
	EventBus.prisoner_escaped.connect(_on_prisoner_escaped)
	EventBus.beast_sacrifice.connect(_on_beast_sacrifice)
	EventBus.treasury_stolen.connect(_on_treasury_stolen)
	EventBus.beast_duel_started.connect(_on_beast_duel)
	EventBus.rogue_squad_formed.connect(_on_rogue_squad)
	EventBus.justice_served.connect(_on_justice_served)

func trigger_moment(moment_type: String, involved_players: Array) -> void:
	print("★ LEGENDARY MOMENT TRIGGERED: ", moment_type, " ★")
	EventBus.legendary_moment.emit(moment_type, involved_players)

func _on_traitor_revealed(player) -> void:
	trigger_moment("The Betrayal", [player])

func _on_prisoner_escaped(prisoner, _method) -> void:
	trigger_moment("The Great Escape", [prisoner])

func _on_beast_sacrifice(beast, saved_player) -> void:
	trigger_moment("Beast Sacrifice", [beast, saved_player])

func _on_treasury_stolen(thief, squad, _amount) -> void:
	trigger_moment("Crown Thief", [thief, squad])

func _on_beast_duel(b1, b2) -> void:
	trigger_moment("Beast Duel", [b1, b2])

func _on_rogue_squad(squad) -> void:
	trigger_moment("Rogue Alliance", [squad])

func _on_justice_served(killer, traitor) -> void:
	trigger_moment("Justice Served", [killer, traitor])
