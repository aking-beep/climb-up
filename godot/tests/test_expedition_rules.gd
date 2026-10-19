extends ClimbBot
## The rules of breath on the mountain, played in the real levels: only
## REST gives stamina back; every obstacle (walking, uphill, hops, ice,
## rock) costs it; a gust is sat out with REST; and gear makes a climb
## easier for as long as the attempt lasts.

const BARRANCO := "res://modes/expedition/levels/kilimanjaro/barranco/barranco.tscn"
const SUMMIT := "res://modes/expedition/levels/kilimanjaro/summit_night/summit_night.tscn"


func _load(path: String, fresh: bool = true) -> void:
	if fresh:
		Expedition.new_expedition(7)
	Settings.touch_controls = false
	level = load(path).instantiate()
	root.add_child(level)
	level.finished.connect(func(o: ChallengeOutcome) -> void: outcome = o)
	await physics_frames(2)
	level.panel.choose("start")
	await physics_frames(1)
	c = level.climber


func _done() -> void:
	GameInput.scripted = {}
	level.queue_free()
	await physics_frames(2)


func _hold(actions: Array, frames: int) -> void:
	var held := {"_": false}
	for a in actions:
		held[a] = true
	for i in frames:
		GameInput.scripted = held
		await tree.physics_frame
	GameInput.scripted = {"_": false}


func test_standing_still_gives_nothing_back_only_rest_does() -> void:
	await _load(BARRANCO)
	await physics_frames(5)
	c.stamina.value = c.stamina.max_value * 0.5
	var before := c.stamina.value
	await _hold([], 120)
	eq(c.state, Climber.State.GROUND, "standing")
	check(c.stamina.value <= before, "two seconds standing still gives nothing back (%.1f -> %.1f)" % [before, c.stamina.value])
	before = c.stamina.value
	await _hold(["rest"], 1)
	await _hold([], 120)
	eq(c.state, Climber.State.REST, "sitting")
	check(c.stamina.value > before + 10.0, "two seconds of REST gives breath back (%.1f -> %.1f)" % [before, c.stamina.value])
	# The crag keeps its old rule: a standing shake-out there still helps.
	var crag := StaminaModel.new(80.0)
	check(crag.rate("still") < 0.0, "standing still recovers at the crag")
	eq(level.stamina.rate("still"), 0.0, "and not on the mountain")
	await _done()


func test_walking_uphill_and_hopping_cost_stamina() -> void:
	await _load(BARRANCO)
	await physics_frames(5)
	# Out of camp: flat ground, then the slope up to the wall foot.
	var before := c.stamina.value
	var seen_up := false
	var up_cost := 0.0
	for i in 60 * 30:
		if tx() >= 50.0:
			break
		var v := c.stamina.value
		var held := {"_": false, "move_right": true}
		_hop(held)
		GameInput.scripted = held
		await tree.physics_frame
		if c.last_activity == "walk_up":
			seen_up = true
			up_cost += v - c.stamina.value
	GameInput.scripted = {"_": false}
	check(seen_up, "the slope out of camp is uphill walking")
	check(up_cost > 0.0, "walking uphill costs stamina (%.2f)" % up_cost)
	check(c.stamina.value < before, "walking costs stamina")
	check(level.stamina.rate("walk_up") > level.stamina.rate("walk"), "uphill costs more than the flat")
	# A hop.
	await physics_frames(10)
	before = c.stamina.value
	var jumps := c.jumps
	await _hold(["jump"], 2)
	check(c.jumps == jumps + 1, "hopped")
	check(c.stamina.value < before, "a hop costs stamina (%.1f -> %.1f)" % [before, c.stamina.value])
	await physics_frames(60)
	# Climbing rock.
	check(level.stamina.rate("climb") > level.stamina.rate("walk_up"), "rock costs more than walking")
	await _done()


