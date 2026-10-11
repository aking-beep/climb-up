extends ClimbBot
## Crag mode: the routes led by a scripted climber through the real input
## actions (walk to the line, climb, traverse where the line goes, rest on
## jugs, keep moving on crimps, dyno the blank, pull over the top), plus the
## rules one at a time: crimps, jugs, the dyno, clipping and lead falls,
## styles, unlocking, and saves. Nothing here touches the expedition.

func _load(id: String) -> void:
	Crag.navigate = false
	Settings.touch_controls = false
	Crag.current = id
	level = load(Crag.LEVEL).instantiate()
	root.add_child(level)
	await physics_frames(2)
	c = level.climber
	check(level.panel.open, "the brief is shown first")
	level.panel.choose("start")
	await physics_frames(1)


func _done() -> void:
	GameInput.scripted = {}
	level.queue_free()
	await physics_frames(2)


func _above(dy: int, x: float) -> Vector2i:
	var top := Terrain.cell_of(c.body_rect().position)
	return Vector2i(Terrain.cell_of(Vector2(x, 0)).x, top.y - dy)


## A column within reach sideways along the hands' row from which the line
## goes on up: its x, or NAN.
func _line_goes_up(dir: int) -> float:
	var t: Terrain = level.terrain
	var row := Terrain.cell_of(c.body_rect().position + Vector2(0, 4)).y
	var col := Terrain.cell_of(c.global_position).x
	for k in range(1, 16):
		var x := col + dir * k
		if not t.is_climbable(Vector2i(x, row)) and not t.is_climbable(Vector2i(x, row + 1)):
			return NAN
		if t.is_climbable(Vector2i(x, row - 1)):
			return x * T + T / 2.0
	return NAN


## Leads the current route to the anchor, as a player would. Returns true
## on the send.
func lead(seconds: float = 120.0) -> bool:
	var t: Terrain = level.terrain
	var resting := false
	var target := NAN
	for i in int(seconds * 60.0):
		if level._ended:
			break
		var held := {"_": false}
		if c.state == Climber.State.GROUND and not c.can_grab():
			held["move_right"] = true
		elif c.state == Climber.State.GROUND:
			held["climb_up"] = true
		elif c.state == Climber.State.CLIMB:
			var hold := t.hold_at(c.body_rect())
			if hold == Terrain.Kind.JUG and (resting or c.stamina.fraction() < 0.9):
				# Shake out on the jug until the arms are full.
				resting = c.stamina.fraction() < 0.97
			elif not is_nan(target):
				if absf(target - c.global_position.x) < 1.5:
					target = NAN
				else:
					held["move_left" if target < c.global_position.x else "move_right"] = true
			else:
				var top := t.hold_at(c.body_rect(c.global_position + Vector2(0, -6))) == Terrain.Kind.AIR
				if top and level.dyno_above():
					held["climb_up"] = true
					held["jump"] = true
				elif top:
					var right := _line_goes_up(1)
					var left := _line_goes_up(-1)
					target = right if not is_nan(right) else left
					if is_nan(target):
						# The top of the line: pull over onto the ledge.
						held["climb_up"] = true
						held["move_right"] = true
				else:
					held["climb_up"] = true
		if held.has("jump") and _hopped:
			held.erase("jump")
		_hopped = held.has("jump")
		GameInput.scripted = held
		if OS.get_environment("CRAG_DEBUG") != "" and i % 30 == 0:
			print("CRAGDBG ", where(), " held=", held.keys(), " target=", target, " resting=", resting)
		await tree.physics_frame
	GameInput.scripted = {"_": false}
	return level.result == "sent"


func _fresh_progress() -> void:
	Crag.navigate = false
	Crag.reset()


func test_the_title_opens_two_separate_games() -> void:
	var title: Node = load("res://modes/title/title.tscn").instantiate()
	root.add_child(title)
	await physics_frames(2)
	var labels: Array = []
	for b in title.card.get_children():
		if b is Button:
			labels.append(b.text)
	check(labels.size() == 2 and "Expedition" in labels[0] and "Crag" in labels[1], "Expedition and Crag: %s" % [labels])
	title.queue_free()
	var menu: Node = load(Crag.MENU).instantiate()
	_fresh_progress()
	root.add_child(menu)
	await physics_frames(2)
	var routes := 0
	var locked := 0
	for b in menu.card.get_children():
		if b is Button and Crag.ROUTES.any(func(r: Dictionary) -> bool: return b.text.begins_with(r["grade"] + "  ")):
			routes += 1
			if b.disabled:
				locked += 1
	eq(routes, 5, "five routes")
	eq(locked, 4, "only the first is open at the start")
	menu.queue_free()
	await physics_frames(1)


func test_every_route_is_led_to_the_anchor() -> void:
	_fresh_progress()
	for r in Crag.ROUTES:
		check(Crag.unlocked(r["id"]), "%s is open by now" % r["name"])
		Crag.climb(r["id"])
		await _load(r["id"])
		var sent := await lead()
		check(sent, "%s (%s) sent; stopped at %s, %s" % [r["name"], r["grade"], where(), level.stats_line(int(c.stamina.fraction() * 100))])
		eq(level.checkpoint, level.clips.size(), "%s: every bolt clipped" % r["name"])
		if r["id"] in ["leap-of-faith", "lions-roof"]:
			check(c.dynos >= 1, "%s needs a dyno" % r["name"])
		print("      %s %s: %s, %d falls, %d s, %d dynos, %d%% stamina left" % [r["grade"], r["name"], level.outcome.get("style", "-"), c.slips, int(c.clock), c.dynos, int(c.stamina.fraction() * 100)])
		await _done()
	_fresh_progress()


