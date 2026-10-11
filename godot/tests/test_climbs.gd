extends ClimbBot
## The Lava Tower and the summit night, played by a scripted climber through
## the real levels, hazards and all. Also the hazards one by one, walking in
## thin air, the three climbs' order of difficulty, and each outcome landing
## on the expedition through the Coordinator.


func _load(challenge: String) -> void:
	SaveGame.erase()
	Expedition.found = {}
	Settings.touch_controls = false
	Expedition.session = TestSessions.at(challenge)
	check(Expedition.pending() != null, "the careful party reached %s" % challenge)
	Expedition.resume_climb()
	outcome = null
	level = load(Expedition.LEVELS[challenge]).instantiate()
	root.add_child(level)
	level.finished.connect(func(o: ChallengeOutcome) -> void: outcome = o)
	await physics_frames(2)
	check(level.panel.open, "the brief is shown first")
	level.panel.choose("start")
	await physics_frames(1)
	c = level.climber


func _done() -> void:
	GameInput.scripted = {}
	level.queue_free()
	await physics_frames(2)
	SaveGame.erase()


func test_the_lava_tower_climbed() -> void:
	await _load("lava-tower")
	check(level.mate == null, "nobody to carry on the tower")
	await drive(["move_right"], func() -> bool: return tx() >= 53.0, 40.0, "to the tower foot")
	check(level.checkpoint >= 1, "cairn 1 at the tower foot")
	await up_to(42, "the scramble band")
	await rest_up()
	# The scree bridge: keep walking and it holds.
	await cross(74.0)
	check(level.checkpoint >= 2, "cairn 2 on bench 1")
	eq(c.slips, 0, "walked the bridge without stopping")
	await rest_up()
	await up_to(30, "the scree face")
	await drive(["move_left"], func() -> bool: return tx() <= 68.6, 10.0, "to the rest stone")
	check(level.checkpoint >= 3, "cairn 3 on bench 2")
	await rest_up(0.99)
	await cross(56.5)
	await up_to(14, "the chimney, dodging stones")
	await drive(["move_right"], func() -> bool: return outcome != null, 60.0, "over the top and down")
	check(level.checkpoint >= 4, "cairn 4 on the top, got %d" % level.checkpoint)
	check(outcome != null, "the climb ended")
	if outcome:
		eq(outcome.result, "complete", "result")
		eq(outcome.challenge_id, "lava-tower", "which climb")
		eq(outcome.assisted, null, "no teammate on the tower")
		print("      Lava Tower took %d s of game time, %d%% stamina left, %d slips" % [outcome.seconds, outcome.stamina_left, outcome.slips])
	await physics_frames(130)
	eq(Expedition.state()["checkpoint"], "camp2", "the outcome landed: the party sleeps at Barranco")
	check(Expedition.pending() == null, "the climb is closed")
	await _done()


func _switchback(row: float, right: bool, label: String) -> void:
	var dir := "move_right" if right else "move_left"
	await drive([dir], func() -> bool: return tx() >= 99.0 if right else tx() <= 19.5, 60.0, "walk toward " + label)
	await rest_up(0.98)
	await drive([dir], func() -> bool: return c.is_climbing() or (tx() >= 103.0 if right else tx() <= 15.5), 20.0, "walk to " + label)
	await up_to(row, label)


