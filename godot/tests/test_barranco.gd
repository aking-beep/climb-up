extends ClimbBot
## The Barranco Wall, played. A scripted climber drives the real level
## through the same input actions a player presses (GameInput.scripted):
## walk out of camp, scramble, climb, traverse the void, rest, cross the
## exposed ledge between gusts, deal with Marco, climb the gully, and walk
## to Karanga. Run with --fixed-fps 60 so physics steps are exact.

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


func climb_the_wall(on_marco: String) -> void:
	# Camp to the wall foot.
	await drive(["move_right"], func() -> bool: return tx() >= 62.2, 40.0, "to the wall foot")
	check(level.checkpoint == 1, "cairn 1 at the wall foot, got %d" % level.checkpoint)
	# The scramble band, then mantle onto ledge 1.
	await drive(["climb_up"], func() -> bool: return c.state == Climber.State.GROUND and ty() <= 74.05, 20.0, "scramble")
	# Ledge 1 to the first face.
	await drive(["move_right"], func() -> bool: return tx() >= 85.6, 20.0, "ledge 1")
	await rest_up()
	await drive(["climb_up"], func() -> bool: return c.state == Climber.State.GROUND and ty() <= 60.05, 30.0, "first face")
	await rest_up()
	# Ledge 2 back left to the traverse; grab before the void.
	await drive(["move_left"], func() -> bool: return tx() <= 63.7, 20.0, "ledge 2")
	await drive(["climb_up"], func() -> bool: return c.is_climbing() and ty() <= 57.70, 10.0, "grab the traverse")
	await drive(["move_left", "climb_up"], func() -> bool: return c.state == Climber.State.GROUND and tx() <= 55.0, 30.0, "traverse")
	await rest_up(0.98)
	# The steeper face to ledge 3.
	await drive(["move_left"], func() -> bool: return tx() <= 49.6, 10.0, "to the face")
	check(level.checkpoint >= 2, "cairn 2 at the rest ledge, got %d" % level.checkpoint)
	await drive(["climb_up"], func() -> bool: return c.state == Climber.State.GROUND and ty() <= 42.05, 30.0, "steeper face")
	await drive(["move_right"], func() -> bool: return tx() >= 52.5, 10.0, "cairn 3")
	await rest_up()
	check(level.checkpoint >= 3, "cairn 3 before the exposed ledge, got %d" % level.checkpoint)
	# The exposed ledge, between gusts, to Marco.
	await cross(77.0)
	await drive([], func() -> bool: return level.panel.open, 5.0, "panel")
	check(level.panel.open, "meeting Marco opens a choice")
	if on_marco == "help":
		level.panel.choose("help")
		await drive([], func() -> bool: return level.panel.open, 5.0, "panel")
		check(level.mate_state == "helped", "Marco helped")
		check(c.spotter, "Marco will catch a slip")
		level.panel.choose("continue")
	elif on_marco == "leave":
		level.panel.choose("leave")
		await drive([], func() -> bool: return level.panel.open, 2.0, "panel")
		level.panel.choose("continue")
	await physics_frames(2)
	await rest_up(0.98)
	# The loose gully, with a breather in the niche halfway.
	await drive(["move_right"], func() -> bool: return tx() >= 83.4, 10.0, "to the gully")
	await climb_dodging(func() -> bool: return ty() <= 33.90, "lower gully, under stonefall")
	await drive(["move_right"], func() -> bool: return c.state == Climber.State.GROUND and tx() >= 84.5, 10.0, "into the niche")
	await rest_up(0.98)
	await drive(["move_left"], func() -> bool: return tx() <= 83.6, 5.0, "back to the gully")
	await drive(["climb_up"], func() -> bool: return c.is_climbing(), 5.0, "regrab")
	await up_to(26, "upper gully, under stonefall", "move_right")
	check(level.checkpoint >= 4, "cairn 4 at Marco's ledge, got %d" % level.checkpoint)
	# The shoulder, then the crouch ledge in the wind, to the upper face.
	await drive(["move_right"], func() -> bool: return tx() >= 96.5, 15.0, "the shoulder")
	await rest_up(0.98)
	await cross(118.2)
	await drive(["climb_up"], func() -> bool: return c.state == Climber.State.GROUND and ty() <= 12.05, 30.0, "upper face")
	# The top, over the rise, and down to Karanga.
	await drive(["move_right"], func() -> bool: return outcome != null, 90.0, "to Karanga")
	check(level.checkpoint >= 6, "cairn 6 at the top of the wall, got %d" % level.checkpoint)


func test_a_careful_climb_helping_marco_reaches_karanga() -> void:
	await _load()
	await climb_the_wall("help")
	check(outcome != null, "the climb ended")
	if outcome:
		eq(outcome.result, "complete", "result")
		eq(outcome.assisted, true, "assisted")
		eq(outcome.slips, 0, "slips")
		check(outcome.seconds > 120, "even a bot that knows the route takes minutes, got %ds" % outcome.seconds)
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
	c.global_position = Terrain.feet(Vector2i(60, 41))
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
	# Walking into a gust is a slip.
	while c.wind.phase_at(c.clock) != WindSchedule.Phase.BLOW:
		GameInput.scripted = {"_": false}
		await tree.physics_frame
	await drive(["move_right"], func() -> bool: return c.state == Climber.State.SLIP, 2.0, "walk into the gust")
	eq(c.slips, 1, "walking in a gust slips")
	eq(c.wind_strikes, 1, "wind strike counted")
	var _unused := start
	await _done()


func test_a_long_fall_is_a_slip_back_to_the_last_cairn_and_three_end_it() -> void:
	await _load()
	for i in 3:
		c.global_position = Terrain.feet(Vector2i(59, 64))  # over the void under the traverse
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
	await drive(["move_right"], func() -> bool: return tx() >= 62.2, 40.0, "to the wall")
	await drive(["climb_up"], func() -> bool: return ty() <= 78.00, 10.0, "climbing")
	check(c.stamina.value < full, "climbing costs stamina")
	await drive(["climb_up"], func() -> bool: return c.state == Climber.State.GROUND and ty() <= 74.05, 20.0, "mantle")
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
	await climb_the_wall("help")
	check(outcome != null and outcome.result == "complete", "a tired party still reaches Karanga")
	check(level.lowest_stamina >= 0.1, "without ever running dry (lowest %d%%)" % int(level.lowest_stamina * 100))
	if outcome:
		print("      tired party: %d s, %d slips, lowest %d%% of a %d bar, food eaten %d" % [outcome.seconds, outcome.slips, int(level.lowest_stamina * 100), int(c.stamina.max_value), level.snacks * ClimbLevel.SNACK])
	await _done()
