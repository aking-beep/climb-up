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

## Easiest first. Each one unlocks the next when sent.
const ROUTES := [
	{"id": "warm-up", "name": "Warm-up Slab", "grade": "4",
		"text": "Straight up good rock. A big jug halfway to shake your arms out. Clip the bolts as you pass them.",
		"crux": "Learning to clip and to rest on a jug."},
	{"id": "sundown", "name": "Sundown Traverse", "grade": "5b",
		"text": "Up, then a long move right along a seam, with a few small holds in the middle, then up to the top.",
		"crux": "The crimps on the traverse: move through them, don't hang there."},
	{"id": "the-pinch", "name": "The Pinch", "grade": "6a",
		"text": "A jug to rest on, then six rows of crimps to the top. Rest on the jug until your arms are full.",
		"crux": "Six rows of crimps. Stopping on them empties the arms."},
	{"id": "leap-of-faith", "name": "Leap of Faith", "grade": "6b",
		"text": "Blank rock above a jug. The holds above are out of reach: jump for them (a dyno). JUMP on the rock, aim with the stick.",
		"crux": "A dyno across blank rock, from the jug."},
	{"id": "lions-roof", "name": "Lion's Roof", "grade": "6c",
		"text": "Everything at once: crimps off the ground, a traverse on crimps, a jug, a dyno, and crimps to the anchor.",
		"crux": "Pacing your arms through three cruxes."},
]

const STYLES := {
	"onsight": ["Onsight", "First go, no falls. The best way to climb a route."],
	"redpoint": ["Redpoint", "No falls, after working it out on earlier goes."],
	"falls": ["Sent, with falls", "To the top, with rests on the rope. Try it clean next."],
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
