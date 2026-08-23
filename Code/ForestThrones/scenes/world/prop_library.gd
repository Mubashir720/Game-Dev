extends RefCounted
class_name PropLibrary

## ═══════════════════════════════════════════════════════════════════════════════
##  PROP LIBRARY — the bridge between hand-authored props and instanced rendering.
##
##  PropFactory stays the single place where a tree's look is designed. This file
##  bakes each of those designs into a shared mesh (several randomised variants
##  per type so a forest never looks cloned) and describes how each prop should
##  be scattered: which biome, how likely, how big, how much colour jitter, and
##  whether it blocks movement.
##
##  Adding a new prop = write the builder in PropFactory, add one row here.
## ═══════════════════════════════════════════════════════════════════════════════

const PropFactory = preload("res://scenes/world/prop_factory.gd")
const Baker = preload("res://scripts/render/prop_baker.gd")

## How many randomised bakes to make per prop type. Higher = more visual variety,
## costs one extra mesh each. 3 is plenty because we also randomise yaw, scale
## and per-instance tint at placement time.
## Each variant is a separate baked mesh, which means a separate MultiMesh and
## therefore a separate draw call per chunk. Two is the sweet spot: placement
## already randomises yaw, scale and tint, so a third mesh cost ~50% more draw
## calls for variation nobody could see at gameplay distance.
const VARIANTS := 2

## Visual layers — control draw distance & shadow cost independently.
enum Layer {
	CANOPY,     ## Trees, big rocks. Long draw distance, cast shadows.
	MIDGROUND,  ## Bushes, logs, stumps, ruins. Medium distance, cast shadows.
	DETAIL,     ## Ferns, mushrooms, reeds, skulls. Short distance, no shadows.
	GROUND,     ## Grass tufts, pebbles, flowers. Shortest distance, no shadows.
}

## Draw distances are sized to the ACTUAL camera, not to a guess. The match
## camera is orthographic at size 18 sitting ~21 units back on a 45 degree
## isometric angle, so its ground footprint is roughly 40 x 70 units. Rendering
## trees 260 units away was paying for scenery no player could ever see.
const LAYER_RANGE := {
	Layer.CANOPY: 62.0,
	Layer.MIDGROUND: 50.0,
	Layer.DETAIL: 38.0,
	Layer.GROUND: 30.0,
}

## Thinned far band — keeps a believable treeline on the horizon well past the
## full-density ring, for a fraction of the triangles.
const LAYER_FAR_RANGE := {
	Layer.CANOPY: 112.0,
	Layer.MIDGROUND: 0.0,
	Layer.DETAIL: 0.0,
	Layer.GROUND: 0.0,
}

const LAYER_FAR_FRACTION := {
	Layer.CANOPY: 0.30,
	Layer.MIDGROUND: 0.22,
	Layer.DETAIL: 0.0,
	Layer.GROUND: 0.0,
}

const LAYER_FADE := {
	Layer.CANOPY: 14.0,
	Layer.MIDGROUND: 11.0,
	Layer.DETAIL: 8.0,
	Layer.GROUND: 6.0,
}

const LAYER_SHADOWS := {
	Layer.CANOPY: true,
	Layer.MIDGROUND: true,
	Layer.DETAIL: false,
	Layer.GROUND: false,
}


## Every scatterable prop. `build` names the PropFactory call.
##   scale   — random uniform scale range
##   tint    — per-instance brightness jitter (1.0 = untouched); gives a forest
##             hundreds of green shades from one shared material, free.
##   solid   — keep the baked collision shapes (blocks players/beasts)
##   layer   — draw-distance/shadow class
static var _defs: Dictionary = {}