func test_the_summit_night_climbed_helping_jun() -> void:
	await _load("summit-night")
	check(level.mate != null and level.mate.person == "jun", "Jun is on the mountain")
	check(level.spec["theme"]["night"], "by headlamp")
	await _switchback(77, true, "step 1")
	await _switchback(68, false, "step 2")
	await _switchback(59, true, "step 3")
	# Ice to the crevasse, the band of rock across it, then Jun.
	await drive(["move_left"], func() -> bool: return level.panel.open, 60.0, "across the crevasse to Jun")
	check(level.panel.open, "meeting Jun opens a choice")
	eq(c.slips, 0, "the crevasse crossed")
	await rest_up_locked()
	level.panel.choose("help")
	await drive([], func() -> bool: return level.panel.open, 5.0, "panel")
	eq(level.mate_state, "helped", "Jun helped")
	level.panel.choose("continue")
	await physics_frames(2)
	await _switchback(50, false, "step 4")
	await _switchback(41, true, "step 5, under stonefall")
	await _switchback(32, false, "the rim step, under stonefall")
	await rest_up(0.99)
	await cross(108.5)
	# The long rim in thin air takes it out of you: sit before the last step.
	await rest_up(0.98)
	await up_to(24, "Stella step")
	await drive(["move_right"], func() -> bool: return outcome != null, 30.0, "to Stella Point")
	check(outcome != null, "the climb ended")
	if outcome:
		eq(outcome.result, "complete", "result")
		eq(outcome.assisted, true, "assisted")
		print("      summit night took %d s of game time, %d%% stamina left, %d slips, %d caught, %d wind strikes" % [outcome.seconds, outcome.stamina_left, outcome.slips, outcome.caught, outcome.wind_strikes])
	await physics_frames(130)
	check(Expedition.state()["summitReached"], "the summit is recorded on the expedition")
	await _done()


## Jun's panel locks the climber; sit there until the arms are back so the
## help (which costs stamina) is affordable.
func rest_up_locked() -> void:
	if c.stamina.value >= c.helper_cost + 5:
		return
	level.panel.choose("back")
	await rest_up(0.9)
	await drive(["move_left"], func() -> bool: return level.panel.open, 10.0, "back to Jun")


# --- The hazards, one at a time -------------------------------------------------

func _put(cell: Vector2i) -> void:
	c.global_position = Terrain.feet(cell)
	c.reset_physics_interpolation()
	c.velocity = Vector2.ZERO
	c.state = Climber.State.GROUND
	c.fall_from = c.global_position.y
	await physics_frames(3)


func test_a_cracked_slab_holds_a_walker_and_drops_someone_who_stops() -> void:
	await _load("lava-tower")
	await _put(Vector2i(62, 41))
	await drive(["move_right"], func() -> bool: return tx() >= 69.0, 10.0, "over the bridge")
	eq(c.slips, 0, "walking across holds")
	await _put(Vector2i(65, 41))
	await drive([], func() -> bool: return c.state == Climber.State.SLIP, 4.0, "standing on the bridge")
	eq(c.slips, 1, "standing still on the slabs is a fall")
	await drive([], func() -> bool: return c.state == Climber.State.GROUND, 4.0, "back at the cairn")
	await physics_frames(int(7.0 * 60))
	check(c.terrain.is_solid(Vector2i(65, 42)), "the slabs settle back")
	await _done()


func test_stones_are_announced_and_miss_the_next_column() -> void:
	await _load("lava-tower")
	var hz: Hazards = level.hazards
	await _put(Vector2i(56, 29))
	# Stand at the chimney foot until a stone is announced over this column.
	var warned := false
	for i in 60 * 30:
		if hz.threat_at(c.global_position.x, Hazards.WARN):
			warned = true
			break
		await tree.physics_frame
	check(warned, "a stone is announced over the column first")
	await drive([], func() -> bool: return c.slips > 0, Hazards.WARN + 3.0, "standing under it")
	eq(c.slips, 1, "standing under a stone is a slip")
	await _done()


func test_ice_slides() -> void:
	await _load("summit-night")
	await _put(Vector2i(40, 76))
	check(c.terrain.kind(Vector2i(40, 77)) == Terrain.Kind.ICE, "on ice")
	await drive(["move_right"], func() -> bool: return absf(c.velocity.x) >= Climber.WALK * 0.95, 5.0, "up to speed on ice")
	var from := c.global_position.x
	await drive([], func() -> bool: return absf(c.velocity.x) < 1.0, 5.0, "sliding to a stop")
	var ice_stop := c.global_position.x - from
	await _put(Vector2i(20, 76))
	await drive(["move_right"], func() -> bool: return absf(c.velocity.x) >= Climber.WALK * 0.95, 5.0, "up to speed on rock")
	from = c.global_position.x
	await drive([], func() -> bool: return absf(c.velocity.x) < 1.0, 5.0, "stopping on rock")
	var rock_stop := c.global_position.x - from
	check(ice_stop > rock_stop * 4.0, "ice slides much further (%.1f px vs %.1f px)" % [ice_stop, rock_stop])
	await _done()


