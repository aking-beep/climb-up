class_name Kili
extends RefCounted
## Kilimanjaro's content (route, cards, party), exported from the Expo game
## by tools/godot/export_content.ts into data/kilimanjaro.json.

const PATH := "res://modes/expedition/data/kilimanjaro.json"
static var _def: Dictionary = {}


static func def() -> Dictionary:
	if _def.is_empty():
		_def = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _def


static func checkpoint_name(id: String) -> String:
	for stop in def()["progress"]:
		if stop["id"] == id:
			return stop["name"]
	return "Expedition"


## Tents up at night: every camp, and the descent while still high.
static func camping(checkpoint: String, altitude: float) -> bool:
	if checkpoint in ["briefing", "summit", "complete"]:
		return false
	if checkpoint == "descent":
		return altitude >= 2800
	return true


## Which painted zone the party is in. Not a map.
static func zone(checkpoint: String, altitude: float) -> String:
	if checkpoint == "summit" or altitude >= 5200:
		return "snow"
	if checkpoint in ["complete", "briefing"] or altitude < 3200:
		return "rainforest"
	if altitude < 3900:
		return "moorland"
	return "desert"


## 0 at the gate, 1 at the summit.
static func progress(altitude: float) -> float:
	return clampf((altitude - float(def()["gate"])) / (float(def()["summit"]) - float(def()["gate"])), 0.0, 1.0)
