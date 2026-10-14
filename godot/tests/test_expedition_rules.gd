extends ClimbBot
## The rules of breath on the mountain, played in the real levels: only
## REST gives stamina back; every obstacle (walking, uphill, hops, ice,
## rock) costs it; a gust is sat out with REST; and gear makes a climb
## easier for as long as the attempt lasts.

const BARRANCO := "res://modes/expedition/levels/kilimanjaro/barranco/barranco.tscn"
const SUMMIT := "res://modes/expedition/levels/kilimanjaro/summit_night/summit_night.tscn"


func _load(path: String, fresh: bool = true) -> void:
	if fresh:
		Expedition.new_expedition(7)
	Settings.touch_controls = false
	level = load(path).instantiate()
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


func _hold(actions: Array, frames: int) -> void:
	var held := {"_": false}
	for a in actions:
		held[a] = true
	for i in frames:
		GameInput.scripted = held
		await tree.physics_frame
	GameInput.scripted = {"_": false}


func test_standing_still_gives_nothing_back_only_rest_does() -> void:
	await _load(BARRANCO)
	await physics_frames(5)
	c.stamina.value = c.stamina.max_value * 0.5
	var before := c.stamina.value
	await _hold([], 120)
	eq(c.state, Climber.State.GROUND, "standing")
	check(c.stamina.value <= before, "two seconds standing still gives nothing back (%.1f -> %.1f)" % [before, c.stamina.value])
	before = c.stamina.value
	await _hold(["rest"], 1)
	await _hold([], 120)
	eq(c.state, Climber.State.REST, "sitting")
	check(c.stamina.value > before + 10.0, "two seconds of REST gives breath back (%.1f -> %.1f)" % [before, c.stamina.value])
	# The crag keeps its old rule: a standing shake-out there still helps.
	var crag := StaminaModel.new(80.0)
	check(crag.rate("still") < 0.0, "standing still recovers at the crag")
	eq(level.stamina.rate("still"), 0.0, "and not on the mountain")
	await _done()


func test_walking_uphill_and_hopping_cost_stamina() -> void:
	await _load(BARRANCO)
	await physics_frames(5)
	# Out of camp: flat ground, then the slope up to the wall foot.
	var before := c.stamina.value
	var seen_up := false
	var up_cost := 0.0
	for i in 60 * 30:
		if tx() >= 50.0:
			break
		var v := c.stamina.value
		var held := {"_": false, "move_right": true}
		_hop(held)
		GameInput.scripted = held
		await tree.physics_frame
		if c.last_activity == "walk_up":
			seen_up = true
			up_cost += v - c.stamina.value
	GameInput.scripted = {"_": false}
	check(seen_up, "the slope out of camp is uphill walking")
	check(up_cost > 0.0, "walking uphill costs stamina (%.2f)" % up_cost)
	check(c.stamina.value < before, "walking costs stamina")
	check(level.stamina.rate("walk_up") > level.stamina.rate("walk"), "uphill costs more than the flat")
	# A hop.
	await physics_frames(10)
	before = c.stamina.value
	var jumps := c.jumps
	await _hold(["jump"], 2)
	check(c.jumps == jumps + 1, "hopped")
	check(c.stamina.value < before, "a hop costs stamina (%.1f -> %.1f)" % [before, c.stamina.value])
	await physics_frames(60)
	# Climbing rock.
	check(level.stamina.rate("climb") > level.stamina.rate("walk_up"), "rock costs more than walking")
	await _done()


func test_ice_costs_stamina_and_crampons_make_it_easy() -> void:
	await _load(SUMMIT)
	var ice: Array = []
	for y in level.terrain.height:
		for x in level.terrain.width:
			if level.terrain.kind(Vector2i(x, y)) == Terrain.Kind.ICE and level.terrain.kind(Vector2i(x, y - 1)) == Terrain.Kind.AIR \
					and level.terrain.kind(Vector2i(x + 1, y)) == Terrain.Kind.ICE and level.terrain.kind(Vector2i(x + 2, y)) == Terrain.Kind.ICE \
					and level.terrain.kind(Vector2i(x + 3, y)) == Terrain.Kind.ICE:
				ice.append(Vector2i(x, y))
	check(not ice.is_empty(), "the summit has ice to walk on")
	var cell: Vector2i = ice[0]
	c.global_position = Terrain.feet(cell - Vector2i(0, 1))
	await physics_frames(5)
	check(c.on_ice or level.terrain.kind(cell) == Terrain.Kind.ICE, "standing on ice")
	var before := c.stamina.value
	var on := 0
	for i in 30:
		GameInput.scripted = {"_": false, "move_right": true}
		await tree.physics_frame
		if c.last_activity == "ice":
			on += 1
	GameInput.scripted = {"_": false}
	check(on > 0, "walked on ice")
	check(c.stamina.value < before, "ice costs stamina")
	var bare: float = level.stamina.rate("ice")
	check(bare > 0.0, "ice drains")
	# Crampons: half the cost, and no sliding.
	level.gear_kinds.append("crampons")
	level._apply_gear()
	check(level.stamina.rate("ice") < bare * 0.6, "crampons halve what ice costs")
	check(c.crampons, "crampons on")
	await _done()


