extends Screen
## Records and leaderboards: Crag, Expedition and the World Passport, each
## as Personal, Friends and Global. Personal is the player's own records on
## this device. Friends and Global need the online service, which is not
## running: they say so, and show nothing made up. Free for everyone.

## Two taps to delete, so a stray tap cannot.
var _delete_armed := false
## The text of the last record shared (for tests).
var shared := ""


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
		_not_connected()
	elif Records.board == "crag":
		_crag()
	elif Records.board == "expedition":
		_expedition()
	else:
		_passport()
	text("On this device only, not verified. Verified records need the online service.", 7, MUTED)
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
