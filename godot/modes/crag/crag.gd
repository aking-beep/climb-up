extends Node
## Crag mode (autoload `Crag`): single sport routes at one cliff, nothing to
## do with the expedition. Its own routes, progress and save file.
##
## A route is led: clip each bolt as you pass it; a fall drops you back to
## the last bolt you clipped. Send it (reach the anchor) to unlock the next.
## How you sent it is the style: onsight (first go, no falls), redpoint (no
## falls, after earlier goes), or with falls.

const TITLE := "res://modes/title/title.tscn"
const MENU := "res://modes/crag/crag_menu.tscn"
const LEVEL := "res://modes/crag/crag_level.tscn"
const SAVE := "user://climb_up_crag.json"
const MAX_FALLS := 5

## Easiest first. Each one unlocks the next when sent. `level` is the grade
## in words; `falls` how many falls before you have to come down.
const ROUTES := [
	{"id": "warm-up", "name": "Warm-up Wall", "grade": "4", "level": "easy", "falls": 5,
		"text": "Climb straight up good rock. Halfway up is a big hold (a jug): stop there to get your stamina back. When you reach a bolt, tap CLIP to clip your rope in.",
		"crux": "Learning to clip in and to rest."},
	{"id": "sundown", "name": "Sundown Traverse", "grade": "5b", "level": "moderate", "falls": 5,
		"text": "Up, then a long move sideways to the right. Rest on the big hold, then cross the tiny holds (crimps): tap GRIP to hang on, and keep moving.",
		"crux": "Tiny holds on the sideways part."},
	{"id": "the-pinch", "name": "The Pinch", "grade": "6a", "level": "hard", "falls": 4,
		"text": "A big hold to rest on, then seven rows of tiny holds to the top. Fill your stamina on the big hold first, then tap GRIP and climb fast.",
		"crux": "Seven rows of tiny holds. Stopping on them drains you."},
	{"id": "leap-of-faith", "name": "Leap of Faith", "grade": "6b", "level": "harder", "falls": 4,
		"text": "Above the big hold the rock is blank: no holds within reach. Press JUMP on the rock to leap for the holds above (a dyno), then tap GRIP 3 times fast to stick it.",
		"crux": "A leap across blank rock, then tiny holds."},
	{"id": "lions-roof", "name": "Lion's Roof", "grade": "6c", "level": "very hard", "falls": 3,
		"text": "Tiny holds off the ground, then sideways under a roof of rock on tiny holds, a big hold, a leap, and tiny holds to the top.",
		"crux": "The roof: tiny holds with rock right over your head."},
	{"id": "thunderhead", "name": "Thunderhead", "grade": "7a", "level": "hardest", "falls": 3,
		"text": "The big one. Two leaps across blank rock, a roof, and long stretches of tiny holds. Rest on every big hold you find.",
		"crux": "Two leaps and long tiny holds: plan your rests."},
]

const STYLES := {
	"onsight": ["Onsight", "You climbed it on your first try without falling. The best way to do a route."],
	"redpoint": ["Redpoint", "You climbed it without falling, after trying it before."],
	"falls": ["Sent, with falls", "You made it to the top, but fell on the way. Try it again without falling."],
}
const STYLE_RANK := {"": 0, "falls": 1, "redpoint": 2, "onsight": 3}

## Per route: {attempts, sends, best (style), bestFalls, bestSeconds}.
var progress: Dictionary = {}
## The route being climbed.
var current := "warm-up"
var navigate := true


func _ready() -> void:
	load_progress()


func route(id: String) -> Dictionary:
	for r in ROUTES:
		if r["id"] == id:
			return r
	return ROUTES[0]


func index_of(id: String) -> int:
	for i in ROUTES.size():
		if ROUTES[i]["id"] == id:
			return i
	return 0


func map_path(id: String) -> String:
	return "res://modes/crag/routes/%s.txt" % id


func record(id: String) -> Dictionary:
	return progress.get(id, {"attempts": 0, "sends": 0, "best": "", "bestFalls": -1, "bestSeconds": -1})


## The first route is always open; each one after opens when the one
## before it has been sent.
func unlocked(id: String) -> bool:
	var i := index_of(id)
	return i == 0 or int(record(ROUTES[i - 1]["id"])["sends"]) > 0


## Starts an attempt: counts it, and opens the route.
func climb(id: String) -> void:
	if not unlocked(id):
		return
	current = id
	var r := record(id)
	r["attempts"] = int(r["attempts"]) + 1
	progress[id] = r
	save_progress()
	go(LEVEL)


## The style a send at `falls` falls has on this route, given the goes
## before it (`attempts` includes this one).
static func style_for(falls: int, attempts: int) -> String:
	if falls > 0:
		return "falls"
	return "onsight" if attempts <= 1 else "redpoint"


## A finished attempt. Returns {style, better, unlocked (next route's id or
## "")} for the results card.
func finish(id: String, sent: bool, falls: int, seconds: int) -> Dictionary:
	var r := record(id)
	var out := {"style": "", "better": false, "unlocked": ""}
	if sent:
		var was_sent := int(r["sends"]) > 0
		var style := style_for(falls, int(r["attempts"]))
		out["style"] = style
		r["sends"] = int(r["sends"]) + 1
		if STYLE_RANK[style] > STYLE_RANK[String(r["best"])]:
			r["best"] = style
			out["better"] = true
		if int(r["bestFalls"]) < 0 or falls < int(r["bestFalls"]):
			r["bestFalls"] = falls
		if int(r["bestSeconds"]) < 0 or seconds < int(r["bestSeconds"]):
			r["bestSeconds"] = seconds
		var i := index_of(id)
		if not was_sent and i + 1 < ROUTES.size():
			out["unlocked"] = ROUTES[i + 1]["id"]
	progress[id] = r
	save_progress()
	return out


func save_progress() -> bool:
	return SaveGame.write({"progress": progress}, SAVE)


func load_progress() -> void:
	progress = {}
	var data: Variant = SaveGame.read(SAVE)
	if data == null or typeof(data.get("progress")) != TYPE_DICTIONARY:
		return
	for r in ROUTES:
		var d: Variant = data["progress"].get(r["id"])
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var best := String(d.get("best", ""))
		progress[r["id"]] = {
			"attempts": maxi(0, int(d.get("attempts", 0))),
			"sends": maxi(0, int(d.get("sends", 0))),
			"best": best if STYLE_RANK.has(best) else "",
			"bestFalls": int(d.get("bestFalls", -1)),
			"bestSeconds": int(d.get("bestSeconds", -1)),
		}


func reset() -> void:
	progress = {}
	SaveGame.erase(SAVE)


func go(path: String) -> void:
	if navigate and is_inside_tree():
		get_tree().call_deferred("change_scene_to_file", path)
