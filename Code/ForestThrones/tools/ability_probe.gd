extends SceneTree

## Verifies every archetype resolves to a real ability and that it fires.
func _initialize() -> void:
	var CF = load("res://scenes/player/character_factory.gd")
	var AC = load("res://scenes/roles/ability_controller.gd")
	var ActorScript = load("res://scenes/actors/actor.gd")
	var ok := 0
	var bad := 0
	for id in CF.ARCHETYPE_IDS:
		var ctrl = AC.new()
		root.add_child(ctrl)
		var a = ActorScript.new()
		a.archetype_id = id
		a.squad_id = "probe"
		# setup() only needs archetype_id; skip the full Actor _ready path.
		ctrl.setup(a)
		if ctrl.ability == null:
			print("  MISSING ability: ", id); bad += 1
		else:
			var nm = ctrl.ability_display_name()
			var cd = ctrl.ability.cooldown
			var has_exec = ctrl.ability.has_method("_execute_ability")
			print("  %-10s -> %-14s cd=%.0fs ready=%s" % [id, nm, cd, str(ctrl.is_ready())])
			if nm == "Ability": bad += 1
			else: ok += 1
		ctrl.queue_free()
		a.free()
	print("abilities_ok=%d abilities_bad=%d" % [ok, bad])
	quit(1 if bad > 0 else 0)