static func _build_defs() -> void:
	if not _defs.is_empty():
		return
	_defs = {
		# ── Canopy ────────────────────────────────────────────────────────────
		"pine":        {"build": func(): return PropFactory.build_tree("pine"),   "scale": [0.85, 1.35], "tint": [0.80, 1.15], "solid": true,  "layer": Layer.CANOPY, "style": "foliage"},
		"oak":         {"build": func(): return PropFactory.build_tree("oak"),    "scale": [0.85, 1.30], "tint": [0.82, 1.14], "solid": true,  "layer": Layer.CANOPY, "style": "foliage"},
		"birch":       {"build": func(): return PropFactory.build_tree("birch"),  "scale": [0.88, 1.25], "tint": [0.88, 1.12], "solid": true,  "layer": Layer.CANOPY, "style": "foliage"},
		"canopy":      {"build": func(): return PropFactory.build_tree("canopy"), "scale": [0.95, 1.45], "tint": [0.80, 1.12], "solid": true,  "layer": Layer.CANOPY, "style": "foliage"},
		"willow":      {"build": func(): return PropFactory.build_tree("willow"), "scale": [0.85, 1.25], "tint": [0.84, 1.10], "solid": true,  "layer": Layer.CANOPY, "style": "foliage"},
		"dead_tree":   {"build": func(): return PropFactory.build_tree("dead"),   "scale": [0.80, 1.20], "tint": [0.78, 1.10], "solid": true,  "layer": Layer.CANOPY, "style": "solid"},
		"boulder":     {"build": func(): return PropFactory.build_rock("boulder"),"scale": [0.75, 1.50], "tint": [0.80, 1.18], "solid": true,  "layer": Layer.CANOPY, "style": "solid"},
		"rock_cluster":{"build": func(): return PropFactory.build_rock("cluster"),"scale": [0.80, 1.35], "tint": [0.82, 1.16], "solid": true,  "layer": Layer.CANOPY, "style": "solid"},
		"ore_vein":    {"build": func(): return PropFactory.build_rock("ore_vein"),"scale": [0.85, 1.20],"tint": [0.92, 1.10], "solid": true,  "layer": Layer.CANOPY, "style": "solid"},

		# ── Midground ─────────────────────────────────────────────────────────
		"mossy_rock":  {"build": func(): return PropFactory.build_rock("mossy"),  "scale": [0.70, 1.30], "tint": [0.84, 1.16], "solid": true,  "layer": Layer.MIDGROUND, "style": "solid"},
		"fallen_log":  {"build": func(): return PropFactory.build_fallen_log(),   "scale": [0.85, 1.25], "tint": [0.82, 1.14], "solid": true,  "layer": Layer.MIDGROUND, "style": "solid"},
		"vine_stump":  {"build": func(): return PropFactory.build_vine_stump(),   "scale": [0.85, 1.20], "tint": [0.85, 1.12], "solid": true,  "layer": Layer.MIDGROUND, "style": "solid"},
		"dense_bush":  {"build": func(): return PropFactory.build_dense_bush(),   "scale": [0.80, 1.35], "tint": [0.78, 1.18], "solid": false, "layer": Layer.MIDGROUND, "style": "foliage"},
		"berry_bush":  {"build": func(): return PropFactory.build_berry_bush(),   "scale": [0.85, 1.20], "tint": [0.88, 1.12], "solid": false, "layer": Layer.MIDGROUND, "style": "foliage"},
		"hill_rocks":  {"build": func(): return PropFactory.build_hill_rock_pile(),"scale": [0.80, 1.30],"tint": [0.84, 1.14], "solid": true,  "layer": Layer.MIDGROUND, "style": "solid"},
		"vine_arch":   {"build": func(): return PropFactory.build_vine_archway(), "scale": [0.90, 1.15], "tint": [0.86, 1.10], "solid": false, "layer": Layer.MIDGROUND, "style": "foliage"},
		"cart":        {"build": func(): return PropFactory.build_abandoned_cart(),"scale": [0.90, 1.10],"tint": [0.90, 1.08], "solid": true,  "layer": Layer.MIDGROUND, "style": "solid"},

		# ── Detail ────────────────────────────────────────────────────────────
		"fern":        {"build": func(): return PropFactory.build_fern_cluster(),     "scale": [0.75, 1.35], "tint": [0.80, 1.18], "solid": false, "layer": Layer.DETAIL, "style": "reed"},
		"tall_grass":  {"build": func(): return PropFactory.build_tall_grass(),       "scale": [0.80, 1.40], "tint": [0.78, 1.20], "solid": false, "layer": Layer.DETAIL, "style": "reed"},
		"herb":        {"build": func(): return PropFactory.build_herb_plant(),       "scale": [0.85, 1.25], "tint": [0.85, 1.15], "solid": false, "layer": Layer.DETAIL, "style": "reed"},
		"mushrooms":   {"build": func(): return PropFactory.build_mushroom_cluster(), "scale": [0.80, 1.30], "tint": [0.85, 1.15], "solid": false, "layer": Layer.DETAIL, "style": "reed"},
		"reeds":       {"build": func(): return PropFactory.build_reed_cluster(),     "scale": [0.80, 1.30], "tint": [0.82, 1.16], "solid": false, "layer": Layer.DETAIL, "style": "reed"},
		"lily_pad":    {"build": func(): return PropFactory.build_lily_pad(),         "scale": [0.85, 1.25], "tint": [0.86, 1.12], "solid": false, "layer": Layer.DETAIL, "style": "grass"},
		"skull":       {"build": func(): return PropFactory.build_animal_skull(),     "scale": [0.85, 1.20], "tint": [0.92, 1.06], "solid": false, "layer": Layer.DETAIL, "style": "solid"},
		"bones":       {"build": func(): return PropFactory.build_bone_pile(),        "scale": [0.85, 1.20], "tint": [0.92, 1.06], "solid": false, "layer": Layer.DETAIL, "style": "solid"},
		"weapons":     {"build": func(): return PropFactory.build_broken_weapons(),   "scale": [0.90, 1.10], "tint": [0.90, 1.08], "solid": false, "layer": Layer.DETAIL, "style": "solid"},
		"banner":      {"build": func(): return PropFactory.build_fallen_banner(),    "scale": [0.90, 1.15], "tint": [0.88, 1.10], "solid": false, "layer": Layer.DETAIL, "style": "solid"},

		# ── Roadside set-dressing ─────────────────────────────────────────────
		"torch_post":  {"build": func(): return PropFactory.build_torch_post(),           "scale": [0.95, 1.10], "tint": [0.95, 1.05], "solid": true,  "layer": Layer.MIDGROUND, "style": "solid"},
		"lantern_post":{"build": func(): return PropFactory.build_hanging_lantern_post(), "scale": [0.95, 1.10], "tint": [0.95, 1.05], "solid": true,  "layer": Layer.MIDGROUND, "style": "solid"},
		"sign":        {"build": func(): return PropFactory.build_warning_sign(),         "scale": [0.90, 1.10], "tint": [0.92, 1.08], "solid": false, "layer": Layer.MIDGROUND, "style": "solid"},
		"trail_marker":{"build": func(): return PropFactory.build_trail_marker(),         "scale": [0.90, 1.10], "tint": [0.92, 1.08], "solid": false, "layer": Layer.DETAIL, "style": "solid"},

		# ── Ground cover ──────────────────────────────────────────────────────
		"grass":       {"build": func(): return PropFactory.build_grass_tuft(),  "scale": [0.70, 1.45], "tint": [0.72, 1.24], "solid": false, "layer": Layer.GROUND, "style": "grass"},
		"flowers":     {"build": func(): return PropFactory.build_flower_tuft(), "scale": [0.80, 1.25], "tint": [0.85, 1.15], "solid": false, "layer": Layer.GROUND, "style": "grass"},
		"dry_grass":   {"build": func(): return PropFactory.build_dry_grass(),   "scale": [0.75, 1.35], "tint": [0.80, 1.18], "solid": false, "layer": Layer.GROUND, "style": "grass"},
		"pebble":      {"build": func(): return PropFactory.build_pebble(),      "scale": [0.70, 1.50], "tint": [0.82, 1.16], "solid": false, "layer": Layer.GROUND, "style": "solid"},
	}


