extends CragBot
## Records and leaderboards, on this device: ranks and ties, new records
## only when they are new, first ascents and completions kept for good,
## the daily day's ranking, Expedition boards by difficulty with
## completion meaning summit AND descent, the passport, the offline queue
## (retries, duplicates, nothing marked verified without a server), a
## tampered file, persistence, and the screens saying plainly what is not
## connected.


func _fresh() -> void:
	Crag.navigate = false
	Crag.reset()
	Crag.reset_daily()
	Crag.clock_override = 1791936000
	Records.delete_all()
	Records.online = Online.new()
	Analytics.write_to_disk = false


func _done_all() -> void:
	Records.delete_all()
	Records.online = Online.new()
	Crag.reset()
	Crag.reset_daily()
	Crag.clock_override = -1


func _go(id: String, sent: bool, seconds: int, falls: int = 0, rows: int = 0, style: String = "") -> String:
	Crag.clock_override += 60
	return Records.crag_attempt(Crag.route(id) if id != "daily" else Crag.daily_route(), {"sent": sent, "seconds": seconds, "falls": falls,
		"style": style, "stats": {"high_rows": rows}, "shoes": "neutral"}, null)


func test_ranks_share_ties() -> void:
	eq(Records.rank_of(41, [41, 41, 50], true), 1, "a tie for first is first")
	eq(Records.rank_of(50, [41, 41, 50], true), 3, "and the next is third, not second")
	eq(Records.rank_of(9, [9, 12, 3], false), 2, "higher is better for heights")
	eq(Records.ordinal(1), "1st", "1st")
	eq(Records.ordinal(12), "12th", "12th")
	eq(Records.ordinal(23), "23rd", "23rd")
	var goes := [{"t": 2, "seconds": 41}, {"t": 1, "seconds": 41}, {"t": 3, "seconds": 39}]
	var sorted := Records.sorted_goes(goes, "seconds", true)
	eq(sorted.map(func(g: Dictionary) -> int: return int(g["t"])), [3, 1, 2], "ties listed earliest first")


func test_crag_records_are_only_new_when_they_are_new() -> void:
	_fresh()
	var first := _go("warm-up", false, 30, 1, 6)
	eq(first, "", "a first go short of the top sets nothing to beat")
	var higher := _go("warm-up", false, 32, 1, 9)
	check("high point 4.5 m" in higher, "higher than before: a new high point: " + higher)
	var lower := _go("warm-up", false, 20, 1, 5)
	check(not "New personal record" in lower, "lower: no record: " + lower)
	check("Height rank: 3rd of your 3" in lower, "and its rank among your goes: " + lower)
	var onsight := _go("warm-up", true, 60, 0, 30, "onsight")
	check("first ascent on this device" in onsight and "onsight" in onsight and "fastest clean ascent 1:00" in onsight, onsight)
	var fast_falls := _go("warm-up", true, 50, 2, 30, "falls")
	check("best time 0:50 (was 1:00)" in fast_falls and not "fastest clean" in fast_falls, "faster with falls: best time, not clean: " + fast_falls)
	check("Rank: 1st of your 2 sends" in fast_falls, fast_falls)
	var clean := _go("warm-up", true, 55, 0, 30, "redpoint")
	check("fastest clean ascent 0:55 (was 1:00)" in clean and "redpoint" in clean, clean)
	check("Rank: 2nd of your 3 sends" in clean, clean)
	var tie := _go("warm-up", true, 55, 0, 30, "redpoint")
	check(not "New personal record" in tie, "a tie is not a new record: " + tie)
	check("Rank: 2nd of your 4 sends" in tie, "and it shares the rank: " + tie)
	var r := Records.crag_route("warm-up")
	var fa := int(r["firstAscent"])
	_go("warm-up", true, 40, 0, 30, "redpoint")
	eq(int(Records.crag_route("warm-up")["firstAscent"]), fa, "the first ascent date never moves")
	_done_all()


func test_the_daily_day_is_ranked() -> void:
	_fresh()
	_go("daily", true, 70, 1)
	var better := _go("daily", true, 64, 0)
	check("today's best 1:04 (was 1:10)" in better and "Rank: 1st of your 2 sends today" in better, better)
	eq(Records.data["daily"][Crag.today()].size(), 2, "both goes kept for today")
	_done_all()


