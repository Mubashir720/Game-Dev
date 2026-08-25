extends Node
class_name TrustSystem

## ═══════════════════════════════════════════════════════════════════════════════
##  TRUST SYSTEM  (GDD §11 — the counter-play half of the Traitor pillar)
##
##  Every squad member carries a hidden Trust Score. It falls when they behave the
##  way a traitor tends to — wandering off alone, hoarding gathered resources
##  without depositing, lurking in enemy territory, or openly turning on the squad
##  once activated — and slowly recovers when they act like a teammate. The HUD
##  turns the score into a green / yellow / orange dot beside each name. It NEVER
##  goes red: the system hints, it never confirms (GDD §11).
##
##  Only the player's own squad is tracked — those are the only four dots on
##  screen — so this stays four cheap checks on a slow tick, not 32.
## ═══════════════════════════════════════════════════════════════════════════════

const TICK := 1.5          # seconds between evaluations
const ALONE_RADIUS := 18.0 # far from every squadmate = "wandering alone"
const HOARD_CARRY := 12     # carrying this much un-deposited reads as hoarding
const ENEMY_TERRITORY := 20.0

var director = null
var _timer := 0.0


func setup(match_director) -> void:
	director = match_director


func _process(delta: float) -> void:
	if director == null or director.player_squad == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	for m in director.player_squad.members:
		if is_instance_valid(m):
			_evaluate(m)


func _evaluate(m: Actor) -> void:
	var delta := 1.2   # baseline recovery toward trustworthy

	# Openly hostile once the token is active — trust collapses fast (but not to red).
	if m.traitor_activated:
		delta = -8.0
	else:
		if _is_alone(m):
			delta -= 3.0
		if m.has_method("total_carried") and m.total_carried() >= HOARD_CARRY:
			delta -= 2.2
		if _in_enemy_territory(m):
			delta -= 3.5

	# Never below 15 — the system hints, it never confirms a traitor (GDD §11).
	m.trust_score = clampf(m.trust_score + delta, 15.0, 100.0)


func _is_alone(m: Actor) -> bool:
	for other in director.player_squad.members:
		if other == m or not is_instance_valid(other):
			continue
		if m.global_position.distance_to(other.global_position) <= ALONE_RADIUS:
			return false
	return true


func _in_enemy_territory(m: Actor) -> bool:
	for s in director.squads:
		if s == director.player_squad:
			continue
		if m.global_position.distance_to(s.base_position) <= ENEMY_TERRITORY:
			return true
	return false
