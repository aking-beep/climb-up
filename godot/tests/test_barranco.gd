extends ClimbBot
## The middle climb (Marco's), played: on the long way, which these tests
## use, it is the Karanga Valley. A scripted climber drives the real level
## through the same input actions a player presses (GameInput.scripted):
## walk out of camp, climb down into the valley, hop the stream, fetch what
## lies off the line, deal with Marco, climb out, cross the exposed shoulder
## between gusts, and walk to Karanga. Run with --fixed-fps 60 so physics
## steps are exact.

const LEVEL := "res://modes/expedition/levels/kilimanjaro/barranco/barranco.tscn"

var log: Array[String] = []


func _load() -> void:
	Expedition.new_expedition(7)
	Settings.touch_controls = false
	level = load(LEVEL).instantiate()
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


## The wall along this route's layout (the long way's in these tests),
## choosing `on_marco` (help or leave) when you reach him.
func climb_the_wall(on_marco: String) -> void:
	var script: Array = level.layout["script"].duplicate(true)
	for step in script:
		if step[0] == "mate":
			step[1]["choice"] = on_marco
	await follow(script)
	check(level.checkpoint == level.cairns.size() - 1, "every cairn on the way, got %d of %d" % [level.checkpoint, level.cairns.size() - 1])
	if on_marco == "help":
		eq(level.mate_state, "helped", "Marco helped")
	else:
		eq(level.mate_state, "left", "Marco left for Lena")


func test_a_careful_climb_helping_marco_reaches_karanga() -> void:
	await _load()
	await climb_the_wall("help")
	check(outcome != null, "the climb ended")
	if outcome:
		eq(outcome.result, "complete", "result")
		eq(outcome.assisted, true, "assisted")
		eq(outcome.slips, 0, "slips")
		check(outcome.seconds > 60, "even a bot that knows the route takes minutes, got %ds" % outcome.seconds)
		check_pacing("Barranco Wall")
		print("      ascent took %d s of game time, %d%% stamina left, wind strikes %d, %.0f s on loose rock, %.0f s resting, lowest %d%% of a %d bar, food eaten %d" % [outcome.seconds, outcome.stamina_left, outcome.wind_strikes, outcome.loose_seconds, outcome.rest_seconds, int(level.lowest_stamina * 100), int(level.climber.stamina.max_value), level.snacks * ClimbLevel.SNACK])
	await _done()


func test_leaving_marco_is_reported() -> void:
	await _load()
	await climb_the_wall("leave")
	if outcome:
		eq(outcome.result, "complete", "result")
		eq(outcome.assisted, false, "assisted")
	else:
		failures.append("no outcome")
	await _done()


func test_walking_in_a_gust_on_exposed_ground_is_a_slip_and_resting_is_safe() -> void:
	await _load()
	var start: Vector2i = level.terrain.markers["K"][0]
	# Put the climber on the exposed ledge, at the next gust.
	c.global_position = Terrain.feet(exposed_cell())
	await physics_frames(5)
	# Sit down (REST) while the wind is rising, and stay sat through the gust.
	GameInput.scripted = {"_": false}
	while c.wind.phase_at(c.clock) != WindSchedule.Phase.CALM:
		await tree.physics_frame
	while c.wind.phase_at(c.clock) != WindSchedule.Phase.WARN:
		await tree.physics_frame
	await drive(["rest"], func() -> bool: return c.state == Climber.State.REST, 1.0, "sit down")
	while c.wind.phase_at(c.clock) != WindSchedule.Phase.BLOW:
		GameInput.scripted = {"_": false}
		await tree.physics_frame
	await physics_frames(1)
	check(c.exposed, "on exposed ground")
	eq(c.state, Climber.State.REST, "sitting as the gust hits")
	var x0 := c.global_position.x
	await drive([], func() -> bool: return c.wind.phase_at(c.clock) != WindSchedule.Phase.BLOW, 3.0, "sat out the gust")
	eq(c.slips, 0, "resting through a gust is safe")
	check(absf(c.global_position.x - x0) < 0.5, "the gust does not push someone sitting")
	# Stand up (REST again) in the calm, then stand still in the next gust:
	# pushed along the ledge, and it costs breath.
	while c.wind.phase_at(c.clock) != WindSchedule.Phase.CALM:
		await tree.physics_frame
	await drive(["rest"], func() -> bool: return c.state == Climber.State.GROUND, 1.0, "stand up")
	GameInput.scripted = {"_": false}
	while c.wind.phase_at(c.clock) != WindSchedule.Phase.BLOW:
		await tree.physics_frame
	x0 = c.global_position.x
	var before := c.stamina.value
	await physics_frames(20)
	check(absf(c.global_position.x - x0) > 0.2, "standing in a gust gets nudged along (%.1f px, state %d, slips %d)" % [c.global_position.x - x0, c.state, c.slips])
	check(c.stamina.value < before, "standing in a gust costs stamina")
	eq(c.slips, 0, "standing in a gust never sends you back")
	# Walking into a gust: a stagger that costs stamina, not a fall.
	while c.wind.phase_at(c.clock) != WindSchedule.Phase.BLOW:
		GameInput.scripted = {"_": false}
		await tree.physics_frame
	before = c.stamina.value
	await drive(["move_right"], func() -> bool: return c.wind_strikes > 0, 1.0, "walk into the gust")
	eq(c.wind_strikes, 1, "wind strike counted")
	eq(c.slips, 0, "a stagger, not a fall")
	check(c.stamina.value <= before - Climber.GUST_STAGGER + 0.5, "the stagger costs stamina")
	# With nothing left, the stagger is a fall.
	while c.wind.phase_at(c.clock) == WindSchedule.Phase.BLOW:
		GameInput.scripted = {"_": false}
		await tree.physics_frame
	while c.wind.phase_at(c.clock) != WindSchedule.Phase.BLOW:
		GameInput.scripted = {"_": false}
		await tree.physics_frame
	c.stamina.value = 2.0
	for i in 60:
		if c.state == Climber.State.SLIP:
			break
		GameInput.scripted = {"_": false, "move_right": true}
		await tree.physics_frame
	GameInput.scripted = {"_": false}
	eq(c.slips, 1, "spent and staggered: a fall")
	var _unused := start
	await _done()


