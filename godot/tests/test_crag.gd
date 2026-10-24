extends CragBot
## Crag mode: the routes led by a scripted climber through the real input
## actions (walk to the line, climb, traverse where the line goes, rest on
## jugs, keep moving on crimps, dyno the blank, pull over the top), plus the
## rules one at a time: crimps, jugs, the dyno, clipping and lead falls,
## styles, unlocking, and saves. Nothing here touches the expedition.

func _fresh_progress() -> void:
	Crag.navigate = false
	Crag.reset()
	Records.delete_all()


func test_the_title_opens_two_separate_games() -> void:
	_fresh_progress()
	SaveGame.erase()
	var title: Node = load("res://modes/title/title.tscn").instantiate()
	root.add_child(title)
	await physics_frames(2)
	var labels: Array = []
	for b in title.card.get_children():
		if b is Button:
			labels.append(b.text)
	check(labels.size() == 2 and "Crag" in labels[0] and "Expedition" in labels[1], "Crag and Expedition: %s" % [labels])
	check("start here" in labels[0], "a new player is pointed at the crag: " + labels[0])
	var focused: Control = title.get_viewport().gui_get_focus_owner()
	check(focused != null and "Crag" in (focused as Button).text, "and it has the focus")
	title.queue_free()
	var menu: Node = load(Crag.CLASSIC_MENU).instantiate()
	root.add_child(menu)
	await physics_frames(2)
	var routes := 0
	var locked := 0
	for r in Crag.ROUTES:
		var b: Button = menu.rows[r["id"]]
		routes += 1
		if b.disabled:
			locked += 1
	eq(routes, 7, "the lesson and six routes")
	eq(locked, 6, "only the lesson is open at the start")
	check(menu.rows["daily"].disabled, "the daily route opens after the lesson")
	focused = menu.get_viewport().gui_get_focus_owner()
	check(focused != null and "First Climb" in (focused as Button).text, "one clear first choice: %s" % (focused.text if focused else "none"))
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
			# Every lesson but the one for a fall, which shows only after one.
			for key in CragLevel.LESSONS:
				check(level.lessons_seen.has(key) == (key != "fall" or c.slips > 0), "the lesson explains %s (seen: %s)" % [key, level.lessons_seen])
		if r["id"] in ["leap-of-faith", "lions-roof", "thunderhead"]:
			check(c.dynos >= (2 if r["id"] == "thunderhead" else 1), "%s needs its dynos (%d)" % [r["name"], c.dynos])
		print("      %s %s: %s, %d falls, %d s, %d moves, %d dynos, %d rope rests, %d%% stamina left, taps %s" % [r["grade"], r["name"], level.outcome.get("style", "-"), c.slips, int(c.clock), c.moves, c.dynos, level.rope_rests, int(c.stamina.fraction() * 100), level.taps])
		var gs: Dictionary = level.go_stats()
		print("        challenge %s: %s (squeezes %d, rests %d, perfect %d, good clips %d/%d, sloper grip low %.2f)" % [Logbook.CHALLENGES[r["id"]][0],
			Logbook.challenge_progress(r["id"], level.outcome.get("stats", gs).merged({"sent": true, "falls": c.slips, "style": level.outcome.get("style", "")})),
			gs["grip_taps"], gs["rests"], gs["perfect"], gs["good_clips"], gs["bolts"], gs["min_sloper_grip"]])
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


