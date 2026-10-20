extends ClimbBot
## Every played climb, on every route: the long way (easy), the faster way
## (medium) and the fastest way (hard) each have their own layout
## (tools/levels/route_levels.py). The scripted climber follows each
## layout's line through the real level, hazards and all, to the end; the
## climb must be finished, with time to spare on the slips, and keep its
## pacing (something to do every few seconds).
##
## ROUTES_ONLY=<climb>:<route> runs just one (e.g. lava-tower:umbwe); a
## comma-separated list runs several.

const CLIMBS := ["lava-tower", "barranco-wall", "summit-night", "descent"]


func _wanted(climb: String, route: String) -> bool:
	var only := OS.get_environment("ROUTES_ONLY")
	if only == "":
		return true
	for want in only.split(","):
		if want == "%s:%s" % [climb, route] or want == climb or want == route:
			return true
	return false


func _start(climb: String, route: String) -> bool:
	SaveGame.erase()
	Expedition.found = {}
	Expedition.navigate = false
	Settings.touch_controls = false
	var path: String
	if climb == "descent":
		Expedition.session = TestSessions.at("summit-night")
		var p: Dictionary = Expedition.pending()
		Expedition.session = Coordinator.resolve(Expedition.session, TestSessions.complete(p), Expedition.def)["session"]
		Trek.ensure(Expedition.session)["route"] = route
		var card := Expedition.card()
		for i in card["choices"].size():
			if String(card["choices"][i]["effect"].get("move", "")) in ["retreat", "down"]:
				Expedition.choose(i)
				break
		path = Expedition.DESCENT
	else:
		Expedition.session = TestSessions.at(climb)
		if Expedition.session.is_empty():
			failures.append("the careful party never reached %s" % climb)
			return false
		Trek.ensure(Expedition.session)["route"] = route
		Expedition.climb = {}
		Expedition.resume_climb()
		path = Expedition.LEVELS[climb]
	outcome = null
	level = load(path).instantiate()
	root.add_child(level)
	level.finished.connect(func(o: ChallengeOutcome) -> void: outcome = o)
	await physics_frames(2)
	if not level.panel.open:
		failures.append("the brief is shown first")
		return false
	level.panel.choose("start")
	await physics_frames(1)
	c = level.climber
	return true


func _play(climb: String) -> void:
	var navigate := Expedition.navigate
	for route in Trek.ROUTES:
		if not _wanted(climb, route):
			continue
		if not await _start(climb, route):
			continue
		eq(level.route, route, "%s is laid out for %s" % [climb, route])
		var ok := await follow(level.layout.get("script", []))
		check(ok and outcome != null, "%s on %s: the line followed to the end" % [climb, route])
		if outcome:
			eq(outcome.result, "complete", "%s on %s: finished" % [climb, route])
			check(outcome.slips < level.max_slips, "%s on %s: with slips to spare (%d of %d)" % [climb, route, outcome.slips, level.max_slips])
			if climb != "descent":
				check_pacing("%s (%s)" % [climb, route])
			print("      %s %s: %d s of game time, %d%% stamina left, %d slips, %.0f s resting, lowest %d%% of a %d bar, artifacts %d/%d, %d retries" % [climb, route,
				outcome.seconds, outcome.stamina_left, outcome.slips, outcome.rest_seconds, int(level.lowest_stamina * 100), int(c.stamina.max_value),
				outcome.artifacts, outcome.artifacts_total, retries])
			if outcome and outcome.slips > 0:
				print("      slips by cause: ", level.slips_by_cause)
			print("      %s %s: %d%% of the moving time on the rock (%.0f s climbing, %.0f s walking)" % [climb, route, int(level.climbing_share() * 100.0), level.climbing, level.travel])
			if route == "umbwe" and climb != "descent":
				# The fastest way is a climbing route: most of it on the rock,
				# clipping and pulling up, the rest walking.
				check(level.climbing_share() >= 0.6, "%s on %s: at least 60%% of the moving time climbing (%d%%)" % [climb, route, int(level.climbing_share() * 100.0)])
			# The fastest way's pitches: led on the rope, every partner pulled
			# up at every anchor.
			var al: Alpine = level.alpine
			eq(al != null, route == "umbwe" and climb != "descent", "%s on %s: alpine pitches on the fastest way only" % [climb, route])
			if al:
				eq(al.hauls, al.pitches.size(), "%s on %s: the partner pulled up every pitch" % [climb, route])
				var pins := 0
				for p in al.pitches:
					pins += p["pitons"].size()
				check(al.clips_made >= pins, "%s on %s: clipped as it led (%d clips for %d pitons, more after a fall)" % [climb, route, al.clips_made, pins])
				print("      %s %s: %d pitches, %d clips, %d falls held by the rope" % [climb, route, al.pitches.size(), al.clips_made, c.rope_falls])
			# The results card, then the outcome lands on the expedition.
			await drive([], func() -> bool: return level.panel.open, 5.0, "panel")
			check(level.panel.open and level.panel._title.text != "", "%s on %s: the results card shows" % [climb, route])
			level.panel.choose("camp")
			await physics_frames(2)
			if climb == "descent":
				check(Expedition.trek()["descent"].get("played", false), "the way down landed on the expedition")
			else:
				check(Expedition.pending() == null, "%s on %s: the climb is closed" % [climb, route])
			if climb == "summit-night":
				check(Expedition.state()["summitReached"], "the summit is recorded on the expedition")
		retries = 0
		GameInput.scripted = {}
		level.queue_free()
		await physics_frames(2)
		SaveGame.erase()
	Expedition.navigate = navigate


func test_the_lava_tower_on_every_route() -> void:
	await _play("lava-tower")


func test_the_barranco_wall_on_every_route() -> void:
	await _play("barranco-wall")


func test_summit_night_on_every_route() -> void:
	await _play("summit-night")


func test_the_way_down_on_every_route() -> void:
	await _play("descent")