func test_ice_costs_stamina_and_crampons_make_it_easy() -> void:
	await _load(SUMMIT)
	var ice: Array = []
	for y in level.terrain.height:
		for x in level.terrain.width:
			if level.terrain.kind(Vector2i(x, y)) == Terrain.Kind.ICE and level.terrain.kind(Vector2i(x, y - 1)) == Terrain.Kind.AIR \
					and level.terrain.kind(Vector2i(x + 1, y)) == Terrain.Kind.ICE and level.terrain.kind(Vector2i(x + 2, y)) == Terrain.Kind.ICE \
					and level.terrain.kind(Vector2i(x + 3, y)) == Terrain.Kind.ICE:
				ice.append(Vector2i(x, y))
	check(not ice.is_empty(), "the summit has ice to walk on")
	var cell: Vector2i = ice[0]
	c.global_position = Terrain.feet(cell - Vector2i(0, 1))
	await physics_frames(5)
	check(c.on_ice or level.terrain.kind(cell) == Terrain.Kind.ICE, "standing on ice")
	var before := c.stamina.value
	var on := 0
	for i in 30:
		GameInput.scripted = {"_": false, "move_right": true}
		await tree.physics_frame
		if c.last_activity == "ice":
			on += 1
	GameInput.scripted = {"_": false}
	check(on > 0, "walked on ice")
	check(c.stamina.value < before, "ice costs stamina")
	var bare: float = level.stamina.rate("ice")
	check(bare > 0.0, "ice drains")
	# Crampons: half the cost, and no sliding.
	level.gear_kinds.append("crampons")
	level._apply_gear()
	check(level.stamina.rate("ice") < bare * 0.6, "crampons halve what ice costs")
	check(c.crampons, "crampons on")
	await _done()


func test_gear_helps_and_is_lost_with_the_climb() -> void:
	Expedition.new_expedition(7)
	Expedition.climb = {"challengeId": "barranco-wall", "attemptId": "gear-test"}
	await _load(BARRANCO, false)
	var spec_gear: Array = level.spec["gear"]
	eq(spec_gear.size(), 5, "five pieces of gear on the wall")
	eq(level.hazards.gear_total(), 5, "and five on the map")
	for g in spec_gear:
		check(ClimbLevel.GEAR.has(String(g[2])), "%s is a known kind" % g[2])
	var rock: float = level.stamina.rate("climb")
	var walk: float = level.stamina.rate("walk")
	# Pick up the gloves (before the faces) and the poles (for the walk out),
	# by the cells the spec names.
	var cell_of := {}
	for g in spec_gear:
		cell_of[String(g[2])] = Vector2i(int(g[3][0]), int(g[3][1]))
	for kind in ["gloves", "poles"]:
		c.global_position = Terrain.feet(cell_of[kind])
		await physics_frames(4)
	check(level.gear_kinds.has("gloves"), "found the gloves")
	check(level.gear_kinds.has("poles"), "found the poles")
	check(level.stamina.rate("climb") < rock, "gloves: rock costs less")
	check(level.stamina.rate("walk") < walk, "poles: walking costs less")
	eq(level.hazards.gear_count, 2, "two found")
	eq((Expedition.climb.get("gear", []) as Array).size(), 2, "kept for this attempt (resume)")
	# A fall into a hole: back to the start with nothing, and the gear is back
	# where it was.
	c.slip("hole")
	await drive([], func() -> bool: return c.state == Climber.State.GROUND, 5.0, "back at the start")
	eq(level.gear_kinds.size(), 0, "no gear after the hole")
	eq(level.hazards.gear_count, 0, "gear count reset")
	eq(level.stamina.rate("climb"), rock, "rock back to full cost")
	eq((Expedition.climb.get("gear", []) as Array).size(), 0, "nothing kept")
	var shown := 0
	for p in level.hazards.pickups:
		if p["kind"] == "gear" and not p["taken"] and p["node"].visible:
			shown += 1
	eq(shown, 5, "all five back on the ground")
	# Losing the climb also drops it.
	c.global_position = Terrain.feet(cell_of["gloves"])
	await physics_frames(4)
	check(level.gear_kinds.has("gloves"), "found again")
	level.finish("fail")
	await physics_frames(2)
	eq(level.gear_kinds.size(), 0, "a failed climb starts again with no gear")
	await _done()


