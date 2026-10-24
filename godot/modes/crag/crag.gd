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

## Home: the hub (CLIMB UP 2.0). The classic title is still at
## res://modes/title/title.tscn.
const TITLE := "res://modes/hub/hub.tscn"
const MENU := "res://modes/crag/crag_menu.tscn"
const LEVEL := "res://modes/crag/crag_level.tscn"
const LOGBOOK := "res://modes/crag/logbook_screen.tscn"
const SAVE := "user://climb_up_crag.json"
const DAILY_SAVE := "user://climb_up_daily.json"
## Daily results kept, newest first.
const DAILY_KEEP := 60
const MAX_FALLS := 5

## Easiest first. Each one unlocks the next when sent. `level` is the grade
## in words; `falls` how many falls before you have to come down;
## `gripDrain` how fast the grip fades on tiny holds; `pump` how much every
## move costs (1 if not given), set so each grade asks a little more of the
## arms than the one before (test_crag's difficulty curve).
const ROUTES := [
	{"id": "first-climb", "name": "First Climb", "grade": "Lesson", "level": "how to play", "falls": 9,
		"tutorial": true, "gripDrain": 0.25, "skill": "The basics",
		"text": "A short climb that shows you everything, one thing at a time. Take your time.",
		"crux": "Nothing hard: this one is for learning."},
	{"id": "warm-up", "name": "Warm-up Wall", "grade": "4", "level": "easy", "falls": 5, "gripDrain": 0.35,
		"skill": "Clip, rest, repeat",
		"text": "Good rock with pockets (dark holes: hang on them for free) and one big hold halfway. Clip each bolt from a good hold and rest before you need to.",
		"crux": "Two short bits of tiny holds."},
	{"id": "sundown", "name": "Sundown Traverse", "grade": "5b", "level": "moderate", "falls": 5, "pump": 0.6, "gripDrain": 0.45,
		"skill": "Slow and steady",
		"text": "Up, then a long move sideways across slopers: round holds you hold by friction. Move slowly and pause to let your grip settle. Easy moves, but few bolts and a high first one.",
		"crux": "The slopers on the traverse, a long way above the last bolt."},
	{"id": "the-pinch", "name": "The Pinch", "grade": "6a", "level": "hard", "falls": 4, "gripDrain": 0.6,
		"skill": "Squeeze timing",
		"text": "Four stretches of tiny holds, the longest at the top. Squeeze GRIP once when the meter drops below half: not before, not a flurry. Bolts close together all the way.",
		"crux": "The last stretch of tiny holds. Stopping on them drains you."},
	{"id": "leap-of-faith", "name": "Leap of Faith", "grade": "6b", "level": "harder", "falls": 4, "pump": 1.2, "gripDrain": 0.7,
		"skill": "The leap",
		"text": "Above a big hold the rock is blank: press JUMP to leap for the holds above (a dyno). A ring closes on the hold: tap GRIP once as it closes. Slopers and tiny holds above; the top bolts are far apart.",
		"crux": "The catch, then tiny holds."},
	{"id": "lions-roof", "name": "Lion's Roof", "grade": "6c", "level": "very hard", "falls": 3, "pump": 1.2, "gripDrain": 0.85,
		"skill": "Steep ground",
		"text": "Tiny holds off the ground, then sideways under a roof of rock on pockets: clip from them, they are free to hang on. A big hold, a leap, and long tiny holds to the top. The roof is well bolted.",
		"crux": "The roof, then six rows of tiny holds."},
	{"id": "thunderhead", "name": "Thunderhead", "grade": "7a", "level": "hardest", "falls": 3, "gripDrain": 1.0,
		"skill": "All of it, run-out",
		"text": "The big one. Two leaps across blank rock, a roof, slopers, long stretches of tiny holds and only three big holds, far apart. Few bolts, the top ones very far apart: a fall up there is a big one.",
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
## (tips taken: a first-go send is then a flash, not an onsight), falls (all
## falls on it, every go), fellBefore (a go has had a fall: a clean send
## after it is a redpoint), challenge (its Logbook challenge done),
## highRows (the highest you have been on it, rows)}.
var progress: Dictionary = {}
## Achievements held: id → the UTC date it was earned (Logbook.ACHIEVEMENTS).
var achievements: Dictionary = {}
## The route being climbed.
var current := "warm-up"
## The shoes picked last (offered first next time).
var shoes := "neutral"
var navigate := true
## Set by retry(): the next level skips the brief and ties straight in.
var quick_retry := false
var _retry_ms := 0
## Tutorial tips already seen on an earlier go: on a replay they show as a
## short reminder instead of stopping the game (the first time, all of
## them stop it, safety included).
var lessons_seen: Array = []
## The daily route's log (Daily): {days: {date: {attempts, sends, falls,
## best, bestSeconds, bestFalls, hash}}, maxSeen (the latest date this
## device has shown), streak, lastSent}.
var daily: Dictionary = {}
## Tests set a UTC unix time here to play another day; -1 is the clock.
var clock_override := -1
var _daily_cache: Dictionary = {}


func _ready() -> void:
	load_progress()
	load_daily()


func route(id: String) -> Dictionary:
	if id == "daily":
		return daily_route()
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


## The map of a route: its file, or the daily route made for today.
func map_text(id: String) -> String:
	if id == "daily":
		return daily_route()["map"]
	return FileAccess.get_file_as_string(map_path(id))


func record(id: String) -> Dictionary:
	return progress.get(id, {"attempts": 0, "sends": 0, "best": "", "bestFalls": -1, "bestSeconds": -1, "highpoint": 0, "beta": false,
		"falls": 0, "challenge": false, "highRows": 0, "highX": 0})


## Mastery stars on a route, 0 to 3 (Logbook.stars).
func stars(id: String) -> int:
	return Logbook.stars(record(id))


func total_stars() -> int:
	var n := 0
	for r in ROUTES:
		n += stars(r["id"])
	return n


## The route to climb next: the first open route not yet sent, else the
## first without all three stars, else "".
func next_route() -> String:
	for r in ROUTES:
		if unlocked(r["id"]) and int(record(r["id"])["sends"]) == 0:
			return r["id"]
	for r in ROUTES:
		if stars(r["id"]) < 3:
			return r["id"]
	return ""


var _facts := {}


## What a route's map says about it, apart from the grade: {bolts, gaps
## (rows between bolts, bottom up), first (rows from the ground to the
## first bolt), height (m), longest (m between bolts), protection
## (well/sporty/runout), worstFall (m), groundFall (a fall low down can
## reach the ground), exposure (low/medium/high)}.
func facts(id: String) -> Dictionary:
	var key := id if id != "daily" else "daily-" + today()
	if _facts.has(key):
		return _facts[key]
	var t := Terrain.from_text(map_text(id))
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
	_facts[key] = f
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
	if id == "daily":
		# After the lesson: the daily route assumes you know the moves.
		return int(record("first-climb")["sends"]) > 0
	var i := index_of(id)
	return i == 0 or int(record(ROUTES[i - 1]["id"])["sends"]) > 0


## Opens a route at its brief. Reading the brief is not a go.
func climb(id: String) -> void:
	if not unlocked(id):
		return
	current = id
	go(LEVEL)


## One tap from the results: the same route again, straight onto the rock
## in the same shoes, no menu and no brief. The go counts once, at tie-in,
## like any other.
func retry(id: String) -> void:
	if not unlocked(id):
		return
	Analytics.event("instant_retry_tapped", {"route": id})
	quick_retry = true
	_retry_ms = Time.get_ticks_msec()
	current = id
	if navigate and is_inside_tree():
		# No fade: the fastest way back onto the rock.
		get_tree().call_deferred("change_scene_to_file", LEVEL)


## The level is playable again after a retry: how long it took (ms), or -1.
func retry_landed() -> int:
	if _retry_ms <= 0:
		return -1
	var ms := Time.get_ticks_msec() - _retry_ms
	_retry_ms = 0
	Analytics.event("retry_time_ms", {"route": current, "ms": ms})
	return ms


func see_lesson(key: String) -> void:
	if not lessons_seen.has(key):
		lessons_seen.append(key)
		save_progress()


## Tying in starts a go: it counts from here.
func tie_in(id: String) -> void:
	Analytics.event("daily_started" if id == "daily" else "route_started", {"route": id, "attempt": int(daily_record()["attempts"]) + 1 if id == "daily" else int(record(id)["attempts"]) + 1})
	if id != "daily" and int(record(id)["attempts"]) > 0:
		Analytics.event("route_replayed", {"route": id, "sent_before": int(record(id)["sends"]) > 0})
	if id == "first-climb" and int(record(id)["attempts"]) == 0:
		Analytics.event("tutorial_started")
	if id == "daily":
		if daily_counts():
			var d := daily_record()
			d["attempts"] = int(d["attempts"]) + 1
			_set_daily(d)
		return
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


## A finished attempt. `stats` is the go's (CragLevel.go_stats()). Returns
## {style, better, unlocked (next route's id or ""), highpoint, fasterBy
## (seconds off the best time, 0 if not), challenge (done on this go),
## firstChallenge (done for the first time), stars, starsBefore,
## achievements (new ids)} for the results card.
func finish(id: String, sent: bool, falls: int, seconds: int, bolts: int = 0, stats: Dictionary = {}) -> Dictionary:
	if id == "daily":
		return finish_daily(sent, falls, seconds, stats)
	if id == "first-climb" and sent and int(record(id)["sends"]) == 0:
		Analytics.event("tutorial_completed", {"seconds": seconds, "falls": falls})
	var r := record(id)
	var stars_before := Logbook.stars(r)
	var out := {"style": "", "better": false, "unlocked": "", "highpoint": false, "fasterBy": 0, "challenge": false,
		"firstChallenge": false, "achievements": [], "starsBefore": stars_before}
	r["falls"] = int(r.get("falls", 0)) + falls
	# The high point by height on the wall: new only above an earlier one
	# (a first go sets it, it does not beat it).
	var rows := int(stats.get("high_rows", 0))
	var before_rows := int(r.get("highRows", 0))
	out["highRowsBefore"] = before_rows
	out["newHighPoint"] = not sent and before_rows > 0 and rows > before_rows
	if rows > before_rows:
		r["highRows"] = rows
		r["highX"] = int(stats.get("high_x", 0))
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
		if int(r["bestSeconds"]) > 0 and seconds < int(r["bestSeconds"]):
			out["fasterBy"] = int(r["bestSeconds"]) - seconds
		if int(r["bestSeconds"]) < 0 or seconds < int(r["bestSeconds"]):
			r["bestSeconds"] = seconds
		var i := index_of(id)
		if not was_sent and i + 1 < ROUTES.size():
			out["unlocked"] = ROUTES[i + 1]["id"]
	var s := stats.duplicate()
	s["sent"] = sent
	s["falls"] = falls
	s["style"] = out["style"]
	if Logbook.challenge_done(id, s):
		out["challenge"] = true
		out["firstChallenge"] = not bool(r.get("challenge", false))
		r["challenge"] = true
	progress[id] = r
	out["stars"] = Logbook.stars(r)
	out["achievements"] = earn(Logbook.earned(id, s, progress, achievements, ROUTES))
	save_progress()
	return out


## Records new achievements (with today's UTC date). Returns them.
func earn(ids: Array) -> Array:
	for a in ids:
		achievements[a] = Time.get_date_string_from_system(true)
		Analytics.event("achievement_earned", {"id": a})
	return ids


# --- The daily route ----------------------------------------------------------

func now_unix() -> int:
	return clock_override if clock_override >= 0 else int(Time.get_unix_time_from_system())


func today() -> String:
	return Daily.date_key(now_unix())


func daily_route() -> Dictionary:
	var date := today()
	if not _daily_cache.has(date):
		_daily_cache = {date: Daily.route_for(date)}
	return _daily_cache[date]


## False when the device's date is earlier than a day it has already
## shown: the clock has been turned back. The route can still be climbed
## for practice, but the go is not logged as that day's result.
func daily_counts() -> bool:
	return today() >= String(daily.get("maxSeen", ""))


func daily_record(date: String = "") -> Dictionary:
	var d := date if date != "" else today()
	return daily.get("days", {}).get(d, {"attempts": 0, "sends": 0, "falls": 0, "best": "", "bestSeconds": -1, "bestFalls": -1, "hash": 0, "highRows": 0, "highX": 0})


func _set_daily(d: Dictionary) -> void:
	var days: Dictionary = daily.get("days", {})
	d["hash"] = daily_route()["hash"]
	days[today()] = d
	# Keep the newest DAILY_KEEP days.
	var keys := days.keys()
	keys.sort()
	while keys.size() > DAILY_KEEP:
		days.erase(keys.pop_front())
	daily["days"] = days
	save_daily()


## Notes the day as seen (for the clock check). Called when the daily is
## shown.
func see_daily() -> void:
	if today() > String(daily.get("maxSeen", "")):
		daily["maxSeen"] = today()
		save_daily()


## A finished daily go. Styles as on the other routes, counted over today's
## goes. Returns {style, better, practice (not logged: the clock was turned
## back), streak, achievements, fasterBy, unlocked: ""}.
func finish_daily(sent: bool, falls: int, seconds: int, stats: Dictionary = {}) -> Dictionary:
	var out := {"style": "", "better": false, "unlocked": "", "highpoint": false, "fasterBy": 0, "practice": not daily_counts(),
		"achievements": [], "streak": int(daily.get("streak", 0)), "stars": 0}
	var d := daily_record()
	if sent:
		out["style"] = style_for(falls, maxi(1, int(d["attempts"])), false)
	var rows := int(stats.get("high_rows", 0))
	var before_rows := int(d.get("highRows", 0))
	out["highRowsBefore"] = before_rows
	out["newHighPoint"] = not sent and before_rows > 0 and rows > before_rows
	if out["practice"]:
		out["newHighPoint"] = false
		return out
	if rows > before_rows:
		d["highRows"] = rows
		d["highX"] = int(stats.get("high_x", 0))
	d["falls"] = int(d["falls"]) + falls
	if sent:
		d["sends"] = int(d["sends"]) + 1
		if STYLE_RANK[out["style"]] > STYLE_RANK[String(d["best"])]:
			d["best"] = out["style"]
			out["better"] = true
		if int(d["bestSeconds"]) > 0 and seconds < int(d["bestSeconds"]):
			out["fasterBy"] = int(d["bestSeconds"]) - seconds
		if int(d["bestSeconds"]) < 0 or seconds < int(d["bestSeconds"]):
			d["bestSeconds"] = seconds
		if int(d["bestFalls"]) < 0 or falls < int(d["bestFalls"]):
			d["bestFalls"] = falls
		# The streak: days in a row with a send.
		var last := String(daily.get("lastSent", ""))
		if last != today():
			var yesterday := Daily.date_key(now_unix() - 86400)
			daily["streak"] = int(daily.get("streak", 0)) + 1 if last == yesterday else 1
			daily["lastSent"] = today()
		out["streak"] = int(daily["streak"])
		Analytics.event("daily_completed", {"date": today(), "style": out["style"], "falls": falls, "seconds": seconds})
	_set_daily(d)
	var s := stats.duplicate()
	s["sent"] = sent
	s["falls"] = falls
	s["style"] = out["style"]
	s["daily"] = true
	out["achievements"] = earn(Logbook.earned("daily", s, progress, achievements, ROUTES))
	save_progress()
	return out


## The result as text, for sharing anywhere (no images or emoji needed).
func daily_share_text(date: String = "") -> String:
	var r := daily_route() if date == "" or date == today() else Daily.route_for(date)
	var d := daily_record(r["date"])
	var lines := ["CLIMB UP · Daily route %s" % r["date"], "%s (%s)" % [r["name"], r["grade"]]]
	if int(d["sends"]) > 0:
		lines.append("%s in %d:%02d · %d fall%s · %d go%s" % [STYLES[d["best"]][0], int(d["bestSeconds"]) / 60, int(d["bestSeconds"]) % 60,
			int(d["bestFalls"]), "" if int(d["bestFalls"]) == 1 else "s", int(d["attempts"]), "" if int(d["attempts"]) == 1 else "s"])
	else:
		lines.append("Not topped yet · %d go%s" % [int(d["attempts"]), "" if int(d["attempts"]) == 1 else "s"])
	if int(daily.get("streak", 0)) > 1 and String(daily.get("lastSent", "")) == r["date"]:
		lines.append("Streak: %d days" % int(daily["streak"]))
	lines.append("Route #%08x" % int(r["hash"]))
	return "\n".join(lines)


func save_daily() -> bool:
	return SaveGame.write(daily, DAILY_SAVE)


func load_daily() -> void:
	daily = {"days": {}, "maxSeen": "", "streak": 0, "lastSent": ""}
	var data: Variant = SaveGame.read(DAILY_SAVE)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var date_ok := func(v: Variant) -> bool:
		return typeof(v) == TYPE_STRING and v.length() == 10 and v[4] == "-" and v[7] == "-"
	if date_ok.call(data.get("maxSeen")):
		daily["maxSeen"] = data["maxSeen"]
	if date_ok.call(data.get("lastSent")):
		daily["lastSent"] = data["lastSent"]
	daily["streak"] = clampi(_num(data.get("streak"), 0), 0, 10000)
	if typeof(data.get("days")) == TYPE_DICTIONARY:
		for k in data["days"]:
			var v: Variant = data["days"][k]
			if not date_ok.call(k) or typeof(v) != TYPE_DICTIONARY:
				continue
			var best := String(v.get("best", "")) if typeof(v.get("best")) == TYPE_STRING else ""
			daily["days"][k] = {"attempts": maxi(0, _num(v.get("attempts"), 0)), "sends": maxi(0, _num(v.get("sends"), 0)),
				"falls": maxi(0, _num(v.get("falls"), 0)), "best": best if STYLE_RANK.has(best) else "",
				"bestSeconds": _num(v.get("bestSeconds"), -1), "bestFalls": _num(v.get("bestFalls"), -1), "hash": _num(v.get("hash"), 0),
				"highRows": clampi(_num(v.get("highRows"), 0), 0, 999), "highX": clampi(_num(v.get("highX"), 0), 0, 9999)}


func reset_daily() -> void:
	daily = {"days": {}, "maxSeen": "", "streak": 0, "lastSent": ""}
	_daily_cache = {}
	clock_override = -1
	SaveGame.erase(DAILY_SAVE)


func save_progress() -> bool:
	return SaveGame.write({"progress": progress, "shoes": shoes, "achievements": achievements, "lessons": lessons_seen, "version": 2}, SAVE)


func load_progress() -> void:
	progress = {}
	achievements = {}
	shoes = "neutral"
	lessons_seen = []
	var data: Variant = SaveGame.read(SAVE)
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("progress")) != TYPE_DICTIONARY:
		return
	if typeof(data.get("lessons")) == TYPE_ARRAY:
		for k in data["lessons"]:
			if typeof(k) == TYPE_STRING and CragLevel.LESSONS.has(k) and not lessons_seen.has(k):
				lessons_seen.append(k)
	if typeof(data.get("achievements")) == TYPE_DICTIONARY:
		for a in data["achievements"]:
			if Logbook.ACHIEVEMENTS.has(a):
				achievements[a] = str(data["achievements"][a])
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
			"falls": maxi(0, _num(d.get("falls"), 0)),
			"challenge": typeof(d.get("challenge")) == TYPE_BOOL and d["challenge"],
			"highRows": clampi(_num(d.get("highRows"), 0), 0, 999),
			"highX": clampi(_num(d.get("highX"), 0), 0, 9999),
		}


func reset() -> void:
	progress = {}
	achievements = {}
	shoes = "neutral"
	lessons_seen = []
	quick_retry = false
	_retry_ms = 0
	SaveGame.erase(SAVE)


func go(path: String) -> void:
	if navigate and is_inside_tree():
		Transition.go(get_tree(), path)
