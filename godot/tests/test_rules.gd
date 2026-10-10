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


func _outcome(result: String, patch: Dictionary = {}) -> ChallengeOutcome:
	var o := ChallengeOutcome.new()
	o.attempt_id = "a"
	o.result = result
	o.stamina_left = 60
	for k in patch:
		o.set(k, patch[k])
	return o


func test_helping_marco_beats_leaving_him() -> void:
	var helped := ExpeditionState.new()
	helped.apply_wall(_outcome("complete", {"assisted": true}))
	var left := ExpeditionState.new()
	left.apply_wall(_outcome("complete", {"assisted": false}))
	check(helped.team_condition > left.team_condition, "team condition")
	check(helped.energy > left.energy, "energy")
	eq(helped.camp, "Karanga Camp", "a completed wall moves the party up")


func test_backing_off_is_better_than_failing_and_stays_low() -> void:
	var back := ExpeditionState.new()
	back.apply_wall(_outcome("retreat"))
	var fail := ExpeditionState.new()
	fail.apply_wall(_outcome("fail"))
	eq(back.camp, "Barranco Camp", "a retreat stays at Barranco")
	eq(fail.camp, "Barranco Camp", "a failure stays at Barranco")
	check(back.health > fail.health, "health")
	check(back.energy > fail.energy, "energy")
	check(back.team_condition > fail.team_condition, "team")


func test_score_notes_land_once() -> void:
	var s := ExpeditionState.new()
	s.note("judgment", "x", 3, "m")
	s.note("judgment", "x", 3, "m")
	eq(s.ledger.size(), 1, "marked note counted once")


func test_saves_round_trip_and_refuse_bad_files() -> void:
	var path := "user://test_save.json"
	var s := ExpeditionState.new()
	s.energy = 51
	check(SaveGame.write({"expedition": s.to_dict()}, path), "written")
	var data: Variant = SaveGame.read(path)
	check(data != null, "read back")
	eq(ExpeditionState.from_dict(data["expedition"]).energy, 51, "energy kept")
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
	var repaired := ExpeditionState.from_dict({"camp": "x", "energy": 900, "health": -5, "ledger": [{"mark": "m", "delta": 99}]})
	eq(repaired.energy, 100, "energy clamped")
	eq(repaired.health, 0, "health clamped")
	eq(repaired.ledger[0]["delta"], 8, "note delta bounded")
	SaveGame.erase(path)
