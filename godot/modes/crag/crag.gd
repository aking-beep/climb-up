extends Node
## Crag mode (autoload `Crag`): single sport routes at one cliff, nothing to
## do with the expedition. Its own routes, progress and save file.
##
## A route is led: clip each bolt as you pass it; a fall is caught by the
## last bolt you clipped. Send it (reach the anchor) to unlock the next.
## How you sent it is the style: onsight (first go, no falls, no beta),
## flash (first go, no falls, with beta), redpoint (no falls, after earlier
## goes), or with falls (not a clean ascent). A go counts from when you tie
## in, not when you read the brief. Lowering off keeps your high point.
##
## Three things describe a route, apart from each other: the grade (how hard
## the moves are), the bolting (how far apart the bolts are) and the
## exposure (how far a fall can go, and whether it can reach the ground).
## facts() works the last two out from the route's map.

const TITLE := "res://modes/title/title.tscn"
const MENU := "res://modes/crag/crag_menu.tscn"
const LEVEL := "res://modes/crag/crag_level.tscn"
const SAVE := "user://climb_up_crag.json"
const MAX_FALLS := 5

## Easiest first. Each one unlocks the next when sent. `level` is the grade
## in words; `falls` how many falls before you have to come down;
## `gripDrain` how fast the grip fades on tiny holds.
const ROUTES := [
	{"id": "first-climb", "name": "First Climb", "grade": "Lesson", "level": "how to play", "falls": 9,
		"tutorial": true, "gripDrain": 0.25,
		"text": "A short climb that shows you everything, one thing at a time. The game stops each time there is something new, and explains it. Take your time.",
		"crux": "Nothing hard: this one is for learning."},
	{"id": "warm-up", "name": "Warm-up Wall", "grade": "4", "level": "easy", "falls": 5, "gripDrain": 0.35,
		"text": "Climb straight up good rock, with two short bits of tiny holds and one big hold (a jug) halfway: stop there to get your stamina back. Tap CLIP at each bolt.",
		"crux": "Learning to clip in and to rest."},
	{"id": "sundown", "name": "Sundown Traverse", "grade": "5b", "level": "moderate", "falls": 5, "gripDrain": 0.45,
		"text": "Up, then a long move sideways to the right across tiny holds (crimps): squeeze GRIP when the grip meter drops, and keep moving. Two big holds. Easy moves, but few bolts and a high first one.",
		"crux": "The tiny holds on the sideways part, a long way above the last bolt."},
	{"id": "the-pinch", "name": "The Pinch", "grade": "6a", "level": "hard", "falls": 4, "gripDrain": 0.6,
		"text": "Four stretches of tiny holds, the longest at the top, and only two big holds to rest on. Hard moves, but bolts close together all the way: clip from good holds where you can.",
		"crux": "The last stretch of tiny holds. Stopping on them drains you."},
	{"id": "leap-of-faith", "name": "Leap of Faith", "grade": "6b", "level": "harder", "falls": 4, "gripDrain": 0.7,
		"text": "Above a big hold the rock is blank: press JUMP on the rock to leap for the holds above (a dyno), then tap GRIP 3 times fast to stick it. Five stretches of tiny holds; the top bolts are far apart.",
		"crux": "A leap across blank rock, then tiny holds."},
	{"id": "lions-roof", "name": "Lion's Roof", "grade": "6c", "level": "very hard", "falls": 3, "gripDrain": 0.85,
		"text": "Tiny holds off the ground, then sideways under a roof of rock on tiny holds, a big hold, a leap, and long tiny holds to the top. The roof is well bolted.",
		"crux": "The roof, then six rows of tiny holds."},
	{"id": "thunderhead", "name": "Thunderhead", "grade": "7a", "level": "hardest", "falls": 3, "gripDrain": 1.0,
		"text": "The big one. Two leaps across blank rock, a roof, seven stretches of tiny holds and only three big holds, far apart. Few bolts, the top ones very far apart: a fall up there is a big one.",
		"crux": "Two leaps and long tiny holds: plan your rests."},
]

const STYLES := {
	"onsight": ["Onsight", "You climbed it on your first try without falling, and without beta. The best way to do a route."],
	"flash": ["Flash", "You climbed it on your first try without falling, with beta (tips on how to climb it)."],
	"redpoint": ["Redpoint", "You climbed it without falling, after trying it before."],
	"falls": ["Top, with falls", "You made it to the top, but fell on the way: not a clean ascent yet. Climb it again without falling for a redpoint."],
}
## The shoes, picked before each route. `pace` multiplies climbing speed,
## `stamina` what being on the rock costs.
const SHOES := {
	"neutral": {"name": "Neutral shoes", "pace": 0.75, "stamina": 0.7,
		"text": "Comfy and flat: you climb slower, but use less stamina."},
	"aggressive": {"name": "Aggressive shoes", "pace": 1.3, "stamina": 1.35,
		"text": "Tight and bent: you climb faster, but use more stamina."},
}

const STYLE_RANK := {"": 0, "falls": 1, "redpoint": 2, "flash": 3, "onsight": 4}
## Metres per row of the map (a row is about half a metre of rock).
const ROW_M := 0.5

## Per route: {attempts, sends, best (style), bestFalls, bestSeconds,
## highpoint (most bolts clipped on a go that did not reach the top), beta
## (tips taken: a first-go send is then a flash, not an onsight)}.
var progress: Dictionary = {}
## The route being climbed.
var current := "warm-up"
## The shoes picked last (offered first next time).
var shoes := "neutral"
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
	return progress.get(id, {"attempts": 0, "sends": 0, "best": "", "bestFalls": -1, "bestSeconds": -1, "highpoint": 0, "beta": false})


var _facts := {}


