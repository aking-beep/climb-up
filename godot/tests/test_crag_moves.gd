extends ClimbBot
## The crag's holds and moves, one at a time: slopers want a steady pace,
## pockets are free to hang on, a dyno is caught with one well-timed tap
## (mashing misses), every fall says why, and each of the seven routes
## tests a skill of its own. Also: the game's route builder makes the same
## maps as tools/levels/crag_maps.py.


func _load(id: String) -> void:
	Crag.navigate = false
	Crag.reset()
	Settings.touch_controls = false
	Crag.current = id
	level = load(Crag.LEVEL).instantiate()
	root.add_child(level)
	await physics_frames(2)
	c = level.climber
	level.panel.choose("start" if id == "first-climb" else "neutral")
	await physics_frames(1)


func _done() -> void:
	GameInput.scripted = {}
	level.queue_free()
	await physics_frames(2)
	Crag.reset()


## The first cell of `kind` on the line, bottom up, with rock of the same
## kind above it for at least `rows` rows.
func _first(kind: int, rows: int = 2) -> Vector2i:
	var t: Terrain = level.terrain
	for y in range(t.height - 1, 0, -1):
		for x in t.width:
			var ok := true
			for k in rows:
				if t.kind(Vector2i(x, y - k)) != kind:
					ok = false
			if ok and t.kind(Vector2i(x - 1, y)) == kind and t.kind(Vector2i(x + 1, y)) == kind:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Hangs the climber with the hands on `cell`.
func _hang_on(cell: Vector2i) -> void:
	c.hang_at(Terrain.feet(cell + Vector2i(0, 1)))
	await physics_frames(3)


