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
	# A fresh go: nothing left over from an earlier test's climb.
	Expedition.climb = {}
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
		check(outcome.stars >= 2, "a clean ascent earns at least two stars, got %d" % outcome.stars)
		check(outcome.flowers > 0 and outcome.flowers_total > outcome.flowers - 1, "everlastings were picked on the way (%d of %d)" % [outcome.flowers, outcome.flowers_total])
		check_pacing("Lava Tower")
		print("      Lava Tower took %d s of game time, %d%% stamina left, %d slips, %.0f s resting, lowest %d%% of a %d bar" % [outcome.seconds, outcome.stamina_left, outcome.slips, outcome.rest_seconds, int(level.lowest_stamina * 100), int(c.stamina.max_value)])
	await _results()
	eq(Expedition.state()["checkpoint"], "camp2", "the outcome landed: the party sleeps at Barranco")
	check(Expedition.pending() == null, "the climb is closed")
	await _done()


## The results card: shows the stars, then back to camp.
func _results() -> void:
	await drive([], func() -> bool: return level.panel.open, 5.0, "panel")
	check(level.panel.open and level.panel._title.text != "", "the results card shows")
	level.panel.choose("camp")
	await physics_frames(2)


func _switchback(row: float, right: bool, label: String) -> void:
	var dir := "move_right" if right else "move_left"
	await drive([dir], func() -> bool: return tx() >= 99.0 if right else tx() <= 19.5, 60.0, "walk toward " + label)
	await rest_up(0.98)
	await wait_for_stone_window((103.5 if right else 15.5) * T)
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
	# Out of the stones' line: sit at the cairn, as the brief says.
	await drive(["move_right"], func() -> bool: return tx() >= 19.5, 10.0, "to the rim cairn")
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
		check_pacing("summit night")
		print("      summit night took %d s of game time, %d%% stamina left, %d slips, %d caught, %d wind strikes, %.0f s resting, lowest %d%% of a %d bar" % [outcome.seconds, outcome.stamina_left, outcome.slips, outcome.caught, outcome.wind_strikes, outcome.rest_seconds, int(level.lowest_stamina * 100), int(c.stamina.max_value)])
	await _results()
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
	await _put(Vector2i(90, 58))
	check(c.terrain.kind(Vector2i(90, 59)) == Terrain.Kind.ICE, "on ice")
	# Full walking speed, as the cold allows (Climate.pace).
	await drive(["move_right"], func() -> bool: return absf(c.velocity.x) >= Climber.WALK * c.chill * 0.95, 5.0, "up to speed on ice")
	var from := c.global_position.x
	await drive([], func() -> bool: return absf(c.velocity.x) < 1.0, 5.0, "sliding to a stop")
	var ice_stop := c.global_position.x - from
	await _put(Vector2i(20, 76))
	await drive(["move_right"], func() -> bool: return absf(c.velocity.x) >= Climber.WALK * c.chill * 0.95, 5.0, "up to speed on rock")
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
		await _put(Vector2i(5, 55) if id == "lava-tower" else Vector2i(16, 85))
		# Flat ground, a few seconds of walking, nothing to hop. Only what
		# walking costs counts (an everlasting picked on the way gives a
		# little back).
		var spent := [0.0, c.stamina.value]
		await drive(["move_right"], func() -> bool:
			if c.last_activity == "walk" and c.stamina.value < spent[1]:
				spent[0] += spent[1] - c.stamina.value
			spent[1] = c.stamina.value
			return false, 2.0, "")
		failures.clear()
		lost[id] = [spent[0], c.stamina.thin_air]
		await _done()
	check(lost["lava-tower"][0] > 0.0, "walking costs breath at the tower (%.1f)" % lost["lava-tower"][0])
	check(lost["summit-night"][0] > lost["lava-tower"][0], "and more on the summit night (%.1f vs %.1f)" % [lost["summit-night"][0], lost["lava-tower"][0]])
	check(lost["summit-night"][1] > lost["lava-tower"][1], "the air is thinner up there")


