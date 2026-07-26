extends Node

var active_curses: Dictionary = {} # squad -> float (remaining duration)
var execution_counts: Dictionary = {} # squad -> int

func trigger_curse(squad, trigger_type: int) -> void:
	var count = execution_counts.get(squad, 0) + 1
	execution_counts[squad] = count
	
	# GDD §11 System 3: Stacking duration (1st = 90s, 2nd = 120s, 3rd = 150s)
	var duration = Constants.CURSE_EXECUTION_BASE_DURATION + (count - 1) * 30.0
	active_curses[squad] = duration
	
	EventBus.forest_curse_triggered.emit(squad, trigger_type)
	print("Forest Curse triggered on squad! Duration: ", duration, "s")

func _process(delta: float) -> void:
	for squad in active_curses.keys():
		var time_left = active_curses[squad] - delta
		if time_left <= 0.0:
			active_curses.erase(squad)
			EventBus.forest_curse_ended.emit(squad)
		else:
			active_curses[squad] = time_left
