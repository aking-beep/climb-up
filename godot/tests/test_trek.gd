extends TestCase
## The harder strategy layer: routes and the permit, sickness, emergencies,
## people going down, and the endings. Whole expeditions are played through
## the real Expedition autoload by two policies, so the tests show that care
## pays and recklessness costs, on every route.


## Plays a whole expedition. `careful`: the patient choices, water at every
## camp, Jun's care, everyone down in an emergency. Otherwise: always up,
## no care, wait out emergencies. `brisk` is careful but skips the two
## optional rest days, the way a short permit asks. Climbs land completed.
static func play(route: String, careful: bool, seed: int, brisk: bool = false) -> Dictionary:
	Expedition.navigate = false
	Expedition.new_expedition(seed)
	var guard := 0
	var stats := {"maxStage": 0, "sickEvents": 0, "emerg": 0, "summitDay": -1}
	while Expedition.active() and guard < 200:
		guard += 1
		var tk := Trek.ensure(Expedition.session)
		for id in tk["sick"]:
			stats["maxStage"] = maxi(stats["maxStage"], tk["sick"][id]["stage"])
		if tk["emergency"] != null:
			stats["emerg"] += 1
		if Expedition.state()["summitReached"] and stats["summitDay"] < 0:
			stats["summitDay"] = ExpeditionEngine.day_of(Expedition.state())
		var p: Variant = Expedition.pending()
		if p != null:
			Expedition.finish_climb(TestSessions.complete(p))
			continue
		var card := Expedition.card()
		var pick := 0
		if card["id"] == "trek-route":
			for i in card["choices"].size():
				if card["choices"][i]["route"] == route:
					pick = i
		elif String(card["id"]).begins_with("trek-emergency"):
			var want := "descend" if careful else "wait"
			for i in card["choices"].size():
				if card["choices"][i]["act"] == want:
					pick = i
		else:
			if careful:
				var s := Expedition.state()
				if s["marks"].get("water-" + String(s["checkpoint"])) != true and s["supplies"] >= 6:
					Expedition.play_routine("water")
				for id in Party.ORDER:
					if Trek.can_treat(Expedition.session, id):
						Expedition.treat(id)
				card = Expedition.card()
				if card.get("trek", false) or not Expedition.active():
					continue
				for i in card["choices"].size():
					var label: String = card["choices"][i]["label"]
					if brisk and label in ["Take the extra day", "Rest the day"]:
						continue
					if TestSessions.CAREFUL.has(label):
						pick = i
						break
				if brisk and card["choices"][pick]["label"] in ["Take the extra day", "Rest the day"]:
					for i in card["choices"].size():
						if String(card["choices"][i].get("effect", {}).get("move", "")) == "up":
							pick = i
			else:
				for i in card["choices"].size():
					var mv := String(card["choices"][i].get("effect", {}).get("move", ""))
					if mv == "up" or mv == "summit":
						pick = i
						break
		Expedition.choose(pick)
	var s := Expedition.state()
	return {"ending": Trek.ensure(Expedition.session)["ending"] if not Expedition.active() else "unfinished",
		"summit": s["summitReached"], "gone": Trek.ensure(Expedition.session)["gone"].size(),
		"day": ExpeditionEngine.day_of(s), "score": ExpeditionEngine.score(s)["overall"], "stats": stats}


func _tally(route: String, careful: bool, seeds: Array, brisk: bool = false) -> Dictionary:
	var t := {"summit": 0, "together": 0, "endings": {}}
	for seed in seeds:
		var r := play(route, careful, seed, brisk)
		if r["summit"]:
			t["summit"] += 1
		if r["ending"] == "summit-together":
			t["together"] += 1
		t["endings"][r["ending"]] = t["endings"].get(r["ending"], 0) + 1
		if OS.get_environment("TREK_DEBUG") != "":
			print("        ", route, " careful=", careful, " seed=", seed, " ", r["ending"], " day=", r["day"], " ", r["stats"])
	return t


func test_the_route_card_comes_first_and_sets_the_permit() -> void:
	SaveGame.erase()
	Expedition.new_expedition(7)
	eq(Expedition.card()["id"], "trek-route", "the first decision is the route")
	eq(Expedition.playable(), ["", "", ""], "no climb launches from it")
	var i := 0
	for c in Expedition.card()["choices"]:
		if c["route"] == "umbwe":
			Expedition.choose(i)
		i += 1
	eq(Trek.permit_days(Expedition.session), 7, "the direct way has seven days")
	check(int(Expedition.state()["supplies"]) < 80, "and carries less")
	eq(Expedition.state()["checkpoint"], "camp1", "and starts high, at Shira 2")
	check(Expedition.card()["id"] != "trek-route", "then the expedition starts")
	SaveGame.erase()


func test_the_permit_turns_a_slow_party_around() -> void:
	SaveGame.erase()
	Expedition.new_expedition(7)
	Expedition.choose(1)  # the steep way: eight days
	# The last hour of the permit, still low on the mountain.
	var s: Dictionary = Expedition.state()
	s["elapsedHours"] = Trek.permit_days(Expedition.session) * 24 - 1
	Expedition.choose(0)
	check(Expedition.state()["retreating"] or not Expedition.active(), "the party was walked down")
	eq(Trek.ensure(Expedition.session)["ending"], "permit", "out of days")
	check(not Expedition.state()["summitReached"], "without the summit")
	SaveGame.erase()


