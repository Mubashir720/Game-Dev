extends CanvasLayer

@onready var readout_label: Label = $HUDContainer/ReadoutLabel
@onready var action_button: Button = $HUDContainer/ActionButton
@onready var action_fill: ColorRect = $HUDContainer/ActionButton/ActionFill
@onready var ransom_banner: PanelContainer = $HUDContainer/RansomBanner
@onready var ransom_amount_label: Label = $HUDContainer/RansomBanner/AmountLabel
@onready var ransom_timer_label: Label = $HUDContainer/RansomBanner/TimerLabel
@onready var prison_options: HBoxContainer = $HUDContainer/PrisonOptions
@onready var toast_label: Label = $HUDContainer/ToastLabel

var _toast_timer: SceneTreeTimer = null

func _ready() -> void:
	EventBus.ransom_posted.connect(_on_ransom_posted)
	EventBus.player_imprisoned.connect(_on_player_imprisoned)
	EventBus.prisoner_executed.connect(_on_prisoner_executed)

func set_readout(text: String) -> void:
	if readout_label:
		readout_label.text = text

func show_action_button(label_text: String) -> void:
	if action_button:
		action_button.text = label_text
		action_button.visible = true
		if action_fill:
			action_fill.size.x = 0

func set_action_fill_percentage(pct: float) -> void:
	if action_button and action_fill:
		action_fill.size.x = action_button.size.x * clamp(pct, 0.0, 1.0)

func hide_action_button() -> void:
	if action_button:
		action_button.visible = false

func show_toast(message: String) -> void:
	if toast_label:
		toast_label.text = message
		toast_label.visible = true
		_toast_timer = get_tree().create_timer(4.2)
		_toast_timer.timeout.connect(func(): toast_label.visible = false)

func _on_ransom_posted(_squad, _prisoner, amount: int) -> void:
	if ransom_banner:
		ransom_amount_label.text = str(amount) + " coins"
		ransom_banner.visible = true
		show_toast("Ransom posted — " + str(amount) + " coins")

func _on_player_imprisoned(_captor, _captive, _cage) -> void:
	if prison_options:
		prison_options.visible = true
		set_readout("Prisoner locked in cage — choose their fate")

func _on_prisoner_executed(_executor, _prisoner) -> void:
	if prison_options:
		prison_options.visible = false
	show_toast("Prisoner executed — Forest Curse triggered on your squad.")
	set_readout("Forest Curse active — beasts are hunting you")
