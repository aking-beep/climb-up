extends Screen
## The crag: what to climb next (always one clear choice), today's daily
## route, the seven routes easiest first with their stars and best result,
## and the logbook. A locked route opens when the one before it is sent.

var rows: Dictionary = {}


func _ready() -> void:
	super._ready()
	Audio.play_music("crag")
	kicker("The crag · rock climbing")
	title("Lion Rock", 16)
	text("Short routes up one cliff. Clip the bolts, rest, and send it clean: first go with no falls is an onsight.", 8, MUTED)
	var focus: Button = null
	var next := Crag.next_route()
	if next != "":
		var r := Crag.route(next)
		var words := "Start here: %s" % r["name"] if next == "first-climb" and int(Crag.record(next)["attempts"]) == 0 else "Next up: %s · %s · %s" % [r["name"], r["grade"], r.get("skill", "")]
		focus = button(words, Crag.climb.bind(next), true)
	var d := Crag.daily_route()
	var dr := Crag.daily_record()
	var today := "new today"
	if int(dr["sends"]) > 0:
		today = "today: %s %d:%02d · beat your time" % [Crag.STYLES[dr["best"]][0], int(dr["bestSeconds"]) / 60, int(dr["bestSeconds"]) % 60]
	elif int(dr["attempts"]) > 0:
		today = "today: %d go%s%s · try again" % [int(dr["attempts"]), "" if int(dr["attempts"]) == 1 else "s",
			(", best %s m up" % Crag._m(int(dr.get("highRows", 0)) * Crag.ROW_M)) if int(dr.get("highRows", 0)) > 0 else ""]
	var daily := button("Daily route · %s · %s · %s" % [d["name"], d["grade"], today], Crag.climb.bind("daily"))
	if not Crag.unlocked("daily"):
		daily.text = "Daily route · opens after First Climb"
		daily.disabled = true
	rows["daily"] = daily
	text("Routes · %d of %d stars" % [Crag.total_stars(), Crag.ROUTES.size() * 3], 7, MUTED)
	for r in Crag.ROUTES:
		var b := _route_row(r)
		rows[r["id"]] = b
		if focus == null and not b.disabled:
			focus = b
	button("Logbook and achievements", func() -> void: Crag.go(Crag.LOGBOOK))
	button("Records and leaderboards", func() -> void: Records.open("crag", Crag.MENU))
	var back := button("Back", func() -> void: Crag.go(Crag.TITLE))
	(focus if focus else back).grab_focus()


## A route: grade, name, its skill, how you have done; stars on the right.
func _route_row(r: Dictionary) -> Button:
	var rec := Crag.record(r["id"])
	var open: bool = Crag.unlocked(r["id"])
	var status := "locked"
	if open:
		status = "new"
		if int(rec["sends"]) > 0:
			status = "%s %d:%02d" % [Crag.STYLES[rec["best"]][0], int(rec["bestSeconds"]) / 60, int(rec["bestSeconds"]) % 60]
		elif int(rec["attempts"]) > 0:
			status = "%d tr%s%s" % [int(rec["attempts"]), "y" if int(rec["attempts"]) == 1 else "ies",
				(", best %s m" % Crag._m(int(rec.get("highRows", 0)) * Crag.ROW_M)) if int(rec.get("highRows", 0)) > 0 else ""]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	card.add_child(row)
	var b := Button.new()
	b.text = "%s  %s · %s · %s" % [r["grade"], r["name"], r.get("skill", ""), status]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 20)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 9)
	b.clip_text = true
	if UiFont.display():
		b.add_theme_font_override("font", UiFont.display())
	UiStyle.paper_button(b)
	b.disabled = not open
	b.pressed.connect(Crag.climb.bind(r["id"]))
	row.add_child(b)
	var stars := StarRow.new()
	stars.count = Crag.stars(r["id"])
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stars)
	return b


func on_back() -> void:
	Crag.go(Crag.TITLE)
