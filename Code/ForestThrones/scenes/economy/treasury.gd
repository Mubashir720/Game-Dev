extends Node3D

@export var squad_id: String = "squad_1"
@export var max_hp: float = 30.0

var current_hp: float = 30.0
var balance: int = 0
var is_locked: bool = false
var lock_timer: float = 0.0
var is_split: bool = false

var visual_chest: MeshInstance3D = null

func _ready() -> void:
	current_hp = max_hp
	_build_3d_chest()

func _build_3d_chest() -> void:
	visual_chest = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 0.8, 0.8)
	visual_chest.mesh = box
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.32, 0.18)
	mat.roughness = 0.8
	visual_chest.material_override = mat
	visual_chest.position.y = 0.4
	visual_chest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(visual_chest)
	
	# Gold Trim
	var trim := MeshInstance3D.new()
	var tbox := BoxMesh.new()
	tbox.size = Vector3(1.25, 0.15, 0.85)
	trim.mesh = tbox
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.83, 0.69, 0.22)
	gmat.metallic = 0.85
	trim.material_override = gmat
	trim.position.y = 0.75
	add_child(trim)

func deposit(amount: int, player_name: String = "") -> void:
	if is_locked:
		print("Treasury is locked! Cannot deposit.")
		return
	balance += amount
	EventBus.coins_earned.emit(squad_id, amount, "deposit")

func withdraw(amount: int, player_name: String = "") -> bool:
	if is_locked:
		print("Treasury is locked! Cannot withdraw.")
		return false
		
	if balance >= amount:
		balance -= amount
		if amount > 20:
			EventBus.coins_spent.emit(squad_id, amount, "large_withdrawal_alarm")
			print("TREASURY ALARM: ", player_name, " withdrew ", amount, " coins!")
		else:
			EventBus.coins_spent.emit(squad_id, amount, "withdrawal")
		return true
	return false

func lock_treasury(duration: float = 180.0) -> void:
	is_locked = true
	lock_timer = duration
	EventBus.treasury_locked.emit(squad_id, duration)

func _process(delta: float) -> void:
	if is_locked:
		lock_timer -= delta
		if lock_timer <= 0.0:
			is_locked = false
			print("Treasury lock expired.")

func take_damage(damage: float) -> void:
	current_hp = max(0.0, current_hp - damage)
	if current_hp == 0.0:
		var coin_sys = get_tree().root.find_child("CoinSystem", true, false)
		if coin_sys:
			coin_sys.scatter_treasury(squad_id, global_position)
		queue_free()
