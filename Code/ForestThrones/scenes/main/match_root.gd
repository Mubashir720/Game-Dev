extends Node3D

## ═══════════════════════════════════════════════════════════════════════════════
##  MATCH ROOT — boots one Battle Siege match.
##
##  Replaces the old inline script inside main.tscn, which spawned exactly one
##  player, four hard-coded structures at fixed coordinates and a single wolf.
##  That was a sandbox, not the game in the design document.
##
##  Order matters here:
##    1. Generate the world (time-sliced, so the loading screen keeps animating)
##    2. Spawn 8 squads of 4 at the 8 drop zones, distribute Traitor Tokens
##    3. Seed wild beasts, including the centre patrol that keeps early squads
##       off the Cursed Throne (GDD §3)
##    4. Hand the camera and HUD their targets, then start the match clock
## ═══════════════════════════════════════════════════════════════════════════════

const MatchDirector = preload("res://scenes/ai/match_director.gd")
const BeastFactory = preload("res://scenes/beasts/beast_factory.gd")
const ZoneShrinkScript = preload("res://scenes/zone_shrink/zone_shrink.gd")
const MomentsEngineScript = preload("res://scenes/moments/moments_engine.gd")
const ForestCurseScript = preload("res://scenes/curse/forest_curse.gd")

signal loading_progress(fraction: float, stage: String)
signal match_started()

@export var spawn_full_roster: bool = true
@export var wild_beast_count: int = 14
@export var centre_patrol_count: int = 4

@onready var camera: Camera3D = $IsometricCamera
@onready var world: Node3D = $World

var director: MatchDirector = null
var report := {}


func _ready() -> void:
	GameManager.game_state = Constants.GameState.LOADING
	world.auto_generate = false
	call_deferred("_boot")


func _boot() -> void:
	var t0 := Time.get_ticks_msec()

	world.generation_progress.connect(func(f: float, s: String):
		loading_progress.emit(f * 0.80, s))
	await world.generate_streamed()

	loading_progress.emit(0.84, "Deploying squads")
	await get_tree().process_frame

	director = MatchDirector.new()
	director.name = "MatchDirector"
	director.spawn_full_roster = spawn_full_roster
	add_child(director)
	director.setup(world, GameManager.selected_archetype_id)

	# Give the player's own actor its world references.
	if director.player_actor:
		director.player_actor.world = world
		director.player_actor.director = director
		director.player_actor.squad_brain = director.player_squad

	loading_progress.emit(0.90, "Waking the forest")
	await get_tree().process_frame
	_spawn_wildlife()

	loading_progress.emit(0.96, "Raising camps")
	await get_tree().process_frame
	_seed_squad_camps()

	_attach_systems()
	_attach_camera()
	_attach_hud()
	_attach_post_match()

	report = {
		"boot_ms": Time.get_ticks_msec() - t0,
		"world": world.build_report,
		"actors": director.stats,
	}
	print("[Forest Thrones] match booted: ", report)

	loading_progress.emit(1.0, "Ready")
	GameManager.start_match()
	match_started.emit()


## Wild beasts, plus the centre patrol from GDD §3 that makes building on the
## Cursed Throne in the first ten minutes a bad idea.
func _spawn_wildlife() -> void:
	var half: float = world.map_half_extent()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	var types := ["wolf", "boar", "stag", "raven"]
	for i in range(wild_beast_count):
		var p := Vector3(rng.randf_range(-half * 0.85, half * 0.85), 0.0,
						 rng.randf_range(-half * 0.85, half * 0.85))
		_add_beast(types[i % types.size()], world.on_ground(p, 0.1))

	for j in range(centre_patrol_count):
		var a := (float(j) / float(centre_patrol_count)) * TAU
		var cp := Vector3(cos(a) * 9.0, 0.0, sin(a) * 9.0)
		var beast := _add_beast("wolf", world.on_ground(cp, 0.1))
		if beast:
			beast.set_meta("centre_patrol", true)


func _add_beast(type: String, pos: Vector3) -> Node3D:
	var beast := BeastFactory.build_beast(type, false)
	if beast == null:
		return null
	beast.position = pos
	world.add_child(beast)
	return beast


## Every squad starts with its Hut already standing. GDD §6 makes the Hut the
## respawn anchor, and dropping eight squads into a match with no respawn point
## turns the first thirty seconds into a coin flip.
func _seed_squad_camps() -> void:
	for brain in director.squads:
		brain.place_structure("hut", world.on_ground(brain.base_position))
		brain.build_index = 1


func _attach_camera() -> void:
	if camera == null or director.player_actor == null:
		return
	camera.target_node = director.player_actor
	if camera.has_method("snap_to_target"):
		camera.snap_to_target()


## Live match systems that already had implementations but were never
## instantiated by anything, so they simply never ran:
##
##   ZoneShrink    — the closing border (GDD §12). Also rewritten; the old file
##                   measured the safe zone from the wrong map coordinate and
##                   only looked for a node named "Player".
##   MomentsEngine — listens for betrayals, escapes, beast sacrifices and
##                   emits Legendary Moments. The HUD event feed already
##                   subscribes to them; there was just never a publisher.
##   ForestCurse   — stacking curse durations on execution (GDD §11 System 3).
func _attach_systems() -> void:
	var zone = ZoneShrinkScript.new()
	zone.name = "ZoneShrink"
	add_child(zone)
	zone.setup(director, world)

	var moments = MomentsEngineScript.new()
	moments.name = "MomentsEngine"
	add_child(moments)

	var curse = ForestCurseScript.new()
	curse.name = "ForestCurse"
	add_child(curse)


## The post-match summary lives with the match, not the menu, so it can read the
## final state of every squad the moment the match ends.
func _attach_post_match() -> void:
	var packed: PackedScene = load("res://scenes/hud/post_match_summary.tscn")
	if packed == null:
		return
	var summary := packed.instantiate()
	add_child(summary)
	director.match_over.connect(func(winner):
		if summary.has_method("show_result"):
			summary.show_result(director, winner))


func _attach_hud() -> void:
	var hud := find_child("GameHUD", true, false)
	if hud and hud.has_method("bind_match"):
		hud.bind_match(director, world)
	var minimap := find_child("Minimap", true, false)
	if minimap and minimap.has_method("bind_match"):
		minimap.bind_match(director, world)
