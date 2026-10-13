extends ClimbBot
## The way down from the summit, played: turning around up there opens the
## descent level; the scripted climber brings the team down (helping Jun on
## the rim, the wind, the scree, the rock step climbed down, the ice); and
## how it went lands on the expedition once. The summit alone is not a win:
## the team getting down is.


## A session standing on the summit (the summit night climbed).
func _at_summit() -> void:
	SaveGame.erase()
	Expedition.navigate = false
	Settings.touch_controls = false
	Expedition.session = TestSessions.at("summit-night")
	check(Expedition.pending() != null, "the careful party reached the summit night")
	var p: Dictionary = Expedition.pending()
	Expedition.session = Coordinator.resolve(Expedition.session, TestSessions.complete(p), Expedition.def)["session"]
	Expedition.climb = {}
	eq(Expedition.state()["checkpoint"], "summit", "on the summit")
	check(Expedition.state()["summitReached"], "the summit is recorded")


func _turn_around_index() -> int:
	var c := Expedition.card()
	for i in c["choices"].size():
		if String(c["choices"][i]["effect"].get("move", "")) in ["retreat", "down"]:
			return i
	return -1


func _hold_index() -> int:
	var c := Expedition.card()
	for i in c["choices"].size():
		if String(c["choices"][i]["effect"].get("move", "")) == "hold":
			return i
	return -1


func test_the_descent_effect_rewards_bringing_everyone_down() -> void:
	var together := Expedition.descent_effect({"result": "complete", "slips": 0, "staminaLeft": 60, "assisted": true})
	eq(together["scores"]["teamwork"]["mark"], "descent-assist", "short-roping Jun down is teamwork")
	check(together["teamCondition"] > 0, "and lifts the team")
	eq(together["scores"]["riskManagement"]["delta"], 4, "a clean descent is good risk management")
	var alone := Expedition.descent_effect({"result": "complete", "slips": 2, "staminaLeft": 60, "assisted": false})
	check(alone["scores"]["teamwork"]["delta"] < 0 and alone["teamCondition"] < 0, "leaving Jun on the rim costs the team")
	eq(alone["health"], -4, "slips on the way down cost health")
	var bad := Expedition.descent_effect({"result": "fail", "slips": 3, "staminaLeft": 0, "assisted": null})
	check(bad["health"] <= -10 and bad["scores"]["riskManagement"]["delta"] < 0, "a descent that took too much hurts")
	eq(together["move"], "wait", "the effect does not move the party: the card's own choice does")


func test_turning_around_on_the_summit_opens_the_way_down() -> void:
	await _at_summit()
	var i := _turn_around_index()
	check(i >= 0, "the summit card offers turning around")
	check(Expedition.descent_launches(i), "turning around opens the descent")
	var hold := _hold_index()
	check(hold >= 0 and not Expedition.descent_launches(hold), "staying on the summit does not")
	Expedition.choose(i)
	var d: Dictionary = Expedition.trek()["descent"]
	check(String(d["attemptId"]).begins_with("descent:"), "a descent is under way")
	eq(Expedition.climb.get("challengeId"), "descent", "and resumable like a climb")
	eq(Expedition.state()["checkpoint"], "summit", "the card is not spent until the descent ends")
	var before := ExpeditionEngine.score(Expedition.state())
	var o := {"attemptId": d["attemptId"], "challengeId": "descent", "result": "complete", "slips": 0, "staminaLeft": 50, "assisted": true, "regrouped": false, "seconds": 300}
	eq(Expedition.finish_descent(o), "applied", "the way down lands")
	eq(Expedition.finish_descent(o), "stale", "once")
	check(Expedition.state()["retreating"], "the party is on its way down")
	var marks: Array = []
	for n in Expedition.state()["ledger"]["teamwork"]:
		marks.append(n["mark"])
	check("descent-assist" in marks, "bringing Jun down is on the ledger")
	var after := ExpeditionEngine.score(Expedition.state())
	check(after["teamwork"] > before["teamwork"], "teamwork rose (%d to %d)" % [before["teamwork"], after["teamwork"]])
	check(Expedition.trek()["descent"]["played"], "the descent is played")
	if Expedition.active() and Expedition.state()["checkpoint"] == "summit":
		check(not Expedition.descent_launches(_turn_around_index()), "and not opened again")
	# Saved and loaded with the trek.
	Expedition.save()
	check(Expedition.load_saved(), "the save loads")
	check(Expedition.trek()["descent"].get("played", false), "the descent is remembered")
	SaveGame.erase()


