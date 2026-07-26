extends RefCounted

signal hp_changed(new_hp: float)
signal hunger_changed(new_hunger: float)
signal thirst_changed(new_thirst: float)
signal xp_changed(new_xp: float, max_xp: float, level: int)
signal state_changed(new_state: int) # Maps to HPState enums below

enum HPState { HEALTHY, WOUNDED, CRITICAL, DOWNED, DEAD }

var hp := 100.0
var max_hp := 100.0
var hunger := 100.0
var thirst := 100.0
var xp := 0.0
var max_xp := 100.0
var level := 1
var state = HPState.HEALTHY

# Decay accumulation helper timers
var _hunger_timer := 0.0
var _thirst_timer := 0.0
var _starvation_timer := 0.0
var _dehydration_timer := 0.0
var _bleed_timer := 0.0

func initialize(role_type: Constants.Role) -> void:
    # GDD Section 4 Role Stat Modifiers
    match role_type:
        Constants.Role.KING:
            max_hp = 130.0
        Constants.Role.QUEEN:
            max_hp = 80.0
        Constants.Role.SOLDIER_A:
            max_hp = 110.0
        Constants.Role.SOLDIER_B:
            max_hp = 90.0
    hp = max_hp

func reset_stats() -> void:
    hp = max_hp
    hunger = 100.0
    thirst = 100.0
    state = HPState.HEALTHY
    hp_changed.emit(hp)
    hunger_changed.emit(hunger)
    thirst_changed.emit(thirst)
    state_changed.emit(state)

func take_damage(amount: float) -> void:
    if state == HPState.DEAD:
        return
    hp = clamp(hp - amount, 0.0, max_hp)
    hp_changed.emit(hp)
    _check_state_transitions()

func heal(amount: float) -> void:
    if state == HPState.DEAD or state == HPState.DOWNED:
        return
    hp = clamp(hp + amount, 0.0, max_hp)
    hp_changed.emit(hp)
    _check_state_transitions()

func consume_food(amount: float) -> void:
    hunger = clamp(hunger + amount, 0.0, 100.0)
    hunger_changed.emit(hunger)

func consume_water(amount: float) -> void:
    thirst = clamp(thirst + amount, 0.0, 100.0)
    thirst_changed.emit(thirst)

func gain_xp(amount: float) -> void:
    if state == HPState.DEAD:
        return
    xp += amount
    while xp >= max_xp:
        xp -= max_xp
        level += 1
        max_xp = max_xp * 1.5 # Level up scaling GDD
        # Heal on level up
        hp = min(hp + max_hp * 0.25, max_hp)
        hp_changed.emit(hp)
        _check_state_transitions()
        EventBus.level_up.emit(null, level) # (player reference will be set in player.gd wrapper)
    xp_changed.emit(xp, max_xp, level)

func update_decay(delta: float) -> void:
    if state == HPState.DEAD:
        return
        
    # GDD Section 8: Hunger decays -1 per 8 seconds
    if hunger > 0:
        _hunger_timer += delta
        if _hunger_timer >= 8.0:
            _hunger_timer = 0.0
            hunger = max(0.0, hunger - 1.0)
            hunger_changed.emit(hunger)
    else:
        # GDD Section 8: Starvation drains -1 HP per 3 seconds
        _starvation_timer += delta
        if _starvation_timer >= 3.0:
            _starvation_timer = 0.0
            take_damage(1.0)
            
    # GDD Section 8: Thirst decays -1 per 6 seconds
    if thirst > 0:
        _thirst_timer += delta
        if _thirst_timer >= 6.0:
            _thirst_timer = 0.0
            thirst = max(0.0, thirst - 1.0)
            thirst_changed.emit(thirst)
    else:
        # GDD Section 8: Dehydration drains -1 HP per 2 seconds
        _dehydration_timer += delta
        if _dehydration_timer >= 2.0:
            _dehydration_timer = 0.0
            take_damage(1.0)

    # Downed bleeding: GDD Section 9 down state bleeds -1 HP per 3 seconds
    if state == HPState.DOWNED:
        _bleed_timer += delta
        if _bleed_timer >= 3.0:
            _bleed_timer = 0.0
            take_damage(1.0)

func _check_state_transitions() -> void:
    var old_state = state
    
    if hp <= 0.0:
        if state == HPState.DEAD:
            pass
        elif state == HPState.DOWNED:
            # Bleed timer expired -> Dead
            state = HPState.DEAD
        else:
            # 0 HP first time -> Downed (crawl only, bleed 1 HP/3s, dies in 30s)
            state = HPState.DOWNED
            _bleed_timer = 0.0
    elif hp <= 10.0:
        state = HPState.CRITICAL
    elif hp <= 40.0:
        state = HPState.WOUNDED
    else:
        state = HPState.HEALTHY
        
    if state != old_state:
        state_changed.emit(state)
