extends Node
## Personal records and leaderboards (autoload `Records`).
##
## Everything here is the player's own and lives on this device
## (user://climb_up_records.json). Nothing is "verified" or "global": that
## needs the online service in docs/records-backend.md, which is designed
## but not deployed. Until a server confirms an attempt, every record says
## it is on this device, and Global and Friends boards say they are not
## connected. Finished attempts wait in a queue (with their event log) so
## they can be sent once a service exists; the queue never decides a rank.
##
## Crag, per route: best time, fastest clean ascent (no falls), highest
## point, the dates of the onsight, flash and redpoint, the first ascent
## on this device, and the last goes. Daily: every go of the day, ranked.
## Expedition: every finished expedition with its score (the game's own
## ExpeditionEngine.score), whether it summited and came down, the team,
## the stores and the decisions; split by route (difficulty) and assisted
## play. The boards rank by leader points (leader_points): the score, plus
## speed and stores left over when the whole team summits and comes home,
## minus every teammate who did not. World Passport: places and continents
## completed.

const PATH := "user://climb_up_records.json"
const VERSION := 1
## Goes kept per route and per day, newest last.
const KEEP_GOES := 40
const KEEP_DAYS := 60
const KEEP_RUNS := 50
const KEEP_QUEUE := 200

## Places in the World Passport: where they are, what completes them.
const PLACES := {
	"kilimanjaro": {"name": "Kilimanjaro", "continent": "africa", "kind": "expedition"},
	"lion-rock": {"name": "Lion Rock crag", "continent": "africa", "kind": "crag"},
}
const CONTINENTS := {
	"africa": "Africa", "asia": "Asia", "europe": "Europe", "north-america": "North America",
	"south-america": "South America", "oceania": "Oceania", "antarctica": "Antarctica",
}
## Global passport rankings need more than one continent with places.
const GLOBAL_PASSPORT_MIN_CONTINENTS := 2

const SCREEN := "res://modes/records/records_screen.tscn"
## The screen's board (crag, expedition, passport) and scope (personal,
## friends, global), and where Back goes.
var board := "crag"
var scope := "personal"
var back_to := "res://modes/title/title.tscn"

var data: Dictionary = {}
## Where online submissions would go; null while there is no service.
## See Online (core/records/online.gd).
var online: Online


func _ready() -> void:
	online = Online.new()
	online.host = self
	load_records()


func _blank() -> Dictionary:
	return {"version": VERSION, "player": {"localId": Crypto.new().generate_random_bytes(8).hex_encode()},
		"crag": {}, "daily": {}, "expedition": {"runs": [], "firstCompletion": 0}, "queue": []}


func load_records() -> void:
	data = _blank()
	var d: Variant = SaveGame.read(PATH)
	if typeof(d) != TYPE_DICTIONARY:
		return
	# Only what has the right shape is kept: a hand-edited or damaged file
	# loses those entries, it never breaks the game.
	if typeof(d.get("crag")) == TYPE_DICTIONARY:
		for r in Crag.ROUTES:
			var e: Variant = d["crag"].get(r["id"])
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var clean := crag_route("")
			for k in ["bestSeconds", "bestCleanSeconds", "highRows", "onsight", "flash", "redpoint", "firstAscent"]:
				clean[k] = _int(e.get(k), clean[k])
			clean["goes"] = _goes(e.get("goes"))
			data["crag"][r["id"]] = clean
	if typeof(d.get("daily")) == TYPE_DICTIONARY:
		for date in d["daily"]:
			if typeof(date) == TYPE_STRING and date.length() == 10:
				data["daily"][date] = _goes(d["daily"][date])
	if typeof(d.get("expedition")) == TYPE_DICTIONARY:
		var e: Dictionary = d["expedition"]
		data["expedition"]["firstCompletion"] = _int(e.get("firstCompletion"), 0)
		if typeof(e.get("runs")) == TYPE_ARRAY:
			for run in e["runs"]:
				if typeof(run) == TYPE_DICTIONARY and _int(run.get("score"), -1) >= 0 and typeof(run.get("difficulty")) == TYPE_STRING:
					run["score"] = clampi(_int(run["score"], 0), 0, 100)
					run["complete"] = _bool(run.get("complete"))
					run["returned"] = _bool(run.get("returned"))
					run["assisted"] = _bool(run.get("assisted"))
					run["t"] = _int(run.get("t"), 0)
					# Runs from before leader points rank by their score.
					run["points"] = clampi(_int(run.get("points"), run["score"]), 0, LEADER_MAX)
					data["expedition"]["runs"].append(run)
	if typeof(d.get("queue")) == TYPE_ARRAY:
		data["queue"] = d["queue"].filter(func(q: Variant) -> bool: return typeof(q) == TYPE_DICTIONARY and typeof(q.get("id")) == TYPE_STRING and typeof(q.get("status")) == TYPE_STRING)
	if typeof(d.get("player")) == TYPE_DICTIONARY and typeof(d["player"].get("localId")) == TYPE_STRING:
		data["player"] = d["player"]