func test_a_ruinous_descent_can_lose_the_expedition() -> void:
	await _at_summit()
	var s: Dictionary = Expedition.state().duplicate(true)
	s["health"] = 8
	Expedition.session["state"] = s
	var i := _turn_around_index()
	Expedition.choose(i)
	var d: Dictionary = Expedition.trek()["descent"]
	Expedition.finish_descent({"attemptId": d["attemptId"], "challengeId": "descent", "result": "fail", "slips": 3, "staminaLeft": 0, "assisted": false, "regrouped": false, "seconds": 400})
	eq(Expedition.state()["status"], "failed", "the summit without getting down is not a success")
	var sc := ExpeditionEngine.score(Expedition.state())
	check(sc["summitReached"] and not sc["returnedSafely"], "summit recorded, return not")
	check(sc["overall"] <= 36, "and the score says so (%d)" % sc["overall"])
	SaveGame.erase()


func test_the_way_down_played() -> void:
	await _at_summit()
	var i := _turn_around_index()
	Expedition.choose(i)
	outcome = null
	level = load(Expedition.DESCENT).instantiate()
	root.add_child(level)
	level.finished.connect(func(o: ChallengeOutcome) -> void: outcome = o)
	await physics_frames(2)
	check(level.panel.open, "the brief first")
	check(not level.panel.has_choice("backoff"), "no backing off: the only way is down")
	check("summit" in level.panel.body_text().to_lower(), "the brief says what the game is about: " + level.panel.body_text().left(80))
	level.panel.choose("start")
	await physics_frames(1)
	c = level.climber
	check(level.mate != null and level.mate.person == "jun", "Jun is on the rim")
	# Along the rim to Jun: help him.
	await drive(["move_right"], func() -> bool: return level.panel.open, 20.0, "to Jun")
	check(level.panel.open and level.panel.has_choice("help"), "meeting Jun asks what to do")
	if not level.panel.has_choice("help") or c.stamina.value < c.helper_cost + 5:
		level.panel.choose("back")
		await rest_up(0.95)
		await drive(["move_right"], func() -> bool: return level.panel.open, 10.0, "back to Jun")
	level.panel.choose("help")
	await drive([], func() -> bool: return level.panel.open, 5.0, "panel")
	eq(level.mate_state, "helped", "Jun on the rope")
	level.panel.choose("continue")
	await physics_frames(2)
	# The rim in the wind, the scree, the icy bench to the rock step.
	await cross(41.0)
	await drive(["move_right"], func() -> bool: return tx() >= 86.3 or level.panel.open, 60.0, "down the scree to the rock step")
	check(tx() >= 86.0, "at the top of the rock step (%.1f, %.1f)" % [tx(), ty()])
	# Climb down the step.
	await drive(["climb_down", "move_right"], func() -> bool: return c.is_climbing(), 3.0, "onto the step")
	check(c.is_climbing(), "on the rock, climbing down")
	await drive(["climb_down"], func() -> bool: return c.state == Climber.State.GROUND, 20.0, "down the step")
	check(ty() >= 45.5, "at the foot of the step (%.1f)" % ty())
	# The last scree to Barafu.
	await drive(["move_right"], func() -> bool: return outcome != null, 90.0, "to Barafu")
	check(outcome != null, "the descent ended")
	if outcome:
		eq(outcome.result, "complete", "down")
		eq(outcome.assisted, true, "with Jun")
		eq(outcome.challenge_id, "descent", "the descent")
		print("      the way down took %d s of game time, %d%% stamina left, %d slips, %d wind strikes, %.0f s resting" % [outcome.seconds, outcome.stamina_left, outcome.slips, outcome.wind_strikes, outcome.rest_seconds])
	await drive([], func() -> bool: return level.panel.open, 5.0, "panel")
	level.panel.choose("camp")
	await physics_frames(2)
	check(Expedition.trek()["descent"].get("played", false), "the way down landed on the expedition")
	check(Expedition.state()["retreating"] or Expedition.state()["status"] != "active", "the party is going home")
	GameInput.scripted = {}
	level.queue_free()
	await physics_frames(2)
	SaveGame.erase()
