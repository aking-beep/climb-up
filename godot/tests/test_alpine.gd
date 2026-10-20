extends ClimbBot
## The fastest way's alpine pitches (Alpine): only the Umbwe climbs rope up;
## a clipped piton holds a fall (no slip, but it hurts, and you hang below
## the piton); with nothing clipped a fall is a slip back to the cairn; REST
## on the rock hangs on the rope; at the anchor you are tied in until you
## have pulled your partner up.


func _load(climb: String, route: String) -> void:
	SaveGame.erase()
	Expedition.found = {}
	Settings.touch_controls = false
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
	# A tap right after the brief closes is the brief's own (the level
	# lets 0.3 s pass).
	await physics_frames(30)


func _done() -> void:
	GameInput.scripted = {}
	level.queue_free()
	level = null
	await physics_frames(2)
	SaveGame.erase()


## On the first pitch's rock, feet level with piton `i` (its row).
func _on_pitch_at(i: int) -> Dictionary:
	var al: Alpine = level.alpine
	var p: Dictionary = al.current()
	var pin: Vector2i = p["pitons"][i]["cell"]
	c.hang_at(Terrain.feet(pin + Vector2i(0, 1)))
	await physics_frames(2)
	return p


func _clip_in_reach() -> void:
	var al: Alpine = level.alpine
	await drive([], func() -> bool: return al.clip_target >= 0, 1.0, "a piton in reach")
	await press("interact")


func test_only_the_fastest_way_ropes_up() -> void:
	for climb in ["lava-tower", "barranco-wall", "summit-night"]:
		for route in Trek.ROUTES:
			await _load(climb, route)
			var al: Alpine = level.alpine
			eq(al != null, route == "umbwe", "%s on %s: pitches only on the fastest way" % [climb, route])
			if al:
				check(al.pitches.size() >= 6, "%s: a climbing route, mostly pitches (%d)" % [climb, al.pitches.size()])
				for p in al.pitches:
					check(p["pitons"].size() >= 3, "%s: pitons up each pitch" % climb)
					check(float(p["base"].y) - float(p["top"]) * Terrain.TILE >= 9.0 * Terrain.TILE, "%s: each pitch taller than the bar climbs in one go" % climb)
				check(al.partner != null, "%s: a partner on the other end of the rope" % climb)
			await _done()


func test_a_clipped_fall_is_held_by_the_rope() -> void:
	await _load("lava-tower", "umbwe")
	var al: Alpine = level.alpine
	var p := await _on_pitch_at(1)
	eq(c.state, Climber.State.CLIMB, "on the rock")
	var before := c.stamina.value
	await _clip_in_reach()
	eq(al.clipped(), 1, "the piton is clipped")
	check(c.stamina.value < before, "clipping costs a little breath")
	# Up a row past the piton, then the arms give out.
	c.hang_at(c.global_position + Vector2(0, -Terrain.TILE))
	await physics_frames(2)
	var slips := c.slips
	var cp: int = level.checkpoint
	var pin_feet := Terrain.feet(p["pitons"][1]["cell"] + Vector2i(0, 1))
	c.stamina.value = c.stamina.max_value * 0.8
	var had := c.stamina.value
	c.slip("arms")
	await drive([], func() -> bool: return c.state != Climber.State.SLIP, 3.0, "the rope comes tight")
	eq(c.slips, slips, "the rope held it: no slip")
	eq(c.rope_falls, 1, "a fall on the rope")
	eq(level.checkpoint, cp, "no further back than you were")
	check(c.global_position.y > pin_feet.y, "hanging below the piton (%.0f, piton at %.0f)" % [c.global_position.y, pin_feet.y])
	check(c.global_position.y <= p["base"].y + 0.5, "no lower than the foot of the pitch")
	check(absf(c.global_position.x / Terrain.TILE - float(p["x"])) < 2.6, "still on the pitch")
	check(c.stamina.value < had, "the fall hurts (%.1f from %.1f)" % [c.stamina.value, had])
	check(c.stamina.value >= c.stamina.max_value * 0.25 - 0.01, "never below a quarter of the bar")
	await _done()


func test_with_nothing_clipped_a_fall_is_a_slip() -> void:
	await _load("lava-tower", "umbwe")
	await _on_pitch_at(1)
	var slips := c.slips
	c.slip("arms")
	await drive([], func() -> bool: return c.state != Climber.State.SLIP, 3.0, "the fall")
	eq(c.slips, slips + 1, "nothing clipped: it counts")
	eq(c.rope_falls, 0, "the rope held nothing")
	check(c.global_position.distance_to(level.cairns[level.checkpoint]) < 2.0, "back at the cairn")
	await _done()


