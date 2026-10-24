class_name EquipmentCatalog
extends RefCounted
## Gear you take on the expedition: shoes, helmet, rope, harness, clothing
## and supplies. The first item in each slot is the standard kit (no
## effect). The others are earned (Unlocks), and each is a trade: better at
## one thing, a little worse at another, so the choice depends on the route
## and the weather. Effects apply to expedition climbs only (FeatureFlags.
## gear_effects). Crag routes keep their own shoe choice (Crag.SHOES),
## because crag scores and styles are protected.
##
## Effects multiply the climb's stamina fields (StaminaModel): `walk`
## (walk_gear), `rock` (rock_gear), `wet` (the extra cost of wet rock in a
## downpour), `rest` (recovery), plus `hurt` (what a stone or a fall costs),
## `rope_rest` (the rope's share on an alpine pitch), `rests` (extra REST
## sits on the climb) and `haul` (breath per pull at an anchor).

const SLOTS := ["shoes", "helmet", "rope", "harness", "clothing", "supplies"]
const SLOT_NAMES := {"shoes": "Shoes", "helmet": "Helmet", "rope": "Rope", "harness": "Harness",
	"clothing": "Clothing", "supplies": "Supplies"}

const GEAR := {
	"shoes": [
		{"id": "approach", "name": "Approach shoes", "text": "Good for walking and easy rock. The standard kit.", "effect": {}},
		{"id": "boots", "name": "Stiff boots", "text": "Long walks cost less. On steep rock you feel less.",
			"effect": {"walk": 0.88, "rock": 1.08}, "lock": {"expedition": true}},
		{"id": "rock-shoes", "name": "Rock shoes", "text": "Precise on rock. Painful to walk far in.",
			"effect": {"rock": 0.9, "walk": 1.12}, "lock": {"stars": 2, "route": "warm-up"}},
	],
	"helmet": [
		{"id": "crag-helmet", "name": "Crag helmet", "text": "Always worn. A stone that hits you hurts the standard amount.", "effect": {}},
		{"id": "alpine-helmet", "name": "Alpine helmet", "text": "Covers more of the head: stones and knocks hurt less. A little heavier.",
			"effect": {"hurt": 0.75, "walk": 1.03}, "lock": {"sent": "leap-of-faith"}},
	],
	"rope": [
		{"id": "single", "name": "Single rope, 60 m", "text": "The standard rope.", "effect": {}},
		{"id": "dry", "name": "Dry-treated rope", "text": "Stays light in the rain: more rest hanging on it on an alpine pitch.",
			"effect": {"rope_rest": 1.4}, "lock": {"achievement": "no-sitting"}},
		{"id": "skinny", "name": "Thin rope", "text": "Lighter to pull up: each pull at an anchor costs less. Less rest hanging on it.",
			"effect": {"haul": 0.6, "rope_rest": 0.8}, "lock": {"achievement": "redpoint"}},
	],
	"harness": [
		{"id": "sport", "name": "Sport harness", "text": "Light and simple. The standard kit.", "effect": {}},
		{"id": "alpine", "name": "Padded alpine harness", "text": "Comfortable to hang in: rests on the rope give back more.",
			"effect": {"rope_rest": 1.25, "walk": 1.02}, "lock": {"total_stars": 6}},
	],
	"clothing": [
		{"id": "softshell", "name": "Soft shell", "text": "Breathes well. The standard kit.", "effect": {}},
		{"id": "hardshell", "name": "Hard shell", "text": "Keeps the rain out: wet rock costs less in a downpour. Warm work on a dry walk.",
			"effect": {"wet": 0.6, "walk": 1.04}, "lock": {"knowledge": 3}},
		{"id": "down", "name": "Down layer", "text": "Warm in the cold: rests give back more. Bulky to climb in.",
			"effect": {"rest": 1.2, "rock": 1.05}, "lock": {"summit": true}},
	],
	"supplies": [
		{"id": "snacks", "name": "Water and snacks", "text": "The standard kit.", "effect": {}},
		{"id": "gels", "name": "Energy gels", "text": "One more rest on each climb. Heavier pack.",
			"effect": {"rests": 1, "walk": 1.04}, "lock": {"total_stars": 10}},
		{"id": "thermos", "name": "Thermos of tea", "text": "Every rest gives back more.",
			"effect": {"rest": 1.15, "walk": 1.02}, "lock": {"knowledge": 6}},
	],
}


static func items(slot: String) -> Array:
	return GEAR.get(slot, [])


static func item(slot: String, id: String) -> Dictionary:
	for g in items(slot):
		if g["id"] == id:
			return g
	return {}


static func standard(slot: String) -> String:
	return items(slot)[0]["id"]


static func open(g: Dictionary) -> bool:
	return Unlocks.met(g.get("lock", {}))


## All effects of the items in `loadout` (slot -> id), multiplied (and
## `rests` added). Missing keys mean no change.
static func effects(loadout: Dictionary) -> Dictionary:
	var out := {"walk": 1.0, "rock": 1.0, "wet": 1.0, "rest": 1.0, "hurt": 1.0, "rope_rest": 1.0, "haul": 1.0, "rests": 0}
	for slot in SLOTS:
		var g := item(slot, String(loadout.get(slot, standard(slot))))
		for k in g.get("effect", {}):
			if k == "rests":
				out[k] = int(out[k]) + int(g["effect"][k])
			else:
				out[k] = float(out[k]) * float(g["effect"][k])
	return out


## The effect as a few words for the screen ("walking −12%").
static func effect_words(effect: Dictionary) -> String:
	var names := {"walk": "walking", "rock": "climbing", "wet": "wet rock", "rest": "rests give", "hurt": "hits",
		"rope_rest": "rope rest", "haul": "pulls cost"}
	var parts: Array[String] = []
	for k in ["walk", "rock", "wet", "hurt", "haul", "rest", "rope_rest"]:
		if effect.has(k):
			var pct := int(round((float(effect[k]) - 1.0) * 100.0))
			if pct != 0:
				parts.append("%s %s%d%%" % [names[k], "+" if pct > 0 else "−", absi(pct)])
	if effect.has("rests"):
		parts.append("+%d rest" % int(effect["rests"]))
	return "standard" if parts.is_empty() else ", ".join(parts)


## For the costs (walk, rock, wet, hurt, haul) lower is better; for rest,
## rope_rest and rests higher is better. True when the effect helps.
static func helps(key: String, value: float) -> bool:
	if key in ["rest", "rope_rest", "rests"]:
		return value > 1.0 or (key == "rests" and value > 0.0)
	return value < 1.0
