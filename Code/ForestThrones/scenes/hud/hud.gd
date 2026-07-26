extends CanvasLayer

@onready var timer_label: Label = $Control/TopPanel/HBoxContainer/TimerLabel
@onready var phase_label: Label = $Control/TopPanel/HBoxContainer/PhaseLabel
@onready var wood_label: Label = $Control/BottomPanel/HBoxContainer/WoodLabel
@onready var stone_label: Label = $Control/BottomPanel/HBoxContainer/StoneLabel
@onready var food_label: Label = $Control/BottomPanel/HBoxContainer/FoodLabel
@onready var herbs_label: Label = $Control/BottomPanel/HBoxContainer/HerbsLabel
@onready var metal_label: Label = $Control/BottomPanel/HBoxContainer/MetalLabel
@onready var gold_label: Label = %GoldLabel
@onready var ticker_label: Label = %TickerLabel
@onready var ticker_panel: PanelContainer = %TickerPanel

var _player_ref: Node3D = null

func _ready() -> void:
	# Style HPBar
	_style_bar(%HPBar, Color(0.12, 0.45, 0.22), Color(0.4, 0.1, 0.1))
	# Style HungerBar
	_style_bar(%HungerBar, Color(0.72, 0.45, 0.15), Color(0.2, 0.15, 0.1))
	# Style ThirstBar
	_style_bar(%ThirstBar, Color(0.15, 0.52, 0.82), Color(0.1, 0.15, 0.2))
	# Style XPBar
	_style_bar(%XPBar, Color(0.85, 0.68, 0.15), Color(0.18, 0.18, 0.15))
	
	# Add Ransom Board button to TopPanel HBoxContainer
	var ransom_btn = Button.new()
	ransom_btn.text = "Ransom Board"
	ransom_btn.custom_minimum_size = Vector2(90, 24)
	ransom_btn.add_theme_font_size_override("font_size", 9)
	ransom_btn.pressed.connect(func():
		var rb_scene = load("res://scenes/economy/ransom_board.tscn")
		if rb_scene:
			var rb = rb_scene.instantiate()
			get_tree().current_scene.add_child(rb)
	)
	$Control/TopPanel/HBoxContainer.add_child(ransom_btn)
	
	# Add Lobby / BP button to TopPanel HBoxContainer
	var lobby_btn = Button.new()
	lobby_btn.text = "Lobby / BP"
	lobby_btn.custom_minimum_size = Vector2(80, 24)
	lobby_btn.add_theme_font_size_override("font_size", 9)
	lobby_btn.pressed.connect(func():
		var lobby_scene = load("res://scenes/matchmaking/matchmaking_lobby.tscn")
		if lobby_scene:
			var lobby = lobby_scene.instantiate()
			get_tree().current_scene.add_child(lobby)
	)
	$Control/TopPanel/HBoxContainer.add_child(lobby_btn)
	
	# Add Highlights button to TopPanel HBoxContainer
	var highlights_btn = Button.new()
	highlights_btn.text = "Highlights"
	highlights_btn.custom_minimum_size = Vector2(80, 24)
	highlights_btn.add_theme_font_size_override("font_size", 9)
	highlights_btn.pressed.connect(func():
		var game_mgr = get_node_or_null("/root/GameManager")
		var moments_ctrl = game_mgr.get_node_or_null("MomentsEngineController") if game_mgr else null
		if moments_ctrl and not moments_ctrl.saved_moment.is_empty():
			var reel_scene = load("res://scenes/moments/highlights_reel.tscn")
			if reel_scene:
				var reel = reel_scene.instantiate()
				get_tree().current_scene.add_child(reel)
				reel.open_moment(moments_ctrl.saved_moment)
		else:
			print("No highlights captured yet!")
			show_ticker_message("No Highlights captured yet! Press T to simulate a betrayal or low HP kill.")
	)
	$Control/TopPanel/HBoxContainer.add_child(highlights_btn)

	
	# Style TickerPanel programmatically (Premium dark medieval parchment style)
	var sb_ticker = StyleBoxFlat.new()
	sb_ticker.bg_color = Color(0.1, 0.08, 0.06, 0.8) # Semi-trans wood
	sb_ticker.border_color = Color(0.25, 0.20, 0.15) # Light wood trim
	sb_ticker.border_width_bottom = 2
	sb_ticker.border_width_top = 2
	sb_ticker.set_corner_radius_all(3)
	ticker_panel.add_theme_stylebox_override("background", sb_ticker)
	
	# Create and style full-screen red warning vignette overlay
	var vignette = Panel.new()
	vignette.name = "VignettePanel"
	vignette.layout_mode = 3
	vignette.anchors_preset = 15
	vignette.anchor_right = 1.0
	vignette.anchor_bottom = 1.0
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.visible = false
	
	var sb_vignette = StyleBoxFlat.new()
	sb_vignette.bg_color = Color(0, 0, 0, 0)
	sb_vignette.border_color = Color(0.8, 0.0, 0.0, 0.5)
	sb_vignette.border_width_left = 60
	sb_vignette.border_width_top = 60
	sb_vignette.border_width_right = 60
	sb_vignette.border_width_bottom = 60
	sb_vignette.border_blend = true
	vignette.add_theme_stylebox_override("panel", sb_vignette)
	$Control.add_child(vignette)
	
	# Connect to EventBus signals for dynamic ticker updates
	EventBus.coins_earned.connect(_on_coins_earned)
	EventBus.coins_spent.connect(_on_coins_spent)
	EventBus.treasury_stolen.connect(_on_treasury_stolen)
	EventBus.treasury_destroyed.connect(_on_treasury_destroyed)
	EventBus.ransom_posted.connect(_on_ransom_posted)
	EventBus.ransom_paid.connect(_on_ransom_paid)
	EventBus.ransom_outbid.connect(_on_ransom_outbid)
	EventBus.legendary_moment.connect(_on_legendary_moment)
	EventBus.level_up.connect(_on_level_up)
	EventBus.match_ended.connect(_on_match_ended)

