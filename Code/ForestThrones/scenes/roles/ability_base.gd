extends Node
class_name AbilityBase

## ═══════════════════════════════════════════════════════════════════════════════
##  ABILITY BASE — one archetype ability, active + passive.
##
##  GDD §4 gives every archetype an ACTIVE (button, cooldown) and a PASSIVE
##  (always on). Twelve of these scripts already existed but nothing ever
##  instantiated them, so every archetype played identically — which removes the
##  entire reason the character-select screen exists.
##
##  AbilityController now attaches one of these to every Actor, player and bot
##  alike, so a Berserker actually snowballs and a Guardian actually taunts.
##
##  Subclasses override:
##    _execute_ability(caster)     — the button press
##    passive_tick(caster, delta)  — the always-on effect (optional)
##    on_kill(caster, victim)      — kill-triggered passives (optional)
## ═══════════════════════════════════════════════════════════════════════════════

@export var ability_name: String = "Ability"
@export var ability_blurb: String = ""
@export var cooldown: float = 30.0

var current_cooldown: float = 0.0
## Set by AbilityController when the ability is attached.
var caster: Node3D = null


func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = maxf(0.0, current_cooldown - delta)
	if caster != null and is_instance_valid(caster):
		passive_tick(caster, delta)


func is_ready() -> bool:
	return current_cooldown <= 0.0


## 0.0 = just used, 1.0 = ready. Drives the HUD button's cooldown ring.
func charge() -> float:
	if cooldown <= 0.0:
		return 1.0
	return clampf(1.0 - (current_cooldown / cooldown), 0.0, 1.0)


func activate(who: Node3D = null) -> bool:
	var target: Node3D = who if who != null else caster
	if target == null or not is_instance_valid(target):
		return false
	if not is_ready():
		return false
	current_cooldown = cooldown
	_execute_ability(target)
	return true


# ─── Overridable hooks ────────────────────────────────────────────────────────

func _execute_ability(_who: Node3D) -> void:
	pass


func passive_tick(_who: Node3D, _delta: float) -> void:
	pass


func on_kill(_who: Node3D, _victim: Node3D) -> void:
	pass


# ═══════════════════════════════════════════════════════════════════════════════
#  SHARED HELPERS — every ability needs to find people, so this lives once.
# ═══════════════════════════════════════════════════════════════════════════════

## Squadmates within `tiles` of the caster, excluding the caster.
func allies_within(who: Node3D, tiles: float) -> Array:
	var out: Array = []
	var d = _director(who)
	if d == null:
		return out
	var radius: float = tiles * Constants.TILE_SIZE.x
	for a in d.actors:
		if a == who or not is_instance_valid(a) or not a.is_alive():
			continue
		if a.squad_id != who.squad_id:
			continue
		if who.global_position.distance_to(a.global_position) <= radius:
			out.append(a)
	return out


## Hostiles within `tiles`, nearest first.
func enemies_within(who: Node3D, tiles: float) -> Array:
	var out: Array = []
	var d = _director(who)
	if d == null:
		return out
	var radius: float = tiles * Constants.TILE_SIZE.x
	for a in d.actors:
		if a == who or not is_instance_valid(a) or not a.is_alive():
			continue
		if a.squad_id == who.squad_id and not a.traitor_activated:
			continue
		if who.global_position.distance_to(a.global_position) <= radius:
			out.append(a)
	out.sort_custom(func(x, y):
		return who.global_position.distance_squared_to(x.global_position) \
			< who.global_position.distance_squared_to(y.global_position))
	return out


func _director(who: Node3D):
	if who == null:
		return null
	if "director" in who and who.director != null:
		return who.director
	var found := who.get_tree().root.find_child("MatchDirector", true, false)
	return found


## A short-lived expanding ring at the caster's feet. Every active ability wants
## one, and a shared implementation keeps them visually consistent.
func spawn_pulse(who: Node3D, tiles: float, tint: Color, duration: float = 0.9) -> void:
	if who == null or not is_instance_valid(who):
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.35, tiles * Constants.TILE_SIZE.x - 0.35)
	torus.outer_radius = tiles * Constants.TILE_SIZE.x
	torus.rings = 32
	torus.ring_segments = 5
	ring.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.42)
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.12
	ring.scale = Vector3(0.15, 1.0, 0.15)
	who.add_child(ring)

	var tw := who.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(ring.queue_free)
