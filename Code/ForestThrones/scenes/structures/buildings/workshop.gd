extends StructureBase

func _ready() -> void:
	super._ready()
	structure_type = "workshop"
	max_hp = 75.0
	current_hp = max_hp
	is_flammable = true
