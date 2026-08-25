extends Node3D
class_name NpcVendor

## ═══════════════════════════════════════════════════════════════════════════════
##  NPC VENDOR  (GDD §7 — "NPC Vendor, always open")
##
##  A fixed neutral shop. Any player who walks up and interacts can spend their
##  SQUAD treasury on emergency supplies. This is the only always-available money
##  sink in a match, so a squad that is rich in coins but out of food/HP has
##  somewhere to convert one into the other.
##
##  The node owns the catalogue and the purchase rules; the HUD owns the panel of
##  buttons and calls buy() when one is pressed. Keeping the two apart means the
##  same vendor works for a bot economy later without any UI attached.
## ═══════════════════════════════════════════════════════════════════════════════

const INTERACT_RANGE := 4.0   # ~2 tiles; GDD gives the vendor a 3-tile neutral zone

## id · label · price(coins) · effect. Prices are GDD §7 "What Coins Are Spent On".
const CATALOG := [
	{"id": "food",    "label": "Food",           "price": 5,  "desc": "+20 Hunger"},
	{"id": "water",   "label": "Water Skin",     "price": 3,  "desc": "+40 Thirst"},
	{"id": "bandage", "label": "Bandage",        "price": 8,  "desc": "+25 HP"},
	{"id": "potion",  "label": "Healing Potion", "price": 15, "desc": "+50 HP"},
	{"id": "sword",   "label": "Sharpen Blade",  "price": 20, "desc": "+7 Damage"},
]

## The Black Market (GDD §7) is the same shop with a different, pricier stock and
## a price multiplier that scales with squad wealth. Set at spawn.
const BLACK_MARKET_CATALOG := [
	{"id": "metal",     "label": "Metal ×4",      "price": 15, "desc": "+4 Metal"},
	{"id": "adv_sword", "label": "Advanced Sword","price": 45, "desc": "+15 Damage"},
	{"id": "rare_bow",  "label": "Rare Bow",      "price": 40, "desc": "Ranged, 12-tile"},
	{"id": "potion",    "label": "Healing Potion","price": 15, "desc": "+50 HP"},
]

var custom_catalog: Array = []
var price_mult: float = 1.0   # Black Market scales prices by squad wealth (GDD §7)
var is_black_market: bool = false


func catalog() -> Array:
	var base: Array = custom_catalog if not custom_catalog.is_empty() else CATALOG
	if is_equal_approx(price_mult, 1.0):
		return base
	# Reprice a copy so the base constant is never mutated.
	var out: Array = []
	for e in base:
		var c: Dictionary = e.duplicate()
		c["price"] = int(round(float(e["price"]) * price_mult))
		out.append(c)
	return out


func in_range(who: Node3D) -> bool:
	return who != null and is_instance_valid(who) \
		and global_position.distance_to(who.global_position) <= INTERACT_RANGE


func item(id: String) -> Dictionary:
	for e in catalog():
		if e["id"] == id:
			return e
	return {}


## Attempt a purchase. Spends the buyer's SQUAD treasury (GDD §7: coins live in the
## shared treasury and any member can spend). Returns {"ok": bool, "reason": String}.
func buy(buyer: Node3D, id: String) -> Dictionary:
	if not in_range(buyer):
		return {"ok": false, "reason": "Too far from vendor"}
	var it := item(id)
	if it.is_empty():
		return {"ok": false, "reason": "No such item"}
	var brain = buyer.get("squad_brain")
	if brain == null:
		return {"ok": false, "reason": "No treasury"}
	var price: int = it["price"]
	if brain.treasury < price:
		return {"ok": false, "reason": "Not enough coins"}
	if not _apply(buyer, id):
		return {"ok": false, "reason": "No effect right now"}
	brain.spend_coins(price)
	return {"ok": true, "reason": it["label"]}


## Grant the item's effect to the buyer. Returns false if it would be wasted
## (e.g. a bandage at full HP), so the purchase is refused before charging.
func _apply(buyer: Node3D, id: String) -> bool:
	match id:
		"food":
			if buyer.hunger >= Constants.MAX_HUNGER:
				return false
			buyer.hunger = min(Constants.MAX_HUNGER, buyer.hunger + Constants.RAW_FOOD_HUNGER)
			buyer.play_anim("use")
		"water":
			if buyer.thirst >= Constants.MAX_THIRST:
				return false
			buyer.thirst = min(Constants.MAX_THIRST, buyer.thirst + Constants.WATER_THIRST)
			buyer.play_anim("use")
		"bandage":
			if buyer.hp >= buyer.max_hp():
				return false
			buyer.heal(Constants.BANDAGE_HEAL)
			buyer.play_anim("use")
		"potion":
			if buyer.hp >= buyer.max_hp():
				return false
			buyer.heal(Constants.POTION_HEAL)
			buyer.play_anim("use")
		"sword":
			# One permanent edge upgrade per life, so it isn't a coin-to-damage faucet.
			if buyer.get_meta("blade_sharpened", false):
				return false
			buyer.attack_damage += 7.0
			buyer.set_meta("blade_sharpened", true)
			buyer.play_anim("interact")
		"metal":
			buyer.add_resource(Constants.ResourceType.METAL, 4)
		"adv_sword":
			if buyer.get_meta("adv_sword", false):
				return false
			buyer.attack_damage += 15.0
			buyer.set_meta("adv_sword", true)
			buyer.play_anim("interact")
		"rare_bow":
			# The Advanced Bow (GDD §9): turns the buyer into a ranged fighter.
			if buyer.get_meta("rare_bow", false):
				return false
			buyer.is_ranged = true
			buyer.attack_range = Constants.ADVANCED_BOW_RANGE * Constants.TILE_SIZE.x
			buyer.attack_damage = Constants.ADVANCED_BOW_DAMAGE
			buyer.set_meta("rare_bow", true)
			buyer.play_anim("interact")
		_:
			return false
	return true