## Per-biome scatter tables: [prop_key, cumulative_weight]. Weights are relative.
const BIOME_PROPS := {
	Constants.ZoneType.DENSE_FOREST: [
		["pine", 26], ["oak", 18], ["birch", 12], ["canopy", 8],
		["dense_bush", 10], ["fern", 9], ["vine_stump", 5], ["fallen_log", 4],
		["mushrooms", 3], ["vine_arch", 2], ["mossy_rock", 3],
	],
	Constants.ZoneType.OPEN_CLEARING: [
		["birch", 16], ["oak", 14], ["tall_grass", 18], ["dense_bush", 12],
		["berry_bush", 10], ["mossy_rock", 8], ["boulder", 6], ["fern", 6],
		["weapons", 2], ["banner", 1], ["cart", 1],
	],
	Constants.ZoneType.ROCKY_HIGHLANDS: [
		["boulder", 26], ["rock_cluster", 20], ["ore_vein", 14], ["hill_rocks", 14],
		["mossy_rock", 10], ["skull", 6], ["dead_tree", 5], ["bones", 5],
	],
	Constants.ZoneType.SWAMP: [
		["willow", 20], ["dead_tree", 18], ["herb", 16], ["mushrooms", 14],
		["reeds", 12], ["bones", 8], ["dense_bush", 7], ["vine_stump", 5],
	],
	Constants.ZoneType.DROP_ZONE: [
		["pine", 20], ["birch", 16], ["dense_bush", 20], ["tall_grass", 24],
		["berry_bush", 12], ["mossy_rock", 8],
	],
}

## Base spawn chance per cell, per biome. Instanced rendering means we can
## afford a far denser, better-looking forest than the old node-per-prop path.
const BIOME_DENSITY := {
	Constants.ZoneType.DENSE_FOREST: 0.26,
	Constants.ZoneType.OPEN_CLEARING: 0.14,
	Constants.ZoneType.ROCKY_HIGHLANDS: 0.17,
	Constants.ZoneType.SWAMP: 0.20,
	Constants.ZoneType.DROP_ZONE: 0.07,
	Constants.ZoneType.RIVERBED: 0.0,
	Constants.ZoneType.CURSED_THRONE: 0.0,
}