func test_crimps_drain_jugs_give_back() -> void:
	Crag.navigate = false
	await _load("the-pinch")
	var t: Terrain = level.terrain
	var crimp := Vector2i(-1, -1)
	var jug := Vector2i(-1, -1)
	var face := Vector2i(-1, -1)
	for y in t.height:
		for x in t.width:
			var k := t.kind(Vector2i(x, y))
			var below := t.kind(Vector2i(x, y + 1))
			if k == Terrain.Kind.CRIMP and below == Terrain.Kind.CRIMP and crimp.x < 0:
				crimp = Vector2i(x, y + 1)
			if k == Terrain.Kind.JUG and below == Terrain.Kind.JUG and jug.x < 0:
				jug = Vector2i(x, y + 1)
			if k == Terrain.Kind.FACE and below == Terrain.Kind.FACE and y > 20 and face.x < 0:
				face = Vector2i(x + 1, y + 1)
	var spent := {}
	for pair in [["crimp", crimp], ["face", face], ["jug", jug]]:
		c.hang_at(Terrain.feet(pair[1]))
		c.stamina.value = 50.0
		for i in 60:
			GameInput.scripted = {"_": false}
			await tree.physics_frame
		spent[pair[0]] = 50.0 - c.stamina.value
	check(spent["crimp"] > spent["face"] * 2.0, "hanging on crimps empties the arms (%.1f vs %.1f a second)" % [spent["crimp"], spent["face"]])
	check(spent["jug"] < 0.0, "hanging on a jug gives it back (%.1f)" % -spent["jug"])
	await _done()


func test_a_fall_on_lead_stops_at_the_last_bolt() -> void:
	Crag.navigate = false
	await _load("warm-up")
	# Climb past the first bolt.
	var guard := 0
	while level.checkpoint < 1 and guard < 60 * 20:
		guard += 1
		GameInput.scripted = {"climb_up": true} if c.state == Climber.State.CLIMB else ({"climb_up": true} if c.can_grab() else {"move_right": true})
		await tree.physics_frame
	eq(level.checkpoint, 1, "the first bolt clipped")
	for i in 30:
		GameInput.scripted = {"climb_up": true}
		await tree.physics_frame
	var high := c.global_position.y
	c.stamina.value = 0.0
	await drive([], func() -> bool: return c.state == Climber.State.SLIP, 3.0, "letting go")
	eq(c.slips, 1, "a fall")
	await drive([], func() -> bool: return c.state != Climber.State.SLIP, 3.0, "on the rope")
	eq(c.state, Climber.State.CLIMB, "back on the rock at the bolt")
	var bolt: Vector2 = level.clips[0]["hang"]
	check(absf(c.global_position.y - bolt.y) < 2.0 and c.global_position.y > high, "hanging level with the last bolt, below where you fell from")
	await _done()


func test_a_dyno_crosses_blank_rock() -> void:
	Crag.navigate = false
	await _load("leap-of-faith")
	var t: Terrain = level.terrain
	# Top of the jug, under the blank.
	var jug_top := Vector2i(-1, -1)
	for y in t.height:
		for x in t.width:
			if t.kind(Vector2i(x, y)) == Terrain.Kind.JUG and jug_top.x < 0:
				jug_top = Vector2i(x + 1, y)
	c.hang_at(Terrain.feet(jug_top + Vector2i(0, 1)))
	await physics_frames(2)
	check(level.dyno_above(), "blank rock above, holds in reach")
	check("dyno" in level.hint_now().to_lower(), "and the HUD says so: " + level.hint_now())
	var before := c.global_position.y
	var breath := c.stamina.value
	GameInput.scripted = {"jump": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await drive([], func() -> bool: return c.state == Climber.State.CLIMB, 2.0, "the catch")
	eq(c.state, Climber.State.CLIMB, "caught the holds above")
	check(c.global_position.y < before - 2.0 * T, "two tiles higher, across the blank (%.0f px)" % (before - c.global_position.y))
	check(c.stamina.value <= breath - Climber.DYNO_COST + 0.5, "a hard move's breath")
	await _done()


func test_styles_unlocks_and_saves() -> void:
	_fresh_progress()
	eq(Crag.style_for(0, 1), "onsight", "first go, no falls")
	eq(Crag.style_for(0, 3), "redpoint", "no falls after earlier goes")
	eq(Crag.style_for(2, 1), "falls", "falls")
	check(not Crag.unlocked("sundown"), "the second route starts locked")
	Crag.climb("warm-up")
	var r := Crag.finish("warm-up", false, 1, 30)
	eq(r["style"], "", "lowering off is not a send")
	check(not Crag.unlocked("sundown"), "and opens nothing")
	Crag.climb("warm-up")
	r = Crag.finish("warm-up", true, 0, 60)
	eq(r["style"], "redpoint", "a clean second go")
	eq(r["unlocked"], "sundown", "the send opens the next route")
	check(Crag.unlocked("sundown"), "it is open")
	Crag.load_progress()
	eq(Crag.record("warm-up")["best"], "redpoint", "saved")
	eq(int(Crag.record("warm-up")["attempts"]), 2, "with both goes")
	check(Crag.unlocked("sundown"), "and the unlock")
	check(Crag.SAVE != SaveGame.PATH, "the crag keeps its own save file, apart from the expedition")
	_fresh_progress()
	await tree.process_frame
