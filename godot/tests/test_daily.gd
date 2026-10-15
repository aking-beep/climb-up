extends CragBot
## The daily route: the same route for everyone on a date (seed, numbers
## and map are pure functions of the date and version), always a fair
## route (validated, and led to the top by the scripted climber across a
## run of days), logged per day with a streak, shareable as text and as a
## picture, and honest about a device clock turned back.

## 2026-10-13 12:00 UTC (a Tuesday).
const DAY := 1791892800


func _daily_fresh(unix: int = DAY) -> void:
	Crag.navigate = false
	Crag.reset()
	Crag.reset_daily()
	Crag.clock_override = unix
	# The lesson done: the daily route opens after it.
	Crag.tie_in("first-climb")
	Crag.finish("first-climb", true, 0, 60)


func _daily_done() -> void:
	Crag.reset()
	Crag.reset_daily()


func test_the_numbers_are_the_same_everywhere() -> void:
	# Reference values from an independent implementation (Python), and
	# mulberry32's well-known first output for seed 1.
	eq(Daily.fnv1a("climbup-daily-v1-2026-10-13-0"), 1057183616, "FNV-1a of the day's seed text")
	var rng := Daily.Rng.new(1)
	check(absf(rng.next() - 0.6270739405881613) < 1e-12, "mulberry32(1) gives its known first number")
	rng = Daily.Rng.new(1057183616)
	var want := [0.793362004, 0.544496522, 0.49219991, 0.903117958]
	for w in want:
		check(absf(rng.next() - w) < 1e-8, "the sequence matches (%f)" % w)
	eq(Daily.date_key(DAY), "2026-10-13", "dates are UTC")
	eq(Daily.date_key(DAY + 11 * 3600 + 59 * 60), "2026-10-13", "until midnight UTC")
	eq(Daily.date_key(DAY + 12 * 3600), "2026-10-14", "then the next day")


func test_one_route_per_day_the_same_for_everyone() -> void:
	var a := Daily.route_for("2026-10-13")
	var b := Daily.route_for("2026-10-13")
	eq(a["map"], b["map"], "the same date makes the same route")
	eq(a["hash"], Daily.fnv1a(a["map"]), "its hash is the map's")
	eq(a["version"], Daily.VERSION, "and carries its version")
	var maps := {}
	for i in 30:
		var r := Daily.route_for(Daily.date_key(DAY + i * 86400))
		maps[r["hash"]] = true
	check(maps.size() >= 28, "thirty days, thirty routes (%d different)" % maps.size())
	# The same seed text on another version is another route.
	check(Daily.seed_for("2026-10-13") != Daily.fnv1a("climbup-daily-v2-2026-10-13-0"), "a new version is a new set of routes")


func test_a_year_of_routes_is_fair() -> void:
	var tiers := {}
	var fallbacks := 0
	var subs := 0
	for i in 366:
		var date := Daily.date_key(DAY + i * 86400)
		var r := Daily.route_for(date)
		eq(Daily.validate(r["map"]), "", "%s is a fair route" % date)
		var t := Terrain.from_text(r["map"])
		check(t.markers.has("P") and t.markers.has("X") and t.markers.get("Q", []).size() >= 4, "%s: a start, an anchor and bolts" % date)
		tiers[r["tier"]] = true
		if int(r["sub"]) < 0:
			fallbacks += 1
		subs += int(r["sub"])
	eq(fallbacks, 0, "no day needs the fallback route")
	eq(tiers.size(), 4, "every tier of the week comes up")
	print("      a year of dailies: %.2f re-rolls a day on average" % (subs / 366.0))
	# The validator does reject unfair routes.
	check(Daily.validate("") != "", "no map")
	var tall := RouteBuilder.build([["up", 4], ["blank", 3], ["up", 20]], 14, 4, 0.0, 3)
	check("dyno" in Daily.validate(tall) or "blank" in Daily.validate(tall), "a blank taller than a dyno: " + Daily.validate(tall))
	var pump := RouteBuilder.build([["up", 4], ["crimps", 9], ["up", 12]], 14, 4, 0.0, 3)
	check(Daily.validate(pump) != "", "nine rows of crimps with no rest: " + Daily.validate(pump))


func test_daily_routes_can_be_climbed() -> void:
	# Two weeks, every tier twice: the scripted climber leads each one.
	var sent := 0
	for i in 14:
		_daily_fresh(DAY + i * 86400)
		var r := Crag.daily_route()
		await _load("daily", "neutral")
		var ok: bool = await lead(300.0)
		check(ok, "%s (%s, %s) sent; stopped at %s" % [r["date"], r["name"], r["grade"], where()])
		if ok:
			sent += 1
		eq(level.checkpoint, level.clips.size(), "%s: every bolt clipped" % r["date"])
		print("      daily %s %s (%s, tier %d): %d s, %d falls" % [r["date"], r["name"], r["grade"], r["tier"], int(c.clock), c.slips])
		await _done()
	eq(sent, 14, "every day's route goes to the top")
	_daily_done()