static func _int(v: Variant, default: int) -> int:
	return int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) else default


static func _bool(v: Variant) -> bool:
	return typeof(v) == TYPE_BOOL and v


static func _goes(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for g in v:
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var seconds := _int(g.get("seconds"), -1)
		if seconds < 0:
			continue
		out.append({"t": _int(g.get("t"), 0), "sent": _bool(g.get("sent")), "seconds": seconds, "falls": maxi(0, _int(g.get("falls"), 0)),
			"rows": maxi(0, _int(g.get("rows"), 0)), "style": String(g.get("style", "")) if typeof(g.get("style")) == TYPE_STRING else "",
			"shoes": String(g.get("shoes", "")) if typeof(g.get("shoes")) == TYPE_STRING else "", "verified": false})
	return out


func save() -> bool:
	return SaveGame.write(data, PATH)


## Privacy: forget every record on this device (the game's progress and
## logbook are separate and stay).
func delete_all() -> void:
	data = _blank()
	SaveGame.erase(PATH)


func now() -> int:
	return Crag.now_unix()


func open(which: String, from: String) -> void:
	board = which
	scope = "personal"
	back_to = from
	if Crag.navigate and is_inside_tree():
		Transition.go(get_tree(), SCREEN)


# --- Ranking -----------------------------------------------------------------

## Competition ranking ("1224"): 1 + how many are strictly better. Equal
## values share a rank; the next rank skips.
static func rank_of(value: float, values: Array, lower_is_better: bool = true) -> int:
	var better := 0
	for v in values:
		if (float(v) < value) if lower_is_better else (float(v) > value):
			better += 1
	return better + 1


static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, suffix]


## Sorted best first; ties keep the earlier go first.
static func sorted_goes(goes: Array, key: String, lower_is_better: bool = true) -> Array:
	var list := goes.duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a[key]) == float(b[key]):
			return int(a.get("t", 0)) < int(b.get("t", 0))
		return float(a[key]) < float(b[key]) if lower_is_better else float(a[key]) > float(b[key]))
	return list


# --- Crag -------------------------------------------------------------------

func crag_route(id: String) -> Dictionary:
	return data["crag"].get(id, {"bestSeconds": -1, "bestCleanSeconds": -1, "highRows": 0, "onsight": 0, "flash": 0,
		"redpoint": 0, "firstAscent": 0, "goes": []})