func test_goggles_soften_a_gust() -> void:
	await _load(BARRANCO)
	c.global_position = Terrain.feet(Vector2i(60, 41))
	await physics_frames(5)
	var pushed := []
	for shell in [false, true]:
		level.gear_kinds.clear()
		if shell:
			level.gear_kinds.append("shell")
		level._apply_gear()
		# Wait standing (no input) for the next gust to start.
		GameInput.scripted = {"_": false}
		while c.wind.phase_at(c.clock) == WindSchedule.Phase.BLOW:
			await tree.physics_frame
		while c.wind.phase_at(c.clock) != WindSchedule.Phase.BLOW:
			await tree.physics_frame
		eq(c.state, Climber.State.GROUND, "standing in the gust")
		var x0 := c.global_position.x
		var s0 := c.stamina.value
		await physics_frames(15)
		pushed.append([c.global_position.x - x0, s0 - c.stamina.value])
	eq(pushed.size(), 2, "measured both")
	if pushed.size() == 2:
		check(pushed[1][0] < pushed[0][0], "goggles and buff: pushed less (%.1f vs %.1f)" % [pushed[1][0], pushed[0][0]])
		check(pushed[1][1] < pushed[0][1], "and it costs less")
	# Resting in a gust with them gives full breath back.
	check(c.wind_shell, "shell on")
	await _done()


## Puts the climber on plain ground at the start, half empty.
func _half() -> void:
	c.global_position = level.cairns[0]
	await physics_frames(3)
	c.stamina.value = c.stamina.max_value * 0.5


## Sits until full (or `seconds`), then stands up.
func _sit(seconds: float = 6.0) -> void:
	await _hold([], 2)
	await _hold(["rest"], 2)
	var frames := int(seconds * 60.0)
	for i in frames:
		GameInput.scripted = {"_": false}
		await tree.physics_frame
		if c.stamina.value >= c.stamina.max_value:
			break
	await _hold([], 2)
	await _hold(["rest"], 2)
	await _hold([], 2)


func test_two_rests_a_cairn_then_camp_food_then_nothing() -> void:
	Expedition.new_expedition(7)
	Expedition.climb = {"challengeId": "barranco-wall", "attemptId": "rest-test"}
	await _load(BARRANCO, false)
	eq(level.rests_left, ClimbLevel.REST_LIMIT, "two rests to start")
	# Rest 1, interrupted: getting up and sitting again is the same rest.
	await _half()
	await _hold(["rest"], 2)
	await physics_frames(20)
	await _hold([], 2)
	await _hold(["rest"], 2)
	eq(c.state, Climber.State.GROUND, "got up")
	await _hold([], 2)
	await _sit()
	eq(level.rests_left, 1, "one rest used, even sitting twice")
	check(c.stamina.value >= c.stamina.max_value - 0.5, "rested to full")
	# Rest 2.
	await _half()
	await _sit()
	eq(level.rests_left, 0, "both rests used")
	# Out of rests: a snack from camp.
	var food: int = level.food_left()
	await _half()
	await _sit()
	eq(level.snacks, 1, "a snack eaten")
	eq(level.food_left(), food - ClimbLevel.SNACK, "camp food goes down")
	check(c.stamina.value >= c.stamina.max_value - 0.5, "the snack refills you")
	# No food to spare: sitting gives nothing back.
	Expedition.state()["supplies"] = level.snacks * ClimbLevel.SNACK + 1
	await _half()
	var before := c.stamina.value
	await _hold([], 2)
	await _hold(["rest"], 2)
	await physics_frames(120)
	eq(c.state, Climber.State.REST, "sitting")
	check(c.stamina.value <= before + 0.01, "no rests, no food: nothing comes back")
	await _hold([], 2)
	await _hold(["rest"], 2)
	# The next cairn gives the rests back.
	c.global_position = level.cairns[1]
	await physics_frames(6)
	eq(level.checkpoint, 1, "at cairn 1")
	eq(level.rests_left, ClimbLevel.REST_LIMIT, "fresh rests at the cairn")
	# What was eaten lands on the outcome.
	eq(level.outcome_now("complete").food, ClimbLevel.SNACK, "the outcome carries the food eaten")
	await _done()


