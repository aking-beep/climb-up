extends CragBot
## The crag's replay loop: fail, see why, tap Retry, climb again at once.
## Retry skips the menu and the brief, counts the go once, keeps the
## shoes; the results put Retry first after a fall short and the next
## route first after the top; the high point is measured on the wall and
## "NEW HIGH POINT" only shows above an earlier one; near-miss words are
## only said when true.

const DAY := 1791936000  # a fixed UTC day for the daily tests


func _fresh() -> void:
	Crag.navigate = false
	Crag.reset()
	Crag.reset_daily()
	Crag.clock_override = -1
	Analytics.recent.clear()
	Analytics.write_to_disk = false


func _events(name: String) -> Array:
	return Analytics.recent.filter(func(e: Dictionary) -> bool: return e["e"] == name)


## Ends the current go as a fall short at `rows` up the wall, or as a send,
## and waits for the results (skipping the beat before them).
func _end(sent: bool, rows: int = -1) -> void:
	if rows >= 0:
		level.high_rows = rows
	level._skip_celebration = true
	level.finish(sent)
	for i in 30:
		await physics_frames(1)
		if level.panel.open:
			break


## The Retry tap, then the level the game would load (tests do not change
## scene: Crag.navigate is off).
func _retry() -> void:
	level.panel.choose("retry")
	await _done()
	level = load(Crag.LEVEL).instantiate()
	root.add_child(level)
	await physics_frames(2)
	c = level.climber


func test_retry_is_one_tap_back_onto_the_rock() -> void:
	_fresh()
	Crag.tie_in("first-climb")
	Crag.finish("first-climb", true, 0, 60)
	Crag.climb("warm-up")
	await _load("warm-up", "aggressive")
	eq(int(Crag.record("warm-up")["attempts"]), 1, "the first go counted at tie-in")
	await _end(false, 6)
	check(level.panel.open, "the results show")
	eq(level.panel.choice_ids[0], "retry", "after a fall short, Retry is the first choice")
	check(level.panel.choice_ids.has("again") and level.panel.choice_ids.has("menu"), "the brief and the menu are still a tap away")
	var ev: Array = _events("attempt_ended")
	eq(ev.size(), 1, "one attempt_ended for the go")
	await _retry()
	check(not level.panel.open, "no brief on a retry")
	check(level.quick_started and c.state != Climber.State.LOCKED, "straight onto the route, ready to climb")
	eq(level.shoes, "aggressive", "in the same shoes")
	eq(int(Crag.record("warm-up")["attempts"]), 2, "the retry is one more go, counted once")
	eq(_events("instant_retry_tapped").size(), 1, "the tap is logged once")
	eq(_events("route_replayed").size(), 1, "the replay is logged once (at tie-in, as before)")
	await physics_frames(2)
	check(level.retry_ms >= 0 and level.retry_ms < 1000, "playable %d ms after the tap (headless; a phone needs checking)" % level.retry_ms)
	eq(_events("retry_time_ms").size(), 1, "the time is logged once")
	print("      retry to playable: %d ms (headless desktop)" % level.retry_ms)
	await _done()
	_fresh()


func test_twenty_retries_leave_nothing_behind() -> void:
	_fresh()
	Crag.tie_in("first-climb")
	Crag.finish("first-climb", true, 0, 60)
	Crag.climb("warm-up")
	await _load("warm-up", "neutral")
	await physics_frames(2)
	var nodes_after_first := 0
	for i in 20:
		await _end(false, 3)
		await _retry()
		await physics_frames(2)
		if i == 1:
			nodes_after_first = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	check(nodes <= nodes_after_first + 20, "no nodes pile up over 20 retries (%d then %d)" % [nodes_after_first, nodes])
	eq(int(Crag.record("warm-up")["attempts"]), 21, "21 goes, each counted once")
	# Nothing held over: with no input the climber stands still.
	GameInput.scripted = {"_": false}
	var x := c.global_position.x
	await physics_frames(30)
	near(c.global_position.x, x, 0.5, "no stuck input after the retries")
	check(not level.panel.open and c.state != Climber.State.LOCKED, "and the route is playable")
	await _done()
	_fresh()


func test_after_the_top_the_next_route_comes_first() -> void:
	_fresh()
	Crag.tie_in("first-climb")
	Crag.finish("first-climb", true, 0, 60)
	Crag.climb("warm-up")
	await _load("warm-up", "neutral")
	await _end(true)
	eq(level.panel.choice_ids[0], "next", "a first send opens the next route, and offers it first")
	eq(level.panel.choice_ids[1], "retry", "with a replay second")
	check("Replay" in level.panel._buttons.get_child(1).text, "named Replay")
	var body: String = level.panel.body_text()
	check("Time" in body and "falls 0" in body and "Grade 4" in body and "best ascent" in body, "time, falls, grade and best style: " + body)
	await _done()
	_fresh()