func test_rest_on_the_rope() -> void:
	await _load("lava-tower", "umbwe")
	var al: Alpine = level.alpine
	await _on_pitch_at(1)
	# Not clipped yet: REST on the rock does nothing, nor does holding still.
	c.stamina.value = 4.0
	await press("rest")
	await physics_frames(60)
	check(not al.resting, "nothing to sit back on before the first piton")
	await _clip_in_reach()
	c.stamina.value = 4.0
	var bar := al.rope_left
	# Clipped: holding still hangs you on the rope by itself.
	await drive([], func() -> bool: return al.resting, 2.0, "hang on the rope")
	check(al.resting, "clipped: holding still sits you back on the rope")
	await drive([], func() -> bool: return not al.resting, 10.0, "until the rope's share is spent or you are full")
	check(c.stamina.value > 4.0 + 2.0, "breath back on the rope (%.1f)" % c.stamina.value)
	check(al.rope_left < bar, "the rope's share runs down")
	eq(c.state, Climber.State.CLIMB, "still on the rock")
	# Climb a move: off the rope. REST sits back again at once.
	await drive(["climb_up"], func() -> bool: return not al.resting, 1.0, "climb on")
	check(not al.resting, "moving climbs on")
	c.stamina.value = 4.0
	al.rope_left = bar
	GameInput.scripted = {"_": false, "rest": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await tree.physics_frame
	check(al.resting, "clipped: REST sits back on the rope")
	await _done()


func test_pull_the_partner_up_at_the_anchor() -> void:
	await _load("lava-tower", "umbwe")
	var al: Alpine = level.alpine
	var p: Dictionary = al.current()
	var partner := al.partner
	check(partner != null, "a partner")
	# Start up the pitch: the partner stays at the foot to belay.
	await _on_pitch_at(1)
	await physics_frames(2)
	eq(partner.state, Companion.State.CAMP, "the partner belays from the foot")
	var low := partner.global_position.y
	# At the top: the anchor ties you in.
	c.respawn(p["anchor"])
	c.stamina.value = c.stamina.max_value
	await physics_frames(3)
	check(al.belaying, "at the anchor, you bring the partner up")
	eq(c.state, Climber.State.LOCKED, "tied in: no walking on")
	eq(level.action_word, "PULL", "the button says PULL")
	var had := c.stamina.value
	for i in Alpine.PULLS - 1:
		await press("interact")
	check(al.belaying, "not up yet after %d pulls" % (Alpine.PULLS - 1))
	check(partner.global_position.y < low - 4.0 * Terrain.TILE, "the partner comes up with each pull")
	await press("interact")
	check(not al.belaying, "up after %d pulls" % Alpine.PULLS)
	eq(al.hauls, 1, "one pitch done")
	eq(al.lead, 1, "the next pitch is the one to lead")
	check(c.state != Climber.State.LOCKED, "free to climb on")
	check(c.stamina.value < had, "pulling costs breath")
	eq(partner.state, Companion.State.FOLLOWING, "the partner follows you on")
	for pt in p["pitons"]:
		check(not pt["node"].visible, "the partner cleaned the pitons")
	await _done()


## Balance: someone who has never heard of REST, who climbs a few moves
## and stops to look, tapping CLIP when a piton lights up, gets up every
## pitch of the hardest climb without coming off, from the first (pitons
## close together) to the last. Hard, but not a wall that throws you off.
func test_a_person_gets_up_every_pitch() -> void:
	await _load("summit-night", "umbwe")
	var al: Alpine = level.alpine
	for i in al.pitches.size():
		var p: Dictionary = al.pitches[i]
		al.lead = i
		for j in i:
			al.pitches[j]["done"] = true
		# At the foot, with what a walk there leaves you (most of the bar).
		c.respawn(Vector2(float(p["x"]) * Terrain.TILE, p["base"].y))
		c.stamina.value = c.stamina.max_value * 0.8
		await physics_frames(2)
		var slips := c.slips
		var falls := c.rope_falls
		var frame := 0
		while not al.belaying and al.lead == i and frame < 60 * 90:
			frame += 1
			if al.clip_target >= 0:
				await press("interact")
				continue
			# Climb for 0.6 s, then stop and look for 0.8 s.
			var held := {"_": false}
			if frame % 84 < 36:
				held["climb_up"] = true
				if c.is_climbing() and c.terrain.hold_at(c.body_rect(c.global_position + Vector2(0, -6))) == Terrain.Kind.AIR:
					held["move_right"] = true
				elif c.state == Climber.State.GROUND and c.global_position.y <= float(p["top"]) * Terrain.TILE + 1.0:
					held = {"_": false, "move_right": true}
			GameInput.scripted = held
			await tree.physics_frame
		GameInput.scripted = {"_": false}
		check(al.belaying, "pitch %d of %d: up to the anchor (%s)" % [i + 1, al.pitches.size(), where()])
		eq(c.slips, slips, "pitch %d: no slip" % (i + 1))
		eq(c.rope_falls, falls, "pitch %d: not even a fall on the rope" % (i + 1))
		while al.belaying:
			await press("interact")
	await _done()
