extends Node

@export var initial_state: String = "idle"

var current_state: PlayerState = null
var states: Dictionary = {}
var player: Node3D = null

func _ready() -> void:
	player = get_parent() as Node3D
	for child in get_children():
		if child is PlayerState:
			states[child.name.to_lower().replace("state", "")] = child
			child.player = player

	if initial_state in states:
		transition_to(initial_state)

func transition_to(target_state_name: String, params: Dictionary = {}) -> void:
	if current_state:
		current_state.exit()

	var key = target_state_name.to_lower().replace("state", "")
	if key in states:
		current_state = states[key] as PlayerState
		if current_state:
			current_state.enter(params)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
