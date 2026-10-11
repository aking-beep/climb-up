extends TestCase
## The climbing and expedition rules, without any scene.


func test_stamina_bar_is_sized_by_expedition_energy() -> void:
	eq(StaminaModel.max_for_energy(0), 55.0, "floor")
	eq(StaminaModel.max_for_energy(100), 100.0, "ceiling")
	eq(StaminaModel.max_for_energy(74), 88.0, "Barranco default")


func test_climbing_drains_and_resting_recovers() -> void:
	var s := StaminaModel.new(80)
	var full := s.value
	s.tick(1.0, "climb")
	near(s.value, full - 6.0, 0.001, "climbing costs 6/s")
	s.tick(1.0, "climb", true)
	near(s.value, full - 6.0 - 9.6, 0.001, "loose rock costs 1.6x")
	s.value = 20.0
	var before := s.value
	s.tick(1.0, "rest_stone")
	near(s.value, before + 26.0, 0.001, "a rest stone gives 26/s")


func test_walking_costs_breath_and_more_in_thin_air() -> void:
	var low := StaminaModel.new(80)
	low.thin_air = StaminaModel.thin_air_for(4000, 60)
	var high := StaminaModel.new(80)
	high.thin_air = StaminaModel.thin_air_for(5700, 60)
	var raw := StaminaModel.new(80)
	raw.thin_air = StaminaModel.thin_air_for(5700, 10)
	for m in [low, high, raw]:
		m.tick(10.0, "walk")
	check(low.value < low.max_value, "walking costs a little even low down")
	check(high.value < low.value, "more at the summit")
	check(raw.value < high.value, "more again for a party that has not acclimatized")
	var up := StaminaModel.new(80)
	up.tick(10.0, "walk_up")
	var flat := StaminaModel.new(80)
	flat.tick(10.0, "walk")
	check(up.value < flat.value, "uphill costs more than flat")
	var still := StaminaModel.new(80)
	still.value = 10.0
	still.tick(1.0, "still")
	check(still.value > 10.0, "standing still still recovers")


func test_cold_slows_recovery_but_not_drain() -> void:
	var warm := StaminaModel.new(80)
	var cold := StaminaModel.new(80, 0.55)
	warm.value = 10.0
	cold.value = 10.0
	warm.tick(1.0, "still")
	cold.tick(1.0, "still")
	near(cold.value - 10.0, (warm.value - 10.0) * 0.55, 0.001, "recovery scaled")


func test_stamina_never_leaves_its_bar() -> void:
	var s := StaminaModel.new(50)
	s.tick(100.0, "rest_stone")
	eq(s.value, s.max_value, "capped at the top")
	s.tick(100.0, "climb")
	eq(s.value, 0.0, "floored at zero")
	check(not s.spend(5.0), "cannot spend what is not there")


func test_wind_is_telegraphed_and_regular() -> void:
	var w := WindSchedule.new(30, 4)
	var t := 0.0
	var saw_warn_before_blow := false
	var last := WindSchedule.Phase.CALM
	while t < w.period * 3:
		var p := w.phase_at(t)
		if p == WindSchedule.Phase.BLOW and last == WindSchedule.Phase.WARN:
			saw_warn_before_blow = true
		check(not (p == WindSchedule.Phase.BLOW and last == WindSchedule.Phase.CALM), "a gust never arrives unwarned (t=%.2f)" % t)
		last = p
		t += 1.0 / 60.0
	check(saw_warn_before_blow, "gusts follow warnings")
	check(WindSchedule.new(80, 4).period < WindSchedule.new(10, 4).period, "worse weather, more frequent gusts")


func test_outcome_has_the_expo_shape() -> void:
	var o := ChallengeOutcome.new()
	o.attempt_id = "a"
	o.result = "complete"
	o.assisted = true
	var keys := o.to_expo().keys()
	keys.sort()
	eq(keys, ["assisted", "attemptId", "challengeId", "regrouped", "result", "seconds", "slips", "staminaLeft"], "fields")
	var back := ChallengeOutcome.from_dict(o.to_dict())
	eq(back.assisted, true, "round trip")
	check(ChallengeOutcome.from_dict({"result": "won"}) == null, "unknown result refused")
	check(ChallengeOutcome.from_dict("nonsense") == null, "non-dictionary refused")