func test_the_high_point_is_measured_on_the_wall() -> void:
	_fresh()
	Crag.tie_in("first-climb")
	Crag.finish("first-climb", true, 0, 60)
	Crag.climb("warm-up")
	await _load("warm-up", "neutral")
	await _end(false, 8)
	check(not level.outcome["newHighPoint"], "a first go sets a high point, it does not beat one")
	check(not "NEW HIGH POINT" in level.panel.title_text(), "so no NEW HIGH POINT")
	await _retry()
	check(level.high_mark.get_child_count() >= 2, "a chalk mark at the best height")
	for n in level.high_mark.get_children():
		if n is Line2D:
			var row := Terrain.cell_of(Vector2(0, n.points[0].y - 1)).y
			for x in range(int(minf(n.points[0].x, n.points[1].x) / Terrain.TILE), int(maxf(n.points[0].x, n.points[1].x) / Terrain.TILE) + 1):
				check(not level.terrain.is_climbable(Vector2i(x, row)), "the chalk stays off the holds (column %d)" % x)
	await _end(false, 11)
	check(level.outcome["newHighPoint"], "above the best: a new high point")
	check("NEW HIGH POINT" in level.panel.title_text(), "and it says so: " + level.panel.title_text())
	eq(_events("new_high_point").size(), 1, "logged once")
	eq(int(Crag.record("warm-up")["highRows"]), 11, "the record moves up")
	await _retry()
	await _end(false, 10)
	check(not level.outcome["newHighPoint"], "below it: not new")
	check("short of your best" in level.near_miss, "one row short: a near miss, in metres: " + level.near_miss)
	check("0.5 m" in level.near_miss, "half a metre: " + level.near_miss)
	await _retry()
	await _end(false, 3)
	eq(level.near_miss, "", "far below the best and the anchor: nothing to say")
	await _retry()
	var top: int = level.route_rows()
	await _end(false, top - 3)
	check("New high point, and only 1.5 m from the anchor" in level.near_miss, "near the top: " + level.near_miss)
	await _retry()
	await _end(true)
	eq(level.near_miss, "", "a send is never a near miss")
	await _done()
	_fresh()


func test_a_replay_of_the_lesson_does_not_stop_for_tips_again() -> void:
	_fresh()
	Crag.climb("first-climb")
	await _load("first-climb")
	var stopped := 0
	for i in 60 * 6:
		var held := {"_": false, "move_right": true}
		if level.panel.open and level.lesson != "":
			stopped += 1
			level.panel.choose("lesson")
		GameInput.scripted = held
		await tree.physics_frame
	check(stopped >= 1, "the first time, tips stop the game (%d)" % stopped)
	await _end(false, 2)
	await _retry()
	var again := 0
	for i in 60 * 6:
		if level.panel.open and level.lesson != "":
			again += 1
			level.panel.choose("lesson")
		GameInput.scripted = {"_": false, "move_right": true}
		await tree.physics_frame
	eq(again, 0, "on a replay, tips seen before do not stop it")
	check(Crag.lessons_seen.size() >= stopped, "the tips seen are remembered (%s)" % [Crag.lessons_seen])
	await _done()
	_fresh()


func test_the_daily_route_retries_and_keeps_its_own_best() -> void:
	_fresh()
	Crag.clock_override = DAY
	Crag.tie_in("first-climb")
	Crag.finish("first-climb", true, 0, 60)
	Crag.current = "daily"
	await _load("daily", "neutral")
	await _end(false, 7)
	eq(int(Crag.daily_record()["highRows"]), 7, "the day's high point is the day's")
	eq(int(Crag.record("daily")["highRows"]), 0, "not mixed into a route's record")
	check("Today: 1 go" in level.panel.body_text(), "the results say how today is going: " + level.panel.body_text())
	await _retry()
	check(not level.panel.open and level.is_daily(), "Retry goes straight back onto today's route")
	eq(int(Crag.daily_record()["attempts"]), 2, "counted once")
	await _end(false, 9)
	check(level.outcome["newHighPoint"], "above today's best: new")
	await _done()
	_fresh()


func test_the_beat_before_the_results_can_be_skipped() -> void:
	_fresh()
	Crag.tie_in("first-climb")
	Crag.finish("first-climb", true, 0, 60)
	Crag.climb("warm-up")
	await _load("warm-up", "neutral")
	level.high_rows = 4
	level.finish(false)
	await physics_frames(2)
	check(not level.panel.open, "a short beat first")
	GameInput.scripted = {"_": false, "interact": true}
	await physics_frames(3)
	GameInput.scripted = {"_": false}
	check(level.panel.open, "a tap skips straight to the results")
	await _done()
	_fresh()
