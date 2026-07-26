extends StructureBase

func _ready() -> void:
	super._ready()
	structure_type = "wood_wall"
	max_hp = 50.0
	current_hp = max_hp
	is_flammable = true