func _style_bar(bar: ProgressBar, fill_color: Color, bg_color: Color) -> void:
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = fill_color
	sb_fill.corner_detail = 4
	sb_fill.set_corner_radius_all(3)
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = bg_color
	sb_bg.corner_detail = 4
	sb_bg.set_corner_radius_all(3)
	
	bar.add_theme_stylebox_override("fill", sb_fill)
	bar.add_theme_stylebox_override("background", sb_bg)

func set_player(player: Node3D) -> void:
	_player_ref = player

func show_ticker_message(msg: String) -> void:
	if is_instance_valid(ticker_label):
		ticker_label.text = msg
		# Animate ticker flash/pulse for premium feel
		var tween = create_tween()
		tween.tween_property(ticker_panel, "scale", Vector2(1.05, 1.05), 0.1)
		tween.tween_property(ticker_panel, "scale", Vector2(1.0, 1.0), 0.15)

# EventBus Callbacks
func _on_coins_earned(squad, amount: int, source: String) -> void:
	show_ticker_message("Squad %d earned %d Gold via %s!" % [squad.squad_id, amount, source.replace("_", " ")])

func _on_coins_spent(squad, amount: int, target: String) -> void:
	show_ticker_message("Squad %d spent %d Gold on %s!" % [squad.squad_id, amount, target.replace("_", " ")])

func _on_treasury_stolen(thief, squad_id: int, amount: int) -> void:
	show_ticker_message("ALERT! Traitor %s stole %d Gold from Squad %d's Treasury!" % [thief.name, amount, squad_id])

func _on_treasury_destroyed(squad_id: int, scatter_amount: int) -> void:
	show_ticker_message("Treasury of Squad %d was destroyed! %d Gold scattered!" % [squad_id, scatter_amount])

func _on_ransom_posted(captor_squad_id: int, prisoner: Node3D, amount: int) -> void:
	show_ticker_message("RANSOM: Squad %d has posted %d Gold ransom for %s!" % [captor_squad_id, amount, prisoner.name])

func _on_ransom_paid(payer_squad, prisoner: Node3D, amount: int) -> void:
	show_ticker_message("RANSOM PAID: %s was released for %d Gold!" % [prisoner.name, amount])

func _on_ransom_outbid(bidder_squad, prisoner: Node3D, amount: int) -> void:
	show_ticker_message("PRISONER STOLEN: Squad %d outbid and claimed %s!" % [bidder_squad.squad_id, prisoner.name])

func _on_legendary_moment(moment_type: String, _involved_players: Array) -> void:
	match moment_type:
		"black_market_spawned":
			show_ticker_message("BLACK MARKET: A shady merchant has appeared mid-map! (Lasts 3m)")
		"shipment_dropped":
			show_ticker_message("SHIPMENT DROP: A supply crate is parachuting into a clearing!")
		"shipment_crate_looted":
			show_ticker_message("SHIPMENT CLAIMED: A squad has successfully looted the supply crate!")

