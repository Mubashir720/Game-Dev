extends CanvasModulate

var cycle_gradient: Gradient
var current_phase: Constants.DayPhase = Constants.DayPhase.DAY

func _ready() -> void:
    # Programmatic visual gradient mapping out a 12-minute day/night flow
    cycle_gradient = Gradient.new()
    # Remove default points
    cycle_gradient.remove_point(0)
    cycle_gradient.remove_point(0)
    
    cycle_gradient.add_point(0.0, Color(0.12, 0.12, 0.3))    # Midnight (Night)
    cycle_gradient.add_point(0.15, Color(0.12, 0.12, 0.3))   # Late Night
    cycle_gradient.add_point(0.25, Color(0.85, 0.52, 0.3))   # Dawn (Ember Gold)
    cycle_gradient.add_point(0.35, Color(1.0, 1.0, 1.0))     # Day (Bright)
    cycle_gradient.add_point(0.68, Color(1.0, 1.0, 1.0))     # Day ends
    cycle_gradient.add_point(0.78, Color(0.68, 0.32, 0.58))  # Dusk (Moonlit Purple)
    cycle_gradient.add_point(0.88, Color(0.2, 0.18, 0.35))   # Twilight
    cycle_gradient.add_point(1.0, Color(0.12, 0.12, 0.3))    # Midnight

func _process(delta: float) -> void:
    if GameManager.game_state != Constants.GameState.PLAYING:
        return
        
    var time_of_day = GameManager.current_day_time
    color = cycle_gradient.sample(time_of_day)
    
    _update_phase(time_of_day)

func _update_phase(time_of_day: float) -> void:
    var new_phase = Constants.DayPhase.DAY
    
    if time_of_day < 0.2:
        new_phase = Constants.DayPhase.NIGHT
    elif time_of_day < 0.3:
        new_phase = Constants.DayPhase.DAWN
    elif time_of_day < 0.7:
        new_phase = Constants.DayPhase.DAY
    elif time_of_day < 0.8:
        new_phase = Constants.DayPhase.DUSK
    else:
        new_phase = Constants.DayPhase.NIGHT
        
    if new_phase != current_phase:
        current_phase = new_phase
        EventBus.day_phase_changed.emit(current_phase)