func test_a_hop_clears_a_gap_and_costs_breath() -> void:
	await _load("lava-tower")
	await _put(Vector2i(34, 55))
	var before := c.stamina.value
	await drive(["move_right"], func() -> bool: return tx() >= 39.5, 8.0, "over the stream cut")
	eq(c.slips, 0, "hopped the gap")
	check(c.jumps >= 1, "with a hop")
	check(c.stamina.value < before, "which cost breath")
	await _done()


func test_a_rolling_stone_knocks_down_someone_who_stands_in_its_way() -> void:
	await _load("summit-night")
	await _put(Vector2i(80, 67))
	# Standing still, no hop (the bot's drive would hop it).
	for i in 60 * 15:
		GameInput.scripted = {"_": false}
		await tree.physics_frame
		if c.slips > 0:
			break
	eq(c.slips, 1, "a rolling stone is a slip")
	await _done()


func test_a_teammate_who_runs_out_of_breath_waits_for_you() -> void:
	await _load("summit-night")
	var lvl: ClimbLevel = level
	lvl.mate_state = "helped"
	lvl.mate.helped()
	lvl.mate.global_position = c.global_position
	lvl.mate_breath = 2.0
	await drive(["move_right"], func() -> bool: return lvl.mate_winded, 5.0, "walking until Jun is winded")
	check(lvl.mate_winded, "Jun has to stop")
	# Sitting beside him brings him round.
	await drive(["move_left"], func() -> bool: return absf(lvl.mate.global_position.x - c.global_position.x) < 2.0 * T, 10.0, "back to Jun")
	GameInput.scripted = {"_": false, "rest": true}
	await tree.physics_frame
	await drive([], func() -> bool: return not lvl.mate_winded, 15.0, "sitting with Jun")
	check(not lvl.mate_winded and lvl.mate_state == "helped", "Jun is ready again")
	# Walking off and leaving him sitting there: Lena brings him.
	lvl.mate_breath = 0.5
	# Walking away from him (inputs held directly: the bot would go back).
	for i in 60 * 70:
		var held := {"_": false, "move_right": true}
		_hop(held)
		GameInput.scripted = held
		await tree.physics_frame
		if lvl.mate_state == "left":
			break
	eq(lvl.mate_state, "left", "a teammate left sitting is left")
	await _done()


func test_a_climber_at_the_edge_of_a_face_is_not_caught_under_the_lip() -> void:
	await _load("summit-night")
	# Hanging at the very left edge of the last rock step, under the shelf.
	c.global_position = Vector2(102.1 * T, 46.0 * T)
	c.reset_physics_interpolation()
	c.state = Climber.State.CLIMB
	c.velocity = Vector2.ZERO
	var from := ty()
	for i in 60 * 3:
		GameInput.scripted = {"_": false, "climb_up": true}
		await tree.physics_frame
	check(ty() < from - 1.5 or c.state == Climber.State.GROUND, "pushing up gets past the lip (from %.2f to %.2f)" % [from, ty()])
	await _done()


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


func test_a_fall_drops_every_everlasting_back_on_the_ground() -> void:
	await _load("lava-tower")
	var hz: Hazards = level.hazards
	var cells: Array = level.terrain.markers.get("f", [])
	check(cells.size() >= 2, "everlastings to pick")
	for cell in cells.slice(0, 2):
		await _put(cell)
	eq(hz.flowers, 2, "two picked")
	c.slip("test")
	await physics_frames(2)
	eq(hz.flowers, 0, "a fall drops them all")
	for p in hz.pickups:
		if p["kind"] == "flower":
			check(not p["taken"] and p["node"].visible, "every everlasting is back on the ground")
	var taken: Array = Expedition.climb.get("taken", [])
	for cell in cells:
		check(not taken.has("%d,%d" % [cell.x, cell.y]), "and the save forgets them")
	await _done()


