extends Control

@onready var ticker_label: Label = $Banner/TickerLabel
@onready var timer_label: Label = $Banner/TimerLabel

var active_ransom_amount: int = 0
var active_prisoner: Node3D = null
var active_squad: String = ""
var time_remaining: float = 0.0

func _ready() -> void:
	EventBus.ransom_posted.connect(_on_ransom_posted)
	visible = false

func _on_ransom_posted(squad, prisoner, amount: int) -> void:
	active_squad = str(squad)
	active_prisoner = prisoner
	active_ransom_amount = amount
	time_remaining = Constants.RANSOM_WINDOW_DURATION
	visible = true

func _process(delta: float) -> void:
	if visible and time_remaining > 0.0:
		time_remaining -= delta
		if timer_label:
			timer_label.text = str(ceil(time_remaining)) + "s"
		if ticker_label:
			ticker_label.text = "RANSOM: " + active_squad + " — " + str(active_ransom_amount) + " coins"
			
		if time_remaining <= 0.0:
			visible = false
			print("Ransom window expired.")

func outbid(bidder_squad: String) -> void:
	var outbid_cost = int(active_ransom_amount * Constants.RANSOM_OUTBID_COST_RATIO)
	EventBus.ransom_outbid.emit(bidder_squad, active_prisoner, outbid_cost)
	visible = false

func extend_ransom() -> void:
	time_remaining += Constants.RANSOM_EXTENSION_TIME
	active_ransom_amount += Constants.RANSOM_EXTENSION_COST
