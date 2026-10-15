class_name Daily
extends RefCounted
## The daily route: one new crag route each UTC day, the same for every
## player on the same date and VERSION. Everything here is a pure function
## of the date: the seed (FNV-1a of "climbup-daily-v<VERSION>-<date>"), the
## random numbers (mulberry32, written out here so they never change with
## the engine), the route's segments and its map. Nothing needs a network.
##
## A route is only offered once it passes validate(): it builds, it starts
## at the foot and ends at the anchor, the line is continuous (blank rock
## only in two-row gaps, holds straight above and below), every bolt is in
## reach of the line, no stretch of hard holds is longer than a fit climber
## can do, and a stamina budget walked up the route never runs dry. If a
## day's first try fails, the next sub-seed is tried, deterministically. A
## test also leads a run of days with the scripted climber.
##
## For leaderboards later: payload() is what a server would need to check a
## result (date, version, the route's hash, the go), and the seed and route
## can be rebuilt there from the date alone.

const VERSION := 1
## Difficulty by day of the week (Sunday 0): easier early in the week.
const WEEKDAY_TIER := [4, 1, 2, 2, 3, 3, 4]
const GRADES := ["5a", "5c", "6a+", "6b+", "6c+"]
const NAMES_A := ["Granite", "Amber", "Quiet", "Swallow", "Ember", "Juniper", "Falcon", "Hollow", "Saffron", "Lantern", "Cedar", "Kestrel"]
const NAMES_B := ["Whisper", "Ladder", "Arete", "Seam", "Ribbon", "Prow", "Groove", "Spine", "Corner", "Pillar", "Flake", "Slab"]
## The most rows of crimps or slopers in a row before a rest is required.
const MAX_HARD := 6
const MIN_ROWS := 26
const MAX_ROWS := 48


## "YYYY-MM-DD" for a UTC unix time.
static func date_key(unix: int) -> String:
	var d := Time.get_date_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


static func today() -> String:
	return date_key(int(Time.get_unix_time_from_system()))


## FNV-1a, 32 bit, over the UTF-8 bytes.
static func fnv1a(text: String) -> int:
	var h := 0x811c9dc5
	for b in text.to_utf8_buffer():
		h = h ^ b
		h = (h * 0x01000193) & 0xffffffff
	return h


static func seed_for(date: String, sub: int = 0) -> int:
	return fnv1a("climbup-daily-v%d-%s-%d" % [VERSION, date, sub])


## mulberry32: a tiny, well-known PRNG, the same on every platform.
class Rng:
	var state := 0

	func _init(s: int) -> void:
		state = s & 0xffffffff

	func next() -> float:
		state = (state + 0x6D2B79F5) & 0xffffffff
		var t := state
		t = _imul(t ^ (t >> 15), t | 1)
		t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xffffffff
		return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

	func range_int(lo: int, hi: int) -> int:
		return lo + int(next() * float(hi - lo + 1))

	func pick(a: Array) -> Variant:
		return a[int(next() * a.size())]

	static func _imul(a: int, b: int) -> int:
		return (a * b) & 0xffffffff


static func tier_for(date: String) -> int:
	var parts := date.split("-")
	var unix := Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 12})
	return WEEKDAY_TIER[Time.get_datetime_dict_from_unix_time(unix)["weekday"]]


## The day's route: {id, date, version, seed, sub, name, grade, tier, level,
## falls, gripDrain, skill, text, crux, segments, x0, bolts, spread, first,
## map, hash}. Always a valid route (falls back to a fixed one if fifty
## sub-seeds fail, which the tests show does not happen).
static func route_for(date: String) -> Dictionary:
	var tier := tier_for(date)
	for sub in 50:
		var r := _generate(date, tier, sub)
		if not r.is_empty() and validate(r["map"]).is_empty():
			return r
	return _fallback(date)


