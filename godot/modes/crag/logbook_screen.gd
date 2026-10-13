extends Screen
## The logbook: every route's record (goes, falls, best style and time,
## stars, its challenge), today's daily route and streak, and the
## achievements, held or still to earn.


func _ready() -> void:
	super._ready()
	kicker("The crag · logbook")
	title("Your logbook", 14)
	var goes := 0
	var falls := 0
	var sends := 0
	for r in Crag.ROUTES:
		var rec := Crag.record(r["id"])
		goes += int(rec["attempts"])
		falls += int(rec["falls"])
		sends += int(rec["sends"])
	text("%d goes · %d sends · %d falls · %d of %d stars · %d of %d achievements" % [goes, sends, falls, Crag.total_stars(), Crag.ROUTES.size() * 3,
		Crag.achievements.size(), Logbook.ACHIEVEMENTS.size()], 8, MUTED)
	for r in Crag.ROUTES:
		var rec := Crag.record(r["id"])
		var line := "%s %s · " % [r["grade"], r["name"]]
		if not Crag.unlocked(r["id"]):
			line += "locked"
		elif int(rec["attempts"]) == 0:
			line += "not tried"
		else:
			line += "%d go%s, %d fall%s" % [int(rec["attempts"]), "" if int(rec["attempts"]) == 1 else "s", int(rec["falls"]), "" if int(rec["falls"]) == 1 else "s"]
			if int(rec["sends"]) > 0:
				line += " · best %s in %d:%02d" % [Crag.STYLES[rec["best"]][0], int(rec["bestSeconds"]) / 60, int(rec["bestSeconds"]) % 60]
			elif int(rec["highpoint"]) > 0:
				line += " · high point bolt %d" % int(rec["highpoint"])
		var ch: Array = Logbook.CHALLENGES.get(r["id"], ["", ""])
		var row := HBoxContainer.new()
		card.add_child(row)
		var l := Label.new()
		l.text = "%s\n   Challenge, %s: %s" % [line, ch[0], "done" if rec.get("challenge", false) else ch[1]]
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", INK)
		if UiFont.body():
			l.add_theme_font_override("font", UiFont.body())
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(250, 0)
		row.add_child(l)
		var stars := StarRow.new()
		stars.count = Crag.stars(r["id"])
		row.add_child(stars)
	var dr := Crag.daily_record()
	text("Daily route · %s: %s · streak %d day%s" % [Crag.today(),
		("%s in %d:%02d" % [Crag.STYLES[dr["best"]][0], int(dr["bestSeconds"]) / 60, int(dr["bestSeconds"]) % 60]) if int(dr["sends"]) > 0 else "%d go%s" % [int(dr["attempts"]), "" if int(dr["attempts"]) == 1 else "s"],
		int(Crag.daily.get("streak", 0)), "" if int(Crag.daily.get("streak", 0)) == 1 else "s"], 8)
	kicker("Achievements")
	for a in Logbook.ACHIEVEMENTS:
		var held := Crag.achievements.has(a)
		var words: Array = Logbook.ACHIEVEMENTS[a]
		text("%s %s: %s%s" % ["✓" if held else "·", words[0], words[1], (" (%s)" % Crag.achievements[a]) if held else ""], 8, INK if held else MUTED)
	button("Back to the routes", func() -> void: Crag.go(Crag.MENU), true).grab_focus()


func on_back() -> void:
	Crag.go(Crag.MENU)