## A finished crag go (from CragLevel.finish): updates the records and
## queues it for the online service. Returns one line for the results:
## the new records and the go's rank among your own goes ("" if none).
func crag_attempt(route: Dictionary, outcome: Dictionary, level: Node) -> String:
	var id: String = route["id"]
	var sent: bool = outcome.get("sent", false)
	var seconds := int(outcome.get("seconds", 0))
	var falls := int(outcome.get("falls", 0))
	var rows := int(outcome.get("stats", {}).get("high_rows", 0))
	var style := String(outcome.get("style", ""))
	if outcome.get("practice", false):
		return ""
	var go := {"t": now(), "sent": sent, "seconds": seconds, "falls": falls, "rows": rows, "style": style,
		"shoes": String(outcome.get("shoes", "")), "verified": false}
	var news: Array = []
	if id == "daily":
		news = _daily_go(go)
	else:
		news = _route_go(id, go)
	_enqueue("crag", {"route": id, "date": route.get("date", ""), "mapHash": map_hash(id),
		"beta": bool(Crag.record(id).get("beta", false)) if id != "daily" else false,
		"go": go, "events": level.get("attempt_log") if level and level.get("attempt_log") != null else []})
	save()
	for n in news:
		Analytics.event("record_set", {"route": id, "kind": n[0]})
	var words: Array = news.map(func(n: Array) -> String: return n[1])
	var line := ""
	if not words.is_empty():
		line = "New personal record: " + "; ".join(words) + "."
	var rank_line := crag_rank_line(id, go)
	if rank_line != "":
		line = (line + " " + rank_line).strip_edges()
	return line


## The route's map as the server knows it (FNV-1a of the map text, the
## same function as the daily route's seed): a client on other maps is
## refused rather than ranked against them.
static func map_hash(id: String) -> int:
	return Daily.fnv1a(Crag.map_text(id))


func _route_go(id: String, go: Dictionary) -> Array:
	var r := crag_route(id)
	var news: Array = []
	var sent: bool = go["sent"]
	if sent:
		if int(r["firstAscent"]) == 0:
			r["firstAscent"] = go["t"]
			news.append(["first_ascent", "first ascent on this device"])
		if int(r["bestSeconds"]) < 0 or go["seconds"] < int(r["bestSeconds"]):
			if int(r["bestSeconds"]) > 0:
				news.append(["best_time", "best time %s (was %s)" % [_clock(go["seconds"]), _clock(int(r["bestSeconds"]))]])
			r["bestSeconds"] = go["seconds"]
		if go["falls"] == 0 and (int(r["bestCleanSeconds"]) < 0 or go["seconds"] < int(r["bestCleanSeconds"])):
			news.append(["fastest_clean", "fastest clean ascent %s" % _clock(go["seconds"]) + ((" (was %s)" % _clock(int(r["bestCleanSeconds"]))) if int(r["bestCleanSeconds"]) > 0 else "")])
			r["bestCleanSeconds"] = go["seconds"]
		for style in ["onsight", "flash", "redpoint"]:
			if go["style"] == style and int(r[style]) == 0:
				r[style] = go["t"]
				news.append([style, Crag.STYLES[style][0].to_lower()])
	elif go["rows"] > int(r["highRows"]):
		if int(r["highRows"]) > 0:
			news.append(["high_point", "high point %s m" % Crag._m(go["rows"] * Crag.ROW_M)])
		r["highRows"] = go["rows"]
	var goes: Array = r["goes"]
	goes.append(go)
	while goes.size() > KEEP_GOES:
		goes.pop_front()
	data["crag"][id] = r
	return news


func _daily_go(go: Dictionary) -> Array:
	var date := Crag.today()
	var day: Array = data["daily"].get(date, [])
	var news: Array = []
	var sends := day.filter(func(g: Dictionary) -> bool: return g["sent"])
	if go["sent"]:
		var best := -1
		for g in sends:
			best = int(g["seconds"]) if best < 0 else mini(best, int(g["seconds"]))
		if best > 0 and go["seconds"] < best:
			news.append(["daily_best", "today's best %s (was %s)" % [_clock(go["seconds"]), _clock(best)]])
	day.append(go)
	while day.size() > KEEP_GOES:
		day.pop_front()
	data["daily"][date] = day
	var keys: Array = data["daily"].keys()
	keys.sort()
	while keys.size() > KEEP_DAYS:
		data["daily"].erase(keys.pop_front())
	return news