func _on_level_up(player: Node3D, new_level: int) -> void:
	if is_instance_valid(player) and player == _player_ref:
		show_ticker_message("👑 LEVEL UP! Reached Level %d! (+25 Gold, +10 Wood, +10 Stone) 👑" % new_level)
		
		# Pulse animation on LevelLabel for premium feel
		var level_label = %LevelLabel
		if is_instance_valid(level_label):
			var orig_color = level_label.get_theme_color("font_color")
			var tween = create_tween()
			tween.tween_property(level_label, "theme_override_colors/font_color", Color(1.0, 0.85, 0.2), 0.15)
			tween.parallel().tween_property(level_label, "scale", Vector2(1.2, 1.2), 0.15)
			tween.tween_property(level_label, "theme_override_colors/font_color", orig_color, 0.2)
			tween.parallel().tween_property(level_label, "scale", Vector2(1.0, 1.0), 0.2)

func _on_match_ended(winning_squad_ref) -> void:
	# Show Post Match Summary scoreboard screen
	var summary_scene = load("res://scenes/hud/post_match_summary.tscn")
	if summary_scene:
		var summary = summary_scene.instantiate()
		get_tree().current_scene.add_child(summary)

func _process(_delta: float) -> void:
	# Update Red Vignette Overlay based on player zone state
	var vignette = $Control/VignettePanel
	if vignette:
		if is_instance_valid(_player_ref) and _player_ref.has_meta("outside_zone") and _player_ref.get_meta("outside_zone") == true:
			vignette.visible = true
			var alpha = 0.4 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
			vignette.modulate.a = alpha
		else:
			vignette.visible = false

	# 1. Update Match Timer & Day Phase
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		var mins = int(game_manager.match_time) / 60
		var secs = int(game_manager.match_time) % 60
		timer_label.text = "%02d:%02d" % [mins, secs]
		
		var day_phase_str = "DAY"
		var cycle_node = get_tree().current_scene.find_child("DayNightCycle", true, false)
		if cycle_node:
			match cycle_node.current_phase:
				Constants.DayPhase.DAWN: day_phase_str = "DAWN"
				Constants.DayPhase.DAY: day_phase_str = "DAY"
				Constants.DayPhase.DUSK: day_phase_str = "DUSK"
				Constants.DayPhase.NIGHT: day_phase_str = "NIGHT"
		phase_label.text = "PHASE: " + day_phase_str
		
	# 2. Update Inventory Counters from player state
	if is_instance_valid(_player_ref):
		wood_label.text = "Wood: %d" % _player_ref.inventory.get(Constants.ResourceType.WOOD, 0)
		stone_label.text = "Stone: %d" % _player_ref.inventory.get(Constants.ResourceType.STONE, 0)
		food_label.text = "Food: %d" % _player_ref.inventory.get(Constants.ResourceType.FOOD, 0)
		herbs_label.text = "Herbs: %d" % _player_ref.inventory.get(Constants.ResourceType.HERBS, 0)
		metal_label.text = "Metal: %d" % _player_ref.inventory.get(Constants.ResourceType.METAL, 0)
		gold_label.text = "Gold: %d" % _player_ref.coins
		
		# 3. Update Stat Bars
		if _player_ref.stats:
			var st = _player_ref.stats
			
			# HP
			%HPBar.max_value = st.max_hp
			%HPBar.value = st.hp
			%HPBar.get_node("Label").text = "HP: %d/%d" % [int(st.hp), int(st.max_hp)]
			
			# Hunger
			%HungerBar.max_value = 100.0
			%HungerBar.value = st.hunger
			%HungerBar.get_node("Label").text = "HUNGER: %d/100" % int(st.hunger)
			
			# Thirst
			%ThirstBar.max_value = 100.0
			%ThirstBar.value = st.thirst
			%ThirstBar.get_node("Label").text = "THIRST: %d/100" % int(st.thirst)
			
			# XP & Level
			%XPBar.max_value = st.max_xp
			%XPBar.value = st.xp
			%XPBar.get_node("Label").text = "XP: %d/%d" % [int(st.xp), int(st.max_xp)]
			
			var role_str = "KING"
			match _player_ref.role:
				Constants.Role.KING: role_str = "KING"
				Constants.Role.QUEEN: role_str = "QUEEN"
				Constants.Role.SOLDIER_A: role_str = "SOLDIER A"
				Constants.Role.SOLDIER_B: role_str = "SOLDIER B"
				
			%LevelLabel.text = "%s | LEVEL: %d (%s)" % [
				role_str,
				st.level,
				_player_ref.archetype if _player_ref.archetype != "" else "No Archetype"
			]

