extends StructureBase

func _ready() -> void:
	super._ready()
	structure_type = "cage_full"
	max_hp = 100.0
	current_hp = max_hp
	is_flammable = false # Metal reinforced