## "Your 2nd best of 7 sends" (by time) or "your 3rd highest of 9 goes"
## (by height), among your own goes on this device.
func crag_rank_line(id: String, go: Dictionary) -> String:
	var goes: Array = data["daily"].get(Crag.today(), []) if id == "daily" else crag_route(id)["goes"]
	var where := " today" if id == "daily" else ""
	if go["sent"]:
		var times := goes.filter(func(g: Dictionary) -> bool: return g["sent"]).map(func(g: Dictionary) -> int: return int(g["seconds"]))
		if times.size() < 2:
			return ""
		return "Rank: %s of your %d sends%s (this device)." % [ordinal(rank_of(go["seconds"], times, true)), times.size(), where]
	var heights := goes.filter(func(g: Dictionary) -> bool: return not g["sent"]).map(func(g: Dictionary) -> int: return int(g["rows"]))
	if heights.size() < 2:
		return ""
	return "Height rank: %s of your %d goes short of the top%s (this device)." % [ordinal(rank_of(go["rows"], heights, false)), heights.size(), where]


static func _clock(s: int) -> String:
	return "%d:%02d" % [s / 60, s % 60]


# --- Expedition ------------------------------------------------------------

## A finished expedition: its record, from the game's own scoring.
## Completion is the summit AND the way down.
func expedition_finished(session: Dictionary) -> Dictionary:
	var s: Dictionary = session["state"]
	var sc := ExpeditionEngine.score(s)
	var t := Trek.ensure(session)
	var gone: Array = t.get("gone", [])
	var run := {
		"t": now(), "seed": int(s.get("seed", 0)), "route": String(t.get("route", "")),
		"difficulty": difficulty_of(String(t.get("route", ""))), "assisted": assisted(session),
		"score": int(sc["overall"]), "summit": bool(sc["summitReached"]), "returned": bool(sc["returnedSafely"]),
		"complete": bool(sc["summitReached"]) and bool(sc["returnedSafely"]),
		"judgment": int(sc["judgment"]), "risk": int(sc["riskManagement"]), "teamwork": int(sc["teamwork"]), "preparation": int(sc["preparation"]),
		"teamHome": 4 - gone.size() if bool(sc["returnedSafely"]) else 0, "sentDown": gone.size(),
		"health": int(s.get("health", 0)), "teamCondition": int(s.get("teamCondition", 0)), "supplies": int(s.get("supplies", 0)),
		"days": ExpeditionEngine.day_of(s), "verified": false,
	}
	var lp := leader_points(s, run["route"], run["teamHome"])
	run["points"] = lp["points"]
	run["leader"] = lp
	var runs: Array = data["expedition"]["runs"]
	var best_before := -1
	for r in runs:
		if r["difficulty"] == run["difficulty"] and r["assisted"] == run["assisted"]:
			best_before = maxi(best_before, int(r.get("points", r["score"])))
	run["newBest"] = best_before < 0 or run["points"] > best_before
	run["firstCompletion"] = run["complete"] and int(data["expedition"]["firstCompletion"]) == 0
	if run["firstCompletion"]:
		data["expedition"]["firstCompletion"] = run["t"]
	runs.append(run)
	while runs.size() > KEEP_RUNS:
		runs.pop_front()
	var keep := {}
	for k in ["ledger", "health", "energy", "teamCondition", "supplies", "oxygen", "summitReached", "returnedSafely", "highestAltitude", "elapsedHours", "seed"]:
		keep[k] = s.get(k)
	_enqueue("expedition", {"run": run, "state": keep, "route": run["route"],
		"history": s.get("history", []).map(func(h: Dictionary) -> String: return String(h.get("choice", "")))})
	save()
	if run["newBest"]:
		Analytics.event("record_set", {"route": "expedition", "kind": "score"})
	return run


