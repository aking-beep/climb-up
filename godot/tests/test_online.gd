extends CragBot
## The online records flow, as players meet it.
##
## Always: the queue and the screens when the service cannot be reached,
## the age gate, consent before anything is sent.
## With RECORDS_SERVER set (a running server/records_service): separate
## accounts climbing for real, first verified ascents by the server's
## clock, the Daily Crag and Expedition boards, friends, the screens
## reading the boards, restoring an account from its recovery code,
## reports and deleting an account. CI runs it against a fresh server.

const DOWN := "http://127.0.0.1:9"


func _fresh() -> void:
	Crag.navigate = false
	Crag.reset()
	Crag.reset_daily()
	Crag.clock_override = -1
	Records.delete_all()
	SaveGame.erase(Online.CONFIG)
	Records.online = _client("")
	Analytics.write_to_disk = false


func _client(endpoint: String) -> Online:
	var o := Online.new()
	o.host = Records
	o.endpoint = endpoint
	return o


func _done_all() -> void:
	await _settle()
	Records.delete_all()
	SaveGame.erase(Online.CONFIG)
	Records.online = _client("")
	Crag.reset()
	Crag.reset_daily()
	Crag.clock_override = -1
	Records.board = "crag"
	Records.scope = "personal"


## Waits for a sync round started on its own (after a finished go).
func _settle() -> void:
	for i in 600:
		if not Records.syncing:
			return
		await physics_frames(1)


func _accepted() -> int:
	return Records.data["queue"].filter(func(e: Dictionary) -> bool: return e["status"] == "accepted").size()


func _screen(scene: String) -> Node:
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	root.add_child(vp)
	var screen: Node = load(scene).instantiate()
	vp.add_child(screen)
	await physics_frames(3)
	return screen


## Waits (in real time: frames run fast headless) for the online board.
func _board_loaded(screen: Node) -> void:
	var until := Time.get_ticks_msec() + 15000
	while not screen.board_done and Time.get_ticks_msec() < until:
		await physics_frames(1)


func _text(screen: Node) -> String:
	var t := ""
	for n in screen.card.find_children("*", "", true, false):
		if n is Label or n is Button:
			t += n.text + "\n"
	return t


func test_offline_the_queue_waits_and_the_boards_say_why() -> void:
	_fresh()
	var o := _client(DOWN)
	o.token = "a-token-for-a-server-that-is-down"
	Records.online = o
	Records.crag_attempt(Crag.route("warm-up"), {"sent": true, "seconds": 60, "falls": 0, "stats": {"high_rows": 30}, "style": "onsight"}, null)
	await _settle()
	eq(await Records.sync(), 0, "no server: nothing accepted")
	eq(Records.pending().size(), 1, "the go still waits, nothing lost")
	eq(int(Records.crag_route("warm-up")["bestSeconds"]), 60, "and the personal record is kept")
	Records.board = "crag"
	Records.scope = "global"
	var screen := await _screen(Records.SCREEN)
	await _board_loaded(screen)
	check(screen.board_done, "the board gives up rather than hanging")
	check("Could not reach the CLIMB UP service" in _text(screen), "and says why: " + _text(screen).left(400))
	screen.get_parent().queue_free()
	await _done_all()


func test_sign_up_asks_age_and_consent_first() -> void:
	_fresh()
	Records.online = _client(DOWN)
	var screen := await _screen("res://modes/records/account_screen.tscn")
	check(screen.age_field != null and screen.consent != null, "the form asks for an age and consent")
	check("No email" in _text(screen), "and says what is kept")
	screen.age_field.text = "30"
	screen._create()
	check("agree to the privacy policy" in screen._status.text, "nothing is sent without consent: " + screen._status.text)
	screen.age_field.text = ""
	screen.consent.button_pressed = true
	screen._create()
	check("age" in screen._status.text, "an age is needed")
	screen.get_parent().queue_free()
	await physics_frames(2)
	# Under 13: no account, nothing sent, and the device does not ask again.
	var why := await Records.online.register("", 11, "")
	check("13 and over" in why, "under 13: records stay on the device: " + why)
	check(Records.online.under_age and not Records.online.signed_in(), "no account was made")
	check(_client("").under_age, "and the answer is remembered on the device")
	Records.board = "crag"
	Records.scope = "global"
	screen = await _screen(Records.SCREEN)
	check("for players 13 and over" in _text(screen), "the online boards say so")
	screen.get_parent().queue_free()
	check(Online.endpoint_ok("https://records.example.com") and not Online.endpoint_ok("http://records.example.com"), "only https leaves this machine")
	await _done_all()


## A send of `id`. `pause` frames standing at the foot first: the bot climbs
## the same way every time, and the server takes a climb's log only once
## (two people never log the same hundredths), so each account's climb
## starts a little later.
func _climb(id: String, pause := 0) -> void:
	if id == "daily":
		Crag.current = "daily"
	else:
		Crag.climb(id)
	await _load(id, "neutral")
	await physics_frames(pause)
	check(await lead(), "a real send of %s" % id)
	level._skip_celebration = true
	await physics_frames(5)
	await _done()


func _first(o: Online, scope: String) -> String:
	var f := await o.firsts()
	for e in f.get("firsts", []):
		if e["scope"] == scope:
			return String(e["display"])
	return ""


func _names(res: Dictionary) -> Array:
	return res.get("entries", []).map(func(e: Dictionary) -> String: return e["player"])


