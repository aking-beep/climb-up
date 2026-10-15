extends Screen
## Records and leaderboards: Crag, Expedition and the World Passport, each
## as Personal, Friends and Global. Personal is the player's own records on
## this device. Friends and Global come from the online service: in a build
## without one they say they are not connected and show nothing made up;
## with one, Global reads the server's boards (anyone may look) and Friends
## needs an account (the account screen). Free for everyone.

## Two taps to delete, so a stray tap cannot.
var _delete_armed := false
## The text of the last record shared (for tests).
var shared := ""
## The online board's rows go here once they arrive.
var board_box: VBoxContainer
## True once the online board has loaded (or failed), for tests.
var board_done := false
## The route the online crag board shows ("daily" for today's).
static var online_route := "warm-up"


func _ready() -> void:
	super._ready()
	kicker("Records · free for every player")
	title({"crag": "Crag records", "expedition": "Expedition records", "passport": "World Passport"}[Records.board], 14)
	_tabs([["crag", "Crag"], ["expedition", "Expedition"], ["passport", "Passport"]], Records.board, func(id: String) -> void:
		Records.board = id
		_reload())
	_tabs([["personal", "Personal"], ["friends", "Friends"], ["global", "Global"]], Records.scope, func(id: String) -> void:
		Records.scope = id
		_reload())
	if Records.scope != "personal":
		if not Records.online.available():
			_not_connected()
		else:
			_online()
	elif Records.board == "crag":
		_crag()
	elif Records.board == "expedition":
		_expedition()
	else:
		_passport()
	if Records.scope == "personal" or not Records.online.available():
		text("On this device only, not verified. Verified records need the online service.", 7, MUTED)
	else:
		text("Checked by the CLIMB UP service (server time decides who was first). Your Personal tab is this device's records, not verified.", 7, MUTED)
	var del := button("Delete my records on this device", _delete)
	del.name = "Delete"
	var back := button("Back", on_back)
	back.grab_focus()


func _reload() -> void:
	get_tree().reload_current_scene()


