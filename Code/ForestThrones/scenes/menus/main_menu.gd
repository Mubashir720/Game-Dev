extends Control

const CharacterFactory = preload("res://scenes/player/character_factory.gd")
const UITheme = preload("res://scenes/hud/ui_theme.gd")

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var play_button: Button = $MarginContainer/VBoxContainer/PlayButton
@onready var archetype_button: Button = $MarginContainer/VBoxContainer/ArchetypeButton
@onready var settings_button: Button = $MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/QuitButton
@onready var preview_viewport: SubViewport = $PreviewContainer/SubViewport

var _preview_character: Node3D = null

func _ready() -> void:
	UITheme.apply_rpg_theme(self)
	
	if subtitle_label:
		subtitle_label.text = "Selected Archetype: " + GameManager.selected_archetype_id.capitalize()
	
	# Spawn rotating 3D preview model for the selected archetype!
	if preview_viewport:
		var scene_3d := Node3D.new()
		preview_viewport.add_child(scene_3d)
		
		_preview_character = CharacterFactory.create_character_by_archetype(GameManager.selected_archetype_id)
		scene_3d.add_child(_preview_character)
		
		var cam := Camera3D.new()
		cam.position = Vector3(0, 1.5, 3.5)
		cam.look_at(Vector3(0, 1.3, 0))
		scene_3d.add_child(cam)
		
		var light := DirectionalLight3D.new()
		light.position = Vector3(5, 10, 5)
		light.light_color = Color(1.0, 0.9, 0.75)
		scene_3d.add_child(light)

func _process(delta: float) -> void:
	if _preview_character:
		_preview_character.rotation.y += delta * 0.5 # Slow 3D showcase rotation

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_archetype_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/archetype_select.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