## Riverbank-only detail (reeds / lilies / pebbles handled by the generator).
const RIVER_EDGE_PROPS := [["reeds", 55], ["lily_pad", 30], ["bones", 15]]

## Ground-cover mix per biome: [prop_key, cumulative weight] plus a per-cell
## chance. Rendered in the GROUND layer so it only draws in the near ring.
const GROUND_COVER := {
	Constants.ZoneType.DENSE_FOREST:   {"chance": 0.55, "mix": [["grass", 68], ["flowers", 8], ["pebble", 10], ["dry_grass", 14]]},
	Constants.ZoneType.OPEN_CLEARING:  {"chance": 0.72, "mix": [["grass", 62], ["flowers", 26], ["dry_grass", 8], ["pebble", 4]]},
	Constants.ZoneType.DROP_ZONE:      {"chance": 0.60, "mix": [["grass", 70], ["flowers", 18], ["pebble", 12]]},
	Constants.ZoneType.ROCKY_HIGHLANDS:{"chance": 0.34, "mix": [["pebble", 55], ["dry_grass", 35], ["grass", 10]]},
	Constants.ZoneType.SWAMP:          {"chance": 0.40, "mix": [["grass", 40], ["dry_grass", 42], ["pebble", 18]]},
	Constants.ZoneType.RIVERBED:       {"chance": 0.22, "mix": [["pebble", 80], ["dry_grass", 20]]},
	Constants.ZoneType.CURSED_THRONE:  {"chance": 0.0,  "mix": []},
}

static var _weight_cache: Dictionary = {}
static var _cover_weight_cache: Dictionary = {}


## Ground-cover chance for a biome cell.
static func cover_chance(zone: int) -> float:
	var e = GROUND_COVER.get(zone, null)
	return 0.0 if e == null else float(e.chance)


## Pick a ground-cover prop key for a biome. `roll` is 0..1.
static func pick_cover(zone: int, roll: float) -> String:
	var e = GROUND_COVER.get(zone, null)
	if e == null or e.mix.is_empty():
		return ""
	var total: int = _cover_weight_cache.get(zone, -1)
	if total < 0:
		total = 0
		for row in e.mix:
			total += int(row[1])
		_cover_weight_cache[zone] = total
	var target := roll * float(total)
	var acc := 0.0
	for row in e.mix:
		acc += float(row[1])
		if target <= acc:
			return row[0]
	return e.mix[e.mix.size() - 1][0]


# ─── API ──────────────────────────────────────────────────────────────────────

static func def(key: String) -> Dictionary:
	_build_defs()
	return _defs.get(key, {})


static func template(key: String, variant: int) -> Dictionary:
	_build_defs()
	var d: Dictionary = _defs.get(key, {})
	if d.is_empty():
		return {}
	return Baker.get_template(key, d.build, variant % VARIANTS, d.get("style", "solid"))


## Bake every prop up-front so nothing hitches mid-match. Returns bake count.
static func warm_all() -> int:
	_build_defs()
	var n := 0
	for key in _defs.keys():
		for v in range(VARIANTS):
			template(key, v)
			n += 1
	return n


## Pick a prop key for a biome using the weighted table. `roll` is 0..1.
static func pick_for_biome(zone: int, roll: float) -> String:
	var table = BIOME_PROPS.get(zone, [])
	if table.is_empty():
		return ""
	var total: int = _total_weight(zone, table)
	var target := roll * float(total)
	var acc := 0.0
	for row in table:
		acc += float(row[1])
		if target <= acc:
			return row[0]
	return table[table.size() - 1][0]


static func pick_river_edge(roll: float) -> String:
	var total := 0
	for row in RIVER_EDGE_PROPS:
		total += row[1]
	var target := roll * float(total)
	var acc := 0.0
	for row in RIVER_EDGE_PROPS:
		acc += float(row[1])
		if target <= acc:
			return row[0]
	return "reeds"


static func layer_of(key: String) -> int:
	var d := def(key)
	return d.get("layer", Layer.DETAIL)


static func density_for(zone: int) -> float:
	return BIOME_DENSITY.get(zone, 0.0)


static func _total_weight(zone: int, table: Array) -> int:
	if _weight_cache.has(zone):
		return _weight_cache[zone]
	var t := 0
	for row in table:
		t += int(row[1])
	_weight_cache[zone] = t
	return t


static func stats() -> Dictionary:
	_build_defs()
	return {"prop_types": _defs.size(), "variants_each": VARIANTS}