func test_the_wildlife_is_spread_along_the_walk() -> void:
	for id in ["lava-tower", "barranco-wall", "summit-night"]:
		var lvl: ClimbLevel = load(Expedition.LEVELS[id]).instantiate()
		var t := Terrain.load_file(lvl.spec["map"])
		var all: Array = []
		for ch in ["n", "a", "v"]:
			all.append_array(t.markers.get(ch, []))
		check(all.size() >= 4, "%s has wildlife (%d)" % [id, all.size()])
		# Not bunched: nothing within 8 tiles of another on the same stretch.
		for i in all.size():
			for j in range(i + 1, all.size()):
				var a: Vector2i = all[i]
				var b: Vector2i = all[j]
				check(absi(a.y - b.y) > 4 or absi(a.x - b.x) >= 8, "%s: %s and %s are apart" % [id, a, b])
		# Spread from the bottom of the walk to the top, not all in one band.
		var start: int = t.markers["P"][0].y
		var exit: int = t.markers["X"][0].y
		var lo := 0
		var hi := 99999
		for c in all:
			lo = maxi(lo, c.y)
			hi = mini(hi, c.y)
		check(float(lo - hi) >= 0.4 * float(start - exit), "%s: from row %d to %d, of a climb from %d to %d" % [id, lo, hi, start, exit])
		lvl.free()


func test_falling_into_a_hole_starts_the_climb_again() -> void:
	await _load("lava-tower")
	var lvl: ClimbLevel = level
	lvl.checkpoint = 2
	# The stream cut: open to the bottom of the map.
	c.global_position = Terrain.feet(Vector2i(37, 57))
	c.reset_physics_interpolation()
	c.state = Climber.State.AIR
	c.fall_from = c.global_position.y
	for i in 60 * 4:
		GameInput.scripted = {"_": false}
		await tree.physics_frame
		if c.slips > 0 and c.state != Climber.State.SLIP:
			break
	eq(c.slips, 1, "a fall into a hole counts")
	eq(lvl.checkpoint, 0, "and the climb starts again")
	check(c.global_position.distance_to(lvl.cairns[0]) < 4.0, "back at the start (%s)" % c.global_position)
	check("hole" in level.hud.flash_text(), "and it says so: " + level.hud.flash_text())
	var why := lvl.slip_summary()
	check("1 from holes" in why and "Try next:" in why, "the results will say what to try: " + why)
	await _done()


## Running out of stamina on a face is never a surprise: grabbing a face
## you cannot afford says so, the arms hang on for a moment with a warning,
## there is time to climb down, and if they do give out the slip says why.
func test_empty_arms_warn_before_they_let_go() -> void:
	await _load("summit-night")
	var lvl: ClimbLevel = level
	# The last rock step, from its foot, with almost nothing left.
	await _put(Vector2i(103, 50))
	c.stamina.value = 8.0
	GameInput.scripted = {"_": false, "climb_up": true}
	await physics_frames(3)
	check(c.state == Climber.State.CLIMB, "on the rock")
	check(lvl.face_cost() > 8.0, "the face costs more than that (%.0f)" % lvl.face_cost())
	check("Climb down and rest first" in level.hud.flash_text(), "and grabbing it says so: " + level.hud.flash_text())
	for i in 60 * 3:
		GameInput.scripted = {"_": false, "climb_up": true}
		await tree.physics_frame
		if c.arms_failing:
			break
	await physics_frames(1)
	check(c.arms_failing and c.slips == 0, "empty arms hang on first (slips %d)" % c.slips)
	check("giving out" in level.hud.flash_text(), "with a warning: " + level.hud.flash_text())
	# Climbing down in time: no fall.
	for i in 60 * 3:
		GameInput.scripted = {"_": false, "climb_down": true}
		await tree.physics_frame
		if c.state == Climber.State.GROUND:
			break
	eq(c.slips, 0, "climbed down in time, no slip")
	await _done()
	# Hanging there instead: the arms give out, and the slip says why.
	await _load("summit-night")
	await _put(Vector2i(103, 50))
	GameInput.scripted = {"_": false, "climb_up": true}
	await physics_frames(40)
	c.stamina.value = 0.0
	for i in 60 * 5:
		GameInput.scripted = {"_": false}
		await tree.physics_frame
		if c.slips > 0:
			break
	eq(c.slips, 1, "the arms gave out")
	check("arms gave out" in level.hud.flash_text(), "and it says so: " + level.hud.flash_text())
	await _done()


