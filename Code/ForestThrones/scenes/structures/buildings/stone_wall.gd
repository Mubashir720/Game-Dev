extends StructureBase

func _ready() -> void:
	super._ready()
	structure_type = "stone_wall"
	max_hp = 150.0
	current_hp = max_hp
	is_flammable = false
