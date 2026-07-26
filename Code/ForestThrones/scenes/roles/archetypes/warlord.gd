extends AbilityBase

func _init() -> void:
	ability_name = "Rally Cry"
	cooldown = Constants.WARLORD_RALLY_COOLDOWN

func _execute_ability(caster: Node3D) -> void:
	print("Warlord activates Rally Cry!")
	# Spawn shockwave particle effect in 3D
	var shockwave := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = Constants.WARLORD_RALLY_RADIUS
	shockwave.mesh = torus
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.84, 0.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.84, 0.0)
	shockwave.material_override = mat
	
	caster.add_child(shockwave)
	
	# Tween expand & fade
	var tween = caster.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 1.0)
	tween.tween_callback(shockwave.queue_free)
