extends Node3D

## ═══════════════════════════════════════════════════════════════════════════════
##  DAY / NIGHT CONTROLLER — sun arc, sky, fog and ambient light over the match.
##
##  GDD §12: 8 minutes of day, 4 minutes of night, cycling through the 25-minute
##  match. Night is a real tactical state, not a tint — visibility drops, fog
##  thickens, and firelight becomes worth building for.
##
##  BUG FIXED: `world_env` used to be looked up as `$WorldEnvironment`, but in
##  main.tscn the WorldEnvironment is a SIBLING of this node, not a child. The
##  lookup silently returned null, so sky colour, fog colour and fog density
##  never changed for the entire match — the whole day/night atmosphere was
##  dead code. It now resolves the node properly and warns if it can't.
## ═══════════════════════════════════════════════════════════════════════════════

@onready var sun_light: DirectionalLight3D = $SunLight

var world_env: WorldEnvironment = null

@export var dawn_sky_color := Color(0.72, 0.55, 0.48)
@export var day_sky_color := Color(0.52, 0.66, 0.72)
@export var dusk_sky_color := Color(0.58, 0.34, 0.26)
@export var night_sky_color := Color(0.055, 0.075, 0.125)

@export var dawn_sun_color := Color(1.0, 0.84, 0.62)
@export var day_sun_color := Color(1.0, 0.96, 0.88)
@export var dusk_sun_color := Color(1.0, 0.58, 0.34)
@export var night_moon_color := Color(0.46, 0.58, 0.82)

## Depth-fog START distance per phase, in world units. The environment uses
## DEPTH fog, not exponential, so this is "how far you can see clearly" — night
## pulls it in close, which is exactly what makes a Fire Pit, a torch or a
## Watchtower worth the wood after dark. fog_depth_end stays fixed just inside
## the camera's far plane so the draw-distance cut is never visible.
@export var fog_begin_day := 52.0
@export var fog_begin_dawn := 34.0
@export var fog_begin_dusk := 30.0
@export var fog_begin_night := 16.0

@export var ambient_day := 0.55
@export var ambient_night := 0.20

var _last_phase: int = -1


func _ready() -> void:
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	world_env = _find_world_environment()
	if world_env == null:
		push_warning("DayNightController: no WorldEnvironment found — sky and fog will not animate.")
	if sun_light:
		sun_light.shadow_enabled = true
		sun_light.shadow_bias = 0.04
		sun_light.shadow_normal_bias = 1.4
		sun_light.shadow_blur = 1.2
		sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		# Shadows only need to cover what the isometric camera can see. A long
		# shadow distance spreads the same texture over a huge area and makes
		# every shadow soft and wrong.
		sun_light.directional_shadow_max_distance = 60.0
		sun_light.directional_shadow_fade_start = 0.85


func _process(_delta: float) -> void:
	var t: float = GameManager.current_day_time

	# Sun arc. Keep it away from grazing angles at the horizon so the terrain
	# never goes fully black at the dawn/dusk boundaries.
	var elevation: float = deg_to_rad(lerp(18.0, 74.0, sin(clamp(t, 0.0, 1.0) * PI)))
	sun_light.rotation.x = -elevation
	sun_light.rotation.y = deg_to_rad(lerp(-40.0, 60.0, t))

	var sun_color := day_sun_color
	var sky_color := day_sky_color
	var energy := 1.08
	var fog_begin := fog_begin_day
	var ambient := ambient_day

	if t < 0.10:                       # DAWN
		var k: float = t / 0.10
		sun_color = night_moon_color.lerp(dawn_sun_color, k)
		sky_color = night_sky_color.lerp(dawn_sky_color, k)
		energy = lerp(0.26, 0.85, k)
		fog_begin = lerp(fog_begin_night, fog_begin_dawn, k)
		ambient = lerp(ambient_night, ambient_day * 0.8, k)
	elif t < 0.60:                     # DAY
		var k2: float = min((t - 0.10) / 0.25, 1.0)
		sun_color = dawn_sun_color.lerp(day_sun_color, k2)
		sky_color = dawn_sky_color.lerp(day_sky_color, k2)
		energy = lerp(0.85, 1.08, k2)
		fog_begin = lerp(fog_begin_dawn, fog_begin_day, k2)
		ambient = ambient_day
	elif t < 0.70:                     # DUSK
		var k3: float = (t - 0.60) / 0.10
		sun_color = day_sun_color.lerp(dusk_sun_color, k3)
		sky_color = day_sky_color.lerp(dusk_sky_color, k3)
		energy = lerp(1.08, 0.55, k3)
		fog_begin = lerp(fog_begin_day, fog_begin_dusk, k3)
		ambient = lerp(ambient_day, ambient_night * 1.6, k3)
	else:                              # NIGHT
		var k4: float = min((t - 0.70) / 0.12, 1.0)
		sun_color = dusk_sun_color.lerp(night_moon_color, k4)
		sky_color = dusk_sky_color.lerp(night_sky_color, k4)
		energy = lerp(0.55, 0.26, k4)
		fog_begin = lerp(fog_begin_dusk, fog_begin_night, k4)
		ambient = lerp(ambient_night * 1.6, ambient_night, k4)

	sun_light.light_color = sun_color
	sun_light.light_energy = energy

	if world_env and world_env.environment:
		var env: Environment = world_env.environment
		env.background_color = sky_color
		env.fog_light_color = sky_color.lerp(Color(0.26, 0.36, 0.34), 0.40)
		env.fog_depth_begin = fog_begin
		env.ambient_light_energy = ambient
		env.ambient_light_color = sky_color.lerp(Color(0.70, 0.80, 0.95), 0.45)


## Returns the current 0..1 darkness factor — 0 at full noon, 1 at deep night.
## Gameplay systems (vision radius, Scout stealth, beast aggro) can read this.
func darkness() -> float:
	var t: float = GameManager.current_day_time
	if t < 0.10:
		return 1.0 - (t / 0.10)
	elif t < 0.60:
		return 0.0
	elif t < 0.70:
		return (t - 0.60) / 0.10
	return 1.0


func _find_world_environment() -> WorldEnvironment:
	var direct := get_node_or_null("WorldEnvironment")
	if direct is WorldEnvironment:
		return direct
	var parent := get_parent()
	if parent:
		for c in parent.get_children():
			if c is WorldEnvironment:
				return c
	var found := get_tree().root.find_child("WorldEnvironment", true, false)
	return found if found is WorldEnvironment else null


func _on_day_phase_changed(phase: Constants.DayPhase) -> void:
	# Only react to an actual transition. This signal fires every frame from
	# GameManager, so the old version spammed the log with one print per frame.
	if int(phase) == _last_phase:
		return
	_last_phase = int(phase)
