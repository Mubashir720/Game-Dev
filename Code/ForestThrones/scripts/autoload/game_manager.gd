extends Node

var match_time := 0.0
var game_state: Constants.GameState = Constants.GameState.LOADING
var current_day_time := 0.33 # Start in morning (0.0 = midnight, 0.5 = midday)
var squads: Array = []
var selected_archetype_id: String = "warlord"
## Practice Island (GDD §14) — solo, no enemies, tutorial integrated.
var practice_mode: bool = false
## Last completed match's summary, read by the post-match screen.
var last_match_report: Dictionary = {}

var _last_emitted_tick := -1
var _current_phase: int = -1

func _ready() -> void:
	# BUG FIXED: this used to call start_match() on autoload _ready, which meant
	# the 25-minute match clock began ticking the moment the app launched — while
	# the player was still on the main menu. By the time they actually pressed
	# Play, the Traitor unlock and zone shrink could already have passed.
	# The match now starts when MatchRoot says it does.
	game_state = Constants.GameState.LOBBY

func start_match() -> void:
	game_state = Constants.GameState.PLAYING
	match_time = 0.0
	_last_emitted_tick = -1
	EventBus.match_started.emit()

func _process(delta: float) -> void:
	if game_state != Constants.GameState.PLAYING:
		return
		
	match_time += delta
	
	var current_tick = int(match_time)
	if current_tick > _last_emitted_tick:
		_last_emitted_tick = current_tick
		EventBus.match_tick.emit(float(current_tick))
		_check_timeline_events(current_tick)
		
	# Day/Night time progression (720 seconds full cycle)
	var cycle_speed = 1.0 / Constants.FULL_DAY_NIGHT_CYCLE
	current_day_time = fmod(current_day_time + delta * cycle_speed, 1.0)
	
	# Determine Day Phase.
	# BUG FIXED: this used to emit day_phase_changed EVERY frame, which meant
	# every listener re-ran its transition work 60 times a second and the log
	# filled with one line per frame. It now only fires on an actual change.
	var phase := Constants.DayPhase.DAY
	if current_day_time < 0.10:
		phase = Constants.DayPhase.DAWN
	elif current_day_time < 0.60:
		phase = Constants.DayPhase.DAY
	elif current_day_time < 0.70:
		phase = Constants.DayPhase.DUSK
	else:
		phase = Constants.DayPhase.NIGHT

	if phase != _current_phase:
		_current_phase = phase
		EventBus.day_phase_changed.emit(phase)

func _check_timeline_events(tick: int) -> void:
	# GDD §12 Match Timeline Triggers (in seconds)
	
	# Min 7:00 (420s) - Black Market Warning
	if tick == 420 or tick == 1020:
		EventBus.black_market_warning.emit()
		
	# Min 8:00 (480s) - Traitor Unlock + Mutation Wave 1 + Black Market 1
	elif tick == 480:
		EventBus.mutation_wave_started.emit(1)
		spawn_black_market()
		
	# Min 10:00 (600s) - Shipment Crate 1
	elif tick == 600:
		spawn_shipment_crate()
		
	# Min 16:00 (960s) - Mutation Wave 2
	elif tick == 960:
		EventBus.mutation_wave_started.emit(2)
		
	# Min 17:00 (1020s) - Zone Shrink Starts
	elif tick == int(Constants.ZONE_SHRINK_START):
		EventBus.zone_shrink_started.emit()
		
	# Min 18:00 (1080s) - Black Market 2
	elif tick == 1080:
		spawn_black_market()
		
	# Min 20:00 (1200s) - Shipment Crate 2
	elif tick == 1200:
		spawn_shipment_crate()
		
	# End of match: Min 25:00 (1500s)
	if match_time >= Constants.MATCH_DURATION:
		end_match()

func end_match() -> void:
	game_state = Constants.GameState.POST_MATCH
	var winning_squad = _evaluate_winning_squad()
	EventBus.match_ended.emit(winning_squad)

func _evaluate_winning_squad():
	var best_squad = null
	var best_coins = -1
	for squad in squads:
		if squad.has_method("is_alive") and squad.is_alive():
			var coins = squad.treasury_balance if "treasury_balance" in squad else 0
			if coins > best_coins:
				best_coins = coins
				best_squad = squad
	return best_squad

func spawn_black_market() -> void:
	var spawn_pos = Vector3(randf_range(-40.0, 40.0), 0.0, randf_range(-40.0, 40.0))
	EventBus.black_market_spawned.emit(spawn_pos)

func spawn_shipment_crate() -> void:
	var drop_pos = Vector3(randf_range(-30.0, 30.0), 15.0, randf_range(-30.0, 30.0))
	EventBus.shipment_crate_dropped.emit(drop_pos)