## Standing still on ice in a gust (the descent's rim): the wind's nudge
## must never count as moving.
func test_standing_on_ice_in_a_gust_is_not_a_fall() -> void:
	await _load()
	c.global_position = Terrain.feet(exposed_cell())
	await physics_frames(3)
	c.on_ice = true
	for i in 60 * 6:
		GameInput.scripted = {"_": false}
		# As on ice: nothing slows the nudge.
		if c.wind.phase_at(c.clock) == WindSchedule.Phase.BLOW:
			c.velocity.x = maxf(c.velocity.x, 30.0)
		await tree.physics_frame
	eq(c.slips, 0, "no fall from standing still")
	eq(c.wind_strikes, 0, "and no wind strike")
	await _done()


func test_a_long_fall_is_a_slip_back_to_the_last_cairn_and_three_end_it() -> void:
	await _load()
	for i in 3:
		c.global_position = level.cairns[1] - Vector2(0, 8 * T)  # high over the wall foot
		c.state = Climber.State.AIR
		c.fall_from = c.global_position.y
		await drive([], func() -> bool: return c.state == Climber.State.SLIP or outcome != null, 5.0, "fall %d" % i)
		await drive([], func() -> bool: return c.state != Climber.State.SLIP or outcome != null, 5.0, "settle %d" % i)
	eq(c.slips, 3, "three slips")
	check(outcome != null and outcome.result == "fail", "three slips end the attempt")
	await _done()


func test_a_helped_marco_catches_the_next_slip() -> void:
	await _load()
	c.spotter = true
	c.slip("fall")
	eq(c.slips, 0, "not counted")
	eq(c.caught, 1, "caught")
	check(not c.spotter, "only once")
	c.state = Climber.State.GROUND
	c.slip("fall")
	eq(c.slips, 1, "the next one counts")
	await _done()


func test_climbing_drains_and_sitting_recovers() -> void:
	await _load()
	var full := c.stamina.value
	# The first face on the line, from the foot of the wall.
	var steps: Array = level.layout["script"]
	var k := 0
	while steps[k][0] != "climb":
		k += 1
	await follow(steps.slice(0, k))
	var face: Dictionary = steps[k][1]
	var right: bool = int(face["dir"]) > 0
	await drive(["move_right" if right else "move_left"], func() -> bool: return c.is_climbing() or (tx() >= float(face["x"]) - 0.5 if right else tx() <= float(face["x"])), 20.0, "to the wall")
	var foot := ty()
	full = c.stamina.value
	await drive(["climb_up"], func() -> bool: return ty() <= foot - 2.0, 10.0, "climbing")
	check(c.stamina.value < full, "climbing costs stamina")
	# Pull over the way the line goes on (the layout's lean).
	await up_to(float(face["row"]), "mantle", "move_right" if int(face.get("lean", 1)) > 0 else "move_left")
	var before := c.stamina.value
	await rest_up(0.99)
	check(c.stamina.value > before, "sitting recovers")
	check(c.rest_seconds > 0.0, "rest time is counted")
	await _done()


func test_retreat_from_the_pause_menu_is_always_open() -> void:
	await _load()
	await physics_frames(10)
	level.pause_menu()
	check(level.panel.open, "pause menu")
	level.panel.choose("retreat")
	await physics_frames(2)
	check(outcome != null and outcome.result == "retreat", "retreat outcome")
	await _done()


## The middle climb is passable for a worn party, not only a fresh one:
## energy 10 at camp (a stamina bar of about 60), and still to Karanga,
## helping Marco, without running out. The summit is the hard one.
func test_a_tired_party_still_gets_up_the_wall() -> void:
	Expedition.new_expedition(7)
	Expedition.state()["energy"] = 10
	Settings.touch_controls = false
	level = load(LEVEL).instantiate()
	root.add_child(level)
	level.finished.connect(func(o: ChallengeOutcome) -> void: outcome = o)
	await physics_frames(2)
	level.panel.choose("start")
	await physics_frames(1)
	c = level.climber
	check(c.stamina.max_value <= 62, "a small bar (%d)" % c.stamina.max_value)
	retries = 0
	await climb_the_wall("help")
	check(outcome != null and outcome.result == "complete", "a tired party still reaches Karanga")
	check(level.lowest_stamina >= 0.1, "without ever running dry (lowest %d%%)" % int(level.lowest_stamina * 100))
	if outcome:
		print("      tired party: %d s, %d slips, lowest %d%% of a %d bar, food eaten %d" % [outcome.seconds, outcome.slips, int(level.lowest_stamina * 100), int(c.stamina.max_value), level.snacks * ClimbLevel.SNACK])
	await _done()