func test_sickness_worsens_going_up_and_eases_going_down() -> void:
	var def := Expedition.def
	var session := TestSessions.at("barranco-wall")
	session["pending"] = null
	var t := Trek.ensure(session)
	t["sick"]["marco"] = {"kind": "ams", "stage": 1}
	var low: Dictionary = session["state"].duplicate(true)
	# Going higher with a gap in acclimatization.
	var up: Dictionary = low.duplicate(true)
	up["altitude"] = 4600
	up["acclimatization"] = 10
	up["elapsedHours"] = float(low["elapsedHours"]) + 8.0
	up["history"].append({})
	var worse := 0
	for k in 20:
		t["sick"]["marco"] = {"kind": "ams", "stage": 1}
		var a: Dictionary = up.duplicate(true)
		a["elapsedHours"] += k
		session["state"] = a
		Trek.advance(session, low, def)
		if t["sick"].get("marco", {}).get("stage", 0) >= 2:
			worse += 1
	check(worse >= 10, "climbing while unadapted usually makes it worse (%d of 20)" % worse)
	# Going down clears a first stage.
	t["sick"]["marco"] = {"kind": "ams", "stage": 1}
	var down: Dictionary = low.duplicate(true)
	down["altitude"] = int(low["altitude"]) - 600
	down["elapsedHours"] = float(low["elapsedHours"]) + 6.0
	session["state"] = down
	Trek.advance(session, low, def)
	check(not t["sick"].has("marco"), "going down helps")


func test_an_emergency_has_only_hard_answers() -> void:
	SaveGame.erase()
	Expedition.new_expedition(7)
	Expedition.choose(0)
	var t := Expedition.trek()
	t["emergency"] = {"who": "marco"}
	t["sick"]["marco"] = {"kind": "ams", "stage": 3}
	var card := Expedition.card()
	check(String(card["id"]).begins_with("trek-emergency"), "the emergency replaces the day's card")
	var acts: Array = card["choices"].map(func(c: Dictionary) -> String: return c["act"])
	eq(acts, ["descend", "evacuate", "wait"], "go down, send down, or wait")
	Expedition.choose(1)
	check(Trek.is_gone(Expedition.session, "marco"), "Marco went down with porters")
	check(Party.ORDER.has("marco"), "")
	SaveGame.erase()


func test_a_teammate_sent_down_is_not_on_the_climb() -> void:
	SaveGame.erase()
	Expedition.session = TestSessions.at("barranco-wall")
	Expedition.trek()["gone"].append("marco")
	Expedition.climb = {}
	Expedition.resume_climb()
	var level: ClimbLevel = load(Expedition.LEVELS["barranco-wall"]).instantiate()
	root.add_child(level)
	await tree.physics_frame
	check(level.mate == null, "no Marco on the wall")
	eq(level.mate_state, "none", "nobody to help or leave")
	level.queue_free()
	await tree.physics_frame
	SaveGame.erase()


func test_being_unwell_shrinks_the_climb() -> void:
	SaveGame.erase()
	Expedition.session = TestSessions.at("lava-tower")
	Expedition.climb = {}
	Expedition.resume_climb()
	var well: ClimbLevel = load(Expedition.LEVELS["lava-tower"]).instantiate()
	root.add_child(well)
	await tree.physics_frame
	var full := well.stamina.max_value
	var breath := well.stamina.thin_air
	well.queue_free()
	await tree.physics_frame
	Expedition.trek()["sick"]["you"] = {"kind": "ams", "stage": 2}
	var ill: ClimbLevel = load(Expedition.LEVELS["lava-tower"]).instantiate()
	root.add_child(ill)
	await tree.physics_frame
	check(ill.stamina.max_value < full, "less in the arms when unwell (%.0f vs %.0f)" % [ill.stamina.max_value, full])
	check(ill.stamina.thin_air > breath, "and more breath per step")
	ill.queue_free()
	await tree.physics_frame
	SaveGame.erase()


func test_care_pays_and_haste_costs_on_every_route() -> void:
	var seeds := [3, 7, 11, 19, 23, 31, 42, 57]
	var report := []
	var careful_long := {}
	var reckless_direct := {}
	var brisk_steep := {}
	for route in ["lemosho", "machame", "umbwe"]:
		for style in ["careful", "brisk", "reckless"]:
			var t := _tally(route, style != "reckless", seeds, style == "brisk")
			report.append("%s %s: summit %d/8, together %d/8, %s" % [route, style, t["summit"], t["together"], JSON.stringify(t["endings"])])
			if route == "lemosho" and style == "careful":
				careful_long = t
			if route == "umbwe" and style == "reckless":
				reckless_direct = t
			if route == "machame" and style == "brisk":
				brisk_steep = t
	for line in report:
		print("      " + line)
	check(careful_long["together"] >= 4, "a careful party on the long way usually summits together")
	check(reckless_direct["together"] <= 1, "a reckless party on the direct way almost never does")
	check(brisk_steep["together"] >= 2, "the steep way can be done, briskly and with care")
	check(careful_long["endings"].size() + reckless_direct["endings"].size() + brisk_steep["endings"].size() >= 3, "different roads, different endings")
	SaveGame.erase()
