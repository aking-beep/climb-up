extends ClimbBot
## The fastest way, as asked for: a quarter of the bar, a rest gives back
## at most that quarter, and every piece of gear or artifact found grows the
## bar for good (Zelda's hearts). Stones fall, but never while you are on a
## wall. And the rain: a downpour makes wet rock cost more and a rest in
## the open give less, unless you are under rock.


func _load(climb: String, route: String, keep_session: bool = false) -> void:
	SaveGame.erase()
	Expedition.found = {}
	Settings.touch_controls = false
	if not keep_session:
		Expedition.session = TestSessions.at(climb)
		Trek.ensure(Expedition.session)["route"] = route
		Expedition.state()["energy"] = 100
	Expedition.climb = {}
	Expedition.resume_climb()
	outcome = null
	level = load(Expedition.LEVELS[climb]).instantiate()
	root.add_child(level)
	await physics_frames(2)
	c = level.climber
	level.panel.choose("start")
	await physics_frames(30)


func _done() -> void:
	GameInput.scripted = {}
	level.queue_free()
	level = null
	await physics_frames(2)
	SaveGame.erase()


func test_the_bar_grows_with_every_find_and_stays_grown() -> void:
	await _load("lava-tower", "umbwe")
	var base: float = level.bar_base
	eq(c.stamina.max_value, base, "a quarter of the bar to start")
	level.on_find("gear:test:0")
	eq(c.stamina.max_value, base + Trek.GROW, "a find grows the bar")
	level.on_find("gear:test:0")
	eq(c.stamina.max_value, base + Trek.GROW, "the same find grows it once")
	level.on_find("artifact:test:1")
	eq(c.stamina.max_value, base + 2.0 * Trek.GROW, "an artifact grows it too")
	await _done()
	# The next climb on the fastest way starts with the bar it grew to.
	await _load("barranco-wall", "umbwe", true)
	eq(c.stamina.max_value, float(level.bar_base) + 2.0 * Trek.GROW, "kept for the rest of the expedition")
	await _done()
	# The other routes' bars do not grow.
	await _load("lava-tower", "machame")
	var bar := c.stamina.max_value
	level.on_find("gear:test:0")
	eq(c.stamina.max_value, bar, "only the fastest way grows its bar")
	await _done()


func test_a_real_find_grows_the_bar() -> void:
	await _load("lava-tower", "umbwe")
	var before := c.stamina.max_value
	var g: Array = level.layout["gear"][0]
	var cell := Vector2i(int(g[0]), int(g[1]))
	c.respawn(Terrain.feet(cell))
	await physics_frames(5)
	eq(level.gear_kinds.size(), 1, "the gear is in the pack")
	eq(c.stamina.max_value, before + Trek.GROW, "and the bar grew")
	await _done()


func test_a_rest_gives_back_a_quarter_at_most() -> void:
	await _load("lava-tower", "umbwe")
	for i in 6:
		level.on_find("gear:grow:%d" % i)
	var base: float = level.bar_base
	check(c.stamina.max_value > base * 1.5, "a grown bar (%d)" % int(c.stamina.max_value))
	c.stamina.value = 2.0
	var rests: int = level.rests_left
	await press("rest")
	eq(c.state, Climber.State.REST, "sitting")
	await drive([], func() -> bool: return c.state != Climber.State.REST, 20.0, "the rest runs out")
	check(absf(c.stamina.value - (2.0 + base)) < 1.0, "one rest gives back the quarter: %.1f (from 2, quarter %d)" % [c.stamina.value, int(base)])
	eq(level.rests_left, rests - 1, "that was one rest")
	await press("rest")
	await drive([], func() -> bool: return c.state != Climber.State.REST or c.stamina.value >= c.stamina.max_value - 0.01, 20.0, "and again")
	eq(level.rests_left, rests - 2, "sitting again is another rest")
	check(c.stamina.value <= 2.0 + 2.0 * level.bar_base + 0.5, "again a quarter at most (%.1f)" % c.stamina.value)
	await _done()


func test_no_stones_while_on_a_wall() -> void:
	await _load("lava-tower", "machame")
	var hz: Hazards = level.hazards
	check(not hz.chutes.is_empty(), "the tower has stonefall")
	# Under a chute, on its rock: a long while, and nothing comes down.
	var chute: Dictionary = hz.chutes[0]
	var col: Vector2i = chute["cell"]
	var face := Vector2i(-1, -1)
	for dx in [0, 1, 2, -1]:
		for y in range(col.y, mini(col.y + 30, level.terrain.height)):
			var cell := Vector2i(col.x + dx, y)
			if level.terrain.is_climbable(cell) and level.terrain.is_climbable(cell + Vector2i.UP):
				face = cell
				break
		if face.x >= 0:
			break
	check(face.x >= 0, "rock under the chute")
	c.hang_at(Terrain.feet(face))
	await physics_frames(2)
	eq(c.state, Climber.State.CLIMB, "on the rock")
	var slips := c.slips
	var hurt := c.hurt_total
	c.stamina.value = c.stamina.max_value
	for i in int(hz.rock_period * 3.0 * 60.0):
		c.stamina.value = c.stamina.max_value
		await tree.physics_frame
		check(hz.rocks.is_empty() or c.is_climbing(), "")
	eq(c.slips, slips, "no stone knocks you off a wall")
	eq(c.hurt_total, hurt, "nor hurts you there")
	eq(hz.rocks.size(), 0, "no stone falls while you climb")
	await _done()


func test_the_rain_makes_wet_rock_and_poor_rests() -> void:
	await _load("lava-tower", "machame")
	check(level.rain == null, "no rain on the Lava Tower")
	await _done()
	await _load("lava-tower", "umbwe")
	var rain: RainSchedule = level.rain
	check(rain != null, "rain on the Umbwe Ridge")
	# Find a downpour on the climber's clock.
	var t := c.clock
	while not rain.pouring(t):
		t += 0.5
	c.clock = t + 1.0
	c.stamina.value = 2.0
	await physics_frames(2)
	check(level.pouring(), "pouring")
	eq(c.stamina.wet, RainSchedule.WET_ROCK, "wet rock costs more")
	check(not level.sheltered(), "out in the open at the start")
	var open_recovery := c.stamina.recovery
	check(level.climate_line().contains("downpour"), "the HUD says so: %s" % level.climate_line())
	# Out of it: drizzle.
	while rain.pouring(t):
		t += 0.5
	c.clock = t + 0.5
	await physics_frames(2)
	eq(c.stamina.wet, 1.0, "drizzle: dry enough")
	check(c.stamina.recovery > open_recovery * 1.5, "a rest in the open gives back more out of the downpour (%.2f vs %.2f)" % [c.stamina.recovery, open_recovery])
	await _done()
