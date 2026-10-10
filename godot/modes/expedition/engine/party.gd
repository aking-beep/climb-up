class_name Party
extends RefCounted
## The four people, ported from src/expeditions/kilimanjaro/party.ts: how
## each one is doing, the camp beats they run (pole pole, water, head count),
## and sitting with someone who is down. Game fiction, not a routine to copy.

const ORDER := ["jun", "marco", "you", "lena"]
const NAMES := {"jun": "Jun", "marco": "Marco", "you": "You", "lena": "Lena"}
const ROLES := {"jun": "Doctor", "marco": "Climber", "you": "Lead", "lena": "Guide"}
const BIAS := {
	"you": [0, 0, 0], "lena": [2, 6, 8], "marco": [-6, -12, -10], "jun": [8, -2, 2],
}
const DUTY := {
	"lena": "Guide. She sets pole pole, the slow pace this mountain is walked at.",
	"jun": "Doctor, in the game. He walks the tents and says if the day should wait.",
	"marco": "Climber. He feels the pace first. If he sits, the party sits.",
	"you": "Lead. The card below is still your decision.",
}


static func expedition_hour(elapsed: float) -> float:
	return fmod(9.0 + elapsed, 24.0)


static func day_phase(hour: float) -> String:
	if hour < 5 or hour >= 20:
		return "night"
	if hour < 8:
		return "dawn"
	if hour >= 17:
		return "dusk"
	return "day"


static func _tended(s: Dictionary, id: String) -> bool:
	return s["marks"].get("tend-" + id) == true


static func members(s: Dictionary) -> Array:
	var out: Array = []
	for id in ORDER:
		var b: Array = BIAS[id]
		var care := 1 if _tended(s, id) else 0
		var health := clampi(int(s["health"]) + b[0] + care * 4, 0, 100)
		var energy := clampi(int(s["energy"]) + b[1] + care * 8, 0, 100)
		var spirits := clampi(int(s["teamCondition"]) + b[2] + care * 8, 0, 100)
		var pose := "kneel" if energy < 36 or spirits < 40 else ("lag" if energy < 56 or spirits < 62 else "walk")
		out.append({
			"id": id, "name": NAMES[id], "role": ROLES[id], "duty": DUTY[id],
			"health": health, "energy": energy, "spirits": spirits, "pose": pose,
			"line": _line(id, pose, care == 1, s),
		})
	return out


static func _line(id: String, pose: String, care: bool, s: Dictionary) -> String:
	if pose == "kneel":
		return "Down, but someone stayed with them." if care else "Down. The day can wait."
	if pose == "lag":
		return "Off the pace."
	if id == "lena":
		return "Pole pole is set." if s["marks"].get("pole-" + s["checkpoint"]) == true else "Ready to set pole pole."
	if id == "jun":
		return "The party is counted." if s["marks"].get("head-" + s["checkpoint"]) == true else "Ready to walk the tents."
	if id == "marco":
		return "Back on his feet." if care else "Carrying his share."
	return "The decision is still yours."


static func _night(s: Dictionary) -> bool:
	return day_phase(expedition_hour(s["elapsedHours"])) == "night"


static func routines(s: Dictionary) -> Array:
	var dark := _night(s)
	var cp: String = s["checkpoint"]
	var pole: bool = s["marks"].get("pole-" + cp) == true
	var water: bool = s["marks"].get("water-" + cp) == true
	var head: bool = s["marks"].get("head-" + cp) == true
	return [
		{"id": "pole-pole", "label": "Slow the first hour" if dark else "Pole pole",
			"detail": "Lena keeps the dark hour slow." if dark else "Lena sets a slow pace before anyone leaves.", "done": pole, "enabled": not pole},
		{"id": "water", "label": "Drink before the dark" if dark else "Put the water on",
			"detail": "The stores are too thin." if s["supplies"] < 6 else "A camp beat. It spends a little of the stores.", "done": water, "enabled": not water and s["supplies"] >= 6},
		{"id": "head-count", "label": "Check before anyone leaves" if dark else "Head count",
			"detail": "Jun walks the party. In this game, a quiet person stops the day. Not a diagnosis.", "done": head, "enabled": not head},
	]


static func routine_effect(s: Dictionary, id: String) -> Variant:
	var enabled := false
	for r in routines(s):
		if r["id"] == id:
			enabled = r["enabled"]
	if not enabled:
		return null
	var cp: String = s["checkpoint"]
	if id == "pole-pole":
		return {"note": "Lena keeps the first dark hour slow." if _night(s) else "Lena sets pole pole. The party will walk slowly.",
			"hours": 1, "move": "hold", "mark": "pole-" + cp, "acclimatization": 3, "energy": 2, "teamCondition": 3,
			"scores": {"judgment": {"label": "You let Lena set pole pole", "delta": 4, "mark": "pole-pole"}}}
	if id == "water":
		return {"note": "The water goes on. The stores pay for it.", "hours": 1, "move": "hold", "mark": "water-" + cp,
			"supplies": -1, "health": 1, "energy": 1,
			"scores": {"preparation": {"label": "You treated water as part of camp", "delta": 4, "mark": "camp-water"}}}
	return {"note": "Jun walks the tents. In this game, that is a reason to notice the quiet one. Not a diagnosis.",
		"hours": 1, "move": "hold", "mark": "head-" + cp, "teamCondition": 4,
		"scores": {"teamwork": {"label": "Jun counted the party before the trail", "delta": 5, "mark": "head-count"}}}


static func tend_effect(s: Dictionary, id: String) -> Variant:
	if _tended(s, id):
		return null
	for m in members(s):
		if m["id"] == id:
			if m["pose"] == "walk":
				return null
			return {"note": "You sit with %s. The party waits with you." % m["name"], "hours": 1, "move": "hold",
				"mark": "tend-" + id, "energy": 4, "teamCondition": 5,
				"scores": {"teamwork": {"label": "You sat with %s" % m["name"], "delta": 6, "mark": "sit-" + id}}}
	return null
