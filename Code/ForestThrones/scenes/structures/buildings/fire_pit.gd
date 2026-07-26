extends StructureBase

var fire_light: OmniLight3D = null

func _ready() -> void:
	super._ready()
	structure_type = "fire_pit"
	max_hp = 30.0
	current_hp = max_hp
	is_flammable = false
	
	# Add 3D warmth fire light
	fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.55, 0.15)
	fire_light.light_energy = 2.5
	fire_light.omni_range = 6.0
	fire_light.position.y = 0.5
	add_child(fire_light)
