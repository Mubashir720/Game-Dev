extends StructureBase

# GDD §6: Mint doubles Queen coin rate from 1/20s to 1/10s
# Requires upgraded Hut to build. 12 Wood + 8 Stone + 4 Metal

func _ready() -> void:
	super._ready()
	structure_type = "mint"
	max_hp = 80.0
	current_hp = max_hp
	is_flammable = false  # Stone structure — fireproof
	add_to_group("mints")  # Queried by CoinSystem.has_active_mint()
	print("[Mint] Active for squad: ", squad_id, " — Queen coin rate doubled to 1 per 10s")
