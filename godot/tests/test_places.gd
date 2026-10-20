extends TestCase
## Each route goes its own way up the mountain (Places): three played climbs
## per route, nine places in all, each with its own name, ground, sky and
## gear; the route sets the stamina bar (full, half, a quarter) and how much
## a knock hurts (half on the long way); what you find lies off the line,
## up a wall you climb for it; and the camp names the route's own camps and
## climbs.

const CLIMBS := ["lava-tower", "barranco-wall", "summit-night"]

var level: Node


func _load(climb: String, route: String) -> Node:
	SaveGame.erase()
	Expedition.found = {}
	Expedition.navigate = false
	Expedition.session = TestSessions.at(climb)
	Trek.ensure(Expedition.session)["route"] = route
	# The same body on every route, so only the route differs.
	Expedition.state()["energy"] = 100
	Expedition.climb = {}
	Expedition.resume_climb()
	level = load(Expedition.LEVELS[climb]).instantiate()
	root.add_child(level)
	await physics_frames(2)
	return level


func _done() -> void:
	GameInput.scripted = {}
	if level:
		level.queue_free()
		level = null
	await physics_frames(2)
	SaveGame.erase()


func test_nine_places_each_its_own() -> void:
	var names := {}
	for climb in CLIMBS:
		var looks := {}
		for route in Trek.ROUTES:
			var lvl: Node = await _load(climb, route)
			var place := Places.climb_name(climb, route)
			eq(lvl.spec["place"], place, "%s on %s is %s" % [climb, route, place])
			check(place.ends_with(String(lvl.spec["hud"])), "the HUD names the place: %s" % lvl.spec["hud"])
			names[place] = true
			var theme: Dictionary = lvl.spec["theme"]
			# What you see: the sky, the rock's colours, the skyline, the far
			# painting, the plants, the weather.
			var look := JSON.stringify([theme.get("sky", []), theme.get("ramp", []), theme.get("skylines", []), theme.get("far", ""),
				theme.get("deep", ""), theme.get("flora", {}), theme.get("weather", ""), theme.get("night", false)])
			check(not looks.has(look), "%s on %s looks like no other route's" % [climb, route])
			looks[look] = true
			# Its own people's words and signs.
			check(not String(lvl.spec["copy"]["brief"]).is_empty(), "%s has a brief" % place)
			eq(lvl.layout.get("signs", []).size(), lvl.spec["signs"].size(), "%s: a sign for every sign's words" % place)
			await _done()
	eq(names.size(), 9, "nine different places: %s" % ", ".join(names.keys()))


func test_each_route_has_its_own_gear_and_artifacts() -> void:
	for climb in CLIMBS:
		var seen := {}
		for route in Trek.ROUTES:
			var lvl: Node = await _load(climb, route)
			var words: Array = lvl.gear_words()
			var key := JSON.stringify(words.map(func(w: Array) -> Array: return [w[0], w[1]]))
			check(not seen.has(key), "%s on %s: its own gear and where it lies" % [climb, route])
			seen[key] = true
			var arts := Artifacts.for_climb(climb, route)
			eq(arts.size(), 2, "two artifacts belong to %s" % Places.climb_name(climb, route))
			await _done()


func test_the_bar_is_full_half_and_a_quarter() -> void:
	var bars := {}
	for route in Trek.ROUTES:
		var lvl: Node = await _load("lava-tower", route)
		bars[route] = lvl.stamina.max_value
		await _done()
	check(bars["lemosho"] >= 80.0, "the long way: the full bar (%d)" % int(bars["lemosho"]))
	check(absf(bars["machame"] - bars["lemosho"] * 0.5) <= 1.0, "the faster way: half of it (%d of %d)" % [int(bars["machame"]), int(bars["lemosho"])])
	check(absf(bars["umbwe"] - maxf(Trek.MIN_BAR["umbwe"], bars["lemosho"] * 0.25)) <= 1.0, "the fastest way: a quarter (%d of %d)" % [int(bars["umbwe"]), int(bars["lemosho"])])
	check(bars["umbwe"] < bars["machame"] and bars["machame"] < bars["lemosho"], "smaller every route harder")


func test_knocks_hurt_half_as_much_on_the_long_way() -> void:
	var lost := {}
	for route in Trek.ROUTES:
		var lvl: Node = await _load("lava-tower", route)
		lvl.panel.choose("start")
		await physics_frames(2)
		var c: Climber = lvl.climber
		c.stamina.value = c.stamina.max_value
		var before := c.stamina.value
		check(c.hurt(10.0, "thistle"), "a thistle")
		lost[route] = before - c.stamina.value
		await _done()
	eq(lost["lemosho"], 5.0, "the long way: half the hurt")
	eq(lost["machame"], 10.0, "the faster way: all of it")
	eq(lost["umbwe"], 10.0, "the fastest way: all of it, out of a quarter of the bar")