func test_water_and_lost_gear() -> void:
	await _load("lava-tower")
	var hz: Hazards = level.hazards
	c.stamina.value = 10.0
	await _put(Vector2i(70, 41))
	check(c.stamina.value > 40.0, "a water cache gives most of the bar back")
	eq(Expedition.climb.get("taken", []), ["70,41"], "taken for this attempt")
	eq(hz.gear_count, 0, "nothing found yet")
	await _put(Vector2i(59, 22))
	eq(hz.gear_count, 1, "found the gear in the chimney niche")
	eq(Expedition.gear_found("lava-tower"), [1], "kept on the expedition")
	check(Expedition.load_saved(), "saved")
	eq(Expedition.gear_found("lava-tower"), [1], "and in the save")
	await _done()


func test_walking_costs_more_breath_on_the_summit_than_at_the_tower() -> void:
	var lost := {}
	for id in ["lava-tower", "summit-night"]:
		await _load(id)
		var start := c.stamina.value
		await drive(["move_right"], func() -> bool: return false, 3.0, "")
		failures.clear()
		lost[id] = start - c.stamina.value
		await _done()
	check(lost["lava-tower"] > 0.0, "walking costs breath at the tower (%.1f)" % lost["lava-tower"])
	check(lost["summit-night"] > lost["lava-tower"], "and more on the summit night (%.1f)" % lost["summit-night"])


func test_the_climbs_get_harder_up_the_mountain() -> void:
	var order := ["lava-tower", "barranco-wall", "summit-night"]
	var specs: Array = []
	for id in order:
		var lvl: ClimbLevel = load(Expedition.LEVELS[id]).instantiate()
		specs.append(lvl.spec["difficulty"])
		lvl.free()
	for i in 2:
		var a: Dictionary = specs[i]
		var b: Dictionary = specs[i + 1]
		check(b["recovery"] <= a["recovery"], "%s recovers no faster than %s" % [order[i + 1], order[i]])
		check(b["drain"] >= a["drain"], "%s drains no slower" % order[i + 1])
		check(b["wind"] > a["wind"], "%s is windier" % order[i + 1])
		check(b["maxSlips"] <= a["maxSlips"], "%s forgives no more slips" % order[i + 1])
		check(b["helpCost"] >= a["helpCost"], "helping costs no less on %s" % order[i + 1])
	check(specs[2]["maxSlips"] < specs[0]["maxSlips"], "the summit forgives fewer slips than the tower")


func test_each_level_has_what_its_climb_needs() -> void:
	for id in Expedition.LEVELS:
		var lvl: ClimbLevel = load(Expedition.LEVELS[id]).instantiate()
		var t := Terrain.load_file(lvl.spec["map"])
		check(t.markers.has("P") and t.markers["P"].size() == 1, "%s has one start" % id)
		check(t.markers.has("X"), "%s has an exit" % id)
		check(t.markers.get("K", []).size() >= 4, "%s has cairns" % id)
		eq(t.markers.has("M"), not lvl.spec["mate"].is_empty(), "%s has its teammate marker iff it has a teammate" % id)
		eq(t.markers.get("S", []).size(), lvl.spec["signs"].size(), "%s has words for every sign" % id)
		eq(t.markers.get("*", []).size(), lvl.spec["gear"].size(), "%s has words for every piece of lost gear" % id)
		check(t.markers.get("r", []).size() >= 1, "%s has stonefall" % id)
		for ch in ["*", "w"]:
			for cell in t.markers.get(ch, []):
				check(not t.is_solid(cell) and t.is_solid(cell + Vector2i.DOWN), "%s: %s at %s stands on ground" % [id, ch, cell])
		lvl.free()