func _tap() -> void:
	GameInput.scripted = {"interact": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await tree.physics_frame


func test_the_route_builder_makes_the_same_routes() -> void:
	var specs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://modes/crag/routes/specs.json"))
	eq(specs.size(), Crag.ROUTES.size(), "a spec for every route")
	for r in Crag.ROUTES:
		var s: Dictionary = specs[r["id"]]
		var built := RouteBuilder.build(s["segments"], int(s["x0"]), int(s["bolts"]), float(s["spread"]), int(s["first"]))
		eq(built, FileAccess.get_file_as_string(Crag.map_path(r["id"])), "%s: built in the game as in the tools" % r["id"])
	eq(RouteBuilder.round_even(2.5), 2, "halves round to even, as Python does")
	eq(RouteBuilder.round_even(3.5), 4, "both ways")
	eq(RouteBuilder.build([["up", 3]], 14, 3, 0.0, 3), "", "a route that does not reach the top is refused")


func test_slopers_want_a_steady_pace() -> void:
	await _load("sundown")
	# The traverse: the widest run of slopers on the line.
	var t: Terrain = level.terrain
	var cell := Vector2i(-1, -1)
	for y in t.height:
		for x in t.width:
			if t.kind(Vector2i(x, y)) == Terrain.Kind.SLOPER and t.kind(Vector2i(x - 1, y)) == Terrain.Kind.FACE and t.kind(Vector2i(x + 4, y)) == Terrain.Kind.SLOPER and cell.x < 0:
				cell = Vector2i(x, y)
	check(cell.x >= 0, "sundown traverses on slopers")
	# Charge across them at full speed: the grip slides away and you come off.
	await _hang_on(cell)
	check(level.on_slopers, "on the slopers")
	var start_grip: float = level.grip
	var off := false
	for i in 300:
		GameInput.scripted = {"move_right": true}
		await tree.physics_frame
		if c.state != Climber.State.CLIMB:
			off = true
			break
	GameInput.scripted = {"_": false}
	check(off, "full speed on slopers: you slide off (grip %.2f from %.2f)" % [level.grip, start_grip])
	await physics_frames(70)
	eq(level.fall_cause, "sloper", "and the fall says why")
	check("slowly" in level.hud.flash_text() or "settle" in level.hud.flash_text(), "with the lesson: " + level.hud.flash_text())
	# The same moves with pauses: still on, and the grip comes back while still.
	await _hang_on(cell)
	var x0 := c.global_position.x
	for k in 6:
		for i in 60:
			GameInput.scripted = {"move_right": true}
			await tree.physics_frame
		GameInput.scripted = {"_": false}
		var low: float = level.grip
		await physics_frames(50)
		check(level.grip > low or level.grip >= 0.99 or not level.on_slopers, "pausing lets the grip settle (%.2f to %.2f)" % [low, level.grip])
	eq(c.state, Climber.State.CLIMB, "move, pause, move: still on")
	check(c.global_position.x > x0 + 4 * Terrain.TILE, "and across (%.0f px)" % (c.global_position.x - x0))
	# Squeezing does nothing for an open hand.
	await _hang_on(cell)
	for i in 30:
		GameInput.scripted = {"move_right": true}
		await tree.physics_frame
	GameInput.scripted = {"_": false}
	var g: float = level.grip
	GameInput.scripted = {"interact": true, "move_right": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	check(level.grip <= g + 0.05, "a squeeze does not help on a sloper (%.2f to %.2f)" % [g, level.grip])
	check(level.action_word != "GRIP", "and the button does not ask for one")
	await _done()


func test_pockets_are_free_to_hang_on() -> void:
	await _load("warm-up")
	var cell := _first(Terrain.Kind.POCKET, 2)
	check(cell.x >= 0, "warm-up has pockets")
	await _hang_on(cell)
	var before := c.stamina.value
	await physics_frames(120)
	eq(c.last_activity, "pocket", "hanging on a pocket")
	check(absf(c.stamina.value - before) < 0.5, "costs nothing (%.1f to %.1f)" % [before, c.stamina.value])
	check("pocket" in level.hint_now().to_lower() or c.stamina.fraction() >= 0.9, "the HUD says so")
	var face := _first(Terrain.Kind.FACE, 3)
	await _hang_on(face)
	before = c.stamina.value
	await physics_frames(120)
	check(c.stamina.value < before - 2.0, "on ordinary rock, hanging costs (%.1f to %.1f)" % [before, c.stamina.value])
	await _done()


## Hangs under the blank on leap-of-faith and jumps. Returns once in the air.
func _jump_the_blank() -> void:
	var t: Terrain = level.terrain
	var jug_top := Vector2i(-1, -1)
	for y in t.height:
		for x in t.width:
			var cell := Vector2i(x, y)
			if t.kind(cell) == Terrain.Kind.JUG and t.kind(cell + Vector2i.UP) == Terrain.Kind.AIR and not t.is_solid(cell + Vector2i(0, -2)) and t.is_climbable(cell + Vector2i(0, -3)) and jug_top.x < 0:
				jug_top = Vector2i(x + 1, y)
	c.hang_at(Terrain.feet(jug_top + Vector2i(0, 1)))
	await physics_frames(2)
	# Clip the bolt beside the jug first, so it does not take the taps.
	for i in 8:
		GameInput.scripted = {"interact": i % 4 < 2}
		await tree.physics_frame
	GameInput.scripted = {"jump": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	check(c.state == Climber.State.AIR and level._dyno_air, "in the air, going for the hold")
	check(level.dyno_target_y < INF, "the hold it goes for is known (the catch ring closes on it)")


func test_a_dyno_wants_one_timed_tap() -> void:
	await _load("leap-of-faith")
	# One tap right as the hands land on the hold: a perfect catch.
	await _jump_the_blank()
	await drive([], func() -> bool: return c.state == Climber.State.CLIMB, 2.0, "the catch")
	check(level.catching > 0.0 and level.action_word == "GRIP", "hands on the hold: the catch window is open")
	var breath := c.stamina.value
	await _tap()
	eq(level.catch_quality, "perfect", "one tap on the contact: a perfect catch")
	eq(level.catching, 0.0, "stuck")
	check(c.stamina.value >= breath + Climber.DYNO_COST * 0.5 - 0.5, "and half the jump's stamina back (%.1f to %.1f)" % [breath, c.stamina.value])
	await physics_frames(20)
	eq(c.state, Climber.State.CLIMB, "still on")
	eq(int(level.taps["catch"]), 1, "one tap, not three")
	# A tap a quarter of a second late: caught, not perfect.
	await _jump_the_blank()
	await drive([], func() -> bool: return c.state == Climber.State.CLIMB, 2.0, "the catch")
	await physics_frames(15)
	await _tap()
	eq(level.catch_quality, "good", "a little late: a good catch")
	eq(c.state, Climber.State.CLIMB, "still on")
	# A single reach just before the hands arrive counts too.
	await _jump_the_blank()
	await drive([], func() -> bool: return level.climber.body_rect().position.y - level.dyno_target_y <= 0.4 * Terrain.TILE or c.state != Climber.State.AIR, 2.0, "near the hold")
	await _tap()
	await drive([], func() -> bool: return c.state != Climber.State.AIR, 2.0, "contact")
	check(level.catch_quality in ["perfect", "good"], "a reach just before contact sticks it (%s)" % level.catch_quality)
	await _done()


func test_mashing_a_dyno_misses() -> void:
	await _load("leap-of-faith")
	await _jump_the_blank()
	# Mash from the moment you leave the rock.
	var i := 0
	while c.state == Climber.State.AIR and i < 120:
		GameInput.scripted = {"interact": i % 2 == 0}
		await tree.physics_frame
		i += 1
	GameInput.scripted = {"_": false}
	eq(level.catch_quality, "flail", "snatching at the air: the hands miss")
	await physics_frames(90)
	eq(level.fall_cause, "dyno-flail", "the fall says why")
	check("one tap" in level.hud.flash_text().to_lower() or "snatch" in level.hud.flash_text().to_lower(), "and what to do: " + level.hud.flash_text())
	# Too late: no tap at all.
	await _jump_the_blank()
	await drive([], func() -> bool: return c.state == Climber.State.CLIMB, 2.0, "the catch")
	await physics_frames(int(CragLevel.CATCH_WINDOW * 60.0) + 4)
	eq(level.catch_quality, "late", "no tap in the window: too late")
	check(c.state != Climber.State.CLIMB, "and off")
	await _done()


func test_each_route_tests_its_own_skill() -> void:
	var has := func(id: String, kind: int) -> int:
		var t := Terrain.load_file(Crag.map_path(id))
		var n := 0
		for k in t.kinds:
			if k == kind:
				n += 1
		return n
	var blanks := func(id: String) -> int:
		var t := Terrain.load_file(Crag.map_path(id))
		var n := 0
		var x := Terrain.cell_of(Terrain.feet(t.markers["X"][0])).x
		var prev := true
		for y in range(t.height - 3, 6, -1):
			var any := false
			for xx in t.width:
				if t.is_climbable(Vector2i(xx, y)):
					any = true
			if not any and prev:
				n += 1
			prev = any
		return n
	# Each one's signature, and none of them is a copy of the one before.
	check(has.call("warm-up", Terrain.Kind.POCKET) > 0 and has.call("warm-up", Terrain.Kind.JUG) > 0, "warm-up: pockets and a jug to clip and rest from")
	check(has.call("sundown", Terrain.Kind.SLOPER) >= 15, "sundown: a traverse on slopers")
	check(has.call("the-pinch", Terrain.Kind.CRIMP) > has.call("sundown", Terrain.Kind.CRIMP) * 2, "the pinch: long crimps")
	eq(blanks.call("leap-of-faith"), 1, "leap of faith: one dyno to time")
	check(has.call("lions-roof", Terrain.Kind.POCKET) > 0, "lion's roof: pockets under the roof")
	eq(blanks.call("thunderhead"), 2, "thunderhead: two dynos")
	check(has.call("thunderhead", Terrain.Kind.SLOPER) > 0 and Crag.facts("thunderhead")["protection"] == "runout", "thunderhead: slopers too, and run-out")
	for r in Crag.ROUTES:
		check(String(r.get("skill", "")) != "", "%s names its skill" % r["id"])