## Each climb has its own day: hot to cold up the tower, colder before
## dawn on the summit, warmer on the way down. The cold slows you and
## rest, the heat costs; the brief and the HUD say so, and the light
## changes with it.
func test_the_weather_changes_along_the_climb() -> void:
	await _load("lava-tower")
	var lvl: ClimbLevel = level
	check("Weather" in level.panel.all_text() and "°C" in level.panel.all_text(), "the brief names the weather: " + level.panel.all_text().right(200))
	check(lvl.degrees >= Climate.WARM, "hot sun at the foot of the tower (%d°C)" % lvl.degrees)
	check(c.stamina.drain > lvl.spec["difficulty"]["drain"], "and the heat costs")
	check("hot" in level.hud._temp.text, "the HUD says so: " + level.hud._temp.text)
	var low_tint: Color = lvl._tint.color
	# Up on the tower: the last cairn.
	lvl.checkpoint = lvl.cairns.size() - 1
	await _put(Terrain.cell_of(lvl.cairns[-1] - Vector2(0, 2)))
	check(lvl.degrees < 8.0, "cold by the top (%d°C)" % lvl.degrees)
	check(lvl._tint.color != low_tint, "and the light has changed (%s to %s)" % [low_tint, lvl._tint.color])
	await _done()
	await _load("summit-night")
	lvl = level
	check(lvl.degrees < 0.0, "below freezing on the summit night (%d°C)" % lvl.degrees)
	check(c.chill < 1.0 and c.stamina.recovery < lvl.spec["difficulty"]["recovery"], "slower, and rest works less (pace %.2f)" % c.chill)
	check("freezing" in level.hud._temp.text, "the HUD says so: " + level.hud._temp.text)
	# The same walk, slower in the cold.
	await _put(Vector2i(60, 85))
	var x0 := c.global_position.x
	await drive(["move_right"], func() -> bool: return false, 1.0, "")
	failures.clear()
	check(c.global_position.x - x0 < Climber.WALK * 0.97, "walking is slower in the cold (%.0f px/s)" % (c.global_position.x - x0))
	# A slow climb gets colder.
	var now := lvl.climate.degrees(0.2, 0.0)
	check(lvl.climate.degrees(0.2, 240.0) < now, "the night gets colder as time passes")
	await _done()
	check(Climate.pace(-15.0) >= Climate.SLOWEST and Climate.pace(-15.0) < 1.0, "the cold slows, within reason")


func test_a_rest_stone_shelters_you_from_the_cold() -> void:
	await _load("summit-night")
	var lvl: ClimbLevel = level
	var cell := Vector2i(-1, -1)
	for y in lvl.terrain.height:
		for x in lvl.terrain.width:
			if cell.x < 0 and lvl.terrain.kind(Vector2i(x, y)) == Terrain.Kind.REST:
				cell = Vector2i(x, y)
	check(cell.x >= 0, "the summit night has a rest stone")
	await _put(cell)
	c.stamina.value = 10.0
	GameInput.scripted = {"_": false, "rest": true}
	await physics_frames(2)
	GameInput.scripted = {"_": false}
	await physics_frames(20)
	eq(c.last_activity, "rest_stone", "sitting on the rest stone")
	check(lvl.degrees < Climate.COOL, "in the cold (%d°C)" % lvl.degrees)
	near(c.stamina.recovery, lvl._base_recovery, 0.001, "sheltered: the cold does not slow the rest")
	check("sheltered" in level.hud._temp.text, "the HUD says so: " + level.hud._temp.text)
	await _done()


