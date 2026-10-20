extends ClimbBot
## The hazards one by one on the real levels (found on whichever layout is
## loaded: the long way's unless a test names a route), walking in thin air,
## the three climbs' order of difficulty, what every layout needs, the
## artifacts, and the summit as the boss. The whole climbs, on every route,
## are test_routes.gd.


func _load(challenge: String, route: String = "") -> void:
	SaveGame.erase()
	Expedition.found = {}
	Settings.touch_controls = false
	Expedition.session = TestSessions.at(challenge)
	check(Expedition.pending() != null, "the careful party reached %s" % challenge)
	if route != "":
		Trek.ensure(Expedition.session)["route"] = route
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


# --- The hazards, one at a time -------------------------------------------------

func _put(cell: Vector2i) -> void:
	c.global_position = Terrain.feet(cell)
	c.reset_physics_interpolation()
	c.velocity = Vector2.ZERO
	c.state = Climber.State.GROUND
	c.fall_from = c.global_position.y
	await physics_frames(3)


func test_a_cracked_slab_holds_a_walker_and_drops_someone_who_stops() -> void:
	await _load("lava-tower", "machame")
	var s := slab()
	check(s.x >= 0, "the tower has a bridge of cracked slabs")
	await _put(s + Vector2i(-2, -1))
	await drive(["move_right"], func() -> bool: return tx() >= s.x + 3.5, 10.0, "over the bridge")
	eq(c.slips, 0, "walking across holds")
	await _put(s + Vector2i(1, -1))
	await drive([], func() -> bool: return c.state == Climber.State.SLIP, 4.0, "standing on the bridge")
	eq(c.slips, 1, "standing still on the slabs is a fall")
	await drive([], func() -> bool: return c.state == Climber.State.GROUND, 4.0, "back at the cairn")
	await physics_frames(int(7.0 * 60))
	check(c.terrain.is_solid(s + Vector2i(1, 0)), "the slabs settle back")
	await _done()


func test_stones_are_announced_and_miss_the_next_column() -> void:
	await _load("lava-tower")
	var hz: Hazards = level.hazards
	var foot := chute_foot()
	check(foot.x >= 0, "the tower has stonefall down a face")
	await _put(foot)
	# Stand at the face's foot until a stone is announced over this column.
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
	await _load("summit-night", "machame")
	var on_ice := clear_walk(Terrain.Kind.ICE, 7)
	await _put(on_ice)
	check(c.terrain.kind(on_ice + Vector2i.DOWN) == Terrain.Kind.ICE, "on ice")
	# Full walking speed, as the cold allows (Climate.pace).
	await drive(["move_right"], func() -> bool: return absf(c.velocity.x) >= Climber.WALK * c.chill * 0.95, 5.0, "up to speed on ice")
	var from := c.global_position.x
	await drive([], func() -> bool: return absf(c.velocity.x) < 1.0, 5.0, "sliding to a stop")
	var ice_stop := c.global_position.x - from
	await _put(clear_walk(Terrain.Kind.ROCK, 10))
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
	var water: Vector2i = level.terrain.markers["w"][0]
	await _put(water)
	eq(c.stamina.value, 10.0, "a drink goes in the pack: nothing until you drink it")
	eq(level.drinks, 1, "one drink carried")
	var slots: Array = level.pack_slots()
	eq(String(slots[slots.size() - 1]["id"]), "drink", "in the pack")
	check(level.use_slot(slots.size() - 1), "drink it")
	check(c.stamina.value > 40.0, "a drink gives most of the bar back")
	eq(level.drinks, 0, "and it is gone")
	eq(Expedition.climb.get("taken", []), ["%d,%d" % [water.x, water.y]], "taken for this attempt")
	eq(hz.gear_count, 0, "nothing found yet")
	# The gloves, where this route's layout put them.
	var kinds: Array = level.spec["gear"].map(func(g: Array) -> String: return String(g[2]))
	var at: Array = level.layout["gear"][kinds.find("gloves")]
	await _put(Vector2i(int(at[0]), int(at[1])))
	eq(hz.gear_count, 1, "found the gear")
	# Its index: the markers' order, bottom to top.
	var n := -1
	for i in hz.gear_words.size():
		if hz.gear_words[i].size() > 3 and Vector2i(int(hz.gear_words[i][3][0]), int(hz.gear_words[i][3][1])) == Vector2i(int(at[0]), int(at[1])):
			n = i
	eq(String(hz.gear_words[n][2]), "gloves", "the gloves, where the layout says")
	eq(Expedition.gear_found("lava-tower"), [n], "kept on the expedition")
	check(Expedition.load_saved(), "saved")
	eq(Expedition.gear_found("lava-tower"), [n], "and in the save")
	await _done()