func test_records_persist_and_a_tampered_file_does_not_break_them() -> void:
	_fresh()
	_go("warm-up", true, 60, 0, 30, "onsight")
	Records.load_records()
	eq(int(Records.crag_route("warm-up")["bestSeconds"]), 60, "saved and loaded")
	# Hand-edited: a negative time, a string, a claim of being verified.
	var d: Dictionary = Records.data.duplicate(true)
	d["crag"]["warm-up"]["goes"].append({"t": 5, "sent": true, "seconds": -3, "falls": 0})
	d["crag"]["warm-up"]["goes"].append({"t": 6, "sent": true, "seconds": 5, "falls": "x", "verified": true})
	d["crag"]["warm-up"]["bestSeconds"] = "fast"
	d["crag"]["not-a-route"] = {"bestSeconds": 1}
	d["expedition"]["runs"].append({"score": 9999, "difficulty": "standard", "complete": "yes"})
	SaveGame.write(d, Records.PATH)
	Records.load_records()
	var goes: Array = Records.crag_route("warm-up")["goes"]
	eq(goes.size(), 2, "the impossible go is dropped")
	check(goes.all(func(g: Dictionary) -> bool: return g["verified"] == false), "nothing loaded from the file counts as verified")
	eq(int(Records.crag_route("warm-up")["bestSeconds"]), -1, "a non-number best is reset, not trusted")
	check(not Records.data["crag"].has("not-a-route"), "unknown routes are dropped")
	eq(int(Records.data["expedition"]["runs"][0]["score"]), 100, "an impossible score is clamped")
	check(Records.data["expedition"]["runs"][0]["complete"] == false, "and a string is not a completion")
	_done_all()


func test_the_queue_survives_offline_retries_and_duplicates() -> void:
	_fresh()
	_go("warm-up", false, 30, 1, 6)
	_go("warm-up", true, 60, 0, 30, "onsight")
	eq(Records.pending().size(), 2, "finished goes wait in the queue")
	var ids: Array = Records.pending().map(func(e: Dictionary) -> String: return e["id"])
	check(ids[0] != ids[1], "each with its own id")
	# Offline (no service): nothing sent, nothing verified.
	eq(await Records.sync(), 0, "not configured: nothing sent")
	eq(Records.pending().size(), 2, "still waiting")
	# A flaky network: the first call fails, the server sees each id once.
	var seen := {}
	var calls := [0]
	Records.online.transport = func(e: Dictionary) -> Dictionary:
		calls[0] += 1
		if calls[0] == 1:
			return {"ok": false, "retry": true}
		if seen.has(e["id"]):
			return {"ok": true, "serverTime": seen[e["id"]], "duplicate": true}
		seen[e["id"]] = 1791936000 + calls[0]
		return {"ok": true, "serverTime": seen[e["id"]]}
	eq(await Records.sync(), 0, "a network failure stops the round; nothing lost")
	eq(Records.pending().size(), 2, "both still waiting")
	eq(await Records.sync(), 2, "the next round sends both")
	eq(Records.pending().size(), 0, "none left")
	eq(await Records.sync(), 0, "and nothing is sent twice")
	eq(seen.size(), 2, "the server saw each go once")
	# A refused go stays refused and is never shown as verified.
	_go("warm-up", true, 1, 0, 30, "redpoint")
	Records.online.transport = func(_e: Dictionary) -> Dictionary: return {"ok": false, "reason": "faster than the route allows"}
	await Records.sync()
	var last: Dictionary = Records.data["queue"][-1]
	eq(last["status"], "rejected", "refused by the server")
	eq(last["reason"], "faster than the route allows", "with the reason")
	Records.load_records()
	eq(Records.data["queue"].size(), 3, "the queue's state is saved")
	_done_all()


func test_expedition_records_need_the_summit_and_the_way_down() -> void:
	_fresh()
	var s := TestSessions.at("summit-night")
	s["state"]["summitReached"] = true
	s["state"]["returnedSafely"] = false
	var lost := Records.expedition_finished(s)
	check(not lost["complete"], "the summit without coming down is not a completion")
	eq(int(Records.data["expedition"]["firstCompletion"]), 0, "and not a first completion")
	s["state"]["returnedSafely"] = true
	Crag.clock_override += 100
	var done := Records.expedition_finished(s)
	check(done["complete"] and done["firstCompletion"], "summit and down: the first completion")
	var first := int(Records.data["expedition"]["firstCompletion"])
	Crag.clock_override += 100
	var again := Records.expedition_finished(s)
	check(not again["firstCompletion"], "a second completion is not the first")
	eq(int(Records.data["expedition"]["firstCompletion"]), first, "the first completion date is kept")
	eq(done["score"], ExpeditionEngine.score(s["state"])["overall"], "the score is the game's own")
	var board := Records.expedition_board(done["difficulty"])
	check(board[0]["complete"] and not board[-1]["complete"], "completed runs rank above the rest")
	eq(Records.expedition_board("hardest").size(), 0, "each difficulty has its own board")
	eq(Records.expedition_board(done["difficulty"], true).size(), 0, "and assisted play its own")
	_done_all()


