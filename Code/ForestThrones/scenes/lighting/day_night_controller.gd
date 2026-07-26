extends Node3D

# ═══════════════════════════════════════════════════════════════════════════════
#  DAY NIGHT CONTROLLER — Atmospheric Lighting & Dynamic Sun/Moon Transitions
# ═══════════════════════════════════════════════════════════════════════════════

@onready var sun_light: DirectionalLight3D = $SunLight
@onready var world_env: WorldEnvironment = $WorldEnvironment

@export var dawn_sky_color := Color(0.95, 0.72, 0.55)
@export var day_sky_color := Color(0.62, 0.72, 0.85)
@export var dusk_sky_color := Color(0.85, 0.45, 0.25)
@export var night_sky_color := Color(0.08, 0.11, 0.18)

@export var dawn_sun_color := Color(1.0, 0.88, 0.69)
@export var day_sun_color := Color(1.0, 0.95, 0.85)
@export var dusk_sun_color := Color(1.0, 0.60, 0.35)
@export var night_moon_color := Color(0.40, 0.53, 0.73)

func _ready() -> void:
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	if sun_light:
		sun_light.shadow_enabled = true
		sun_light.shadow_bias = 0.03
		sun_light.shadow_blur = 2.0

func _process(_delta: float) -> void:
	var time_factor = GameManager.current_day_time

	# Rotate sun 360 degrees over 24h simulation
	var angle = time_factor * TAU - (PI * 0.5)
	sun_light.rotation.x = angle
	sun_light.rotation.y = deg_to_rad(30.0)

	var sun_color := day_sun_color
	var sky_color := day_sky_color
	var energy := 1.25
	var fog_density := 0.006

	if time_factor < 0.10: # DAWN
		var t = time_factor / 0.10
		sun_color = night_moon_color.lerp(dawn_sun_color, t)
		sky_color = night_sky_color.lerp(dawn_sky_color, t)
		energy = lerp(0.35, 0.85, t)
		fog_density = lerp(0.015, 0.008, t)
	elif time_factor < 0.60: # DAY
		var t = (time_factor - 0.10) / 0.50
		sun_color = dawn_sun_color.lerp(day_sun_color, t)
		sky_color = dawn_sky_color.lerp(day_sky_color, t)
		energy = lerp(0.85, 1.25, t)
		fog_density = 0.006
	elif time_factor < 0.70: # DUSK
		var t = (time_factor - 0.60) / 0.10
		sun_color = day_sun_color.lerp(dusk_sun_color, t)
		sky_color = day_sky_color.lerp(dusk_sky_color, t)
		energy = lerp(1.25, 0.65, t)
		fog_density = lerp(0.006, 0.014, t)
	else: # NIGHT
		var t = (time_factor - 0.70) / 0.30
		sun_color = dusk_sun_color.lerp(night_moon_color, t)
		sky_color = dusk_sky_color.lerp(night_sky_color, t)
		energy = lerp(0.65, 0.35, t)
		fog_density = 0.022

	sun_light.light_color = sun_color
	sun_light.light_energy = energy

	if world_env and world_env.environment:
		var env = world_env.environment
		env.background_color = sky_color
		env.fog_light_color = sky_color
		env.fog_density = fog_density

func _on_day_phase_changed(phase: Constants.DayPhase) -> void:
	match phase:
		Constants.DayPhase.DAWN:  print("Day Phase: DAWN")
		Constants.DayPhase.DAY:   print("Day Phase: DAY")
		Constants.DayPhase.DUSK:  print("Day Phase: DUSK")
		Constants.DayPhase.NIGHT: print("Day Phase: NIGHT")