func test_a_lead_fall_is_twice_the_height_above_the_bolt() -> void:
	Crag.navigate = false
	await _load("the-pinch")
	# Clipped to bolt 4, then climbing on three rows above it, and off.
	for k in 4:
		level.clips[k]["clipped"] = true
	level.checkpoint = 4
	var bolt: Vector2 = level.clips[3]["hang"]
	var line: Vector2i = Terrain.cell_of(bolt)
	var top := Vector2i(line.x, line.y - 3)
	c.hang_at(Terrain.feet(top))
	await physics_frames(2)
	eq(c.state, Climber.State.CLIMB, "on the rock above bolt 4")
	var high := c.global_position.y
	c.stamina.value = 0.0
	await drive([], func() -> bool: return c.state == Climber.State.SLIP, 3.0, "letting go")
	eq(c.slips, 1, "a fall")
	HitStop.last = 0.0
	level.camera.last_kick = 0.0
	await drive([], func() -> bool: return c.state != Climber.State.SLIP, 3.0, "on the rope")
	check(HitStop.last > 0.0, "the rope's catch holds the frame")
	check(level.camera.last_kick >= 1.0, "then a hard kick (%.1f)" % level.camera.last_kick)
	await physics_frames(10)
	eq(Engine.time_scale, 1.0, "and time runs again")
	eq(c.state, Climber.State.CLIMB, "back on the rock")
	var above := bolt.y - high
	var below := c.global_position.y - bolt.y
	check(below >= above, "as far below the bolt as you were above it, or more (%.0f above, %.0f below)" % [above, below])
	check(below <= above + CragLevel.FALL_SLACK + Terrain.TILE * 1.5, "plus the slack, no more (%.0f above, %.0f below)" % [above, below])
	check(level.last_fall_m >= 3.0 * Crag.ROW_M * 2.0 - 0.6, "the fall is told in metres (%.1f m)" % level.last_fall_m)
	await _done()


