extends Node3D

var is_claimed: bool = false

func try_interact(player: Node3D) -> bool:
	if is_claimed:
		return false
	is_claimed = true
	print("Shipment Crate claimed by player!")
	EventBus.coins_earned.emit(player.get_meta("squad_id", "squad_1"), 25, "shipment_crate")
	queue_free()
	return true