## What a route's map says about it, apart from the grade: {bolts, gaps
## (rows between bolts, bottom up), first (rows from the ground to the
## first bolt), height (m), longest (m between bolts), protection
## (well/sporty/runout), worstFall (m), groundFall (a fall low down can
## reach the ground), exposure (low/medium/high)}.
func facts(id: String) -> Dictionary:
	if _facts.has(id):
		return _facts[id]
	var t := Terrain.load_file(map_path(id))
	var foot: int = (t.markers["P"][0] as Vector2i).y
	var top: int = (t.markers["X"][0] as Vector2i).y
	var rows: Array = []
	for q in t.markers.get("Q", []):
		rows.append((q as Vector2i).y)
	rows.sort()
	rows.reverse()
	var gaps: Array = []
	for i in range(1, rows.size()):
		gaps.append(int(rows[i - 1]) - int(rows[i]))
	var longest: int = gaps.max() if not gaps.is_empty() else 0
	var first: int = foot - int(rows[0]) if not rows.is_empty() else 0
	# A lead fall: twice the distance above the last bolt, plus slack.
	var worst := (2 * longest + 2) * ROW_M
	# A high first bolt, or a long way to the second: a fall low down can
	# reach the ground.
	var ground := first >= 5 or (not gaps.is_empty() and int(gaps[0]) >= first + 3)
	var protection := "well" if longest <= 7 else ("sporty" if longest <= 12 else "runout")
	var exposure := "medium"
	if worst >= 12.0 or first >= 5:
		exposure = "high"
	elif worst <= 7.0 and first <= 3:
		exposure = "low"
	var f := {"bolts": rows.size(), "gaps": gaps, "first": first, "height": (foot - top) * ROW_M,
		"longest": longest * ROW_M, "protection": protection, "worstFall": worst, "groundFall": ground, "exposure": exposure}
	_facts[id] = f
	return f


## The bolting and exposure in words, for the menu and the brief.
func protection_words(id: String) -> String:
	var f := facts(id)
	var name: String = {"well": "Well bolted", "sporty": "Sporty", "runout": "Run-out"}[f["protection"]]
	return "%s: %d bolts, up to %s m apart" % [name, int(f["bolts"]), _m(f["longest"])]


func exposure_words(id: String) -> String:
	var f := facts(id)
	var name: String = {"low": "Low", "medium": "Medium", "high": "High"}[f["exposure"]]
	var words := "%s exposure: %s m tall, falls up to %s m" % [name, _m(f["height"]), _m(f["worstFall"])]
	if f["groundFall"]:
		words += ", and a fall before the second bolt can reach the ground"
	return words


## A whole number from a save, or `default` when it is not a number.
static func _num(v: Variant, default: int) -> int:
	return int(v) if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT else default


static func _m(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## The first route is always open; each one after opens when the one
## before it has been sent.
func unlocked(id: String) -> bool:
	var i := index_of(id)
	return i == 0 or int(record(ROUTES[i - 1]["id"])["sends"]) > 0


## Opens a route at its brief. Reading the brief is not a go.
func climb(id: String) -> void:
	if not unlocked(id):
		return
	current = id
	go(LEVEL)


## Tying in starts a go: it counts from here.
func tie_in(id: String) -> void:
	var r := record(id)
	r["attempts"] = int(r["attempts"]) + 1
	progress[id] = r
	save_progress()


## Tips on how to climb it: from now on a first-go send is a flash.
func take_beta(id: String) -> void:
	var r := record(id)
	r["beta"] = true
	progress[id] = r
	save_progress()


## The style a send at `falls` falls has on this route, given the goes
## before it (`attempts` includes this one) and whether beta was taken.
static func style_for(falls: int, attempts: int, beta: bool = false) -> String:
	if falls > 0:
		return "falls"
	if attempts <= 1:
		return "flash" if beta else "onsight"
	return "redpoint"


## A finished attempt. Returns {style, better, unlocked (next route's id or
## "")} for the results card.
func finish(id: String, sent: bool, falls: int, seconds: int, bolts: int = 0) -> Dictionary:
	var r := record(id)
	var out := {"style": "", "better": false, "unlocked": "", "highpoint": false}
	if not sent and bolts > int(r.get("highpoint", 0)):
		r["highpoint"] = bolts
		out["highpoint"] = true
	if sent:
		var was_sent := int(r["sends"]) > 0
		var style := style_for(falls, int(r["attempts"]), bool(r.get("beta", false)))
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
	return SaveGame.write({"progress": progress, "shoes": shoes}, SAVE)


func load_progress() -> void:
	progress = {}
	shoes = "neutral"
	var data: Variant = SaveGame.read(SAVE)
	if data == null or typeof(data.get("progress")) != TYPE_DICTIONARY:
		return
	if SHOES.has(String(data.get("shoes", ""))):
		shoes = String(data["shoes"])
	for r in ROUTES:
		var d: Variant = data["progress"].get(r["id"])
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var best := String(d.get("best", ""))
		progress[r["id"]] = {
			"attempts": maxi(0, _num(d.get("attempts"), 0)),
			"sends": maxi(0, _num(d.get("sends"), 0)),
			"best": best if STYLE_RANK.has(best) else "",
			"bestFalls": _num(d.get("bestFalls"), -1),
			"bestSeconds": _num(d.get("bestSeconds"), -1),
			"highpoint": clampi(_num(d.get("highpoint"), 0), 0, 99),
			"beta": typeof(d.get("beta")) == TYPE_BOOL and d["beta"],
		}


func reset() -> void:
	progress = {}
	shoes = "neutral"
	SaveGame.erase(SAVE)


func go(path: String) -> void:
	if navigate and is_inside_tree():
		Transition.go(get_tree(), path)
