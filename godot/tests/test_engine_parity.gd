extends TestCase
## The GDScript expedition engine against the TypeScript original: every
## scripted playthrough in fixtures/expeditions.json (exported from the Expo
## game by tools/godot/export_content.ts) is replayed step by step, and the
## whole state, the card, the playable climbs, the party and the camp beats
## must match after every step.

const FIXTURES := "res://tests/fixtures/expeditions.json"


func _diff(a: Variant, b: Variant, path: String) -> String:
	var ta := typeof(a)
	var tb := typeof(b)
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if ta in numeric and tb in numeric:
		return "" if absf(float(a) - float(b)) < 1e-9 else "%s: %s vs %s" % [path, str(a), str(b)]
	if ta != tb:
		return "%s: type %s (%s) vs %s (%s)" % [path, type_string(ta), str(a).left(60), type_string(tb), str(b).left(60)]
	if ta == TYPE_DICTIONARY:
		for k in a:
			if not b.has(k):
				return "%s.%s: missing on the right" % [path, k]
			var d := _diff(a[k], b[k], "%s.%s" % [path, k])
			if d != "":
				return d
		for k in b:
			if not a.has(k):
				return "%s.%s: missing on the left" % [path, k]
		return ""
	if ta == TYPE_ARRAY:
		if a.size() != b.size():
			return "%s: %d items vs %d" % [path, a.size(), b.size()]
		for i in a.size():
			var d := _diff(a[i], b[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	return "" if a == b else "%s: %s vs %s" % [path, str(a).left(80), str(b).left(80)]


func _view(session: Dictionary, def: Dictionary) -> Dictionary:
	var s: Dictionary = session["state"]
	var out := {"state": s, "card": null, "pending": null, "playable": [], "members": [], "routines": []}
	if s["status"] == "active":
		var card := ExpeditionEngine.current_event(s, def)
		var labels: Array = []
		var playable: Array = []
		for i in card["choices"].size():
			labels.append(card["choices"][i]["label"])
			var id := Coordinator.challenge_for(s, card, i)
			playable.append(id if id != "" else null)
		out["card"] = {"id": card["id"], "title": card["title"], "choices": labels}
		out["playable"] = playable
	if session["pending"] != null:
		out["pending"] = {"challengeId": session["pending"]["challengeId"], "attemptId": session["pending"]["attemptId"]}
	for m in Party.members(s):
		out["members"].append({"id": m["id"], "pose": m["pose"], "health": m["health"], "energy": m["energy"], "spirits": m["spirits"]})
	for r in Party.routines(s):
		out["routines"].append({"id": r["id"], "label": r["label"], "enabled": r["enabled"]})
	return out


func test_every_scripted_expedition_matches_the_typescript_engine() -> void:
	var def := Kili.def()
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES))
	check(fixtures.size() >= 6, "fixtures loaded")
	var steps_checked := 0
	for fx in fixtures:
		var session := Coordinator.create_session(ExpeditionEngine.create(int(fx["seed"]), def))
		var d := _diff(_view(session, def), fx["start"], fx["name"] + " start")
		if d != "":
			failures.append(d)
			continue
		for i in fx["steps"].size():
			var step: Dictionary = fx["steps"][i]
			var action: Dictionary = step["action"]
			match action["kind"]:
				"choose":
					session = Coordinator.choose(session, int(action["index"]), def)["session"]
				"climb":
					var o: Dictionary = action["outcome"].duplicate()
					o["attemptId"] = session["pending"]["attemptId"]
					var r := Coordinator.resolve(session, o, def)
					eq(r["status"], "applied", "%s step %d resolve" % [fx["name"], i])
					session = r["session"]
				"routine":
					session = Coordinator.play(session, Party.routine_effect(session["state"], action["id"]), def)
				"tend":
					session = Coordinator.play(session, Party.tend_effect(session["state"], action["id"]), def)
			d = _diff(_view(session, def), step["after"], "%s step %d (%s)" % [fx["name"], i, action.get("label", action["kind"])])
			if d != "":
				failures.append(d)
				break
			steps_checked += 1
	print("      %d steps match the TypeScript engine" % steps_checked)


func test_scores_match_the_typescript_formula() -> void:
	var def := Kili.def()
	var s := ExpeditionEngine.create(7, def)
	s["returnedSafely"] = true
	s["summitReached"] = true
	s["ledger"]["judgment"] = [{"label": "a", "delta": 20}]
	var sc := ExpeditionEngine.score(s)
	eq(sc["judgment"], 72, "judgment")
	check(sc["overall"] > 60, "a strong return scores well")
	s["returnedSafely"] = false
	check(ExpeditionEngine.score(s)["overall"] <= 36, "a summit without a return is capped")


func test_js_arithmetic() -> void:
	eq(ExpeditionEngine.js_round(-2.5), -2, "Math.round halves up")
	eq(ExpeditionEngine.js_round(2.5), 3, "Math.round halves up")
	eq(ExpeditionEngine.format_meters(5895), "5,895", "meters")
	eq(ExpeditionEngine.to_base36(7), "7", "base36")
	eq(ExpeditionEngine.to_base36(1295), "zz", "base36")