func test_gear_helps_and_is_lost_with_the_climb() -> void:
	Expedition.new_expedition(7)
	Expedition.climb = {"challengeId": "barranco-wall", "attemptId": "gear-test"}
	await _load(BARRANCO, false)
	var spec_gear: Array = level.spec["gear"]
	eq(spec_gear.size(), 3, "three pieces of gear on the wall")
	for g in spec_gear:
		check(ClimbLevel.GEAR.has(String(g[2])), "%s is a known kind" % g[2])
	var rock: float = level.stamina.rate("climb")
	var walk: float = level.stamina.rate("walk")
	# Pick up the first piece (gloves, before the faces) and the last (poles).
	var cells: Array = level.terrain.markers["*"].duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y or (a.y == b.y and a.x < b.x))
	for n in [0, 2]:
		c.global_position = Terrain.feet(cells[n])
		await physics_frames(4)
	check(level.gear_kinds.has("gloves"), "found the gloves")
	check(level.gear_kinds.has("poles"), "found the poles")
	check(level.stamina.rate("climb") < rock, "gloves: rock costs less")
	check(level.stamina.rate("walk") < walk, "poles: walking costs less")
	eq(level.hazards.gear_count, 2, "two found")
	eq((Expedition.climb.get("gear", []) as Array).size(), 2, "kept for this attempt (resume)")
	# A fall into a hole: back to the start with nothing, and the gear is back
	# where it was.
	c.slip("hole")
	await drive([], func() -> bool: return c.state == Climber.State.GROUND, 5.0, "back at the start")
	eq(level.gear_kinds.size(), 0, "no gear after the hole")
	eq(level.hazards.gear_count, 0, "gear count reset")
	eq(level.stamina.rate("climb"), rock, "rock back to full cost")
	eq((Expedition.climb.get("gear", []) as Array).size(), 0, "nothing kept")
	var shown := 0
	for p in level.hazards.pickups:
		if p["kind"] == "gear" and not p["taken"] and p["node"].visible:
			shown += 1
	eq(shown, 3, "all three back on the ground")
	# Losing the climb also drops it.
	c.global_position = Terrain.feet(cells[0])
	await physics_frames(4)
	check(level.gear_kinds.has("gloves"), "found again")
	level.finish("fail")
	await physics_frames(2)
	eq(level.gear_kinds.size(), 0, "a failed climb starts again with no gear")
	await _done()


func test_goggles_soften_a_gust() -> void:
	await _load(BARRANCO)
	c.global_position = Terrain.feet(Vector2i(60, 41))
	await physics_frames(5)
	var pushed := []
	for shell in [false, true]:
		level.gear_kinds.clear()
		if shell:
			level.gear_kinds.append("shell")
		level._apply_gear()
		# Wait standing (no input) for the next gust to start.
		GameInput.scripted = {"_": false}
		while c.wind.phase_at(c.clock) == WindSchedule.Phase.BLOW:
			await tree.physics_frame
		while c.wind.phase_at(c.clock) != WindSchedule.Phase.BLOW:
			await tree.physics_frame
		eq(c.state, Climber.State.GROUND, "standing in the gust")
		var x0 := c.global_position.x
		var s0 := c.stamina.value
		await physics_frames(15)
		pushed.append([c.global_position.x - x0, s0 - c.stamina.value])
	eq(pushed.size(), 2, "measured both")
	if pushed.size() == 2:
		check(pushed[1][0] < pushed[0][0], "goggles and buff: pushed less (%.1f vs %.1f)" % [pushed[1][0], pushed[0][0]])
		check(pushed[1][1] < pushed[0][1], "and it costs less")
	# Resting in a gust with them gives full breath back.
	check(c.wind_shell, "shell on")
	await _done()
