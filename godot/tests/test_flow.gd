extends TestCase
## The expedition around the climbs: the camp screen's choices, a played
## choice opening its climb without spending the card, the outcome landing
## once, the brief's back-off, resuming from a cairn, and saves.


func _fresh() -> void:
	SaveGame.erase()
	Expedition.new_expedition(7)


func _park(challenge: String) -> void:
	_fresh()
	Expedition.session = TestSessions.at(challenge)
	Expedition.climb = {}


func test_a_played_choice_opens_its_climb_and_does_not_spend_the_card() -> void:
	_fresh()
	var s := TestSessions.at("lava-tower")
	check(not s.is_empty(), "reached the Lava Tower")
	# Undo the launch, then choose it through the autoload.
	s["pending"] = null
	Expedition.session = s
	var card := Expedition.card()
	var index := Expedition.playable().find("lava-tower")
	check(index >= 0, "one choice of the card is the played climb")
	var history: int = Expedition.state()["history"].size()
	Expedition.choose(index)
	check(Expedition.pending() != null, "the climb is pending")
	eq(Expedition.climb.get("challengeId"), "lava-tower", "the level knows which climb")
	eq(Expedition.state()["history"].size(), history, "the card is not spent yet")
	eq(Expedition.card()["id"], card["id"], "the same card is still up")
	await tree.process_frame


func test_an_outcome_lands_once_through_the_autoload() -> void:
	_park("barranco-wall")
	var p: Dictionary = Expedition.pending()
	Expedition.climb = {"attemptId": p["attemptId"], "challengeId": p["challengeId"], "checkpoint": 0}
	var o := TestSessions.complete(p)
	var stale := o.duplicate()
	stale["attemptId"] = "someone-else"
	eq(Expedition.finish_climb(stale), "stale", "a stale outcome changes nothing")
	check(Expedition.pending() != null, "still pending")
	eq(Expedition.finish_climb(o), "applied", "landed")
	eq(Expedition.state()["checkpoint"], "camp3", "the party is at Karanga")
	eq(Expedition.last.get("kind"), "climb", "the camp screen will show what happened")
	eq(Expedition.finish_climb(o), "stale", "and only once")
	await tree.process_frame


func test_backing_off_at_the_brief_is_a_retreat() -> void:
	_park("lava-tower")
	Expedition.resume_climb()
	var level: Node = load(Expedition.LEVELS["lava-tower"]).instantiate()
	root.add_child(level)
	await physics_frames(3)
	check(level.panel.open, "the brief is up")
	check(level.climber.state == Climber.State.LOCKED, "nobody climbs during the brief")
	level.panel.choose("backoff")
	await physics_frames(2)
	check(Expedition.pending() == null, "the climb is closed")
	eq(Expedition.state()["checkpoint"], "camp1", "the party stays at Shira 2")
	eq(Expedition.last.get("outcome", {}).get("result"), "retreat", "as a retreat")
	level.queue_free()
	await physics_frames(2)


func test_quitting_mid_wall_resumes_at_the_last_cairn() -> void:
	_park("barranco-wall")
	Expedition.resume_climb()
	Expedition.remember({"checkpoint": 3, "slips": 1, "mate": "waiting", "seconds": 95.0})
	# A new app launch: state comes back from disk.
	Expedition.climb = {}
	Expedition.session = Coordinator.create_session(ExpeditionEngine.create(1, Expedition.def))
	check(Expedition.load_saved(), "save restored")
	check(Expedition.pending() != null, "the climb is still pending")
	eq(int(Expedition.climb.get("checkpoint")), 3, "checkpoint")
	var level: Node = load(Expedition.LEVELS["barranco-wall"]).instantiate()
	root.add_child(level)
	await physics_frames(3)
	eq(level.checkpoint, 3, "level resumes at cairn 3")
	eq(level.climber.slips, 1, "with its slips")
	check(not level.panel.open, "no brief when resuming")
	check(level.climber.global_position.distance_to(level.cairns[3]) < 2.0, "standing at cairn 3")
	level.queue_free()
	await physics_frames(2)
	SaveGame.erase()


func test_a_saved_session_plays_on_identically() -> void:
	_park("summit-night")
	Expedition.save()
	var unsaved: Dictionary = Expedition.session.duplicate(true)
	check(Expedition.load_saved(), "restored")
	var p: Dictionary = Expedition.pending()
	var o := TestSessions.complete(p)
	var before: Dictionary = unsaved["state"]
	var direct := Coordinator.resolve(unsaved, o, Expedition.def)
	Trek.advance(direct["session"], before, Expedition.def)
	eq(Expedition.finish_climb(o), "applied", "the restored session takes the outcome")
	var a := Expedition.state()
	var b: Dictionary = direct["session"]["state"]
	for key in ["checkpoint", "health", "energy", "teamCondition", "elapsedHours", "summitReached"]:
		eq(a[key], b[key], "%s matches the never-saved session" % key)
	SaveGame.erase()


func test_camp_beats_and_tending() -> void:
	_fresh()
	var before: float = Expedition.state()["elapsedHours"]
	Expedition.play_routine("pole-pole")
	check(Expedition.state()["elapsedHours"] > before, "a camp beat takes an hour")
	var again: int = Expedition.state()["history"].size()
	Expedition.play_routine("pole-pole")
	eq(Expedition.state()["history"].size(), again, "and only once per camp")
	await tree.process_frame


func test_the_screens_build() -> void:
	_fresh()
	for path in [Expedition.MENU, Expedition.CAMP]:
		var screen: Node = load(path).instantiate()
		root.add_child(screen)
		await tree.process_frame
		await tree.process_frame
		screen.queue_free()
		await tree.process_frame
	# The camp as a scorecard, after the expedition ends.
	var s := Expedition.state()
	s["status"] = "complete"
	s["returnedSafely"] = true
	var camp: Node = load(Expedition.CAMP).instantiate()
	root.add_child(camp)
	await tree.process_frame
	var text := ""
	for c in camp.paper.get_children():
		if c is Label:
			text += c.text + " "
	check("Turned back together" in text, "the scorecard shows the ending")
	camp.queue_free()
	await tree.process_frame
	SaveGame.erase()


func test_quality_settings_never_change_the_climb() -> void:
	var results: Array = []
	for q in [Settings.Quality.FULL, Settings.Quality.LOW_POWER]:
		Settings.quality = q
		_fresh()
		var level: Node = load(Expedition.LEVELS["barranco-wall"]).instantiate()
		root.add_child(level)
		await physics_frames(2)
		level.panel.choose("start")
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