func _tabs(items: Array, current: String, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	card.add_child(row)
	for it in items:
		var b := Button.new()
		b.text = it[1]
		b.toggle_mode = true
		b.button_pressed = it[0] == current
		b.add_theme_font_size_override("font_size", 8)
		if UiFont.display():
			b.add_theme_font_override("font", UiFont.display())
		UiStyle.paper_button(b)
		b.custom_minimum_size = Vector2(0, 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if it[0] == current:
			var on := StyleBoxFlat.new()
			on.bg_color = Color("#1f3d34")
			on.set_corner_radius_all(2)
			for key in ["normal", "hover", "focus", "pressed"]:
				b.add_theme_stylebox_override(key, on)
			for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
				b.add_theme_color_override(key, Color("#eef4ee"))
		b.pressed.connect(on_pick.bind(it[0]))
		row.add_child(b)


func _not_connected() -> void:
	var what := "Friends boards" if Records.scope == "friends" else "Global rankings"
	text("%s: not connected." % what, 9)
	text("%s need the CLIMB UP online service and an account, which are not running yet. Nothing is shown here until they are: no made-up names or numbers." % what, 8, MUTED)
	var waiting := Records.pending().size()
	if waiting > 0:
		text("%d finished go%s saved on this device, ready to send for checking once the service exists." % [waiting, "" if waiting == 1 else "es"], 8, MUTED)


# --- Online boards --------------------------------------------------------

func _online() -> void:
	var o := Records.online
	if o.under_age:
		text("Online boards are for players %d and over. Your records stay on this device." % Online.MIN_ACCOUNT_AGE, 8, MUTED)
		board_done = true
		return
	if Records.scope == "friends" and not o.signed_in():
		text("Friends boards need a free account: add friends by their code and compare climbs.", 8)
		button("Sign up or restore an account", _account, true).name = "Account"
		board_done = true
		return
	if Records.board == "crag":
		var pick := OptionButton.new()
		pick.name = "RoutePick"
		pick.add_theme_font_size_override("font_size", 8)
		var ids: Array = Crag.ROUTES.map(func(r: Dictionary) -> String: return r["id"])
		ids.append("daily")
		for id in ids:
			var r: Dictionary = Crag.route(id) if id != "daily" else {"grade": "", "name": "Daily route, today"}
			pick.add_item(("%s %s" % [r["grade"], r["name"]]).strip_edges())
		if not online_route in ids:
			online_route = "warm-up"
		pick.select(ids.find(online_route))
		pick.item_selected.connect(func(i: int) -> void:
			online_route = ids[i]
			_reload())
		card.add_child(pick)
	board_box = VBoxContainer.new()
	board_box.add_theme_constant_override("separation", 2)
	card.add_child(board_box)
	_line("Loading...", 8, MUTED)
	_load_board()
	if o.signed_in():
		button("My account and friends", _account).name = "Account"
	else:
		button("Sign up to appear on the boards", _account, true).name = "Account"


func _load_board() -> void:
	var o := Records.online
	var scope := Records.scope
	var sections: Array = []
	if Records.board == "crag":
		var kind := "daily" if online_route == "daily" else "crag"
		var id := Crag.today() if online_route == "daily" else online_route
		sections.append(["Fastest sends", await o.board(kind, id, scope, "board=time")])
		sections.append(["Fastest clean (no falls)", await o.board(kind, id, scope, "board=clean")])
		var f := await o.firsts()
		if f["ok"]:
			var scope_key := "crag:" + ("daily:" + id if kind == "daily" else id)
			for e in f["firsts"]:
				if e["scope"] == scope_key:
					sections.push_front(["First verified ascent: %s, %s" % [e["display"], _date(int(e["received"]))], {"ok": true, "entries": [], "note": true}])
	elif Records.board == "expedition":
		for d in ["standard", "hard", "hardest"]:
			sections.append([Records.DIFFICULTY_NAMES[d], await o.board("expedition", d, scope, "assisted=0")])
	else:
		sections.append(["", {"ok": true, "entries": [], "passport": true}])
	if not is_inside_tree() or board_box == null:
		return
	for c in board_box.get_children():
		c.queue_free()
	for sec in sections:
		var res: Dictionary = sec[1]
		if res.get("passport", false):
			_line(Records.passport()["globalNote"] if Records.passport()["globalNote"] != "" else "Passport rankings start when there are places on more continents.", 8, MUTED)
			continue
		_line(sec[0], 7 if not res.get("note", false) else 8, MUTED if not res.get("note", false) else INK)
		if res.get("note", false):
			continue
		if not res["ok"]:
			_line(res["reason"], 8, MUTED)
			continue
		if res["entries"].is_empty():
			_line("Nobody yet." if Records.scope == "global" else "Nobody yet: add friends on your account.", 8, MUTED)
		for e in res["entries"].slice(0, 10):
			_entry(e)
	board_done = true


func _entry(e: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	board_box.add_child(row)
	var what := ""
	if e.has("seconds"):
		what = Records._clock(int(e["seconds"]))
	else:
		what = "%d points%s" % [int(e["points"]), " · summit and down" if e.get("complete", false) else ""]
	var me := String(e["player"]) == Records.online.display_name and Records.online.display_name != ""
	var l := Label.new()
	l.text = "%s  %s  %s%s" % [Records.ordinal(int(e["rank"])), e["player"], what, "  (you)" if me else ""]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", INK if not me else Color("#1f3d34"))
	if UiFont.body():
		l.add_theme_font_override("font", UiFont.body())
	row.add_child(l)
	if not me and Records.online.signed_in() and not String(e["player"]) in ["a climber", "a deleted account"]:
		var b := Button.new()
		b.text = "Report"
		b.add_theme_font_size_override("font_size", 7)
		UiStyle.paper_button(b)
		b.pressed.connect(func() -> void:
			b.disabled = true
			var why := await Records.online.report(String(e["player"]))
			if is_instance_valid(b):
				b.text = "Reported" if why == "" else "Try later")
		row.add_child(b)


func _line(value: String, size: int, color: Color) -> void:
	var l := Label.new()
	l.text = value
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(290, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if UiFont.body():
		l.add_theme_font_override("font", UiFont.body())
	board_box.add_child(l)


func _account() -> void:
	Transition.go(get_tree(), "res://modes/records/account_screen.tscn")


func _crag() -> void:
	var any := false
	for r in Crag.ROUTES:
		var rec := Records.crag_route(r["id"])
		var bits: Array = []
		if int(rec["bestSeconds"]) > 0:
			bits.append("best %s" % Records._clock(int(rec["bestSeconds"])))
		if int(rec["bestCleanSeconds"]) > 0:
			bits.append("clean %s" % Records._clock(int(rec["bestCleanSeconds"])))
		var high := maxi(int(rec["highRows"]), int(Crag.record(r["id"]).get("highRows", 0)))
		if int(rec["firstAscent"]) == 0 and high > 0:
			bits.append("high point %s m" % Crag._m(high * Crag.ROW_M))
		for s in ["onsight", "flash", "redpoint"]:
			if int(rec[s]) > 0:
				bits.append("%s %s" % [Crag.STYLES[s][0], _date(int(rec[s]))])
		if int(rec["firstAscent"]) > 0:
			bits.append("first ascent %s" % _date(int(rec["firstAscent"])))
		if bits.is_empty():
			continue
		any = true
		_row("%s %s" % [r["grade"], r["name"]], " · ".join(bits), r["id"])
	if not any:
		text("No records yet. Climb a route: your best time, fastest clean ascent, high point and styles show here.", 8, MUTED)
	var today: Array = Records.data["daily"].get(Crag.today(), [])
	if not today.is_empty():
		text("Daily route, today: your goes, best first", 7, MUTED)
		var sends := Records.sorted_goes(today.filter(func(g: Dictionary) -> bool: return g["sent"]), "seconds", true)
		var times: Array = sends.map(func(g: Dictionary) -> int: return int(g["seconds"]))
		for g in sends.slice(0, 5):
			text("%s  %s%s" % [Records.ordinal(Records.rank_of(g["seconds"], times, true)), Records._clock(int(g["seconds"])), " · clean" if int(g["falls"]) == 0 else " · %d falls" % int(g["falls"])], 8)
		if sends.is_empty():
			text("Not topped yet today: %d go%s." % [today.size(), "" if today.size() == 1 else "es"], 8)


func _expedition() -> void:
	var first := int(Records.data["expedition"]["firstCompletion"])
	text("First completion (summit and back down): %s" % (_date(first) if first > 0 else "not yet"), 8)
	var shown := false
	for d in ["standard", "hard", "hardest"]:
		var board := Records.expedition_board(d)
		if board.is_empty():
			continue
		shown = true
		text(Records.DIFFICULTY_NAMES[d], 7, MUTED)
		var points: Array = board.map(func(r: Dictionary) -> int: return int(r["points"]))
		for r in board.slice(0, 5):
			var how := "summit and down" if r["complete"] else ("down safely, no summit" if r["returned"] else "did not come down")
			text("%s  %d points (score %d) · %s · %d of 4 home · %d days · %s" % [Records.ordinal(Records.rank_of(r["points"], points, false)), int(r["points"]), int(r["score"]), how,
				int(r["teamHome"]), int(r.get("days", 0)), _date(int(r["t"]))], 8)
	if not shown:
		text("No finished expeditions yet. The score is the game's own: completing means the summit AND bringing everyone down.", 8, MUTED)
	else:
		var b := button("Share my best expedition", func() -> void: _share("expedition"))
		b.name = "Share-expedition"
	text("Leader points: the score, +10 when all four summit and come home, -8 for each teammate who did not. With the whole team home, being quick (+2 a spare permit day, up to 10) and thrifty (+1 for every 10 supplies left, up to 10) counts too.", 7, MUTED)
	text("Assisted play: kept as its own board. The game has no assist options yet, so it is empty.", 7, MUTED)


func _passport() -> void:
	var p := Records.passport()
	for id in Records.PLACES:
		var place: Dictionary = Records.PLACES[id]
		var st: Dictionary = p["places"][id]
		text("%s · %s · %s%s" % [place["name"], Records.CONTINENTS[place["continent"]], st["progress"],
			(" · first completed %s" % _date(int(st["first"]))) if int(st["first"]) > 0 else ""], 8)
	for c in Records.CONTINENTS:
		if p["continents"].has(c):
			var e: Dictionary = p["continents"][c]
			text("%s: %d of %d places complete" % [Records.CONTINENTS[c], int(e["done"]), int(e["places"])], 8, INK)
	var others: int = Records.CONTINENTS.size() - p["continents"].size()
	text("%d continents have no places yet." % others, 7, MUTED)
	for a in p["achievements"]:
		text("Achievement: %s" % a, 8)
	if p["globalNote"] != "":
		text(p["globalNote"], 7, MUTED)


func _row(label: String, detail: String, id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	card.add_child(row)
	var l := Label.new()
	l.text = "%s: %s" % [label, detail]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(200, 0)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", INK)
	if UiFont.body():
		l.add_theme_font_override("font", UiFont.body())
	row.add_child(l)
	var b := Button.new()
	b.name = "Share-" + id
	b.text = "Share"
	b.add_theme_font_size_override("font_size", 8)
	UiStyle.paper_button(b)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: _share(id))
	row.add_child(b)


func _share(id: String) -> void:
	shared = Records.share_text(id)
	if shared != "":
		DisplayServer.clipboard_set(shared)


func _delete() -> void:
	if not _delete_armed:
		_delete_armed = true
		var del := card.get_node_or_null("Delete") as Button
		if del:
			del.text = "Tap again to delete every record on this device"
		return
	Records.delete_all()
	_reload()


static func _date(unix: int) -> String:
	var d := Time.get_date_dict_from_unix_time(unix)
	return "%d %s %d" % [d["day"], ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][int(d["month"]) - 1], d["year"]]


func on_back() -> void:
	if Crag.navigate:
		Transition.go(get_tree(), Records.back_to)