func test_walking_costs_more_breath_on_the_summit_than_at_the_tower() -> void:
	var lost := {}
	for id in ["lava-tower", "summit-night"]:
		await _load(id)
		await _put(clear_walk(Terrain.Kind.ROCK, 10))
		# Flat ground, a few seconds of walking, nothing to hop. Only what
		# walking costs counts.
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
	await _load("lava-tower", "machame")
	var g := gap_before()
	check(g.x >= 0, "a gap to hop")
	await _put(g + Vector2i(-2, 0))
	var before := c.stamina.value
	await drive(["move_right"], func() -> bool: return tx() >= g.x + 4.5, 8.0, "over the gap")
	eq(c.slips, 0, "hopped the gap")
	check(c.jumps >= 1, "with a hop")
	check(c.stamina.value < before, "which cost breath")
	await _done()


func test_a_rolling_stone_knocks_down_someone_who_stands_in_its_way() -> void:
	await _load("lava-tower", "machame")
	var b: Vector2i = level.terrain.markers["b"][0]
	var stand := b + Vector2i(-6, 0)
	while not standable(stand) and stand.x > b.x - 12:
		stand.x -= 1
	await _put(stand)
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
	# Hanging at the very left edge of the first rock step (at the right end of
	# its bench), under the shelf of the bench above.
	var first: Dictionary = level.layout["script"].filter(func(a: Array) -> bool: return a[0] == "climb")[0][1]
	var fc := int(floor(float(first["x"]))) - 1
	c.global_position = Vector2((fc + 0.1) * T, (int(first["row"]) + 3.0) * T)
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


func _scene(climb: String) -> String:
	return Expedition.DESCENT if climb == "descent" else Expedition.LEVELS[climb]


## Every climb on every route: a start, an exit, cairns and signs in the
## order the line reaches them, the teammate (and which way you pass them),
## gear and water on ground, stonefall, two artifacts, and a line to follow.
func test_each_level_has_what_its_climb_needs() -> void:
	for climb in Artifacts.CLIMBS:
		for route in Trek.ROUTES:
			# The place this route climbs here (its spec entry).
			var lvl: ClimbLevel = load(_scene(climb)).instantiate()
			lvl.apply_route(route)
			var id := "%s (%s)" % [climb, route]
			var t := Terrain.load_file(lvl.map_path(route))
			var lay := lvl.layout_for(route)
			eq(String(lay.get("route", "")), route, "%s has its layout" % id)
			check(t.markers.has("P") and t.markers["P"].size() == 1, "%s has one start" % id)
			check(t.markers.has("X"), "%s has an exit" % id)
			check(t.markers.get("K", []).size() >= 4, "%s has cairns" % id)
			eq(lay["cairns"].size(), t.markers.get("K", []).size(), "%s: the layout orders every cairn" % id)
			eq(t.markers.has("M"), not lvl.spec["mate"].is_empty(), "%s has its teammate marker iff it has a teammate" % id)
			if t.markers.has("M"):
				var m: Dictionary = lay["mate"]
				eq(Vector2i(int(m["cell"][0]), int(m["cell"][1])), t.markers["M"][0], "%s: the layout knows where the teammate is" % id)
			eq(t.markers.get("S", []).size(), lvl.spec["signs"].size(), "%s has words for every sign" % id)
			eq(lay["signs"].size(), lvl.spec["signs"].size(), "%s: the layout orders every sign" % id)
			eq(t.markers.get("*", []).size(), lvl.spec["gear"].size(), "%s has words for every piece of lost gear" % id)
			eq(lay["gear"].size(), lvl.spec["gear"].size(), "%s: the layout places every piece of gear" % id)
			check(t.markers.get("r", []).size() >= 1, "%s has stonefall" % id)
			for ch in ["*", "w"]:
				for cell in t.markers.get(ch, []):
					check(not t.is_solid(cell) and t.is_solid(cell + Vector2i.DOWN), "%s: %s at %s stands on ground" % [id, ch, cell])
			check(lay["script"].size() >= 3 and lay["script"][-1][0] == "finish", "%s has a line to the exit" % id)
			lvl.free()


