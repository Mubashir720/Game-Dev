extends Node

enum CapturePhase { APPROACH, IN_RANGE, DOWNED, CARRYING, AT_CAGE, IMPRISONED }

var current_phase: CapturePhase = CapturePhase.APPROACH
var current_captive: Node3D = null
var handcuff_hold_timer: float = 0.0

func start_handcuff_hold() -> void:
	if current_phase == CapturePhase.DOWNED:
		handcuff_hold_timer = 0.0

func process_handcuff_hold(delta: float, captor: Node3D, captive: Node3D) -> bool:
	if current_phase != CapturePhase.DOWNED:
		return false
		
	handcuff_hold_timer += delta
	if handcuff_hold_timer >= Constants.HANDCUFF_HOLD_TIME:
		complete_handcuff(captor, captive)
		return true
	return false

func cancel_handcuff_hold() -> void:
	handcuff_hold_timer = 0.0

func complete_handcuff(captor: Node3D, captive: Node3D) -> void:
	current_phase = CapturePhase.CARRYING
	current_captive = captive
	EventBus.player_handcuffed.emit(captor, captive)

func imprison_in_cage(captor: Node3D, captive: Node3D, cage: Node3D) -> void:
	current_phase = CapturePhase.IMPRISONED
	EventBus.player_imprisoned.emit(captor, captive, cage)

func select_prison_option(option: Constants.PrisonOption, data: Dictionary = {}) -> void:
	match option:
		Constants.PrisonOption.RANSOM:
			var amount = data.get("amount", 50)
			EventBus.ransom_posted.emit(data.get("squad"), current_captive, amount)
		Constants.PrisonOption.FORCED_LABOR:
			var resource_type = data.get("resource_type", Constants.ResourceType.WOOD)
			EventBus.forced_labor_started.emit(data.get("squad"), current_captive, resource_type)
		Constants.PrisonOption.INTERROGATE:
			print("Interrogation initiated on captive.")
		Constants.PrisonOption.EXECUTE:
			EventBus.prisoner_executed.emit(data.get("executor"), current_captive)
			EventBus.forest_curse_triggered.emit(data.get("squad"), 2) # Trigger curse
		Constants.PrisonOption.SELL:
			EventBus.coins_earned.emit(data.get("squad"), Constants.BLACK_MARKET_PRISONER_SALE_PRICE, "sold_prisoner")
