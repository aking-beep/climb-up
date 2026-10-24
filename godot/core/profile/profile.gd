extends Node
## Your climber (autoload `Profile`, CLIMB UP 2.0): the look, the gear you
## have equipped, the knowledge checks you have answered, and which first-
## time tips you have seen. Its own save file. Progress itself (stars,
## sends, summits) stays where it is kept now (Crag, Records); ProfileData
## reads it from there, so nothing is counted twice.

signal changed

const PATH := "user://climb_up_profile.json"

var look: Dictionary = Hero.DEFAULT_LOOK.duplicate()
## slot -> item id (EquipmentCatalog).
var equipped: Dictionary = {}
## card id -> {"right": bool, "t": unix}
var knowledge: Dictionary = {}
## First-time tips seen: "hub", "camp_world", "locker", ...
var seen: Array = []


func _ready() -> void:
	load_profile()


func _blank_equipped() -> Dictionary:
	var e := {}
	for slot in EquipmentCatalog.SLOTS:
		e[slot] = EquipmentCatalog.standard(slot)
	return e


func reset() -> void:
	look = Hero.DEFAULT_LOOK.duplicate()
	equipped = _blank_equipped()
	knowledge = {}
	seen = []


func load_profile() -> void:
	reset()
	var d: Variant = SaveGame.read(PATH)
	if typeof(d) != TYPE_DICTIONARY:
		return
	# Keep only what is the right shape and still exists.
	if typeof(d.get("look")) == TYPE_DICTIONARY:
		for slot in CosmeticCatalog.ORDER:
			var key: String = CosmeticCatalog.SLOTS[slot]["key"]
			var v: Variant = d["look"].get(key)
			if typeof(v) == TYPE_STRING:
				for o in CosmeticCatalog.options(slot):
					if o["value"] == v:
						look = CosmeticCatalog.apply(look, slot, o["id"])
	if typeof(d.get("equipped")) == TYPE_DICTIONARY:
		for slot in EquipmentCatalog.SLOTS:
			var id: Variant = d["equipped"].get(slot)
			if typeof(id) == TYPE_STRING and not EquipmentCatalog.item(slot, id).is_empty():
				equipped[slot] = id
	if typeof(d.get("knowledge")) == TYPE_DICTIONARY:
		for id in d["knowledge"]:
			var k: Variant = d["knowledge"][id]
			if typeof(id) == TYPE_STRING and typeof(k) == TYPE_DICTIONARY:
				knowledge[id] = {"right": bool(k.get("right", false)), "t": int(k.get("t", 0))}
	if typeof(d.get("seen")) == TYPE_ARRAY:
		seen = d["seen"].filter(func(s: Variant) -> bool: return typeof(s) == TYPE_STRING)


func save_profile() -> bool:
	return SaveGame.write({"look": look, "equipped": equipped, "knowledge": knowledge, "seen": seen}, PATH)


## Sets one look slot to an option. False if it is locked or unknown.
func choose_look(slot: String, id: String) -> bool:
	var o := CosmeticCatalog.option(slot, id)
	if o.is_empty() or not CosmeticCatalog.open(o):
		return false
	look = CosmeticCatalog.apply(look, slot, id)
	save_profile()
	changed.emit()
	Analytics.event("look_changed", {"slot": slot, "option": id})
	return true


## Equips gear. False if it is locked or unknown.
func equip(slot: String, id: String) -> bool:
	var g := EquipmentCatalog.item(slot, id)
	if g.is_empty() or not EquipmentCatalog.open(g):
		return false
	equipped[slot] = id
	save_profile()
	changed.emit()
	Analytics.event("gear_equipped", {"slot": slot, "item": id})
	return true


func item(slot: String) -> Dictionary:
	var id: String = equipped.get(slot, EquipmentCatalog.standard(slot))
	var g := EquipmentCatalog.item(slot, id)
	# Gear that was open and is not any more (a reset record) falls back.
	if g.is_empty() or not EquipmentCatalog.open(g):
		return EquipmentCatalog.item(slot, EquipmentCatalog.standard(slot))
	return g


## What the equipped gear does on an expedition climb (all 1 when the
## gear_effects flag is off).
func effects() -> Dictionary:
	if not FeatureFlags.gear_effects:
		return EquipmentCatalog.effects({})
	var loadout := {}
	for slot in EquipmentCatalog.SLOTS:
		loadout[slot] = item(slot)["id"]
	return EquipmentCatalog.effects(loadout)


func answer(card_id: String, right: bool) -> void:
	var before: bool = knowledge.get(card_id, {}).get("right", false)
	knowledge[card_id] = {"right": right or before, "t": Records.now() if Records else 0}
	save_profile()
	changed.emit()


func knowledge_right() -> int:
	var n := 0
	for id in knowledge:
		if knowledge[id]["right"]:
			n += 1
	return n


func has_seen(tip: String) -> bool:
	return tip in seen


func see(tip: String) -> void:
	if tip in seen:
		return
	seen.append(tip)
	save_profile()


func delete_all() -> void:
	reset()
	SaveGame.erase(PATH)
	changed.emit()
