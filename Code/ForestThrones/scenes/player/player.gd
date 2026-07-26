extends CharacterBody3D

const CharacterFactory = preload("res://scenes/player/character_factory.gd")

@export var role: Constants.Role = Constants.Role.KING
@export var speed: float = 6.0

var hp: float = Constants.MAX_HP
var hunger: float = Constants.MAX_HUNGER
var thirst: float = Constants.MAX_THIRST

# Inventory (GDD §5 Resources)
var inventory: Dictionary = {
	Constants.ResourceType.WOOD: 0,
	Constants.ResourceType.STONE: 0,
	Constants.ResourceType.FOOD: 0,
	Constants.ResourceType.WATER: 0,
	Constants.ResourceType.METAL: 0,
	Constants.ResourceType.HERBS: 0,
}
var max_carry: int = 20 # GDD §4: Regent Stockpile gives +50%

# HP State (GDD §9)
enum HPState { HEALTHY, WOUNDED, CRITICAL, DOWNED }
var hp_state: HPState = HPState.HEALTHY
var _downed_bleed_timer: float = 0.0

# Walk animation references
var character_visual: Node3D = null
var _walk_t: float = 0.0

func _ready() -> void:
	# Layer 1 = World Environment, Props, Structures, Buildings
	# Layer 2 = Entities (Player / NPCs / Beasts)
	collision_layer = 1 | 2
	collision_mask = 1 | 2 | 4 | 8 | 16
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 0.35

	var archetype_id = GameManager.selected_archetype_id if GameManager.selected_archetype_id != "" else "warlord"
	character_visual = CharacterFactory.create_character_by_archetype(archetype_id)
	add_child(character_visual)

func _physics_process(delta: float) -> void:
	if hp_state == HPState.DOWNED:
		_process_downed(delta)
		return

	# GDD §8: Stat decay
	hunger = max(0.0, hunger - Constants.HUNGER_DECAY_RATE * delta)
	thirst = max(0.0, thirst - Constants.THIRST_DECAY_RATE * delta)
	if hunger == 0.0:
		hp = max(0.0, hp - Constants.HUNGER_ZERO_HP_DRAIN * delta)
	if thirst == 0.0:
		hp = max(0.0, hp - Constants.THIRST_ZERO_HP_DRAIN * delta)

	# Movement speed modified by HP state (GDD §9)
	var move_speed := speed
	if hp_state == HPState.WOUNDED:
		move_speed *= 0.80   # −20% speed
	elif hp_state == HPState.CRITICAL:
		move_speed *= 0.60   # −40% speed

	# Water Wading Speed Modifier (bypassed when walking on bridges at y >= 0.15)
	if global_position.y < -0.15:
		move_speed *= 0.60   # −40% speed penalty when wading in deep river/pond water!

	# Apply gravity for smooth terrain slope alignment
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	else:
		velocity.y = -0.10

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	var is_moving := direction.length_squared() > 0.01

	if is_moving:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		var target_angle := atan2(direction.x, direction.z)
		if character_visual:
			character_visual.rotation.y = lerp_angle(character_visual.rotation.y, target_angle, 15.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	# Solid physics collision movement
	move_and_slide()
	_animate_walk(is_moving, delta)

func _process_downed(delta: float) -> void:
	_downed_bleed_timer += delta
	if _downed_bleed_timer >= 3.0:
		_downed_bleed_timer = 0.0
		hp = max(0.0, hp - 1.0)
		if hp <= 0.0:
			EventBus.player_killed.emit(self, null)

# ─── Public API ────────────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	hp = max(0.0, hp - amount)
	_update_hp_state()

func set_hp_state(state_name: String) -> void:
	match state_name:
		"wounded":  hp_state = HPState.WOUNDED
		"critical": hp_state = HPState.CRITICAL
		"healthy":  hp_state = HPState.HEALTHY

func enter_downed_state() -> void:
	hp_state = HPState.DOWNED
	hp = 0.0
	_downed_bleed_timer = 0.0
	velocity = Vector3.ZERO

func _update_hp_state() -> void:
	if hp <= 0.0:
		enter_downed_state()
	elif hp <= Constants.CRITICAL_HP_THRESHOLD:
		hp_state = HPState.CRITICAL
	elif hp <= Constants.WOUNDED_HP_THRESHOLD:
		hp_state = HPState.WOUNDED
	else:
		hp_state = HPState.HEALTHY

func add_resource(resource_type: Constants.ResourceType, amount: int) -> void:
	var current: int = inventory.get(resource_type, 0)
	inventory[resource_type] = min(current + amount, max_carry)

func spend_resource(resource_type: Constants.ResourceType, amount: int) -> bool:
	var current: int = inventory.get(resource_type, 0)
	if current >= amount:
		inventory[resource_type] = current - amount
		return true
	return false

func get_resource_count(resource_type: Constants.ResourceType) -> int:
	return inventory.get(resource_type, 0)

# ─── Archetype Animation ───────────────────────────────────────────────────────

const CharacterAnimator = preload("res://scenes/player/character_animator.gd")
var _animator = CharacterAnimator.new()

func _animate_walk(is_moving: bool, delta: float) -> void:
	if character_visual and _animator:
		var archetype_id = GameManager.selected_archetype_id if GameManager.selected_archetype_id != "" else "warlord"
		_animator.animate_character(character_visual, archetype_id, is_moving, delta)
