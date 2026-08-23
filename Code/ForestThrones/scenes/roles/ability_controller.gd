extends Node
class_name AbilityController

## ═══════════════════════════════════════════════════════════════════════════════
##  ABILITY CONTROLLER — attaches the right ability to an Actor and runs it.
##
##  This is the missing link that made twelve archetype scripts dead code. They
##  all existed, correctly named, with the right constants — and nothing ever
##  instantiated one, so every archetype in the game played exactly the same.
##
##  One of these rides on every Actor, player and bot alike. It resolves
##  archetype_id to an ability script, keeps the cooldown ticking, exposes the
##  charge fraction for the HUD's cooldown ring, and gives bots a simple,
##  role-appropriate rule for when to press it.
## ═══════════════════════════════════════════════════════════════════════════════

const ABILITY_SCRIPTS := {
	"warlord":   "res://scenes/roles/archetypes/warlord.gd",
	"regent":    "res://scenes/roles/archetypes/regent.gd",
	"beastlord": "res://scenes/roles/archetypes/beastlord.gd",
	"engineer":  "res://scenes/roles/archetypes/engineer.gd",
	"witch":     "res://scenes/roles/archetypes/witch.gd",
	"herbalist": "res://scenes/roles/archetypes/herbalist.gd",
	"guardian":  "res://scenes/roles/archetypes/guardian.gd",
	"berserker": "res://scenes/roles/archetypes/berserker.gd",
	"sapper":    "res://scenes/roles/archetypes/sapper.gd",
	"scout":     "res://scenes/roles/archetypes/scout.gd",
	"archer":    "res://scenes/roles/archetypes/archer.gd",
	"builder":   "res://scenes/roles/archetypes/builder.gd",
}

signal ability_used(name: String)

var ability: AbilityBase = null
var owner_actor: Node3D = null

## Bots only consider pressing the button this often, so 31 of them don't all
## evaluate every frame.
const BOT_CHECK_INTERVAL := 1.1
var _bot_timer := 0.0


func setup(actor: Node3D) -> void:
	owner_actor = actor
	var path: String = ABILITY_SCRIPTS.get(String(actor.archetype_id).to_lower(), "")
	if path == "":
		return
	var script: GDScript = load(path)
	if script == null:
		push_warning("AbilityController: missing ability script for '%s'" % actor.archetype_id)
		return
	ability = script.new()
	ability.caster = actor
	ability.name = "Ability"
	add_child(ability)


func ability_display_name() -> String:
	return ability.ability_name if ability != null else "Ability"


func ability_blurb() -> String:
	return ability.ability_blurb if ability != null else ""


func charge() -> float:
	return ability.charge() if ability != null else 1.0


func is_ready() -> bool:
	return ability != null and ability.is_ready()


func use() -> bool:
	if ability == null or owner_actor == null:
		return false
	if not owner_actor.is_alive() or owner_actor.is_downed():
		return false
	if ability.activate(owner_actor):
		ability_used.emit(ability.ability_name)
		return true
	return false


## Forwarded by Actor so kill-triggered passives (Bloodlust) can fire.
func notify_kill(victim: Node3D) -> void:
	if ability != null and owner_actor != null:
		ability.on_kill(owner_actor, victim)


func _process(delta: float) -> void:
	if owner_actor == null or not is_instance_valid(owner_actor):
		return
	if not owner_actor.is_bot:
		return
	_bot_timer -= delta
	if _bot_timer > 0.0:
		return
	_bot_timer = BOT_CHECK_INTERVAL
	_bot_consider()


## When a bot should press its button. Deliberately simple and role-shaped:
## fighters use it in a fight, support uses it when the squad is hurt, builders
## use it when there is something to build.
func _bot_consider() -> void:
	if ability == null or not ability.is_ready():
		return
	if not owner_actor.is_alive() or owner_actor.is_downed():
		return

	var id: String = String(owner_actor.archetype_id).to_lower()
	match id:
		"builder", "engineer":
			var brain = owner_actor.get("squad_brain") if "squad_brain" in owner_actor else null
			if brain != null and brain.wants_builder():
				use()
		"herbalist":
			if owner_actor.hp < owner_actor.max_hp() * 0.6:
				use()
		"regent":
			# Fire it on cooldown — it is pure economy, there is no bad moment.
			use()
		"beastlord", "scout":
			use()
		_:
			# Combat abilities: only when something is actually in range.
			if not ability.enemies_within(owner_actor, 10.0).is_empty():
				use()
