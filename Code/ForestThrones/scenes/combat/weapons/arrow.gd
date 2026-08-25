extends Node3D
class_name Arrow
## Arrow — a 3D ranged projectile (GDD §9). Lightly homes onto its target so a
## shot that was in range when loosed actually connects, then applies its damage
## once. Bots and the player use the same projectile.

@export var speed: float = 22.0
@export var max_range: float = 26.0

var direction := Vector3.FORWARD
var damage: float = 8.0
var attacker: Node3D = null
var target: Node3D = null
var _travelled: float = 0.0
var _spent := false


func _ready() -> void:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 0.55
	mesh_inst.mesh = cyl
	mesh_inst.rotation.x = deg_to_rad(90.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.78, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.6, 0.3)
	mat.emission_energy_multiplier = 0.4
	mesh_inst.material_override = mat
	add_child(mesh_inst)


func setup(p_direction: Vector3, p_damage: float, p_attacker: Node3D = null, p_target: Node3D = null) -> void:
	direction = p_direction.normalized() if p_direction.length_squared() > 0.001 else Vector3.FORWARD
	damage = p_damage
	attacker = p_attacker
	target = p_target


func _process(delta: float) -> void:
	if _spent:
		return
	# Gently curve toward a live target so the shot lands; a fixed direction still
	# flies straight if the target died or vanished.
	if target != null and is_instance_valid(target) and target.has_method("is_alive") and target.is_alive():
		var to_t := (target.global_position + Vector3(0, 1.0, 0)) - global_position
		if to_t.length() > 0.01:
			direction = direction.lerp(to_t.normalized(), 0.22).normalized()
	var step := speed * delta
	global_position += direction * step
	_travelled += step
	if direction.length_squared() > 0.001:
		look_at(global_position + direction)

	if target != null and is_instance_valid(target) and target.has_method("take_damage"):
		if global_position.distance_to(target.global_position + Vector3(0, 1.0, 0)) <= 1.2:
			_hit(target)
			return
	if _travelled >= max_range:
		queue_free()


func _hit(who) -> void:
	_spent = true
	var friendly: bool = attacker != null and "squad_id" in attacker and "squad_id" in who \
		and who.squad_id == attacker.squad_id
	who.take_damage(damage, attacker, friendly)
	queue_free()
