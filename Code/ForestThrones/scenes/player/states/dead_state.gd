extends PlayerState

func enter(_params: Dictionary = {}) -> void:
	if player:
		EventBus.player_killed.emit(player, null)