func test_daily_results_streaks_and_sharing() -> void:
	_daily_fresh()
	check(Crag.unlocked("daily"), "open after the lesson")
	Crag.tie_in("daily")
	var o := Crag.finish("daily", true, 1, 120)
	eq(o["style"], "falls", "a fall: not clean")
	Crag.tie_in("daily")
	o = Crag.finish("daily", true, 0, 100)
	eq(o["style"], "redpoint", "clean on the second go: redpoint")
	eq(o["fasterBy"], 20, "and faster")
	var d := Crag.daily_record()
	eq([d["attempts"], d["sends"], d["best"], d["bestSeconds"], d["bestFalls"]], [2, 2, "redpoint", 100, 0], "the day's log")
	eq(o["streak"], 1, "a streak starts")
	check("daily" in Crag.achievements, "the daily achievement")
	# The next day: a new route, a clean first go, the streak goes on.
	Crag.clock_override = DAY + 86400
	check(Crag.daily_route()["date"] == "2026-10-14", "a new day, a new route")
	Crag.tie_in("daily")
	o = Crag.finish("daily", true, 0, 90)
	eq(o["style"], "onsight", "first go today, clean: onsight")
	eq(o["streak"], 2, "two days running")
	check("daily-clean" in Crag.achievements, "the daily onsight achievement")
	var text := Crag.daily_share_text()
	for part in ["CLIMB UP", "2026-10-14", Crag.daily_route()["name"], "Onsight", "1:30", "0 falls", "Streak: 2 days"]:
		check(part in text, "the shared text has %s:\n%s" % [part, text])
	var p := Daily.payload(Crag.daily_route(), {"sent": true, "style": "onsight", "seconds": 90, "falls": 0})
	eq(p["hash"], Crag.daily_route()["hash"], "a server could check which route it was")
	check(not p.has("name") and not p.has("player"), "and nothing about the player")
	# A day missed: the streak starts again.
	Crag.clock_override = DAY + 3 * 86400
	Crag.tie_in("daily")
	eq(Crag.finish("daily", true, 0, 90)["streak"], 1, "a gap resets the streak")
	# Saved and loaded.
	Crag.load_daily()
	eq(Crag.daily_record(Daily.date_key(DAY))["best"], "redpoint", "the log is saved")
	eq(int(Crag.daily["streak"]), 1, "and the streak")
	_daily_done()


func test_a_clock_turned_back_does_not_count() -> void:
	_daily_fresh(DAY + 5 * 86400)
	Crag.see_daily()
	# Back to an earlier day to have another go at it.
	Crag.clock_override = DAY
	check(not Crag.daily_counts(), "the device's date is behind one already shown")
	Crag.tie_in("daily")
	var o := Crag.finish("daily", true, 0, 30)
	check(o["practice"], "the go is practice")
	eq(Crag.daily_record()["sends"], 0, "nothing logged for that day")
	eq(Crag.daily_record()["attempts"], 0, "not even the go")
	# The clock put right: counts again.
	Crag.clock_override = DAY + 5 * 86400
	check(Crag.daily_counts(), "back to today: it counts")
	# A save edited by hand cannot break it.
	SaveGame.write({"days": {"garbage": 3, "2026-10-13": {"attempts": "x", "best": "godlike"}}, "maxSeen": 7, "streak": -5}, Crag.DAILY_SAVE)
	Crag.load_daily()
	eq(Crag.daily_record("2026-10-13")["best"], "", "an unknown style is dropped")
	eq(int(Crag.daily["streak"]), 0, "a bad streak reads as 0")
	_daily_done()


func test_the_daily_level_offers_a_share() -> void:
	_daily_fresh()
	Crag.navigate = false
	Settings.touch_controls = false
	Crag.current = "daily"
	level = load(Crag.LEVEL).instantiate()
	root.add_child(level)
	await physics_frames(2)
	c = level.climber
	check("DAILY ROUTE" in level.panel.kicker_text(), "the brief says it is the daily route: " + level.panel.kicker_text())
	check(not level.panel.has_choice("beta"), "no beta on the daily route: everyone reads it fresh")
	level.panel.choose("neutral")
	await physics_frames(2)
	level.finish(true)
	await physics_frames(70)
	check(level.panel.open, "results shown")
	check(level.panel.has_choice("share"), "with a share button")
	level.panel.choose("share")
	await physics_frames(3)
	check("CLIMB UP" in level.shared_text, "sharing gives the result as text")
	eq(DisplayServer.clipboard_get() if DisplayServer.get_name() != "headless" else level.shared_text, level.shared_text, "copied")
	for i in 30:
		if level.panel.open:
			break
		await physics_frames(2)
	check(level.panel.open and level.panel.has_choice("menu"), "and the results come back: never a screen with no way on")
	await _done()
	_daily_done()