static func _generate(date: String, tier: int, sub: int) -> Dictionary:
	var rng := Rng.new(seed_for(date, sub))
	var segs: Array = [["up", rng.range_int(3, 5)]]
	var x := rng.range_int(12, 18)
	var x0 := x
	var rows := int(segs[0][1])
	var target := rng.range_int(MIN_ROWS + tier * 2, mini(MAX_ROWS, MIN_ROWS + 8 + tier * 4))
	var dynos := 0
	var since_rest := 0
	var traverses := 0
	var featured: String = rng.pick(["crimps", "slopers", "pockets", "dyno", "traverse"])
	while rows < target - 3:
		var options: Array = ["up", "crimps", "jug"]
		if tier >= 2:
			options.append("slopers")
		options.append("pockets")
		if tier >= 2 and dynos < (2 if tier >= 4 else 1) and segs[-1][0] in ["jug", "up", "pockets"]:
			options.append("blank")
		if traverses < 2:
			options.append("traverse")
		# The day's feature comes up more often.
		var kind: String = featured if rng.next() < 0.3 else rng.pick(options)
		if kind == "dyno":
			kind = "blank"
		if kind == "blank" and not "blank" in options:
			kind = "up"
		if kind == "traverse" and not "traverse" in options:
			kind = "up"
		if kind == "slopers" and tier < 2:
			kind = "crimps"
		var hard := 0
		match kind:
			"up":
				segs.append(["up", rng.range_int(2, 4)])
			"crimps":
				hard = rng.range_int(2, 2 + tier)
				segs.append(["crimps", hard])
			"slopers":
				hard = rng.range_int(2, 3)
				segs.append(["slopers", hard])
			"pockets":
				segs.append(["pockets", 2])
			"jug":
				segs.append(["jug", 2])
				since_rest = 0
			"blank":
				segs.append(["blank", 2])
				segs.append(["up" if tier < 3 else rng.pick(["up", "crimps"]), 2])
				dynos += 1
			"traverse":
				var dir: int = 1 if x < 18 else -1
				var dx: int = dir * rng.range_int(5, 8)
				if x + dx < RouteBuilder.WALL_X + 1 or x + dx + RouteBuilder.WIDTH > RouteBuilder.W - 8:
					dx = -dx
				var hold: String = rng.pick(["k", "z", "u"] if tier >= 2 else ["k", "u"])
				# A sideways band of hard holds starts from a rest.
				if hold != "u" and not segs[-1][0] in ["jug", "pockets"]:
					segs.append(["jug", 2])
					since_rest = 0
				segs.append(["traverse", dx, rng.range_int(3, 4) if hold == "z" else rng.range_int(3, 5), tier >= 3 and rng.next() < 0.5, hold])
				x += dx
				traverses += 1
		if hard > 0:
			since_rest += hard
			if since_rest > MAX_HARD:
				segs.append(["jug", 2])
				since_rest = 0
		elif kind in ["up", "pockets"]:
			since_rest = maxi(0, since_rest - 2)
		rows = RouteBuilder.rows_of(segs)
	segs.append(["up", maxi(2, target - rows)])
	# Bolting, apart from the grade: any tier can be well bolted or run-out.
	var bolts := rng.range_int(4, 8)
	var spread: float = [0.0, 0.1, 0.25, 0.45][rng.range_int(0, 3)]
	var first := rng.range_int(3, 5)
	var map := RouteBuilder.build(segs, x0, bolts, spread, first)
	if map == "":
		return {}
	var name := "%s %s" % [NAMES_A[rng.range_int(0, NAMES_A.size() - 1)], NAMES_B[rng.range_int(0, NAMES_B.size() - 1)]]
	var skill: String = {"crimps": "Squeeze timing", "slopers": "Slow and steady", "pockets": "Clip, rest, repeat", "dyno": "The leap", "traverse": "Sideways"}[featured]
	return {"id": "daily", "date": date, "version": VERSION, "seed": seed_for(date, sub), "sub": sub, "name": name,
		"grade": GRADES[tier], "tier": tier, "level": ["easy", "moderate", "hard", "harder", "very hard"][tier],
		"falls": 5 if tier < 3 else 4, "gripDrain": 0.35 + 0.15 * tier, "skill": skill,
		"text": "Today's route, the same for every climber. Featuring: %s." % skill.to_lower(),
		"crux": "Read it from the ground first.", "segments": segs, "x0": x0, "bolts": bolts, "spread": spread,
		"first": first, "map": map, "hash": fnv1a(map)}


static func _fallback(date: String) -> Dictionary:
	var segs: Array = [["up", 5], ["crimps", 3], ["up", 3], ["jug", 2], ["up", 4], ["slopers", 2], ["up", 3], ["pockets", 2], ["up", 4], ["crimps", 3], ["up", 3]]
	var map := RouteBuilder.build(segs, 14, 6, 0.0, 3)
	return {"id": "daily", "date": date, "version": VERSION, "seed": 0, "sub": -1, "name": "Steady Ladder", "grade": "5c", "tier": 1,
		"level": "moderate", "falls": 5, "gripDrain": 0.45, "skill": "Clip, rest, repeat", "text": "Today's route.", "crux": "",
		"segments": segs, "x0": 14, "bolts": 6, "spread": 0.0, "first": 3, "map": map, "hash": fnv1a(map)}