## The harder the route, the more in the way: more stonefall, wildlife,
## ice, slabs and wind, and at least as many walls; but every wall (and
## every side wall up to a find) fits in that route's smallest bar, so the
## quarter bar of the fastest way is never a wall you cannot climb.
func test_the_faster_ways_are_harder_climbs() -> void:
	for climb in Artifacts.CLIMBS:
		var lvl: ClimbLevel = load(_scene(climb)).instantiate()
		var size := []
		for route in ["lemosho", "machame", "umbwe"]:
			var t := Terrain.load_file(lvl.map_path(route))
			var lay: Dictionary = lvl.layout_for(route)
			var hazards := 0
			for ch in ["r", "n", "a", "v", "b", "d"]:
				hazards += t.markers.get(ch, []).size()
			for y in t.height:
				for x in t.width:
					if t.kind(Vector2i(x, y)) in [Terrain.Kind.ICE, Terrain.Kind.CRUMBLE, Terrain.Kind.EXPOSED]:
						hazards += 1
			var walls := 0
			var worst := 0.0
			for a in lay["script"]:
				if a[0] in ["climb", "down"]:
					walls += 1
				if a[0] in ["climb", "fetch"]:
					var col := int(floor(float(a[1]["x"])))
					var row := int(a[1]["row"])
					var rows := 0
					var loose := false
					while t.is_climbable(Vector2i(col, row + rows)):
						loose = loose or t.kind(Vector2i(col, row + rows)) == Terrain.Kind.LOOSE
						rows += 1
					# What the wall costs to climb, resting first (StaminaModel).
					var cost := rows * Terrain.TILE / Climber.CLIMB_UP * StaminaModel.RATES["climb"] * (StaminaModel.LOOSE_FACTOR if loose else 1.0)
					worst = maxf(worst, cost)
			check(worst <= Trek.MIN_BAR[route] * 0.95, "%s on %s: the costliest wall (%.0f) fits the smallest bar (%d)" % [climb, route, worst, int(Trek.MIN_BAR[route])])
			size.append([walls, hazards])
		for k in 2:
			check(size[k + 1][1] > size[k][1], "%s: more in the way on the %s way (%d vs %d)" % [climb, ["faster", "fastest"][k], size[k + 1][1], size[k][1]])
		check(size[2][0] >= size[1][0] and size[2][0] >= size[0][0], "%s: the fastest way has the most walls (%s)" % [climb, size])
		lvl.free()


func _artifact_cells() -> Array:
	return level.hazards.artifact_words.map(func(w: Array) -> Vector2i: return Vector2i(int(w[2][0]), int(w[2][1])))


func test_a_slip_drops_every_artifact_back_where_it_was() -> void:
	await _load("lava-tower")
	var hz: Hazards = level.hazards
	var cells := _artifact_cells()
	eq(cells.size(), 2, "two artifacts on the tower")
	for cell in cells:
		await _put(cell)
	eq(hz.artifacts.size(), 2, "both picked up")
	var taken: Array = Expedition.climb.get("taken", [])
	check(taken.has("artifact:0") and taken.has("artifact:1"), "carried, in the save (a resumed climb keeps them)")
	c.slip("test")
	await physics_frames(2)
	eq(hz.artifacts.size(), 0, "a slip drops them all")
	for p in hz.pickups:
		if p["kind"] == "artifact":
			check(not p["taken"] and p["node"].visible, "every artifact is back where it was")
	taken = Expedition.climb.get("taken", [])
	check(not taken.has("artifact:0") and not taken.has("artifact:1"), "and the save forgets them")
	await _done()


func test_a_raven_snatches_an_artifact() -> void:
	await _load("lava-tower")
	var hz: Hazards = level.hazards
	await _put(_artifact_cells()[0])
	var name := String(hz.artifact_words[0][0])
	eq(hz.steal_artifact(), name, "the raven takes the one you carry")
	eq(hz.artifacts.size(), 0, "none left")
	eq(hz.steal_artifact(), "", "and nothing to take twice")
	check(hz.pickups.any(func(p: Dictionary) -> bool: return p["kind"] == "artifact" and p["index"] == 0 and not p["taken"]), "it is back where you found it")
	await _done()


func test_artifacts_are_kept_when_the_climb_ends_and_lost_when_it_fails() -> void:
	await _load("lava-tower")
	await _put(_artifact_cells()[1])
	level.finish("retreat")
	eq(Artifacts.kept_on(Expedition.session, "lava-tower"), [1], "a retreat walked down keeps what you carry")
	eq(outcome.artifacts, 1, "the outcome says so")
	await _done()
	await _load("lava-tower")
	Trek.ensure(Expedition.session)["artifacts"] = {}
	await _put(_artifact_cells()[0])
	level.finish("fail")
	eq(Artifacts.kept_on(Expedition.session, "lava-tower"), [], "a failed climb leaves them behind")
	eq(outcome.artifacts, 0, "none kept")
	await _done()


