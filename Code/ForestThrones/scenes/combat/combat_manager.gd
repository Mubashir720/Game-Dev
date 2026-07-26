extends Node

# GDD §9: Friendly fire, HP state transitions, charge attack, teamkiller icon

var _teamkiller_timers: Dictionary = {} # player -> float

func _process(delta: float) -> void:
	# Teamkiller icon countdown (GDD §9: 60s visible to all)
	for player in _teamkiller_timers.keys():
		_teamkiller_timers[player] -= delta
		if _teamkiller_timers[player] <= 0.0:
			_teamkiller_timers.erase(player)

func apply_damage(attacker: Node3D, target: Node3D, raw_damage: float, is_friendly: bool = false) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return

	var final_damage := raw_damage
	if is_friendly:
		# GDD §9: 50% reduced damage to teammates
		final_damage *= Constants.FRIENDLY_FIRE_DAMAGE_MODIFIER
		_mark_teamkiller(attacker, target)

	target.take_damage(final_damage)
	EventBus.player_damaged.emit(attacker, target, final_damage)

	var target_hp: float = target.get("hp") if target.get("hp") != null else 100.0
	_evaluate_hp_state(target, target_hp)

func _evaluate_hp_state(target: Node3D, hp: float) -> void:
	# GDD §9 HP States
	if hp <= 0.0:
		EventBus.player_downed.emit(target)
		if target.has_method("enter_downed_state"):
			target.enter_downed_state()
	elif hp <= Constants.CRITICAL_HP_THRESHOLD:
		if target.has_method("set_hp_state"):
			target.set_hp_state("critical")   # −40% speed, red screen pulse
	elif hp <= Constants.WOUNDED_HP_THRESHOLD:
		if target.has_method("set_hp_state"):
			target.set_hp_state("wounded")    # −20% speed, limp animation

func _mark_teamkiller(attacker: Node3D, victim: Node3D) -> void:
	# GDD §9: Check if victim is the confirmed Traitor (Justice Served) or innocent (Teamkiller)
	var traitor_sys = get_tree().root.find_child("TraitorSystem", true, false)
	if traitor_sys and traitor_sys.has_method("is_activated"):
		var is_traitor: bool = traitor_sys.assigned_traitors.get(victim, false) and \
							   traitor_sys.is_activated.get(victim, false)
		if is_traitor:
			# GDD §9: Justice Served — no penalty, +10 coins
			EventBus.justice_served.emit(attacker, victim)
			EventBus.coins_earned.emit(attacker.get_meta("squad_id", ""), Constants.JUSTICE_SERVED_COIN_REWARD, "justice_served")
			return
	# Regular friendly fire — Teamkiller icon for 60s
	EventBus.teamkiller_marked.emit(attacker)
	_teamkiller_timers[attacker] = Constants.TEAMKILLER_ICON_DURATION

func is_teamkiller(player: Node3D) -> bool:
	return _teamkiller_timers.has(player)
