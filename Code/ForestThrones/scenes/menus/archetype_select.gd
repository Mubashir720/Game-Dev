extends Control

const CharacterFactory = preload("res://scenes/player/character_factory.gd")
const UITheme = preload("res://scenes/hud/ui_theme.gd")

@onready var archetype_grid: VBoxContainer = $GridMargin/VBox/Scroll/ArchetypeGrid
@onready var archetype_name_label: Label = $InfoPanel/VBox/NameLabel
@onready var role_label: Label = $InfoPanel/VBox/RoleLabel
@onready var active_ability_label: Label = $InfoPanel/VBox/ActiveLabel
@onready var passive_ability_label: Label = $InfoPanel/VBox/PassiveLabel
@onready var select_play_btn: Button = $InfoPanel/VBox/SelectPlayBtn
@onready var back_button: Button = $InfoPanel/VBox/BackButton
@onready var preview_viewport: SubViewport = $PreviewContainer/SubViewport

var _preview_node: Node3D = null
var _preview_character: Node3D = null
var _selected_id: String = "warlord"

const ALL_ARCHETYPES = [
	# KING ROLES
	{"id": "warlord",   "name": "Warlord",   "role_name": "King (Combat Anchor)",          "role": Constants.Role.KING,      "active": "Rally Cry (+20% speed & damage to squad for 8s)", "passive": "War Banner (+15% damage within 8 tiles)"},
	{"id": "regent",    "name": "Regent",    "role_name": "King (Economy Lead)",           "role": Constants.Role.KING,      "active": "Tax Edict (+50% coins for 20s)",                  "passive": "Stockpile (+50% resource capacity)"},
	{"id": "beastlord", "name": "Beastlord", "role_name": "King (Beast Tamer)",            "role": Constants.Role.KING,      "active": "Tame (+30% stats to tame beast)",                 "passive": "Pack Leader (+15% speed with beasts)"},
	# QUEEN ROLES
	{"id": "engineer",  "name": "Engineer",  "role_name": "Queen (Crafting Engine)",       "role": Constants.Role.QUEEN,     "active": "Overclock (Squad builds 50% faster for 15s)",      "passive": "Trap Master (+40% trap damage)"},
	{"id": "witch",     "name": "Witch",     "role_name": "Queen (Dark Magic)",            "role": Constants.Role.QUEEN,     "active": "Hex (-30% speed & -20% damage on target for 10s)", "passive": "Curse Affinity (Curse lasts 20% less)"},
	{"id": "herbalist", "name": "Herbalist", "role_name": "Queen (Medic & Support)",       "role": Constants.Role.QUEEN,     "active": "Brew (Craft potion with 2 herbs instead of 3)",   "passive": "Mend (Base regen +2 HP/s within 5 tiles)"},
	# SOLDIER A ROLES
	{"id": "guardian",  "name": "Guardian",  "role_name": "Soldier A (Frontline Tank)",    "role": Constants.Role.SOLDIER_A, "active": "Shield Wall (Block 60% incoming melee damage)",    "passive": "Taunt (Forces target enemy to attack Guardian)"},
	{"id": "berserker", "name": "Berserker", "role_name": "Soldier A (Damage Dealer)",    "role": Constants.Role.SOLDIER_A, "active": "Frenzy (6s double attack speed)",                 "passive": "Bloodlust (+5% damage per kill)"},
	{"id": "sapper",    "name": "Sapper",    "role_name": "Soldier A (Siege & Demolition)","role": Constants.Role.SOLDIER_A, "active": "Demolish (Destroys enemy structure in 3s)",       "passive": "Sapper (+50% damage to buildings)"},
	# SOLDIER B ROLES
	{"id": "scout",     "name": "Scout",     "role_name": "Soldier B (Recon & Speed)",     "role": Constants.Role.SOLDIER_B, "active": "Flare (Reveal enemies within 20 tiles on map)",    "passive": "Stealth (Invisible on enemy minimap)"},
	{"id": "archer",    "name": "Archer",    "role_name": "Soldier B (Ranged Sniper)",     "role": Constants.Role.SOLDIER_B, "active": "Volley (3-arrow spread shot)",                   "passive": "Eagle Eye (+50% damage at long range)"},
	{"id": "builder",   "name": "Builder",   "role_name": "Soldier B (Rapid Architect)",   "role": Constants.Role.SOLDIER_B, "active": "Rapid Build (3x build speed for 10s)",            "passive": "Architect (-50% blueprint costs)"}
]

func _ready() -> void:
	UITheme.apply_rpg_theme(self)
	_setup_3d_preview_viewport()
	_populate_archetype_list()
	select_archetype("warlord")
	
	if back_button:
		back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn"))
	if select_play_btn:
		select_play_btn.pressed.connect(func():
			GameManager.selected_archetype_id = _selected_id
			get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
		)

func _setup_3d_preview_viewport() -> void:
	if preview_viewport:
		_preview_node = Node3D.new()
		preview_viewport.add_child(_preview_node)
		
		var cam := Camera3D.new()
		cam.position = Vector3(0, 1.5, 3.5)
		cam.look_at(Vector3(0, 1.3, 0))
		_preview_node.add_child(cam)
		
		var light := DirectionalLight3D.new()
		light.position = Vector3(5, 10, 5)
		light.light_color = Color(1.0, 0.9, 0.75)
		_preview_node.add_child(light)

func _populate_archetype_list() -> void:
	if not archetype_grid:
		return
		
	for arch in ALL_ARCHETYPES:
		var btn := Button.new()
		btn.text = arch.name + " (" + arch.role_name.split(" ")[0] + ")"
		btn.custom_minimum_size = Vector2(0, 36)
		var arch_id = arch.id
		btn.pressed.connect(func(): select_archetype(arch_id))
		archetype_grid.add_child(btn)

func select_archetype(id: String) -> void:
	_selected_id = id
	var arch_data = null
	for arch in ALL_ARCHETYPES:
		if arch.id == id:
			arch_data = arch
			break
			
	if not arch_data:
		return
		
	archetype_name_label.text = arch_data.name.to_upper()
	role_label.text = "Role: " + arch_data.role_name
	active_ability_label.text = "Active: " + arch_data.active
	passive_ability_label.text = "Passive: " + arch_data.passive
	
	# Update 3D character model preview with exact archetype model!
	if _preview_character:
		_preview_character.queue_free()
		
	_preview_character = CharacterFactory.create_character_by_archetype(id)
	_preview_node.add_child(_preview_character)

func _process(delta: float) -> void:
	if _preview_character:
		_preview_character.rotation.y += delta * 0.6 # Showcase 3D rotation