func test_separate_accounts_on_the_records_server() -> void:
	var server := OS.get_environment("RECORDS_SERVER")
	if server == "":
		print("      skipped: RECORDS_SERVER not set (no service to test against)")
		return
	_fresh()
	var tag := str(randi() % 100000)
	# Each account (and each run, for a server kept between runs) climbs
	# from its own start: see _climb.
	var start := randi() % 40
	var ann_name := "Ann " + tag
	var bea_name := "Bea " + tag
	var cyd_name := "Cyd " + tag
	Crag.tie_in("first-climb")
	Crag.finish("first-climb", true, 0, 60)
	# Ann climbs first: the Warm-up Wall, today's daily route, an expedition.
	var ann := _client("")
	Records.online = ann
	eq(await ann.register(server, 30, ann_name), "", "Ann makes an account")
	var first_before := await _first(ann, "crag:warm-up")
	await _climb("warm-up", start)
	await _climb("daily", start)
	var s := TestSessions.at("summit-night")
	s["state"]["summitReached"] = true
	s["state"]["highestAltitude"] = 5895
	s["state"]["returnedSafely"] = true
	var run := Records.expedition_finished(s)
	await _settle()
	await Records.sync()
	await _settle()
	eq(_accepted(), 3, "the server accepted Ann's three: %s" % [Records.data["queue"].map(func(e: Dictionary) -> String: return e["status"] + " " + String(e.get("reason", "")))])
	if first_before == "":
		eq(await _first(ann, "crag:warm-up"), ann_name, "a fresh server: Ann's is the first verified ascent")
	# Bea and Cyd on their own devices.
	Records.delete_all()
	var bea := _client("")
	Records.online = bea
	eq(await bea.register(server, 30, bea_name), "", "Bea makes an account")
	await _climb("warm-up", start + 41)
	await _climb("daily", start + 41)
	await _settle()
	await Records.sync()
	await _settle()
	eq(_accepted(), 2, "the server accepted Bea's two: %s" % [Records.data["queue"].map(func(e: Dictionary) -> String: return e["status"] + " " + String(e.get("reason", "")))])
	check(await _first(bea, "crag:warm-up") != bea_name, "Bea came later: the first is not hers")
	Records.delete_all()
	var cyd := _client("")
	Records.online = cyd
	eq(await cyd.register(server, 16, cyd_name), "", "Cyd (16) makes an account")
	await _climb("warm-up", start + 83)
	await _settle()
	await Records.sync()
	await _settle()
	eq(_accepted(), 1, "the server accepted Cyd's: %s" % [Records.data["queue"].map(func(e: Dictionary) -> String: return e["status"] + " " + String(e.get("reason", "")))])
	# Boards.
	var global := _names(await ann.board("crag", "warm-up", "global", "board=time"))
	check(ann_name in global and bea_name in global, "the global board has Ann and Bea: %s" % [global])
	check(not cyd_name in global, "a 16-year-old is friends-only by default, not global")
	var daily := _names(await ann.board("daily", Crag.today(), "global", "board=time"))
	check(ann_name in daily and bea_name in daily, "today's Daily Crag board: %s" % [daily])
	var exp := _names(await ann.board("expedition", run["difficulty"], "global", "assisted=0"))
	check(ann_name in exp, "the Expedition board has Ann's run: %s" % [exp])
	eq(await ann.add_friend(bea.friend_code), "", "Ann adds Bea by her friend code")
	eq(await ann.add_friend(cyd.friend_code), "", "and Cyd")
	check((await ann.add_friend("NOPE0000")) != "", "a wrong code is refused")
	var friends := _names(await ann.board("crag", "warm-up", "friends", "board=time"))
	check(ann_name in friends and bea_name in friends and cyd_name in friends, "Ann's friends board: %s" % [friends])
	var bea_friends := _names(await bea.board("crag", "warm-up", "friends", "board=time"))
	check(not ann_name in bea_friends, "Bea has not added Ann: %s" % [bea_friends])
	# The records screen reads the boards.
	Records.online = ann
	Records.board = "crag"
	Records.scope = "friends"
	var screen := await _screen(Records.SCREEN)
	await _board_loaded(screen)
	var t := _text(screen)
	check(ann_name + "  " in t and "(you)" in t and bea_name in t, "the Friends tab lists them: " + t.left(500))
	check("Report" in t, "with a report button for other names")
	screen.get_parent().queue_free()
	Records.board = "expedition"
	Records.scope = "global"
	screen = await _screen(Records.SCREEN)
	await _board_loaded(screen)
	check(ann_name in _text(screen) and "points" in _text(screen), "the Expedition tab too")
	screen.get_parent().queue_free()
	screen = await _screen("res://modes/records/account_screen.tscn")
	check(ann.friend_code in _text(screen) and "recovery code" in _text(screen), "the account screen shows the friend code and recovery")
	screen.get_parent().queue_free()
	# Another device restores Ann's account from her recovery code.
	var phone := _client("")
	eq(await phone.restore(server, ann.token), "", "restored from the recovery code")
	eq(phone.display_name, ann_name, "as Ann")
	eq(phone.friend_code, ann.friend_code, "with her friend code")
	check((await _client("").restore(server, "wrong-code")) != "", "a wrong code is refused")
	# A code someone else saw: a new one retires it.
	var old_code := ann.token
	eq(await ann.rotate(), "", "Ann gets a new recovery code")
	check(ann.token != old_code, "a different code")
	check((await _client("").restore(server, old_code)) != "", "the old code no longer restores the account")
	eq(await _client("").restore(server, ann.token), "", "the new one does")
	eq(await bea.report(ann_name), "", "Bea reports a name")
	# Deleting an account takes it off the boards.
	eq(await cyd.delete_account(), "", "Cyd deletes the account")
	check(not cyd.signed_in(), "and is signed out")
	friends = _names(await ann.board("crag", "warm-up", "friends", "board=time"))
	check(not cyd_name in friends, "Cyd is gone from Ann's board")
	eq(await bea.delete_account(), "", "Bea too")
	eq(await ann.delete_account(), "", "and Ann")
	await _done_all()