## Every obstacle costs something: a stone or a fall that knocks you off
## takes a slip and a bruise off the bar you get back at the cairn.
func test_being_knocked_off_hurts() -> void:
	var lvl: Node = await _load("lava-tower", "machame")
	lvl.panel.choose("start")
	await physics_frames(2)
	var c: Climber = lvl.climber
	c.stamina.value = c.stamina.max_value * 0.3
	var slips := c.slips
	c.slip("rock")
	await drive_until(func() -> bool: return c.state == Climber.State.GROUND, 6.0)
	eq(c.slips, slips + 1, "a slip")
	var want := maxf(c.stamina.max_value * 0.25, c.stamina.max_value * 0.5 - Climber.KNOCK["rock"])
	check(absf(c.stamina.value - want) < 1.5, "the bruise comes off what you get back (%.1f, want %.1f)" % [c.stamina.value, want])
	await _done()


## The finds lie off the line: every piece of gear and both artifacts sit on
## a ledge with open air under it (the path goes on below), next to a wall
## you climb to reach it, and the line's script climbs up for each.
func test_finds_are_off_the_line() -> void:
	for climb in CLIMBS + ["descent"]:
		for route in Trek.ROUTES:
			var base: String = {"lava-tower": "lava_tower/lava_tower", "barranco-wall": "barranco/barranco",
				"summit-night": "summit_night/summit_night", "descent": "descent/descent"}[climb]
			var path := "res://modes/expedition/levels/kilimanjaro/%s_%s" % [base, route]
			var t := Terrain.load_file(path + ".txt")
			var lay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".json"))
			var finds: Array = lay["gear"] + lay["artifacts"]
			var fetches: Array = lay["script"].filter(func(a: Array) -> bool: return a[0] == "fetch")
			eq(fetches.size(), finds.size(), "%s %s: the line climbs up for every find" % [climb, route])
			for f in finds:
				var cell := Vector2i(int(f[0]), int(f[1]))
				check(t.is_solid(cell + Vector2i.DOWN), "%s %s: %s stands on a ledge" % [climb, route, cell])
				var open_below := 0
				for dy in range(2, 6):
					if not t.is_solid(cell + Vector2i(0, dy)):
						open_below += 1
				check(open_below >= 2, "%s %s: open air under the ledge at %s (the path goes on below)" % [climb, route, cell])
				var wall := false
				for dx in range(-5, 0):
					if t.is_climbable(cell + Vector2i(dx, 1)):
						wall = true
				check(wall, "%s %s: a wall to climb up to %s" % [climb, route, cell])


func test_the_camp_names_the_routes_places() -> void:
	eq(Places.say("Up to Lava Tower for the air", "umbwe"), "Up to the Umbwe Ridge for the air", "the fastest way climbs the Umbwe Ridge")
	eq(Places.say("the Barranco Wall", "lemosho"), "the Karanga Valley", "the long way's middle climb")
	eq(Places.say("Londorossi Gate", "machame"), "Machame Gate", "each route starts at its own gate")
	eq(Places.say("Londorossi Gate", ""), "Londorossi Gate", "before a route is chosen: the engine's words")
	eq(Places.stop_name("camp4", "umbwe"), "Arrow Glacier Camp", "the fastest way's last camp")
	eq(Places.stop_name("camp4", "lemosho"), "Barafu Camp", "the long way's")
	var card := Trek.route_card()
	for ch in card["choices"]:
		for climb in CLIMBS:
			check(Places.climb_name(climb, String(ch["route"])) in String(ch["detail"]), "the route card lists %s" % Places.climb_name(climb, String(ch["route"])))
	# The faster ways carry less.
	check(int(Trek.ROUTES["machame"]["supplies"]) < int(Trek.ROUTES["lemosho"]["supplies"]), "less food the faster way")
	check(int(Trek.ROUTES["umbwe"]["supplies"]) < int(Trek.ROUTES["machame"]["supplies"]), "and less again the fastest")


func drive_until(done: Callable, seconds: float) -> void:
	var deadline := Engine.get_physics_frames() + int(seconds * 60.0)
	while Engine.get_physics_frames() < deadline and not done.call():
		await tree.physics_frame
