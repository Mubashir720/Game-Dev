extends Node3D
## Arrow — 3D Ranged Projectile (GDD §9)

@export var speed: float = 16.0
@export var max_range: float = 12.0
@export var damage: float = 8.0

var direction := Vector3.FORWARD
var _distance_traveled: float = 0.0
var attacker: Node3D = null

func _ready() -> void:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 0.6
	mesh_inst.mesh = cyl
	mesh_inst.rotation.x = deg_to_rad(90.0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.75, 0.6)
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func setup(p_direction: Vector3, p_damage: float, p_attacker: Node3D = null) -> void:
	direction = p_direction.normalized()
	damage = p_damage
	attacker = p_attacker
	if direction.length_squared() > 0.001:
		look_at(global_position + direction)

func _process(delta: float) -> void:
	var move_dist = speed * delta
	global_position += direction * move_dist
	_distance_traveled += move_dist
	
	if _distance_traveled >= max_range:
		queue_free()
