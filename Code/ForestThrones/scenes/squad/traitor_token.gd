extends Node

signal rogue_activated(player: Node3D)
signal icon_revealed(player: Node3D)

var is_activated: bool = false
var is_revealed: bool = false
var owner_player: Node3D = null

func activate() -> void:
	is_activated = true
	rogue_activated.emit(owner_player)

func reveal() -> void:
	is_revealed = true
	icon_revealed.emit(owner_player)
