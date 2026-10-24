class_name Unlocks
extends RefCounted
## What opens a cosmetic or a piece of gear: always something the player
## did, read from data the game already keeps (crag stars and
## achievements, expedition runs in the records, knowledge checks). No
## currency and no purchases. A lock is a Dictionary:
##   {} (open), {"stars": n, "route": id}, {"total_stars": n},
##   {"achievement": id}, {"sent": route}, {"summit": true},
##   {"expedition": true} (any expedition finished, top or not),
##   {"knowledge": n} (knowledge checks answered right).


static func met(lock: Dictionary) -> bool:
	if lock.is_empty():
		return true
	if lock.has("stars"):
		return Crag.stars(String(lock["route"])) >= int(lock["stars"])
	if lock.has("total_stars"):
		return Crag.total_stars() >= int(lock["total_stars"])
	if lock.has("achievement"):
		return Crag.achievements.has(String(lock["achievement"]))
	if lock.has("sent"):
		return int(Crag.record(String(lock["sent"]))["sends"]) > 0
	if lock.has("summit"):
		return summits() > 0
	if lock.has("expedition"):
		return expeditions() > 0
	if lock.has("knowledge"):
		return Profile.knowledge_right() >= int(lock["knowledge"])
	return false


static func words(lock: Dictionary) -> String:
	if lock.has("stars"):
		return "%d stars on %s" % [int(lock["stars"]), Crag.route(String(lock["route"])).get("name", lock["route"])]
	if lock.has("total_stars"):
		return "%d stars at Lion Rock" % int(lock["total_stars"])
	if lock.has("achievement"):
		var a: Array = Logbook.ACHIEVEMENTS.get(String(lock["achievement"]), ["?", ""])
		return "Achievement: %s" % a[0]
	if lock.has("sent"):
		return "Send %s" % Crag.route(String(lock["sent"])).get("name", lock["sent"])
	if lock.has("summit"):
		return "Reach the top of Kilimanjaro"
	if lock.has("expedition"):
		return "Finish an expedition"
	if lock.has("knowledge"):
		return "%d knowledge checks right" % int(lock["knowledge"])
	return ""


## Expedition runs that reached the top (from the records on this device).
static func summits() -> int:
	var n := 0
	for r in Records.data.get("expedition", {}).get("runs", []):
		if bool(r.get("summit", false)):
			n += 1
	return n


static func expeditions() -> int:
	return Records.data.get("expedition", {}).get("runs", []).size()