func test_a_fall_low_down_can_reach_the_ground() -> void:
	Crag.navigate = false
	await _load("warm-up")
	level.clips[0]["clipped"] = true
	level.checkpoint = 1
	var bolt: Vector2 = level.clips[0]["hang"]
	var line: Vector2i = Terrain.cell_of(bolt)
	c.hang_at(Terrain.feet(Vector2i(line.x, line.y - 3)))
	await physics_frames(2)
	c.stamina.value = 60.0
	c.peel_off()
	await drive([], func() -> bool: return c.state == Climber.State.SLIP, 3.0, "off")
	await drive([], func() -> bool: return c.state != Climber.State.SLIP, 3.0, "landed")
	eq(level.ground_falls, 1, "the first bolt is too low to stop a fall from that high: the ground")
	check(absf(c.global_position.y - level._start.y) < 2.0, "back at the foot of the cliff")
	check(c.stamina.value <= 60.0 - CragLevel.GROUND_HIT + 1.0, "and it hurts (%.0f)" % c.stamina.value)
	check(level.clips[0]["clipped"], "the bolt stays clipped")
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
	eq(level.catch_quality, "good", "the hands have it, no tap needed")
	check(level.catching > 0.0 and level.action_word == "GRIP", "and a tap now makes it perfect (catching %.2f, button %s, state %d)" % [level.catching, level.action_word, c.state])
	GameInput.scripted = {"interact": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await tree.physics_frame
	eq(level.catch_quality, "perfect", "one tap on the contact: perfect")
	eq(level.catching, 0.0, "stuck")
	var higher := before - c.global_position.y
	# Tiny holds above the blank: keep tapping GRIP to stay on.
	for i in 70:
		GameInput.scripted = {"interact": i % 6 < 3}
		await tree.physics_frame
	eq(c.state, Climber.State.CLIMB, "still on the rock")
	check(higher > 2.0 * T, "two tiles higher, across the blank (%.0f px)" % higher)
	check(after <= breath - Climber.DYNO_COST + 0.5, "a hard move's breath (%.1f to %.1f)" % [breath, after])
	await _done()


func test_a_dyno_with_no_tap_still_catches_the_hold() -> void:
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
	eq(c.state, Climber.State.CLIMB, "jumped to the hold and caught it")
	await physics_frames(30)
	eq(c.state, Climber.State.CLIMB, "no tap needed to stay on")
	eq(c.slips, 0, "no fall")
	await _done()


func test_tiny_holds_need_taps_and_a_bolt_asks_to_be_clipped() -> void:
	Crag.navigate = false
	await _load("thunderhead")
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
	# An accepted squeeze is felt and heard over the music.
	var touch: Variant = Settings.touch_controls
	Settings.touch_controls = true
	Haptics.last_ms = 0
	await physics_frames(20)
	GameInput.scripted = {"interact": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await tree.physics_frame
	eq(Haptics.last_ms, 15, "a squeeze: a short buzz")
	eq(Audio.last, "chalk", "and the chalk")
	eq(Audio.last_db, -10.0 + Audio.EFFECTS_DB, "with no body trim")
	Settings.touch_controls = touch
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
	var touch: Variant = Settings.touch_controls
	await _load("warm-up")
	Settings.touch_controls = true
	Haptics.history.clear()
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
	eq(level.checkpoint, 1, "a tap: clipped")
	check(28 in Haptics.history, "the clip: one firm buzz (%s)" % [Haptics.history])
	check("clip" in Audio.history and not "cairn" in Audio.history.slice(Audio.history.rfind("clip")), "one click of the gate, no second chime")
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
	Settings.touch_controls = touch
	await _done()


func _still_frames(n: int) -> void:
	for i in n:
		GameInput.scripted = {"_": false}
		await tree.physics_frame


func test_grade_bolting_and_exposure_are_apart() -> void:
	Crag.navigate = false
	var drains := []
	for r in Crag.ROUTES:
		await _load(r["id"])
		var f := Crag.facts(r["id"])
		var gaps := []
		for k in range(1, level.clips.size()):
			gaps.append(int(level.clips[k]["gap"]))
		eq(gaps, f["gaps"], "%s: the facts read the same bolts as the level" % r["name"])
		eq(int(f["bolts"]), level.clips.size(), "%s: bolts" % r["name"])
		print("      %s %s: %d bolts, gaps %s · %s · %s" % [r["grade"], r["name"], level.clips.size(), gaps, Crag.protection_words(r["id"]), Crag.exposure_words(r["id"])])
		if not r.get("tutorial", false):
			drains.append(float(r["gripDrain"]))
		await _done()
	# The grade is the moves: the tiny holds get harder route by route.
	for k in range(1, drains.size()):
		check(drains[k] > drains[k - 1], "the grade climbs: grip drain %s" % [drains])
	# The bolting is not the grade: an easy route can be run-out and a hard
	# one well bolted.
	eq(Crag.facts("warm-up")["protection"], "well", "the warm-up is well bolted")
	eq(Crag.facts("warm-up")["exposure"], "low", "and low")
	check(Crag.facts("sundown")["protection"] != "well" and Crag.facts("the-pinch")["protection"] == "well", "the 5b is sportier than the 6a")
	check(Crag.facts("lions-roof")["protection"] == "well", "the 6c roof is well bolted")
	eq(Crag.facts("thunderhead")["protection"], "runout", "the 7a is run-out")
	eq(Crag.facts("thunderhead")["exposure"], "high", "and exposed")
	check(Crag.facts("sundown")["exposure"] == "high" and int(Crag.facts("sundown")["first"]) >= 5, "a high first bolt makes an easy route exposed")
	check("ground" in Crag.exposure_words("sundown"), "and it says so: " + Crag.exposure_words("sundown"))
	# One tap clips, on the easiest route and the hardest.
	for id in ["warm-up", "thunderhead"]:
		await _load(id)
		var guard := 0
		while level.clip_target < 0 and guard < 60 * 20:
			guard += 1
			GameInput.scripted = {"climb_up": true} if c.state == Climber.State.CLIMB or c.can_grab() else {"move_right": true}
			await tree.physics_frame
		check(not "times" in level.hint_now(), "the hint asks for one tap: " + level.hint_now())
		GameInput.scripted = {"interact": true}
		await tree.physics_frame
		GameInput.scripted = {"_": false}
		await tree.physics_frame
		eq(level.checkpoint, 1, "%s: one tap clips" % id)
		await _done()


func test_where_you_clip_from_matters() -> void:
	Crag.navigate = false
	await _load("the-pinch")
	var t: Terrain = level.terrain
	var spots := {}
	for y in range(t.height - 1, 0, -1):
		for x in t.width:
			var k := t.kind(Vector2i(x, y))
			var name: String = {Terrain.Kind.JUG: "jug", Terrain.Kind.CRIMP: "crimp", Terrain.Kind.FACE: "face"}.get(k, "")
			if name != "" and not spots.has(name) and t.kind(Vector2i(x, y - 1)) == k and t.kind(Vector2i(x - 1, y)) == k and t.kind(Vector2i(x + 1, y)) == k:
				spots[name] = Vector2i(x, y)
	var costs := {}
	for name in ["jug", "face", "crimp"]:
		c.hang_at(Terrain.feet(spots[name]))
		await physics_frames(1)
		eq(t.hold_at(c.body_rect()), {"jug": Terrain.Kind.JUG, "crimp": Terrain.Kind.CRIMP, "face": Terrain.Kind.FACE}[name], "hanging on the %s" % name)
		costs[name] = level.clip_cost()
	print("      clip costs: %s" % [costs])
	eq(float(costs["jug"]["stamina"]), 0.0, "clipping from a big hold is free")
	check(float(costs["face"]["stamina"]) > 0.0, "from ordinary rock it costs a little")
	check(float(costs["crimp"]["stamina"]) > float(costs["face"]["stamina"]) * 2.0 and float(costs["crimp"]["grip"]) > 0.0, "from tiny holds it costs grip and much more stamina")
	await _done()
	# A real clip off the warm-up's first bolt takes what the hint said.
	await _load("warm-up")
	var guard := 0
	while level.clip_target < 0 and guard < 60 * 20:
		guard += 1
		GameInput.scripted = {"climb_up": true} if c.state == Climber.State.CLIMB or c.can_grab() else {"move_right": true}
		await tree.physics_frame
	GameInput.scripted = {"_": false}
	await tree.physics_frame
	var want: float = level.clip_cost()["stamina"]
	var before: float = c.stamina.value
	GameInput.scripted = {"interact": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	eq(level.checkpoint, 1, "clipped")
	check(absf((before - c.stamina.value) - want) < 0.6, "the clip took its cost (%.1f, said %.1f)" % [before - c.stamina.value, want])
	await _done()


func test_shoes_trade_speed_for_stamina() -> void:
	_fresh_progress()
	Crag.navigate = false
	await _load("warm-up", "")
	var words := ""
	for b in level.panel._buttons.get_children():
		words += b.text + " | "
	check("Neutral shoes" in words and "Aggressive shoes" in words, "the brief offers both pairs of shoes: %s" % words)
	level.panel.choose("aggressive")
	await physics_frames(1)
	eq(Crag.shoes, "aggressive", "the pick is remembered")
	await _done()
	Crag.load_progress()
	eq(Crag.shoes, "aggressive", "and saved")
	# The same climb in each pair: neutral is slower and cheaper a second,
	# aggressive faster and dearer.
	var runs := {}
	for id in ["neutral", "aggressive"]:
		await _load("warm-up", id)
		var t: Terrain = level.terrain
		var cell: Vector2i = level.clips[1]["cell"] + Vector2i(0, 3)
		for x in range(cell.x - 4, cell.x + 5):
			if t.kind(Vector2i(x, cell.y)) == Terrain.Kind.FACE and t.kind(Vector2i(x, cell.y - 6)) == Terrain.Kind.FACE:
				cell.x = x
				break
		c.hang_at(Terrain.feet(cell))
		check(c.state == Climber.State.CLIMB, "on the rock to try the %s shoes" % id)
		var y0: float = c.global_position.y
		var s0: float = c.stamina.value
		GameInput.scripted = {"climb_up": true}
		await physics_frames(60)
		GameInput.scripted = {}
		runs[id] = {"climbed": y0 - c.global_position.y, "spent": s0 - c.stamina.value}
		await _done()
	print("      shoes, one second climbing: %s" % [runs])
	check(runs["aggressive"]["climbed"] > runs["neutral"]["climbed"] * 1.5, "aggressive shoes climb faster")
	check(runs["aggressive"]["spent"] > runs["neutral"]["spent"] * 1.5, "aggressive shoes cost more stamina")
	# Either pair can send the hard routes; aggressive gets up quicker.
	for r in ["the-pinch", "thunderhead"]:
		var secs := {}
		for id in ["neutral", "aggressive"]:
			_fresh_progress()
			await _load(r, id)
			var sent := await lead()
			check(sent, "%s sent in %s shoes; stopped at %s, %s" % [r, id, where(), level.stats_line(int(c.stamina.fraction() * 100))])
			secs[id] = c.clock
			print("      %s in %s shoes: %d s, %d falls, %d rope rests, %d%% stamina left" % [r, id, int(c.clock), c.slips, level.rope_rests, int(c.stamina.fraction() * 100)])
			await _done()
		check(secs["aggressive"] < secs["neutral"], "%s is quicker in aggressive shoes (%s)" % [r, secs])
	_fresh_progress()


func test_grip_wants_squeezes_not_mashing() -> void:
	Crag.navigate = false
	await _load("thunderhead")
	var t: Terrain = level.terrain
	var crimp := Vector2i(-1, -1)
	for y in range(t.height - 1, 0, -1):
		for x in t.width:
			if crimp.x < 0 and t.kind(Vector2i(x, y)) == Terrain.Kind.CRIMP and t.kind(Vector2i(x, y - 4)) == Terrain.Kind.CRIMP and t.kind(Vector2i(x - 1, y)) == Terrain.Kind.CRIMP and t.kind(Vector2i(x + 1, y)) == Terrain.Kind.CRIMP:
				crimp = Vector2i(x, y)
	# Moving up the tiny holds: the grip fades slowly.
	c.hang_at(Terrain.feet(crimp))
	await physics_frames(2)
	level.grip = 1.0
	for i in 40:
		GameInput.scripted = {"climb_up": true}
		await tree.physics_frame
	var moving_grip: float = level.grip
	# Stopped on them: it fades fast.
	level.grip = 1.0
	await _still_frames(40)
	var still_grip: float = level.grip
	print("      grip after 2/3 s: moving %.2f, stopped %.2f" % [moving_grip, still_grip])
	check(moving_grip > 0.6, "keep moving and the grip holds up (%.2f)" % moving_grip)
	check(still_grip < moving_grip - 0.4, "stop and it fades fast (%.2f)" % still_grip)
	# Mashing GRIP is no better than squeezing in time.
	var results := {}
	for style in ["mash", "squeeze"]:
		c.hang_at(Terrain.feet(crimp))
		level.grip = 0.2
		level.taps["grip"] = 0
		level.wasted_squeezes = 0
		# Start each style fresh: no flurry or cooldown left from the last.
		level._burst = 0
		level._grip_cool = 0.0
		level._squeeze_queued = false
		for i in 60:
			# Mash: a tap every other frame. Squeeze: one when the meter is
			# low, as the hint says.
			var tap: bool = (i % 2 == 0) if style == "mash" else (level.grip < 0.5 and i % 4 == 0)
			GameInput.scripted = {"interact": tap}
			await tree.physics_frame
		results[style] = [level.grip, level.taps["grip"], level.wasted_squeezes]
	GameInput.scripted = {"_": false}
	print("      a second of grip: %s" % [results])
	check(results["mash"][1] >= 4 * results["squeeze"][1], "mashing is many more taps (%s)" % [results])
	check(results["mash"][0] <= results["squeeze"][0] + 0.25, "for little more grip (%s)" % [results])
	check(results["mash"][2] >= 10, "and most of the mashing is wasted (%s)" % [results])
	eq(results["squeeze"][2], 0, "squeezing when the meter drops wastes none")
	await _done()


func test_read_the_route_and_take_beta() -> void:
	_fresh_progress()
	Crag.navigate = false
	await _load("sundown", "")
	check(level.panel.open, "the brief")
	level.panel.choose("look")
	await physics_frames(10)
	check(level.previewing and level.marks.visible and level.camera.look != Vector2.INF, "looking at the route: the camera runs up it, marked")
	var kinds: Array = level.marks.sections().map(func(m: Dictionary) -> String: return m["kind"])
	check("crimp" in kinds and "jug" in kinds, "the marks show tiny holds and big holds: %s" % [kinds])
	var y0: float = level.camera.global_position.y
	await physics_frames(90)
	check(level.camera.global_position.y < y0 - 40.0, "the camera climbs the route")
	GameInput.scripted = {"interact": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await physics_frames(3)
	check(not level.previewing and level.panel.open, "a tap skips back to the brief")
	eq(int(Crag.record("sundown")["attempts"]), 0, "looking is not a go")
	level.panel.choose("beta")
	await physics_frames(1)
	check(level.beta and Crag.record("sundown")["beta"], "beta taken")
	check("Bolt" in level.panel._body.text or "leap" in level.panel._body.text.to_lower(), "beta tips: " + level.panel._body.text)
	level.panel.choose("brief")
	await physics_frames(1)
	check("flash" in level.panel._body.text, "the brief says a clean first go is now a flash")
	level.panel.choose("neutral")
	await physics_frames(1)
	eq(int(Crag.record("sundown")["attempts"]), 1, "tying in is the go")
	await _done()
	_fresh_progress()


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
	eq(Crag.style_for(0, 1, true), "flash", "first go, no falls, with beta")
	eq(Crag.style_for(0, 2, true), "redpoint", "beta does not matter after the first go")
	check(not Crag.unlocked("warm-up"), "the first route opens after the lesson")
	Crag.climb("first-climb")
	Crag.tie_in("first-climb")
	Crag.finish("first-climb", true, 0, 60)
	check(Crag.unlocked("warm-up"), "done the lesson: the warm-up opens")
	check(not Crag.unlocked("sundown"), "the next route starts locked")
	# Reading the brief and backing off is not a go.
	Crag.climb("warm-up")
	eq(int(Crag.record("warm-up")["attempts"]), 0, "opening the brief is not a go")
	Crag.tie_in("warm-up")
	var r := Crag.finish("warm-up", false, 1, 30, 3)
	eq(r["style"], "", "lowering off is not a send")
	check(r["highpoint"], "but bolt 3 is a high point")
	eq(int(Crag.record("warm-up")["highpoint"]), 3, "kept")
	check(not Crag.unlocked("sundown"), "and opens nothing")
	Crag.climb("warm-up")
	Crag.tie_in("warm-up")
	r = Crag.finish("warm-up", true, 0, 60)
	eq(r["style"], "redpoint", "a clean second go")
	eq(r["unlocked"], "sundown", "the send opens the next route")
	check(Crag.unlocked("sundown"), "it is open")
	Crag.load_progress()
	eq(Crag.record("warm-up")["best"], "redpoint", "saved")
	eq(int(Crag.record("warm-up")["attempts"]), 2, "with both goes")
	eq(int(Crag.record("warm-up")["highpoint"]), 3, "and the high point")
	check(Crag.unlocked("sundown"), "and the unlock")
	# Beta before a first go: a clean send is a flash.
	Crag.take_beta("sundown")
	Crag.tie_in("sundown")
	eq(Crag.finish("sundown", true, 0, 90)["style"], "flash", "beta, then a clean first go: a flash")
	# A save with odd values loads safely.
	SaveGame.write({"progress": {"warm-up": {"attempts": -4, "sends": "x", "bestFalls": null, "best": "wizard", "highpoint": 500, "beta": "yes"}}, "shoes": "slippers"}, Crag.SAVE)
	Crag.load_progress()
	var w := Crag.record("warm-up")
	check(int(w["attempts"]) == 0 and String(w["best"]) == "" and int(w["highpoint"]) <= 99 and w["beta"] == false, "a bad save is cleaned up: %s" % [w])
	eq(Crag.shoes, "neutral", "unknown shoes fall back to neutral")
	check(Crag.SAVE != SaveGame.PATH, "the crag keeps its own save file, apart from the expedition")
	_fresh_progress()
	await tree.process_frame


## The grades as a curve: a careful player and a casual one lead every
## route. Easy routes stay easy for both; each grade from 6a up asks a bit
## more of the arms (the careful player's lowest point steps down); the
## hardest is a fight for the casual player, down to the last of the bar,
## but not out of reach. Neither too easy nor too hard: a near thing.
func test_the_grades_climb_in_steady_steps() -> void:
	var low := {"expert": {}, "casual": {}}
	for mode in ["expert", "casual"]:
		casual = mode == "casual"
		for r in Crag.ROUTES:
			_fresh_progress()
			Crag.climb(r["id"])
			await _load(r["id"])
			var sent := await lead()
			check(sent, "%s: %s sent (%s)" % [mode, r["name"], level.stats_line(int(c.stamina.fraction() * 100))])
			if mode == "expert" or r["grade"] in ["Lesson", "4", "5b", "6a"]:
				eq(c.slips, 0, "%s: %s without a fall" % [mode, r["name"]])
			low[mode][r["grade"]] = lowest * 100.0
			await _done()
	casual = false
	failures = failures.filter(func(f: String) -> bool: return not f.begins_with("gave up"))
	print("      lowest stamina, careful: %s" % [low["expert"]])
	print("      lowest stamina, casual:  %s" % [low["casual"]])
	var e: Dictionary = low["expert"]
	var k: Dictionary = low["casual"]
	for g in ["Lesson", "4", "5b"]:
		check(e[g] >= 40.0, "%s is easy for a careful player (lowest %d%%)" % [g, e[g]])
		check(k[g] >= 25.0, "and fine for a casual one (lowest %d%%)" % k[g])
	var steps := ["6a", "6b", "6c", "7a"]
	for i in steps.size() - 1:
		check(e[steps[i + 1]] <= e[steps[i]] + 3.0, "%s asks more than %s (%d%% vs %d%%)" % [steps[i + 1], steps[i], e[steps[i + 1]], e[steps[i]]])
	check(e["7a"] >= 15.0 and e["7a"] <= 45.0, "the hardest leaves a careful player some, not much (%d%%)" % e["7a"])
	check(k["7a"] < 20.0, "and is a real fight for a casual one (%d%%)" % k["7a"])
	var easy: float = (k["Lesson"] + k["4"] + k["5b"]) / 3.0
	var hard: float = (k["6b"] + k["6c"] + k["7a"]) / 3.0
	check(easy - hard >= 15.0, "the curve is felt: casual lowest %d%% on the easy routes, %d%% on the hard ones" % [easy, hard])
	_fresh_progress()


func test_low_stamina_pulses_and_breathes_over_the_music() -> void:
	Crag.navigate = false
	await _load("warm-up")
	c.stamina.value = c.stamina.max_value * 0.6
	level.hud.update_from(level)
	check(not level.hud.low_pulse, "plenty left: the bar is steady")
	c.stamina.value = c.stamina.max_value * 0.2
	level.hud.update_from(level)
	check(level.hud.low_pulse, "under a quarter: the bar pulses")
	var effects := Settings.effects_volume
	Settings.effects_volume = 1.0
	Audio.last = ""
	c._breathing(2.2)
	eq(Audio.last, "breath", "and breathing comes sooner than the usual 2.4 s")
	eq(Audio.last_db, -16.0 + Audio.EFFECTS_DB, "over the music: no body trim")
	Settings.effects_volume = effects
	await _done()


func test_the_action_button_clicks_for_the_verb_that_took_the_tap() -> void:
	Crag.navigate = false
	await _load("thunderhead")
	var t: Terrain = level.terrain
	# Tiny holds away from the bolts: the button says GRIP.
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
	eq(level.action_word, "GRIP", "on tiny holds the button is GRIP")
	Audio.history.clear()
	level.panel.show_panel("x", "x", "x", [["x", "ok"]])
	GameInput.scripted = {"interact": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await tree.physics_frame
	check(not "tap" in Audio.history, "no click while a panel is up")
	level.panel.hide_panel()
	await physics_frames(2)
	GameInput.scripted = {"interact": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await tree.physics_frame
	check("tap" in Audio.history, "a tap on GRIP clicks (%s)" % [Audio.history])
	await _done()