func _at_the_wall() -> Dictionary:
	return TestSessions.at("barranco-wall")


func _land(result: String, patch: Dictionary = {}) -> Dictionary:
	var session := _at_the_wall()
	var p: Dictionary = session["pending"]
	var o := {"attemptId": p["attemptId"], "challengeId": "barranco-wall", "result": result, "staminaLeft": 60, "slips": 0, "assisted": null, "regrouped": false, "seconds": 300}
	o.merge(patch, true)
	var r := Coordinator.resolve(session, o, Kili.def())
	eq(r["status"], "applied", "outcome applied")
	return r["session"]["state"]


func test_the_wall_is_reachable_and_launches_a_climb() -> void:
	var session := _at_the_wall()
	check(session["pending"] != null, "a climb is pending at Barranco")
	if session["pending"] != null:
		eq(session["pending"]["challengeId"], "barranco-wall", "the wall")


func test_helping_marco_beats_leaving_him() -> void:
	var helped := _land("complete", {"assisted": true})
	var left := _land("complete", {"assisted": false})
	check(helped["teamCondition"] > left["teamCondition"], "team condition")
	check(helped["energy"] > left["energy"], "energy")
	eq(helped["checkpoint"], "camp3", "a completed wall moves the party up to Karanga")


func test_backing_off_is_better_than_failing_and_stays_low() -> void:
	var back := _land("retreat")
	var fail := _land("fail", {"slips": 3})
	eq(back["checkpoint"], "camp2", "a retreat stays at Barranco")
	eq(fail["checkpoint"], "camp2", "a failure stays at Barranco")
	check(back["health"] > fail["health"], "health")
	check(back["energy"] >= fail["energy"], "energy")
	check(back["teamCondition"] > fail["teamCondition"], "team")


func test_an_outcome_lands_once() -> void:
	var def := Kili.def()
	var session := _at_the_wall()
	var p: Dictionary = session["pending"]
	var o := {"attemptId": p["attemptId"], "challengeId": "barranco-wall", "result": "complete", "staminaLeft": 60, "slips": 0, "assisted": true, "regrouped": false, "seconds": 300}
	var stale := o.duplicate()
	stale["attemptId"] = "someone-else"
	eq(Coordinator.resolve(session, stale, def)["status"], "stale", "another attempt is ignored")
	var r := Coordinator.resolve(session, o, def)
	eq(r["status"], "applied", "applied")
	eq(Coordinator.resolve(r["session"], o, def)["status"], "duplicate", "and only once")


func test_saves_round_trip_and_refuse_bad_files() -> void:
	var path := "user://test_save.json"
	check(SaveGame.write({"energy": 51}, path), "written")
	var data: Variant = SaveGame.read(path)
	check(data != null, "read back")
	eq(int(data["energy"]), 51, "kept")
	var reason: Array = []
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check(SaveGame.read(path, reason) == null, "corrupt file is no save")
	eq(reason, ["corrupt"], "reason")
	reason.clear()
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"game": "climb-up", "version": 99, "data": {}}))
	f.close()
	check(SaveGame.read(path, reason) == null, "a save from a newer game is not loaded")
	eq(reason, ["newer"], "reason")
	var repaired := Coordinator.sanitize({"attemptId": "a", "result": "complete", "staminaLeft": 900, "slips": -5, "assisted": "yes"})
	eq(repaired["staminaLeft"], 100, "stamina clamped")
	eq(repaired["slips"], 0, "slips clamped")
	eq(repaired["assisted"], null, "assisted must be a bool")
	check(Coordinator.sanitize({"result": "won", "attemptId": "a"}).is_empty(), "unknown result refused")
	SaveGame.erase(path)
