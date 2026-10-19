extends TestCase
## The expedition's pacing fixes: time that jumps (a regroup, a resumed
## save) does not unleash the stones it skipped; a stone never starts on the
## climber; the brief says what the climb costs back at camp and does not
## promise a teammate who has gone down; the last slip says the climb is
## over.


func _level(challenge: String, before: Callable = Callable()) -> Node:
	SaveGame.erase()
	Expedition.new_expedition(7)
	Expedition.session = TestSessions.at(challenge)
	Expedition.climb = {}
	if before.is_valid():
		before.call()
	# A fresh go: nothing left over from an earlier test's climb.
	Expedition.climb = {}
	Expedition.resume_climb()
	var level: Node = load(Expedition.LEVELS[challenge]).instantiate()
	root.add_child(level)
	await physics_frames(3)
	return level


func _done(level: Node) -> void:
	GameInput.scripted = {}
	level.queue_free()
	await physics_frames(2)
	SaveGame.erase()


func test_a_regroup_does_not_bring_down_an_hour_of_stones() -> void:
	var level: Node = await _level("barranco-wall")
	level.panel.choose("start")
	await physics_frames(2)
	var h: Hazards = level.hazards
	var sources: int = h.chutes.size() + h.rollers.size()
	check(sources > 0, "the wall has stones")
	level.climber.clock += level.REGROUP_SECONDS
	h.skip_to(level.climber.clock)
	var most := 0
	for i in 30:
		GameInput.scripted = {"_": false}
		await tree.physics_frame
		most = maxi(most, h.rocks.size() + h.rolling.size())
	check(most <= sources, "at most one stone per chute after an hour skipped (%d, %d sources)" % [most, sources])
	await _done(level)


func test_no_stone_starts_on_the_climber() -> void:
	# The faster way's tower has rolling stones on its top (the long way's
	# has none).
	var level: Node = await _level("lava-tower", func() -> void: Trek.ensure(Expedition.session)["route"] = "machame")
	level.panel.choose("start")
	await physics_frames(2)
	var h: Hazards = level.hazards
	if h.rollers.is_empty():
		check(false, "the Lava Tower has rolling stones")
		await _done(level)
		return
	var sp: Dictionary = h.rollers[0]
	level.climber.global_position = Terrain.feet(sp["cell"])
	level.climber.reset_physics_interpolation()
	var t: float = h._roll_time(sp, sp["next"])
	level.climber.clock = t - 0.05
	var slips: int = level.climber.slips
	for i in 20:
		await tree.physics_frame
		if level.climber.state != Climber.State.SLIP:
			level.climber.global_position = Terrain.feet(sp["cell"])
	check(sp["next"] > 0, "the stone's time came")
	eq(level.climber.slips, slips, "standing on the spawner: no stone starts on top of you")
	check(level.climber.state != Climber.State.SLIP, "not knocked off")
	await _done(level)


func test_the_brief_says_what_the_climb_costs_at_camp() -> void:
	var level: Node = await _level("barranco-wall")
	var body: String = level.panel.all_text()
	check("each slip costs the party" in body, "the brief names the cost of a slip: " + body.substr(0, 400))
	check("Marco is somewhere above you" in body, "Marco is on the wall")
	await _done(level)


func test_a_teammate_who_went_down_is_not_in_the_brief() -> void:
	var level: Node = await _level("barranco-wall", func() -> void: Trek._depart(Expedition.session, "marco"))
	var body: String = level.panel.all_text()
	check(level.mate == null, "Marco has gone down")
	check(not "Marco is somewhere" in body, "so the brief does not send you looking for him")
	for p in level.people:
		for line in p["lines"]:
			check(not "Marco" in String(line), "and nobody at the start talks about him: " + String(line))
	await _done(level)


func test_the_last_slip_says_the_climb_is_over() -> void:
	var level: Node = await _level("barranco-wall")
	level.panel.choose("start")
	await physics_frames(2)
	level.climber.slips = level.max_slips - 1
	level.climber.slip("fall")
	await tree.physics_frame
	check("climb is over" in level.hud._flash.text, "the last slip: " + level.hud._flash.text)
	await _done(level)