func test_a_rest_stone_and_the_wind_never_use_a_rest() -> void:
	Expedition.new_expedition(7)
	Expedition.climb = {"challengeId": "barranco-wall", "attemptId": "rest-test-2"}
	await _load(BARRANCO, false)
	var stone := Vector2i(-1, -1)
	for y in level.terrain.height:
		for x in level.terrain.width:
			if stone.x < 0 and level.terrain.kind(Vector2i(x, y)) == Terrain.Kind.REST:
				stone = Vector2i(x, y)
	check(stone.x >= 0, "the wall has a rest stone")
	c.global_position = Terrain.feet(stone)
	await physics_frames(3)
	c.stamina.value = c.stamina.max_value * 0.5
	await _sit()
	check(c.stamina.value >= c.stamina.max_value - 0.5, "the rest stone refilled")
	eq(level.rests_left, ClimbLevel.REST_LIMIT, "a rest stone is free")
	c.global_position = Terrain.feet(Vector2i(60, 41))
	await physics_frames(3)
	c.stamina.value = c.stamina.max_value * 0.5
	var before := c.stamina.value
	await _hold([], 2)
	await _hold(["rest"], 2)
	await physics_frames(60)
	check(c.exposed and c.state == Climber.State.REST, "hunkered down on the windy ledge")
	eq(level.rests_left, ClimbLevel.REST_LIMIT, "sitting out the wind is free")
	check(c.stamina.value <= before + 0.01, "and gives no breath back without goggles")
	await _done()


func test_food_eaten_on_the_climb_comes_out_of_camp_supplies() -> void:
	var base := TestSessions.at("barranco-wall")
	check(not base.is_empty(), "at the wall")
	var landed := []
	for food in [0, 6]:
		Expedition.session = base.duplicate(true)
		Expedition.navigate = false
		var p: Dictionary = Expedition.pending()
		Expedition.climb = {"attemptId": p["attemptId"], "challengeId": p["challengeId"], "checkpoint": 0}
		var o := TestSessions.complete(p)
		o["food"] = food
		eq(Expedition.finish_climb(o), "applied", "landed")
		landed.append(int(Expedition.state()["supplies"]))
	eq(landed[0] - landed[1], 6, "six supplies eaten on the climb are gone from camp")
	check(Expedition.descent_effect({"result": "complete", "food": 3}).get("supplies", 0) == -3, "the way down eats from camp too")


## The rim is long, but the wind is not: no open stretch longer than twelve
## tiles, and a cairn in the lee between the saddles, so a gust never sends
## you back the whole rim.
func test_the_summit_rim_has_short_windy_saddles_and_a_cairn_between() -> void:
	var t := Terrain.load_file("res://modes/expedition/levels/kilimanjaro/summit_night/summit_night.txt")
	var longest := 0
	var runs: Array = []
	for y in t.height:
		var run := 0
		for x in t.width + 1:
			if x < t.width and t.kind(Vector2i(x, y)) == Terrain.Kind.EXPOSED:
				run += 1
			else:
				if run > 0:
					runs.append([x - run, x - 1, y])
				longest = maxi(longest, run)
				run = 0
	check(longest <= 12, "no windy stretch longer than 12 tiles (longest %d)" % longest)
	# Two saddles (a boulder to hop splits the second in two).
	check(runs.size() >= 2 and runs.size() <= 3, "windy saddles on the rim only (%d runs)" % runs.size())
	if runs.size() >= 2:
		var between := false
		for k in t.markers.get("K", []):
			if k.y == runs[0][2] and k.x > runs[0][1] and k.x < runs[runs.size() - 1][0]:
				between = true
		check(between, "a cairn between the saddles")


