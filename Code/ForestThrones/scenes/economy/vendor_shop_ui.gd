extends Control

var _player: Node3D = null

func open_for_player(player: Node3D, _is_black_market: bool = false) -> void:
	_player = player
	visible = true
