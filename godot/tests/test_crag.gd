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
func lead(seconds: float = 300.0) -> bool:
	var t: Terrain = level.terrain
	var resting := false
	var target := NAN
	for i in int(seconds * 60.0):
		if level._ended:
			break
		if level.panel.open and level.lesson != "":
			# A lesson: read it, then on.
			level.panel.choose("lesson")
			await tree.physics_frame
			continue
		var held := {"_": false}
		if c.state == Climber.State.SLIP:
			target = NAN
			resting = false
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
		# Tap tap tap: clip each bolt, hold on to tiny holds, stick dynos.
		if level.action_word in ["CLIP", "GRIP"] and i % 4 < 2:
			held["interact"] = true
		# Just clipped and getting tired: rest on the rope, and keep still
		# while the stamina comes back.
		if level.resting_rope:
			held = {"_": false}
		elif level.can_rest() and level.action_word == "REST" and c.stamina.fraction() < 0.85:
			held = {"interact": i % 4 < 2}
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
	eq(routes, 7, "the lesson and six routes")
	eq(locked, 6, "only the lesson is open at the start")
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
		if r.get("tutorial", false):
			eq(level.lessons_seen.size(), CragLevel.LESSONS.size(), "the lesson explains everything: %s" % [level.lessons_seen])
		if r["id"] in ["leap-of-faith", "lions-roof", "thunderhead"]:
			check(c.dynos >= (2 if r["id"] == "thunderhead" else 1), "%s needs its dynos (%d)" % [r["name"], c.dynos])
		print("      %s %s: %s, %d falls, %d s, %d dynos, %d rope rests, %d%% stamina left" % [r["grade"], r["name"], level.outcome.get("style", "-"), c.slips, int(c.clock), c.dynos, level.rope_rests, int(c.stamina.fraction() * 100)])
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
		var held: Dictionary = {"climb_up": true} if c.state == Climber.State.CLIMB else ({"climb_up": true} if c.can_grab() else {"move_right": true})
		if level.action_word == "CLIP":
			# Stop and clip: tap three times.
			held = {"interact": guard % 4 < 2}
		GameInput.scripted = held
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
	# The top of the jug right under the blank rock.
	var jug_top := Vector2i(-1, -1)
	for y in t.height:
		for x in t.width:
			var cell := Vector2i(x, y)
			if t.kind(cell) == Terrain.Kind.JUG and t.kind(cell + Vector2i.UP) == Terrain.Kind.AIR and not t.is_solid(cell + Vector2i(0, -2)) and t.is_climbable(cell + Vector2i(0, -3)) and jug_top.x < 0:
				jug_top = Vector2i(x + 1, y)
	c.hang_at(Terrain.feet(jug_top + Vector2i(0, 1)))
	await physics_frames(2)
	# The bolt beside the jug asks first: clip it, and let the rest go by.
	for i in 12:
		GameInput.scripted = {"interact": i % 4 < 2}
		await tree.physics_frame
	GameInput.scripted = {"_": false}
	await physics_frames(2)
	check(level.dyno_above(), "blank rock above, holds in reach")
	check("jump" in level.hint_now().to_lower(), "and the HUD says so: " + level.hint_now())
	var before := c.global_position.y
	var breath := c.stamina.value
	GameInput.scripted = {"jump": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await drive([], func() -> bool: return c.state == Climber.State.CLIMB, 2.0, "the catch")
	eq(c.state, Climber.State.CLIMB, "caught the holds above")
	var after := c.stamina.value
	await tree.physics_frame
	check(level.catching > 0.0 and level.action_word == "GRIP", "and has to stick it (catching %.2f, button %s, state %d)" % [level.catching, level.action_word, c.state])
	for i in 12:
		GameInput.scripted = {"interact": i % 4 < 2}
		await tree.physics_frame
	eq(level.catching, 0.0, "three fast taps stick it")
	var higher := before - c.global_position.y
	# Tiny holds above the blank: keep tapping GRIP to stay on.
	for i in 70:
		GameInput.scripted = {"interact": i % 6 < 3}
		await tree.physics_frame
	eq(c.state, Climber.State.CLIMB, "still on the rock")
	check(higher > 2.0 * T, "two tiles higher, across the blank (%.0f px)" % higher)
	check(after <= breath - Climber.DYNO_COST + 0.5, "a hard move's breath (%.1f to %.1f)" % [breath, after])
	await _done()


func test_a_dyno_not_stuck_slips_off() -> void:
	Crag.navigate = false
	await _load("leap-of-faith")
	var t: Terrain = level.terrain
	# The top of the jug right under the blank rock.
	var jug_top := Vector2i(-1, -1)
	for y in t.height:
		for x in t.width:
			var cell := Vector2i(x, y)
			if t.kind(cell) == Terrain.Kind.JUG and t.kind(cell + Vector2i.UP) == Terrain.Kind.AIR and not t.is_solid(cell + Vector2i(0, -2)) and t.is_climbable(cell + Vector2i(0, -3)) and jug_top.x < 0:
				jug_top = Vector2i(x + 1, y)
	c.hang_at(Terrain.feet(jug_top + Vector2i(0, 1)))
	await physics_frames(2)
	GameInput.scripted = {"jump": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await drive([], func() -> bool: return c.state == Climber.State.CLIMB, 2.0, "the catch")
	await drive([], func() -> bool: return c.state != Climber.State.CLIMB, 2.0, "no taps")
	check(c.state != Climber.State.CLIMB, "no taps: the hold slips out of your hands")
	await _done()


func test_tiny_holds_need_taps_and_a_bolt_asks_to_be_clipped() -> void:
	Crag.navigate = false
	await _load("the-pinch")
	var t: Terrain = level.terrain
	# Tiny holds well away from any bolt, so GRIP is the only ask.
	var crimp := Vector2i(-1, -1)
	for y in range(t.height - 1, 0, -1):
		var near_bolt := false
		for q in t.markers["Q"]:
			if absi(q.y - y) < 3:
				near_bolt = true
		for x in t.width:
			if not near_bolt and t.kind(Vector2i(x, y)) == Terrain.Kind.CRIMP and t.kind(Vector2i(x, y - 1)) == Terrain.Kind.CRIMP and crimp.x < 0:
				crimp = Vector2i(x + 1, y)
	c.hang_at(Terrain.feet(crimp))
	c.stamina.value = 100.0
	await physics_frames(2)
	check(level.on_crimps and level.action_word == "GRIP", "on tiny holds the button is GRIP")
	# Tapping keeps the grip tight: the tiny holds cost little.
	for i in 90:
		GameInput.scripted = {"interact": i % 6 < 3}
		await tree.physics_frame
	var tapped := 100.0 - c.stamina.value
	eq(c.state, Climber.State.CLIMB, "tapping GRIP: still on")
	# Not tapping: the grip goes slack and the same time costs far more.
	c.stamina.value = 100.0
	await _still_frames(90)
	var slack := 100.0 - c.stamina.value
	check(slack > tapped * 1.8, "without taps the tiny holds burn stamina (%.1f vs %.1f with taps)" % [slack, tapped])
	await _done()
	# A bolt asks; climbing on without tapping leaves it unclipped.
	await _load("warm-up")
	var guard := 0
	while level.clip_target < 0 and guard < 60 * 20:
		guard += 1
		GameInput.scripted = {"climb_up": true} if c.state == Climber.State.CLIMB or c.can_grab() else {"move_right": true}
		await tree.physics_frame
	check(level.clip_target >= 0 and level.action_word == "CLIP", "a bolt in reach asks: CLIP")
	for i in 60:
		GameInput.scripted = {"climb_up": true}
		await tree.physics_frame
	eq(level.checkpoint, 0, "climbing on without tapping: not clipped")
	await _done()


func test_a_clip_offers_a_rest_on_the_rope() -> void:
	Crag.navigate = false
	await _load("warm-up")
	var guard := 0
	while level.clip_target < 0 and guard < 60 * 20:
		guard += 1
		GameInput.scripted = {"climb_up": true} if c.state == Climber.State.CLIMB or c.can_grab() else {"move_right": true}
		await tree.physics_frame
	for i in 12:
		GameInput.scripted = {"interact": i % 4 < 2}
		await tree.physics_frame
		if level.checkpoint > 0:
			break
	eq(level.checkpoint, 1, "tap tap tap: clipped")
	GameInput.scripted = {"_": false}
	await tree.physics_frame
	check(level.can_rest() and level.action_word == "REST", "then the button offers a rest (%s)" % level.action_word)
	eq(level.rope_left, CragLevel.ROPE_REST, "with a full green rest bar")
	c.stamina.value = 40.0
	GameInput.scripted = {"interact": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await tree.physics_frame
	check(level.resting_rope, "a tap takes it")
	await physics_frames(60)
	check(c.stamina.value > 50.0, "stamina comes back on the rope (%.0f)" % c.stamina.value)
	# Move: the rest ends, and what is left of the bar waits for later.
	GameInput.scripted = {"climb_up": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await tree.physics_frame
	check(not level.resting_rope and level.rope_left > 0.0, "moving ends it; the bar keeps the rest (%.0f)" % level.rope_left)
	check(level.can_rest(), "and you can rest again")
	GameInput.scripted = {"interact": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await physics_frames(180)
	check(not level.resting_rope and level.rope_left <= 0.0, "a bar is only a little: it runs out")
	check(not level.can_rest(), "until the next clip")
	check(c.stamina.value <= 40.0 + Crag.MAX_FALLS * 0 + CragLevel.ROPE_REST + 2.0, "worth at most %d stamina (%.0f)" % [int(CragLevel.ROPE_REST), c.stamina.value])
	await _done()


func _still_frames(n: int) -> void:
	for i in n:
		GameInput.scripted = {"_": false}
		await tree.physics_frame


func test_clipping_takes_more_taps_on_harder_routes() -> void:
	Crag.navigate = false
	var taps := []
	for r in Crag.ROUTES:
		taps.append(int(r.get("clipTaps", 3)))
	eq(taps[0], 1, "one tap on the lesson")
	eq(taps[1], 1, "one tap on the easy route")
	for i in range(1, taps.size()):
		check(taps[i] >= taps[i - 1], "never fewer taps on a harder route: %s" % [taps])
	check(taps[-1] >= 4, "several on the hardest")
	# One tap clips on the warm-up.
	await _load("warm-up")
	var guard := 0
	while level.clip_target < 0 and guard < 60 * 20:
		guard += 1
		GameInput.scripted = {"climb_up": true} if c.state == Climber.State.CLIMB or c.can_grab() else {"move_right": true}
		await tree.physics_frame
	GameInput.scripted = {"interact": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await tree.physics_frame
	eq(level.checkpoint, 1, "one tap clips on the warm-up")
	await _done()


func test_the_lesson_stops_the_game_to_explain() -> void:
	Crag.navigate = false
	Crag.reset()
	check(Crag.unlocked("first-climb") and not Crag.unlocked("warm-up"), "the lesson comes first")
	await _load("first-climb")
	await drive(["move_right"], func() -> bool: return level.panel.open, 10.0, "to the rock")
	eq(level.lesson, "rock", "at the rock the game stops to explain it")
	eq(c.state, Climber.State.LOCKED, "and the climber waits while you read")
	var clock := c.clock
	await physics_frames(60)
	near(c.clock, clock, 0.001, "time stands still")
	level.panel.choose("lesson")
	await tree.physics_frame
	check(not level.panel.open, "Got it: on you go")
	await _done()
	Crag.reset()


func test_styles_unlocks_and_saves() -> void:
	_fresh_progress()
	eq(Crag.style_for(0, 1), "onsight", "first go, no falls")
	eq(Crag.style_for(0, 3), "redpoint", "no falls after earlier goes")
	eq(Crag.style_for(2, 1), "falls", "falls")
	check(not Crag.unlocked("warm-up"), "the first route opens after the lesson")
	Crag.climb("first-climb")
	Crag.finish("first-climb", true, 0, 60)
	check(Crag.unlocked("warm-up"), "done the lesson: the warm-up opens")
	check(not Crag.unlocked("sundown"), "the next route starts locked")
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
