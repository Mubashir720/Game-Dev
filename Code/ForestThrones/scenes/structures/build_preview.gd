extends Node3D
class_name BuildPreview

var active_data: StructureData = null
var is_valid_position := false
var grid_position := Vector2i.ZERO

var _ghost_mesh_inst: MeshInstance3D = null
var _ghost_material: StandardMaterial3D = null

func _ready() -> void:
	_ghost_mesh_inst = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 1.5, 2.0)
	_ghost_mesh_inst.mesh = box
	_ghost_mesh_inst.position.y = 0.75
	
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.albedo_color = Color(0.2, 0.9, 0.2, 0.5) # Green ghost preview
	_ghost_mesh_inst.material_override = _ghost_material
	add_child(_ghost_mesh_inst)

func _process(_delta: float) -> void:
	if not active_data:
		visible = false
		return
		
	visible = true
	
	# Snap to 3D Grid
	var camera = get_viewport().get_camera_3d()
	var world = get_tree().current_scene.find_child("World", true, false)
	if camera and world and world.has_method("world_to_grid") and world.has_method("grid_to_world"):
		# Raycast from mouse to 3D ground plane (Y = 0)
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_dir = camera.project_ray_normal(mouse_pos)
		
		if abs(ray_dir.y) > 0.001:
			var t = -ray_origin.y / ray_dir.y
			var ground_hit = ray_origin + ray_dir * t
			grid_position = world.world_to_grid(ground_hit)
			global_position = world.grid_to_world(grid_position)
			
			# Query build system to check if placement is valid
			var build_sys = get_node_or_null("/root/BuildSystem")
			if build_sys:
				is_valid_position = build_sys.can_build_at(grid_position, active_data)
				
	# Update ghost material color (Green = Valid placement, Red = Blocked)
	if _ghost_material:
		if is_valid_position:
			_ghost_material.albedo_color = Color(0.2, 0.9, 0.2, 0.5)
		else:
			_ghost_material.albedo_color = Color(0.9, 0.2, 0.2, 0.5)
