extends TestCase
## The expedition around the climb: briefing, the climb, the outcome
## landing once, resuming from a cairn after quitting, and resting instead.


func _fresh() -> void:
	SaveGame.erase()
	Expedition.new_expedition(7)
	Expedition.last_outcome = null


func test_an_outcome_lands_once_and_only_for_its_attempt() -> void:
	_fresh()
	Expedition.climb = {"attemptId": Expedition.attempt_id(), "checkpoint": 0}
	var energy := Expedition.state.energy
	var o := ChallengeOutcome.new()
	o.attempt_id = "someone-else"
	o.result = "complete"
	Expedition.finish_climb(o)
	eq(Expedition.state.energy, energy, "a stale outcome changes nothing")
	o.attempt_id = Expedition.climb["attemptId"]
	Expedition.finish_climb(o)
	eq(Expedition.state.camp, "Karanga Camp", "the outcome landed")
	var after := Expedition.state.energy
	Expedition.finish_climb(o)
	eq(Expedition.state.energy, after, "and only once")
	await tree.process_frame


func test_quitting_mid_wall_resumes_at_the_last_cairn() -> void:
	_fresh()
	Expedition.climb = {"attemptId": Expedition.attempt_id(), "checkpoint": 0}
	Expedition.remember({"checkpoint": 3, "slips": 1, "mate": "waiting", "seconds": 95.0})
	# A new app launch: state comes back from disk.
	Expedition.climb = {}
	check(Expedition.load_saved(), "save restored")
	eq(int(Expedition.climb.get("checkpoint")), 3, "checkpoint")
	var level: Node = load(Expedition.BARRANCO).instantiate()
	root.add_child(level)
	await physics_frames(3)
	eq(level.checkpoint, 3, "level resumes at cairn 3")
	eq(level.climber.slips, 1, "with its slips")
	check(level.climber.global_position.distance_to(level.cairns[3]) < 2.0, "standing at cairn 3")
	level.queue_free()
	await physics_frames(2)
	SaveGame.erase()


func test_resting_instead_of_climbing() -> void:
	_fresh()
	var energy := Expedition.state.energy
	Expedition.last_choice = ""
	Expedition.state.rest_day()
	check(Expedition.state.energy > energy, "rest restores energy")
	eq(Expedition.state.camp, "Barranco Camp", "and stays at Barranco")
	await tree.process_frame


func test_the_screens_build() -> void:
	_fresh()
	for path in ["res://modes/expedition/menu.tscn", "res://modes/expedition/briefing.tscn", "res://modes/expedition/outcome.tscn"]:
		var screen: Node = load(path).instantiate()
		root.add_child(screen)
		await tree.process_frame
		check(screen.card.get_child_count() > 2, "%s has content" % path)
		screen.queue_free()
		await tree.process_frame
	SaveGame.erase()


func test_quality_settings_never_change_the_climb() -> void:
	var results: Array = []
	for q in [Settings.Quality.FULL, Settings.Quality.LOW_POWER]:
		Settings.quality = q
		Expedition.state = ExpeditionState.new()
		Expedition.climb = {}
		var level: Node = load(Expedition.BARRANCO).instantiate()
		root.add_child(level)
		await physics_frames(2)
		var c: Climber = level.climber
		for i in 240:
			GameInput.scripted = {"_": false, "move_right": true}
			await tree.physics_frame
		results.append([snappedf(c.global_position.x, 0.01), snappedf(c.stamina.value, 0.01)])
		GameInput.scripted = {}
		level.queue_free()
		await physics_frames(2)
	Settings.quality = Settings.Quality.FULL
	eq(results[0], results[1], "same position and stamina at every quality")