func test_the_passport_counts_places_and_continents() -> void:
	_fresh()
	var p := Records.passport()
	check(not p["places"]["kilimanjaro"]["done"] and not p["places"]["lion-rock"]["done"], "nothing done yet")
	check(not p["globalRanking"] and "more than one continent" in p["globalNote"], "no global passport ranking with one continent")
	for r in Crag.ROUTES:
		Crag.tie_in(r["id"])
		Crag.finish(r["id"], true, 0, 60)
		_go(r["id"], true, 60, 0, 30, "onsight")
	var s := TestSessions.at("summit-night")
	s["state"]["summitReached"] = true
	s["state"]["returnedSafely"] = true
	Records.expedition_finished(s)
	p = Records.passport()
	check(p["places"]["kilimanjaro"]["done"] and p["places"]["lion-rock"]["done"], "both places complete")
	eq(int(p["continents"]["africa"]["done"]), 2, "Africa: 2 of 2")
	check(not p["achievements"].is_empty(), "the combined crag and expedition achievement")
	_done_all()


func test_names_and_ages_for_an_online_profile() -> void:
	eq(Online.name_problem("Kibo_Fan 7"), "", "a fine name")
	check(Online.name_problem("ab") != "", "too short")
	check(Online.name_problem("x" + "y".repeat(20)) != "", "too long")
	check(Online.name_problem("_lead") != "", "must start with a letter or number")
	check(Online.name_problem("Climb-Up Official") != "", "reserved words")
	eq(Online.name_key("Kibo Fan"), Online.name_key("kibo_fan"), "names collide without case, spaces or _")
	check(not Online.age_rules(12)["publicName"] and not Online.age_rules(12)["globalBoards"], "under 13: private")
	check(Online.age_rules(13)["publicName"], "13 and over: a public name")
	check(not Online.new().configured(), "this build has no service: not configured")


func test_the_screens_say_what_is_not_connected() -> void:
	_fresh()
	_go("warm-up", true, 60, 0, 30, "onsight")
	for board in ["crag", "expedition", "passport"]:
		for scope in ["personal", "friends", "global"]:
			Records.board = board
			Records.scope = scope
			var vp := SubViewport.new()
			vp.size = Vector2i(480, 270)
			root.add_child(vp)
			var screen: Node = load(Records.SCREEN).instantiate()
			vp.add_child(screen)
			await physics_frames(3)
			var text := ""
			for n in screen.card.find_children("*", "Label", true, false):
				text += n.text + "\n"
			for n in screen.card.find_children("*", "Button", true, false):
				text += n.text + "\n"
			if scope != "personal":
				check("not connected" in text, "%s/%s says it is not connected" % [board, scope])
			check("not verified" in text, "%s/%s says records are on this device, not verified" % [board, scope])
			check(not "verified record" in text.to_lower() or "not verified" in text, "no claim of verification")
			if board == "crag" and scope == "personal":
				check("Warm-up Wall" in text and "clean 1:00" in text, "the crag records show: " + text.left(300))
				var share: Button = screen.card.find_child("Share-warm-up", true, false)
				share.pressed.emit()
				check("not verified" in screen.shared and "Fastest clean ascent 1:00" in screen.shared, "a shareable record card: " + screen.shared)
			vp.queue_free()
			await physics_frames(1)
	Records.board = "crag"
	Records.scope = "personal"
	_done_all()


func test_the_results_show_new_records_and_rank() -> void:
	_fresh()
	Crag.clock_override = -1
	Crag.tie_in("first-climb")
	Crag.finish("first-climb", true, 0, 60)
	Crag.climb("warm-up")
	for i in 2:
		await _load("warm-up", "aggressive")
		c.clock = 80.0 - i * 10.0
		level._skip_celebration = true
		level.finish(true)
		for k in 30:
			await physics_frames(1)
			if level.panel.open:
				break
		if i == 1:
			var body: String = level.panel.body_text()
			check("New personal record" in body and "fastest clean ascent 1:10 (was 1:20)" in body, "the results name the new record: " + body)
			check("Rank: 1st of your 2 sends (this device)" in body, "and the rank, honestly labelled: " + body)
			eq(Records.pending()[-1]["payload"]["events"][0][1], "tie_in", "the go's event log goes with it")
		await _done()
	_done_all()
