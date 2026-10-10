extends TestCase
## The Lava Tower and the summit night, played by a scripted climber through
## the real levels and the same input actions a player presses. Also holds
## the three climbs to their order of difficulty, and checks each outcome
## lands on the expedition through the Coordinator.

const T := 16.0

var level: ClimbLevel
var c: Climber
var outcome: ChallengeOutcome


func _load(challenge: String) -> void:
	SaveGame.erase()
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


func tx() -> float:
	return c.global_position.x / T


func ty() -> float:
	return c.global_position.y / T


func where() -> String:
	return "(%.2f, %.2f) state=%d stamina=%.0f/%.0f slips=%d cp=%d clock=%.1f" % [tx(), ty(), c.state, c.stamina.value, c.stamina.max_value, c.slips, level.checkpoint, c.clock]


func drive(keys: Array, done: Callable, seconds: float = 40.0, label: String = "") -> bool:
	for i in int(seconds * 60.0):
		if done.call():
			GameInput.scripted = {"_": false}
			return true
		var held := {"_": false}
		for k in keys:
			held[k] = true
		GameInput.scripted = held
		await tree.physics_frame
		if level.panel.open and label != "panel":
			break
	GameInput.scripted = {"_": false}
	var ok: bool = done.call()
	if not ok:
		failures.append("gave up %s at %s" % [label, where()])
	return ok


func rest_up(fraction: float = 0.95) -> void:
	GameInput.scripted = {"_": false, "rest": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await drive([], func() -> bool: return c.stamina.fraction() >= fraction, 90.0, "resting")


## Walk toward `until_x` (either way), bracing whenever a gust is near.
func cross(until_x: float) -> bool:
	var dir := "move_right" if until_x > tx() else "move_left"
	var arrived := func() -> bool: return tx() >= until_x if dir == "move_right" else tx() <= until_x
	for i in 60 * 150:
		if arrived.call() or level.panel.open:
			break
		var held := {"_": false}
		var ahead := c.terrain.kinds_in(c.body_rect(c.global_position + Vector2(T if dir == "move_right" else -T, 0)))
		if (c.exposed or ahead.has(Terrain.Kind.EXPOSED)) and not c.wind.calm_for(c.clock, 0.8):
			held["brace"] = true
		else:
			held[dir] = true
		GameInput.scripted = held
		await tree.physics_frame
	GameInput.scripted = {"_": false}
	if level.panel.open:
		print("      cross stopped by a panel: ", level.panel._title.text, " at ", where())
	var ok: bool = arrived.call() or level.panel.open
	if not ok:
		failures.append("gave up crossing to %.1f at %s" % [until_x, where()])
	return ok


func up_to(floor_row: float, label: String) -> void:
	await drive(["climb_up"], func() -> bool: return c.state == Climber.State.GROUND and ty() <= floor_row + 0.05, 40.0, label)


func test_the_lava_tower_climbed() -> void:
	await _load("lava-tower")
	check(level.mate == null, "nobody to carry on the tower")
	await drive(["move_right"], func() -> bool: return tx() >= 53.0, 40.0, "to the tower foot")
	check(level.checkpoint >= 1, "cairn 1 at the tower foot")
	await up_to(42, "the scramble band")
	await drive(["move_right"], func() -> bool: return tx() >= 74.0, 20.0, "bench 1")
	check(level.checkpoint >= 2, "cairn 2 on bench 1")
	await rest_up()
	await up_to(30, "the scree face")
	await drive(["move_left"], func() -> bool: return tx() <= 68.6, 10.0, "to the rest stone")
	check(level.checkpoint >= 3, "cairn 3 on bench 2")
	await rest_up(0.99)
	await cross(56.5)
	await drive(["climb_up"], func() -> bool: return c.is_climbing(), 5.0, "grab the chimney")
	await up_to(14, "the chimney")
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
	await drive(["move_right" if right else "move_left"], func() -> bool: return tx() >= 103.0 if right else tx() <= 15.5, 60.0, "walk to " + label)
	await rest_up(0.98)
	await drive(["climb_up"], func() -> bool: return c.is_climbing(), 5.0, "grab " + label)
	await up_to(row, label)


func test_the_summit_night_climbed_helping_jun() -> void:
	await _load("summit-night")
	check(level.mate != null and level.mate.person == "jun", "Jun is on the mountain")
	check(level.spec["theme"]["night"], "by headlamp")
	await _switchback(77, true, "step 1")
	await _switchback(68, false, "step 2")
	await _switchback(59, true, "step 3")
	# Jun, on the fourth switchback.
	await drive(["move_left"], func() -> bool: return level.panel.open, 60.0, "to Jun")
	check(level.panel.open, "meeting Jun opens a choice")
	await rest_up_locked()
	level.panel.choose("help")
	await drive([], func() -> bool: return level.panel.open, 5.0, "panel")
	eq(level.mate_state, "helped", "Jun helped")
	level.panel.choose("continue")
	await physics_frames(2)
	await _switchback(50, false, "step 4")
	await _switchback(41, true, "step 5")
	await _switchback(32, false, "the rim step")
	await rest_up(0.99)
	await cross(108.5)
	await drive(["climb_up"], func() -> bool: return c.is_climbing(), 5.0, "grab the last step")
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
		lvl.free()