## Risk on the camp cards is a spread, not everything low: sleeping and
## resting are low, a walk in the dark is not, and the summit night is high.
func test_the_cards_show_low_medium_and_high_risk() -> void:
	SaveGame.erase()
	Expedition.navigate = false
	Expedition.new_expedition(7)
	var seen := {}
	var bands := {"low": 0, "medium": 0, "high": 0}
	for n in 200:
		if not Expedition.active():
			break
		var p: Variant = Expedition.pending()
		if p != null:
			Expedition.finish_climb(TestSessions.complete(p))
			continue
		var tk := Trek.ensure(Expedition.session)
		var dd: Dictionary = tk.get("descent", {})
		if not dd.is_empty() and not dd.get("played", false):
			Expedition.finish_descent({"attemptId": dd["attemptId"], "challengeId": "descent", "result": "complete", "staminaLeft": 60, "slips": 0, "assisted": null, "regrouped": false, "seconds": 300})
			continue
		var card := Expedition.card()
		var pick := 0
		for i in card["choices"].size():
			var ch: Dictionary = card["choices"][i]
			var f := Trek.foresee(Expedition.session, ch, Expedition.def)
			if not f.is_empty():
				bands[f["risk"]] += 1
				seen[String(ch["label"])] = f["risk"]
			if TestSessions.CAREFUL.has(ch["label"]):
				pick = i
		Expedition.choose(pick)
	print("      careful party's cards: ", bands)
	for b in bands:
		check(bands[b] > 0, "some %s-risk choices" % b)
	check(bands["low"] < bands["low"] + bands["medium"] + bands["high"], "not everything is low risk")
	for label in ["Sleep under the trees", "Sleep before the tower", "Rest the day", "Take the extra day"]:
		if seen.has(label):
			eq(seen[label], "low", "%s is low risk" % label)
	for label in ["Walk the mud in the dark", "Start for the tower in the dark", "Push the forest to gain a day"]:
		if seen.has(label):
			check(seen[label] != "low", "%s is not low risk (%s)" % [label, seen[label]])
	for label in ["Keep the pace through the dark", "Start for the summit tonight", "Stay on the summit"]:
		if seen.has(label):
			eq(seen[label], "high", "%s is high risk" % label)


## Easy: thirteen days and twice each climb's slips. Medium: one more slip.
## Hard: the climb's own limit.
func test_the_route_sets_the_days_and_the_slips() -> void:
	eq(int(Trek.ROUTES["lemosho"]["permit"]), 13, "the easy way has thirteen days")
	eq(int(Trek.ROUTES["machame"]["permit"]), 9, "the medium way nine")
	eq(int(Trek.ROUTES["umbwe"]["permit"]), 8, "the hard way eight")
	var want := {"lemosho": [6, 8, 4], "machame": [4, 5, 3], "umbwe": [3, 4, 2]}
	var paths := [BARRANCO, "res://modes/expedition/levels/kilimanjaro/lava_tower/lava_tower.tscn", SUMMIT]
	for route in want:
		for i in paths.size():
			Expedition.new_expedition(7)
			Trek.ensure(Expedition.session)["route"] = route
			await _load(paths[i], false)
			eq(level.max_slips, int(want[route][i]), "%s: %s allows %d slips" % [route, level.spec["id"], want[route][i]])
			await _done()


