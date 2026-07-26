extends StaticBody3D

# ═══════════════════════════════════════════════════════════════════════════════
#  RESOURCE NODE — Solid Physics Collision & Harvest Animations
# ═══════════════════════════════════════════════════════════════════════════════

const PropFactory = preload("res://scenes/world/prop_factory.gd")

@export var resource_type: Constants.ResourceType = Constants.ResourceType.WOOD
@export var amount := 3
@export var max_hits := 5
@export var respawn_time := 60.0

var current_hits := 0
enum NodeState { AVAILABLE, DEPLETED, RESPAWNING }
var state: NodeState = NodeState.AVAILABLE

var _visual: Node3D = null
var _respawn_timer: float = 0.0

func _ready() -> void:
	current_hits = max_hits
	collision_layer = 1
	collision_mask = 1
	add_to_group("resource_nodes")
	_build_3d_visual()

func _build_3d_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)

	var node_prop: Node3D = null

	match resource_type:
		Constants.ResourceType.WOOD:
			node_prop = PropFactory.build_tree("pine")
		Constants.ResourceType.STONE:
			node_prop = PropFactory.build_rock("boulder")
		Constants.ResourceType.FOOD:
			node_prop = PropFactory.build_berry_bush()
		Constants.ResourceType.METAL:
			node_prop = PropFactory.build_rock("ore_vein")
		Constants.ResourceType.HERBS:
			node_prop = PropFactory.build_herb_plant()
		_:
			node_prop = PropFactory.build_tree("pine")

	if node_prop:
		if node_prop is StaticBody3D:
			for child in node_prop.get_children():
				if child is CollisionShape3D:
					# Duplicate collision shape and attach DIRECTLY to self (StaticBody3D) so physics engine recognizes it!
					var col_dup = child.duplicate()
					add_child(col_dup)
				else:
					node_prop.remove_child(child)
					_visual.add_child(child)
			node_prop.queue_free()
		else:
			_visual.add_child(node_prop)
			var col := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.45; cyl.height = 1.8
			col.shape = cyl; col.position.y = 0.90
			add_child(col)

func _process(delta: float) -> void:
	if state == NodeState.RESPAWNING:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()

func try_harvest(player: Node3D) -> bool:
	if state != NodeState.AVAILABLE:
		return false
	current_hits -= 1
	_play_hit_effect()
	if current_hits <= 0:
		_deplete(player)
	return true

func _play_hit_effect() -> void:
	if not _visual:
		return
	var tween = create_tween().set_parallel(true)
	tween.tween_property(_visual, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
	tween.tween_property(_visual, "rotation:z", deg_to_rad(randf_range(-8.0, 8.0)), 0.06)

	var tween2 = create_tween().set_parallel(true)
	tween2.chain().tween_property(_visual, "scale", Vector3(1.0, 1.0, 1.0), 0.10)
	tween2.chain().tween_property(_visual, "rotation:z", 0.0, 0.10)

func _deplete(player: Node3D) -> void:
	state = NodeState.DEPLETED
	if player and player.has_method("add_resource"):
		player.add_resource(resource_type, amount)
	EventBus.resource_harvested.emit(resource_type, amount, global_position)

	var tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tween.tween_callback(func():
		_visual.visible = false
		state = NodeState.RESPAWNING
		_respawn_timer = respawn_time
	)

func _respawn() -> void:
	state = NodeState.AVAILABLE
	current_hits = max_hits
	_visual.visible = true
	_visual.scale = Vector3(0.05, 0.05, 0.05)
	var tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3(1.0, 1.0, 1.0), 0.35)
