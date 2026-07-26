extends StructureBase

var is_triggered: bool = false

func _ready() -> void:
	super._ready()
	structure_type = "bear_trap"
	max_hp = 20.0
	current_hp = max_hp
	is_flammable = false

func _on_body_entered(body: Node3D) -> void:
	if is_triggered or current_state != StructureState.BUILT:
		return
	if body.has_method("take_damage"):
		is_triggered = true
		# GDD §9: 20 damage + 5s freeze
		body.take_damage(Constants.BEAR_TRAP_DAMAGE)
		print("Bear Trap triggered on ", body.name)
		queue_free()