## Leader points: the whole team home is worth the most; speed and stores
## count only then; a summit without your team counts against you.
func test_leader_points_reward_a_quick_thrifty_whole_team() -> void:
	var base: Dictionary = TestSessions.at("summit-night")["state"].duplicate(true)
	base["summitReached"] = true
	base["returnedSafely"] = true
	base["highestAltitude"] = 5895
	base["supplies"] = 40
	var slow := base.duplicate(true)
	slow["elapsedHours"] = 13 * 24 - 2
	var fast := base.duplicate(true)
	fast["elapsedHours"] = 9 * 24
	var all_slow := Records.leader_points(slow, "lemosho", 4)
	var all_fast := Records.leader_points(fast, "lemosho", 4)
	var three_fast := Records.leader_points(fast, "lemosho", 3)
	var two_fast := Records.leader_points(fast, "lemosho", 2)
	eq(int(all_fast["team"]), 10, "everyone home: +10")
	eq(int(all_fast["speed"]), 8, "four spare days: +8")
	eq(int(all_fast["stores"]), 4, "40 supplies left: +4")
	eq(int(all_slow["speed"]), 0, "no spare day: no speed")
	check(int(all_fast["points"]) > int(all_slow["points"]), "quicker ranks higher with the whole team")
	eq(int(three_fast["team"]), -8, "one teammate missing: -8")
	eq(int(three_fast["speed"]) + int(three_fast["stores"]), 0, "and speed and stores do not count")
	check(int(three_fast["points"]) < int(all_slow["points"]), "fast without your team ranks below slow with it")
	check(int(two_fast["points"]) < int(three_fast["points"]), "each missing teammate costs more")
	var no_summit := base.duplicate(true)
	no_summit["summitReached"] = false
	var ns := Records.leader_points(no_summit, "lemosho", 4)
	eq(int(ns["team"]) + int(ns["speed"]) + int(ns["stores"]), 0, "no summit: just the score")


## Artifacts brought home are worth a lot at the end, summit or not; lost
## with an expedition that does not come home, they count for nothing.
func test_artifacts_brought_home_boost_the_end_score() -> void:
	var base: Dictionary = TestSessions.at("summit-night")["state"].duplicate(true)
	base["summitReached"] = true
	base["returnedSafely"] = true
	base["highestAltitude"] = 5895
	var none := Records.leader_points(base, "machame", 4, 0)
	var three := Records.leader_points(base, "machame", 4, 3)
	eq(int(three["artifacts"]), 3 * Artifacts.POINTS, "each one brought home: +%d" % Artifacts.POINTS)
	eq(int(three["points"]) - int(none["points"]), 3 * Artifacts.POINTS, "on top of everything else")
	var every := Records.leader_points(base, "machame", 4, 99)
	eq(int(every["artifacts"]), Artifacts.MAX * Artifacts.POINTS, "never more than the mountain holds")
	check(int(every["points"]) > 130, "the most points need the artifacts: %d" % int(every["points"]))
	var retreat := base.duplicate(true)
	retreat["summitReached"] = false
	eq(int(Records.leader_points(retreat, "machame", 4, 2)["artifacts"]), 2 * Artifacts.POINTS, "a safe retreat still brings them home")
	var lost := base.duplicate(true)
	lost["returnedSafely"] = false
	eq(int(Records.leader_points(lost, "machame", 0, 4)["artifacts"]), 0, "not home: they count for nothing")


## An expedition's artifacts are its own: the route picks which ones, the
## record carries the count, and a new expedition starts with none.
func test_an_expeditions_artifacts_reach_its_record() -> void:
	Expedition.new_expedition(7)
	Trek.ensure(Expedition.session)["route"] = "umbwe"
	Artifacts.keep(Expedition.session, "lava-tower", [0, 1])
	Artifacts.keep(Expedition.session, "barranco-wall", [1])
	Artifacts.keep(Expedition.session, "barranco-wall", [1, 7])
	eq(Artifacts.count(Expedition.session), 3, "two from the tower, one from the wall, nothing twice or out of range")
	eq(Artifacts.kept(Expedition.session)[0]["name"], Artifacts.for_climb("lava-tower", "umbwe")[0][0], "the fastest way's own artifacts")
	var s: Dictionary = Expedition.session["state"]
	s["summitReached"] = true
	s["returnedSafely"] = true
	s["highestAltitude"] = 5895
	Records.delete_all()
	var run := Records.expedition_finished(Expedition.session)
	eq(int(run["artifacts"]), 3, "the record counts them")
	eq(int(run["leader"]["artifacts"]), 3 * Artifacts.POINTS, "and they are in its points")
	Records.delete_all()
	Expedition.new_expedition(8)
	eq(Artifacts.count(Expedition.session), 0, "a new expedition starts with none")


