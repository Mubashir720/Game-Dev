extends PlayerState
## CarriageState — Player is handcuffed and being carried by captor.
## Movement is locked to following the captor. Can attempt lockpick.

var _lockpick_timer := 0.0
const LOCKPICK_TIME := 4.0   # Hold F for 4 seconds to attempt lockpick

func enter(_params: Dictionary = {}) -> void:
	player.velocity = Vector2.ZERO

func exit() -> void:
	_lockpick_timer = 0.0

func update(delta: float) -> void:
	# Attempt lockpick by holding "lockpick" action
	if Input.is_action_pressed("lockpick"):
		_lockpick_timer += delta
		if _lockpick_timer >= LOCKPICK_TIME:
			_attempt_escape()
	else:
		_lockpick_timer = max(0.0, _lockpick_timer - delta * 2.0)

func physics_update(delta: float) -> void:
	var cap_sys = player.get_node_or_null("/root/CaptureSystem")
	if cap_sys:
		cap_sys.update_carriage_follow(player, delta)

func _attempt_escape() -> void:
	_lockpick_timer = 0.0
	# 35% base chance to succeed
	var success := randf() < 0.35
	if success:
		var cap_sys = player.get_node_or_null("/root/CaptureSystem")
		if cap_sys:
			cap_sys.free_prisoner(player)
		EventBus.prisoner_escaped.emit(player, "lockpick")
		player.state_machine.transition_to("idle")