## Leader points: what ranks an expedition on the boards. The score (the
## game's own, 0 to 100), and on top:
## - team: +10 when all four summit and come home; every teammate who did
##   not costs 8 on a run that reached the summit (fast at the top without
##   your team counts against you);
## - speed: 2 for each permit day left unused, up to 10;
## - stores: 1 for every 10 supplies left, up to 10.
## Speed and stores count only on a run where the whole team summited and
## came home: efficiency is worth something only when everyone made it.
## Ported to the records service (validate.leader_points).
const LEADER_MAX := 130
const LEADER_TEAM := 10
const LEADER_MISSING := 8


static func leader_points(s: Dictionary, route_id: String, team_home: int) -> Dictionary:
	var score := int(ExpeditionEngine.score(s)["overall"])
	var summit := bool(s.get("summitReached", false))
	var home := bool(s.get("returnedSafely", false))
	var everyone := summit and home and team_home >= 4
	var team := 0
	if everyone:
		team = LEADER_TEAM
	elif summit:
		team = -LEADER_MISSING * (4 - (clampi(team_home, 0, 4) if home else 0))
	var speed := 0
	var stores := 0
	if everyone:
		var permit: int = Trek.ROUTES.get(route_id, Trek.ROUTES["lemosho"])["permit"]
		var left := float(permit) * 24.0 - float(s.get("elapsedHours", 0))
		speed = ExpeditionEngine.js_round(clampf(left / 24.0, 0.0, 5.0) * 2.0)
		stores = ExpeditionEngine.js_round(clampf(float(s.get("supplies", 0)), 0.0, 100.0) / 10.0)
	return {"points": clampi(score + team + speed + stores, 0, LEADER_MAX), "score": score, "team": team, "speed": speed, "stores": stores}


## The route is the difficulty: the long way, the faster way, the fastest.
static func difficulty_of(route_id: String) -> String:
	return {"lemosho": "standard", "machame": "hard", "umbwe": "hardest"}.get(route_id, "standard")


const DIFFICULTY_NAMES := {"standard": "The long way (standard)", "hard": "The faster way (hard)", "hardest": "The fastest way (hardest)"}


## Assisted play: none of the game's options count as assistance yet, so
## every run is unassisted. The board is kept apart for when they exist.
static func assisted(_session: Dictionary) -> bool:
	return false


func expedition_board(difficulty: String, assisted_play: bool = false) -> Array:
	var runs: Array = data["expedition"]["runs"].filter(func(r: Dictionary) -> bool: return r["difficulty"] == difficulty and r["assisted"] == assisted_play)
	# Completed (summit and down) first, then by leader points; ties:
	# earlier first.
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["complete"] != b["complete"]:
			return a["complete"]
		if int(a["points"]) == int(b["points"]):
			return int(a["t"]) < int(b["t"])
		return int(a["points"]) > int(b["points"]))
	return runs


# --- World Passport --------------------------------------------------------

func passport() -> Dictionary:
	var crag_done := true
	var crag_sent := 0
	for r in Crag.ROUTES:
		if int(Crag.record(r["id"])["sends"]) > 0:
			crag_sent += 1
		else:
			crag_done = false
	var exp_done := int(data["expedition"]["firstCompletion"]) > 0
	var places := {
		"kilimanjaro": {"done": exp_done, "first": int(data["expedition"]["firstCompletion"]),
			"progress": "summit and down" if exp_done else "not completed (summit and come down)"},
		"lion-rock": {"done": crag_done, "first": _crag_all_first(),
			"progress": "%d of %d routes sent" % [crag_sent, Crag.ROUTES.size()]},
	}
	var continents := {}
	for id in PLACES:
		var c: String = PLACES[id]["continent"]
		var entry: Dictionary = continents.get(c, {"places": 0, "done": 0})
		entry["places"] += 1
		entry["done"] += 1 if places[id]["done"] else 0
		continents[c] = entry
	var achievements: Array = []
	if exp_done and crag_done:
		achievements.append("Rock and summit: every route at Lion Rock and Kilimanjaro there and back")
	var live := continents.keys().size()
	return {"places": places, "continents": continents, "achievements": achievements,
		"globalRanking": live >= GLOBAL_PASSPORT_MIN_CONTINENTS,
		"globalNote": "" if live >= GLOBAL_PASSPORT_MIN_CONTINENTS else "Global passport rankings start once places on more than one continent exist (now: %d)." % live}