## The helmet turns a falling stone into a knock (stamina), not a fall; the
## rope catches the next slip.
func test_a_helmet_and_a_rope() -> void:
	Expedition.new_expedition(7)
	Expedition.climb = {"challengeId": "barranco-wall", "attemptId": "helmet-test"}
	await _load(BARRANCO, false)
	var cell_of := {}
	for g in level.spec["gear"]:
		cell_of[String(g[2])] = Vector2i(int(g[3][0]), int(g[3][1]))
	c.global_position = Terrain.feet(cell_of["rope"])
	await physics_frames(4)
	check(level.gear_kinds.has("rope"), "found the rope")
	check(c.spotter, "the rope will hold the next slip")
	c.slip("fall")
	await drive([], func() -> bool: return c.state == Climber.State.GROUND, 5.0, "caught")
	eq(c.slips, 0, "the rope caught it")
	eq(c.caught, 1, "one caught")
	c.global_position = Terrain.feet(cell_of["helmet"])
	await physics_frames(4)
	check(c.helmet, "helmet on")
	var before := c.stamina.value
	# A stone lands on the helmet.
	var hz: Hazards = level.hazards
	var s := Sprite2D.new()
	hz.add_child(s)
	s.position = c.body_rect().get_center()
	hz.rocks.append({"node": s, "vy": 200.0, "col": Terrain.cell_of(s.position).x})
	await physics_frames(3)
	eq(c.slips, 0, "no fall under the helmet")
	check(c.stamina.value <= before - Hazards.HELMET_HIT + 0.5, "it costs stamina instead")
	await _done()


## A fire at a cairn: full stamina and fresh rests, once per cairn, for an
## hour on the expedition's clock.
func test_a_fire_at_a_cairn_costs_an_hour() -> void:
	Expedition.new_expedition(7)
	Expedition.climb = {"challengeId": "barranco-wall", "attemptId": "fire-test"}
	await _load(BARRANCO, false)
	c.global_position = level.cairns[1]
	await physics_frames(4)
	eq(level.checkpoint, 1, "at cairn 1")
	c.stamina.value = 10.0
	level.rests_left = 0
	await physics_frames(2)
	eq(level.action_word, "FIRE", "the cairn offers a fire")
	level._interact()
	check(level.panel.open, "it asks first")
	level.panel.choose("fire")
	await physics_frames(2)
	check(c.stamina.value >= c.stamina.max_value - 0.5, "full stamina")
	eq(level.rests_left, ClimbLevel.REST_LIMIT, "fresh rests")
	eq(level.fires, [1], "one fire, here")
	await physics_frames(2)
	check(level.action_word != "FIRE", "once per cairn")
	eq(level.outcome_now("complete").fire_hours, ClimbLevel.FIRE_HOURS, "the outcome carries the hour")
	await _done()
	# Landed: the hour goes on the expedition's clock.
	var base := TestSessions.at("barranco-wall")
	var hours := []
	for fire in [0, 2]:
		Expedition.session = base.duplicate(true)
		Expedition.navigate = false
		var p: Dictionary = Expedition.pending()
		Expedition.climb = {"attemptId": p["attemptId"], "challengeId": p["challengeId"], "checkpoint": 0}
		var o := TestSessions.complete(p)
		o["fireHours"] = fire
		Expedition.finish_climb(o)
		hours.append(int(Expedition.state()["elapsedHours"]))
	eq(hours[1] - hours[0], 2, "two hours of fires: two hours later")