func test_an_artifact_kept_earlier_is_not_on_the_climb_again() -> void:
	await _load("lava-tower")
	Artifacts.keep(Expedition.session, "lava-tower", [0])
	level.queue_free()
	await physics_frames(2)
	level = load(Expedition.LEVELS["lava-tower"]).instantiate()
	root.add_child(level)
	await physics_frames(2)
	var hz: Hazards = level.hazards
	eq(hz.artifacts_kept, 1, "one already kept")
	for p in hz.pickups:
		if p["kind"] == "artifact" and p["index"] == 0:
			check(p["taken"] and not p["node"].visible, "and it is not on the ground")
	await _done()


func test_each_route_hides_its_own_two_artifacts_on_every_climb() -> void:
	var names := {}
	for climb in Artifacts.CLIMBS:
		var lvl: ClimbLevel = load(_scene(climb)).instantiate()
		for route in Trek.ROUTES:
			var t := Terrain.load_file(lvl.map_path(route))
			var cells: Array = lvl.layout_for(route)["artifacts"]
			var list := Artifacts.placed(climb, route, cells)
			eq(list.size(), Artifacts.PER_CLIMB, "%s on %s: two artifacts" % [climb, route])
			for a in list:
				var cell := Vector2i(int(a[2][0]), int(a[2][1]))
				check(not t.is_solid(cell) and t.is_solid(cell + Vector2i.DOWN), "%s (%s): %s stands on ground at %s" % [climb, route, a[0], cell])
				check(not names.has(a[0]), "every artifact is different: %s" % a[0])
				names[a[0]] = true
				check(String(a[1]).length() > 40, "%s has its story" % a[0])
			eq(Vector2i(int(cells[0][0]), int(cells[0][1])) != Vector2i(int(cells[1][0]), int(cells[1][1])), true, "%s (%s): two places" % [climb, route])
		lvl.free()
	eq(names.size(), Artifacts.CLIMBS.size() * Trek.ROUTES.size() * Artifacts.PER_CLIMB, "24 artifacts in all")


func test_the_wildlife_is_spread_along_the_walk() -> void:
	for id in ["lava-tower", "barranco-wall", "summit-night"]:
		var lvl: ClimbLevel = load(Expedition.LEVELS[id]).instantiate()
		for route in Trek.ROUTES:
			_spread(id, route, Terrain.load_file(lvl.map_path(route)))
		lvl.free()


func _spread(climb: String, route: String, t: Terrain) -> void:
	var id := "%s (%s)" % [climb, route]
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


func test_falling_into_a_hole_starts_the_climb_again() -> void:
	await _load("lava-tower")
	var lvl: ClimbLevel = level
	lvl.checkpoint = 2
	# The stream cut out of camp: open to the bottom of the map.
	var h := hole()
	check(h.x >= 0, "the tower has a hole")
	c.global_position = Terrain.feet(h + Vector2i(0, 2))
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
	await _put(last_face()["foot"])
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
	await _put(last_face()["foot"])
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
	await _put(clear_walk(Terrain.Kind.ROCK, 8))
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
## smallest bar a climb allows) it takes nearly everything on the fastest
## way, but on every route it can be done by resting to full before each
## face.
func test_the_summit_is_the_boss_but_never_impossible() -> void:
	for route in Trek.ROUTES:
		await _load("summit-night", route)
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
		eq(c.stamina.max_value, Trek.MIN_BAR[route], "a worn party gets the route's smallest bar")
		await follow(level.layout["script"])
		check(outcome != null and outcome.result == "complete", "the summit on %s, even worn out" % route)
		if route == "umbwe":
			check(level.lowest_stamina < 0.25, "and the fastest way is the hardest: down to %d%% of the bar" % int(level.lowest_stamina * 100))
		print("      worn-out summit (%s): %d s, %d slips, lowest %d%% of a %d bar, food eaten %d, %d retries, slips by cause %s" % [route, int(c.clock), c.slips, int(level.lowest_stamina * 100), int(c.stamina.max_value), level.snacks * ClimbLevel.SNACK, retries, level.slips_by_cause])
		retries = 0
		await _done()