## Why a map is not a fair route, or "" when it is.
static func validate(map: String) -> String:
	if map == "":
		return "no map"
	var t := Terrain.from_text(map)
	for m in ["P", "X", "Q"]:
		if not t.markers.has(m):
			return "missing marker " + m
	var foot: int = (t.markers["P"][0] as Vector2i).y
	var anchor: Vector2i = t.markers["X"][0]
	var ledge := anchor.y + 1
	# The line, row by row from the foot up: its columns.
	var prev: Array = []
	var prev_wide := false
	var blank := 0
	var hard := 0
	var stamina := 100.0
	for y in range(foot, ledge - 1, -1):
		var cols: Array = []
		var k := Terrain.Kind.AIR
		for x in t.width:
			if t.is_climbable(Vector2i(x, y)):
				cols.append(x)
				var kk := t.kind(Vector2i(x, y))
				if kk == Terrain.Kind.CRIMP or kk == Terrain.Kind.SLOPER or k == Terrain.Kind.AIR:
					k = kk
		if cols.is_empty():
			blank += 1
			if blank > 2:
				return "blank rock taller than a dyno at row %d" % y
			continue
		if blank > 0:
			# Across a blank: holds straight above the ones below.
			var over := false
			for x in cols:
				if prev.has(x):
					over = true
			if not over:
				return "a dyno with nothing straight above at row %d" % y
			stamina -= Climber.DYNO_COST
		elif not prev.is_empty():
			var touch := false
			for x in cols:
				if prev.has(x) or prev.has(x - 1) or prev.has(x + 1):
					touch = true
			if not touch:
				return "the line breaks at row %d" % y
		blank = 0
		prev = cols
		# A sideways band (two rows wider than the line): each cell across
		# costs by its hold, once per band.
		var wide := cols.size() > RouteBuilder.WIDTH
		if wide and not prev_wide:
			for x in cols:
				match t.kind(Vector2i(x, y)):
					Terrain.Kind.SLOPER:
						stamina -= 7.0
					Terrain.Kind.CRIMP:
						stamina -= 5.0
					_:
						stamina -= 3.0
			stamina += 3.0 * RouteBuilder.WIDTH
		prev_wide = wide
		# A stamina budget at a steady pace (a row is half a second up).
		match k:
			Terrain.Kind.CRIMP:
				hard += 1
				stamina -= StaminaModel.RATES["crimp"] * 0.5 * 0.8
			Terrain.Kind.SLOPER:
				hard += 1
				stamina -= StaminaModel.RATES["sloper"] * 0.9
			Terrain.Kind.JUG:
				hard = 0
				stamina = minf(100.0, stamina + 40.0)
			Terrain.Kind.POCKET:
				hard = maxi(0, hard - 1)
				stamina = minf(100.0, stamina + 10.0)
			_:
				hard = maxi(0, hard - 1)
				stamina -= StaminaModel.RATES["climb"] * 0.5
		if hard > MAX_HARD:
			return "%d rows of hard holds without a rest at row %d" % [hard, y]
		if stamina < 20.0:
			return "the stamina budget runs out at row %d" % y
	if blank > 0:
		return "blank rock at the top"
	# The ledge: the line goes through it to the anchor.
	if not t.is_climbable(Vector2i(anchor.x - RouteBuilder.WIDTH - 1, ledge)) and not t.is_climbable(Vector2i(anchor.x - RouteBuilder.WIDTH - 2, ledge)):
		return "no way through the ledge to the anchor"
	# Every bolt within clipping reach of the line.
	for q in t.markers["Q"]:
		var near := false
		for dx in range(-4, 5):
			if t.is_climbable((q as Vector2i) + Vector2i(dx, 0)):
				near = true
		if not near:
			return "bolt at %s out of reach" % q
	return ""


## What a server would need to check a daily result (no player identity).
static func payload(route: Dictionary, go: Dictionary) -> Dictionary:
	return {"v": VERSION, "date": route["date"], "seed": route["seed"], "hash": route["hash"],
		"sent": go.get("sent", false), "style": go.get("style", ""), "seconds": go.get("seconds", 0), "falls": go.get("falls", 0)}