## When the last crag route was first sent on this device (0 if not all).
func _crag_all_first() -> int:
	var latest := 0
	for r in Crag.ROUTES:
		var f := int(crag_route(r["id"])["firstAscent"])
		if f == 0:
			return 0
		latest = maxi(latest, f)
	return latest


# --- The online queue -------------------------------------------------------

## A finished attempt, kept to be sent when a service exists. Each has a
## unique id so a retry of the same submission is not counted twice.
func _enqueue(kind: String, payload: Dictionary) -> void:
	var q: Array = data["queue"]
	q.append({"id": Crypto.new().generate_random_bytes(12).hex_encode(), "kind": kind, "clientTime": now(),
		"player": data["player"]["localId"], "payload": payload, "status": "pending"})
	while q.size() > KEEP_QUEUE:
		q.pop_front()


func pending() -> Array:
	return data["queue"].filter(func(e: Dictionary) -> bool: return e["status"] == "pending")


## Sends what is waiting, if a service is configured. Returns how many the
## server accepted. Accepted entries are marked verified with the server's
## time; rejected ones say why and are never shown as verified.
func sync() -> int:
	if not online.configured():
		return 0
	var accepted := 0
	for e in pending():
		var reply: Dictionary = await online.submit(e)
		if reply.get("ok", false):
			e["status"] = "accepted"
			e["serverTime"] = int(reply.get("serverTime", 0))
			accepted += 1
		elif reply.get("retry", false):
			break
		else:
			e["status"] = "rejected"
			e["reason"] = String(reply.get("reason", ""))
	save()
	return accepted


# --- Sharing ------------------------------------------------------------------

## A personal record as text for sharing (no images or emoji needed).
func share_text(id: String) -> String:
	var lines := ["CLIMB UP · personal record (this device, not verified)"]
	if id == "expedition":
		var best: Array = expedition_board("standard") + expedition_board("hard") + expedition_board("hardest")
		best.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["points"]) > int(b["points"]))
		if best.is_empty():
			return ""
		var r: Dictionary = best[0]
		lines.append("Kilimanjaro · %s" % DIFFICULTY_NAMES[r["difficulty"]])
		lines.append("Leader points %d (score %d) · %s" % [int(r["points"]), int(r["score"]), "summit and back down" if r["complete"] else ("back down safely" if r["returned"] else "did not come down")])
	else:
		var route := Crag.route(id)
		var r := crag_route(id)
		lines.append("%s · grade %s" % [route["name"], route["grade"]])
		if int(r["bestCleanSeconds"]) > 0:
			lines.append("Fastest clean ascent %s" % _clock(int(r["bestCleanSeconds"])))
		elif int(r["bestSeconds"]) > 0:
			lines.append("Best time %s" % _clock(int(r["bestSeconds"])))
		elif int(r["highRows"]) > 0:
			lines.append("High point %s m" % Crag._m(int(r["highRows"]) * Crag.ROW_M))
		else:
			return ""
		var styles := []
		for s in ["onsight", "flash", "redpoint"]:
			if int(r[s]) > 0:
				styles.append(Crag.STYLES[s][0])
		if not styles.is_empty():
			lines.append(", ".join(styles))
	Analytics.event("record_shared", {"route": id})
	return "\n".join(lines)