## A pause in the middle of a fall or a slip holds the moment: nothing
## moves under the menu, and the fall or the walk back to the cairn
## carries on after it (no cancelled falls, no skipped respawns).
func test_a_pause_never_cancels_a_fall_or_a_slip() -> void:
	await _load("lava-tower")
	var lvl: ClimbLevel = level
	# High above the start, falling.
	c.global_position = lvl.cairns[0] - Vector2(0, 12 * T)
	c.reset_physics_interpolation()
	c.state = Climber.State.AIR
	c.fall_from = c.global_position.y
	await physics_frames(5)
	c.lock(true)
	var y := c.global_position.y
	await physics_frames(60)
	near(c.global_position.y, y, 0.5, "frozen under the pause")
	c.lock(false)
	eq(c.state, Climber.State.AIR, "still falling after it")
	for i in 60 * 3:
		await tree.physics_frame
		if c.slips > 0:
			break
	eq(c.slips, 1, "and the long fall still counts")
	# Paused during the slip itself: the respawn still happens after.
	c.lock(true)
	await physics_frames(90)
	eq(c.state, Climber.State.LOCKED, "held under the menu")
	c.lock(false)
	for i in 120:
		await tree.physics_frame
		if c.state == Climber.State.GROUND:
			break
	check(c.global_position.distance_to(lvl.cairns[lvl.checkpoint]) < 4.0, "back at the cairn after the pause (%s)" % c.global_position)
	await _done()


## Quitting after a slip before the first cairn (or after a hole sent you
## back to the start) resumes that go: the slips and the clock are kept,
## not wiped by a fresh start.
func test_a_go_with_no_cairn_yet_still_resumes() -> void:
	await _load("lava-tower")
	c.slips = 1
	c.clock = 40.0
	level._remember()
	GameInput.scripted = {}
	level.queue_free()
	await physics_frames(2)
	level = load(Expedition.LEVELS["lava-tower"]).instantiate()
	root.add_child(level)
	await physics_frames(2)
	c = level.climber
	check(not level.panel.open, "no brief: the go carries on")
	eq(c.slips, 1, "the slip is kept")
	check(c.clock >= 40.0, "and the clock")
	check("start of the climb" in level.hud.flash_text(), "it says where you are: " + level.hud.flash_text())
	await _done()


## The summit night is the boss: for a party at its most worn (the
## smallest bar a climb allows) it takes nearly everything, but it can
## always be done by resting to full before each face.
func test_the_summit_is_the_boss_but_never_impossible() -> void:
	await _load("summit-night")
	level.queue_free()
	await physics_frames(2)
	# Rebuild with a worn party.
	Expedition.state()["energy"] = 0
	Expedition.state()["health"] = 40
	level = load(Expedition.LEVELS["summit-night"]).instantiate()
	root.add_child(level)
	level.finished.connect(func(o: ChallengeOutcome) -> void: outcome = o)
	await physics_frames(2)
	level.panel.choose("start")
	await physics_frames(1)
	c = level.climber
	eq(c.stamina.max_value, ClimbLevel.MIN_BAR, "a worn party gets the smallest bar")
	await _switchback(77, true, "step 1")
	await _switchback(68, false, "step 2")
	await _switchback(59, true, "step 3")
	await drive(["move_left"], func() -> bool: return level.panel.open, 60.0, "across the crevasse to Jun")
	await rest_up_locked()
	level.panel.choose("help")
	await drive([], func() -> bool: return level.panel.open, 5.0, "panel")
	level.panel.choose("continue")
	await physics_frames(2)
	await _switchback(50, false, "step 4")
	await _switchback(41, true, "step 5, under stonefall")
	await _switchback(32, false, "the rim step, under stonefall")
	await drive(["move_right"], func() -> bool: return tx() >= 19.5, 10.0, "to the rim cairn")
	await rest_up(0.99)
	await cross(108.5)
	await rest_up(0.98)
	await up_to(24, "Stella step")
	await drive(["move_right"], func() -> bool: return outcome != null, 30.0, "to Stella Point")
	check(outcome != null and outcome.result == "complete", "the summit, even worn out")
	check(level.lowest_stamina < 0.25, "and it is the hardest: down to %d%% of the bar" % int(level.lowest_stamina * 100))
	print("      worn-out summit: %d s, %d slips, lowest %d%% of a %d bar" % [int(c.clock), c.slips, int(level.lowest_stamina * 100), int(c.stamina.max_value)])
	await _done()
