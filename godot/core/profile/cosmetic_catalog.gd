class_name CosmeticCatalog
extends RefCounted
## Looks for your climber: colours and shapes only, no effect on play.
## Every lock is a skill condition (Unlocks). From the design reference
## (design/magic-patterns/cosmetics.ts).

## slot -> {label, key (the look's field), options: [{id, label, value, trim?, lock?}]}
const SLOTS := {
	"jacket": {"label": "Jacket", "key": "jacket", "options": [
		{"id": "olive", "label": "Olive", "value": "#6f7a3f", "trim": "#4f5a2c"},
		{"id": "ember", "label": "Ember", "value": "#b4512f", "trim": "#7e3520"},
		{"id": "spruce", "label": "Spruce", "value": "#2d5a4b", "trim": "#1f3d34"},
		{"id": "glacier", "label": "Glacier", "value": "#6f9fbf", "trim": "#4a7593"},
		{"id": "ochre", "label": "Ochre", "value": "#c98a2e", "trim": "#94621c", "lock": {"stars": 2, "route": "warm-up"}},
		{"id": "saffron", "label": "Saffron", "value": "#e0a52c", "trim": "#a8771a", "lock": {"achievement": "daily-clean"}},
		{"id": "night", "label": "Summit night", "value": "#2b3256", "trim": "#1b2340", "lock": {"summit": true}},
		{"id": "chalk", "label": "Chalk", "value": "#e8e1d2", "trim": "#bdb29c", "lock": {"achievement": "clean-sweep"}},
	]},
	"headwear": {"label": "Headwear", "key": "headwear", "options": [
		{"id": "helmet", "label": "Crag helmet", "value": "helmet"},
		{"id": "beanie", "label": "Beanie", "value": "beanie"},
		{"id": "sunhat", "label": "Sun hat", "value": "sunhat"},
		{"id": "headlamp", "label": "Buff and headlamp", "value": "headlamp", "lock": {"expedition": true}},
		{"id": "none", "label": "Bare head", "value": "none"},
	]},
	"headwearColor": {"label": "Hat colour", "key": "headwearColor", "options": [
		{"id": "sun", "label": "Sun", "value": "#e9c46a"}, {"id": "chalk", "label": "Chalk", "value": "#f3efe6"},
		{"id": "ember", "label": "Ember", "value": "#a8432a"}, {"id": "spruce", "label": "Spruce", "value": "#2d5a4b"},
		{"id": "sky", "label": "Sky", "value": "#6f9fbf"}, {"id": "ink", "label": "Ink", "value": "#1c1915"},
	]},
	"pack": {"label": "Pack", "key": "pack", "options": [
		{"id": "crag", "label": "Crag pack", "value": "crag"},
		{"id": "daypack", "label": "Daypack", "value": "daypack"},
		{"id": "expedition", "label": "Expedition 45 L", "value": "expedition", "lock": {"expedition": true}},
		{"id": "none", "label": "No pack", "value": "none"},
	]},
	"packColor": {"label": "Pack colour", "key": "packColor", "options": [
		{"id": "ember", "label": "Ember", "value": "#a8432a"}, {"id": "spruce", "label": "Spruce", "value": "#1f3d34"},
		{"id": "ochre", "label": "Ochre", "value": "#c98a2e"}, {"id": "slate", "label": "Slate", "value": "#4a7593"},
		{"id": "earth", "label": "Earth", "value": "#3a342c"},
	]},
	"harness": {"label": "Harness colour", "key": "harness", "options": [
		{"id": "spruce", "label": "Spruce", "value": "#1f3d34"}, {"id": "ember", "label": "Ember", "value": "#a8432a"},
		{"id": "slate", "label": "Slate", "value": "#4c5866"},
		{"id": "gold", "label": "Gold", "value": "#d9a441", "lock": {"achievement": "perfect-catch"}},
	]},
	"bagPattern": {"label": "Chalk bag", "key": "bagPattern", "options": [
		{"id": "plain", "label": "Canvas", "value": "plain"}, {"id": "stripe", "label": "Ridge stripe", "value": "stripe"},
		{"id": "topo", "label": "Topo lines", "value": "topo", "lock": {"achievement": "feather"}},
		{"id": "dots", "label": "Chalk dots", "value": "dots", "lock": {"achievement": "economy"}},
	]},
	"rope": {"label": "Rope colour", "key": "rope", "options": [
		{"id": "ember", "label": "Ember", "value": "#d9572b"}, {"id": "lime", "label": "Lime", "value": "#9cc23a"},
		{"id": "sky", "label": "Sky", "value": "#4fa3d9"}, {"id": "violet", "label": "Violet", "value": "#8a5cc2"},
		{"id": "sun", "label": "Sun", "value": "#f2c14e", "lock": {"achievement": "runout"}},
	]},
	"skin": {"label": "Skin", "key": "skin", "options": [
		{"id": "s1", "label": "1", "value": "#f0c9a6"}, {"id": "s2", "label": "2", "value": "#e0b48e"},
		{"id": "s3", "label": "3", "value": "#d9a77c"}, {"id": "s4", "label": "4", "value": "#c68a62"},
		{"id": "s5", "label": "5", "value": "#a8714f"}, {"id": "s6", "label": "6", "value": "#7a4a2e"},
		{"id": "s7", "label": "7", "value": "#5e3a24"},
	]},
	"hair": {"label": "Hair", "key": "hair", "options": [
		{"id": "h1", "label": "Black", "value": "#120c08"}, {"id": "h2", "label": "Dark brown", "value": "#2a1d16"},
		{"id": "h3", "label": "Auburn", "value": "#3a1f14"}, {"id": "h4", "label": "Red brown", "value": "#5a2a1e"},
		{"id": "h5", "label": "Brown", "value": "#8a5a32"}, {"id": "h6", "label": "Copper", "value": "#b5793e"},
		{"id": "h7", "label": "Fair", "value": "#d8c7a4"},
	]},
	"body": {"label": "Body", "key": "body", "options": [
		{"id": "m", "label": "Build 1", "value": "m"}, {"id": "f", "label": "Build 2", "value": "f"},
	]},
}
const ORDER := ["jacket", "headwear", "headwearColor", "pack", "packColor", "harness", "bagPattern", "rope", "skin", "hair", "body"]


static func options(slot: String) -> Array:
	return SLOTS.get(slot, {}).get("options", [])


static func option(slot: String, id: String) -> Dictionary:
	for o in options(slot):
		if o["id"] == id:
			return o
	return {}


static func open(o: Dictionary) -> bool:
	return Unlocks.met(o.get("lock", {}))


## The option whose value the look has for this slot ("" when none).
static func chosen(look: Dictionary, slot: String) -> String:
	var key: String = SLOTS[slot]["key"]
	for o in options(slot):
		if String(o["value"]) == String(look.get(key, "")):
			return o["id"]
	return ""


## The look with `slot` set to option `id` (a jacket brings its trim).
static func apply(look: Dictionary, slot: String, id: String) -> Dictionary:
	var o := option(slot, id)
	var out := look.duplicate()
	if o.is_empty():
		return out
	out[SLOTS[slot]["key"]] = o["value"]
	if o.has("trim"):
		out["jacketTrim"] = o["trim"]
	return out


## How many options are open, of all.
static func open_count() -> Vector2i:
	var n := 0
	var all := 0
	for slot in ORDER:
		for o in options(slot):
			all += 1
			if open(o):
				n += 1
	return Vector2i(n, all)
