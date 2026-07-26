extends Node3D

var value: int = 1
var _collector: Node3D = null

func collect(player: Node3D) -> void:
	_collector = player
	EventBus.coins_earned.emit(player.get_meta("squad_id", "squad_1"), value, "pickup")
	queue_free()
