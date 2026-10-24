extends JournalPage
## Lion Rock (CLIMB UP 2.0): the routes as a guidebook. Left, every route
## easiest first (grade, stars, how you did, or what opens it) and the
## daily route. Right, the one you picked: its topo, how it is bolted and
## how far a fall can go, its crux, your shoes, and Climb. The crag's rules
## (scores, styles, unlocks) are the crag's own; this is a new page on them.

var list: VBoxContainer
var detail: VBoxContainer
var topo: RouteTopo
var picked := ""
var rows: Dictionary = {}
var climb_button: Button


func build() -> void:
	set_title("Lion Rock")
	back_to = Hub.PATH
	Audio.play_music("crag")
	var row := UiKit.hbox(8)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(row)
	var left := UiKit.vbox(3)
	left.custom_minimum_size = Vector2(170, 0)
	row.add_child(left)
	left.add_child(UiKit.label("%d of %d stars · easiest first" % [Crag.total_stars(), Crag.ROUTES.size() * 3], UiTokens.TEXT_S, UiTokens.INK_MUTED))
	list = UiKit.vbox(2)
	left.add_child(JournalPage.scroller(list))
	var links := UiKit.hbox(2)
	left.add_child(links)
	links.add_child(UiKit.button("Logbook", func() -> void: _go(Crag.LOGBOOK), "paper", UiTokens.TEXT_S))
	links.add_child(UiKit.button("School", func() -> void: _go(Hub.SCHOOL), "paper", UiTokens.TEXT_S))
	links.add_child(UiKit.button("Records", func() -> void: Records.open("crag", Crag.MENU), "paper", UiTokens.TEXT_S))
	var right := UiKit.hbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	topo = RouteTopo.new()
	topo.custom_minimum_size = Vector2(70, 0)
	topo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(topo)
	detail = UiKit.vbox(3)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(JournalPage.scroller(detail))
	_daily_row()
	for r in Crag.ROUTES:
		_route_row(r)
	var start := Crag.next_route()
	pick(start if start != "" else "first-climb")


func _route_row(r: Dictionary) -> void:
	var id: String = r["id"]
	var open := Crag.unlocked(id)
	var rec := Crag.record(id)
	var b := UiKit.button("", pick.bind(id), "paper", UiTokens.TEXT)
	b.name = "Row_" + id
	b.custom_minimum_size = Vector2(0, 24)
	var h := UiKit.hbox(4)
	h.position = Vector2(5, 3)
	b.add_child(h)
	h.add_child(UiKit.chip(String(r["grade"]), UiTokens.SPRUCE if open else UiTokens.PAPER_EDGE, UiTokens.SPRUCE_INK if open else UiTokens.INK_MUTED, 6))
	var name := UiKit.label(String(r["name"]), UiTokens.TEXT, UiTokens.INK if open else UiTokens.INK_MUTED, true)
	name.custom_minimum_size = Vector2(84, 0)
	h.add_child(name)
	if open:
		h.add_child(UiKit.stars(Crag.stars(id)))
	else:
		h.add_child(UiIcon.make("lock", UiTokens.INK_MUTED, 9.0))
	list.add_child(b)
	rows[id] = b


func _daily_row() -> void:
	var d := Crag.daily_route()
	var b := UiKit.button("", pick.bind("daily"), "paper", UiTokens.TEXT)
	b.name = "Row_daily"
	b.custom_minimum_size = Vector2(0, 24)
	var h := UiKit.hbox(4)
	h.position = Vector2(5, 3)
	b.add_child(h)
	h.add_child(UiKit.chip("TODAY", UiTokens.EMBER, UiTokens.CHALK, 6))
	h.add_child(UiKit.label("%s · %s" % [d["name"], d["grade"]], UiTokens.TEXT, UiTokens.INK, true))
	list.add_child(b)
	rows["daily"] = b


## Shows a route on the right.
func pick(id: String) -> void:
	picked = id
	for k in rows:
		UiKit.style_button(rows[k], "primary" if k == id else "paper")
		for l in (rows[k] as Node).find_children("*", "Label", true, false):
			if (l as Label).get_parent() is HBoxContainer:
				(l as Label).add_theme_color_override("font_color", UiTokens.SPRUCE_INK if k == id else (UiTokens.INK if k == "daily" or Crag.unlocked(k) else UiTokens.INK_MUTED))
	topo.show_route(id)
	for c in detail.get_children():
		c.queue_free()
	var open := Crag.unlocked(id)
	var r: Dictionary = Crag.daily_route() if id == "daily" else Crag.route(id)
	detail.add_child(UiKit.label(String(r["name"]), UiTokens.TITLE, UiTokens.INK, true))
	detail.add_child(UiKit.label("%s · %s%s" % [r["grade"], r.get("level", "today's route"), (" · " + String(r["skill"])) if r.has("skill") else ""], UiTokens.TEXT, UiTokens.INK_MUTED))
	if r.has("text"):
		detail.add_child(UiKit.label(String(r["text"]), UiTokens.TEXT_S, UiTokens.INK_SOFT, false, 190.0))
	detail.add_child(UiKit.label(Crag.protection_words(id), UiTokens.TEXT_S, UiTokens.INK, false, 190.0))
	var ex := UiKit.label(Crag.exposure_words(id), UiTokens.TEXT_S, UiTokens.BAD if Crag.facts(id)["exposure"] == "high" else UiTokens.INK, false, 190.0)
	detail.add_child(ex)
	if r.has("crux"):
		detail.add_child(UiKit.label("Crux: " + String(r["crux"]), UiTokens.TEXT_S, UiTokens.INK_MUTED, false, 190.0))
	var rec := Crag.daily_record() if id == "daily" else Crag.record(id)
	if int(rec["sends"]) > 0:
		detail.add_child(UiKit.label("Best: %s, %d:%02d" % [Crag.STYLES[rec["best"]][0], int(rec["bestSeconds"]) / 60, int(rec["bestSeconds"]) % 60], UiTokens.TEXT_S, UiTokens.SPRUCE))
	elif int(rec["attempts"]) > 0:
		detail.add_child(UiKit.label("%d go%s so far" % [int(rec["attempts"]), "" if int(rec["attempts"]) == 1 else "es"], UiTokens.TEXT_S, UiTokens.INK_MUTED))
	if open and id != "daily" and Logbook.CHALLENGES.has(id):
		var ch: Array = Logbook.CHALLENGES[id]
		detail.add_child(UiKit.label("Third star: %s. %s" % [ch[0], ch[1]], UiTokens.TEXT_S, UiTokens.INK_MUTED, false, 190.0))
	# Shoes: the crag's own choice (Crag.SHOES), kept between routes.
	var shoes := UiKit.hbox(2)
	detail.add_child(shoes)
	for s in Crag.SHOES:
		var sb := UiKit.button(String(Crag.SHOES[s]["name"]).replace(" shoes", ""), _shoes.bind(s), "primary" if Crag.shoes == s else "paper", UiTokens.TEXT_S)
		sb.name = "Shoes_" + s
		sb.tooltip_text = String(Crag.SHOES[s]["text"])
		shoes.add_child(sb)
	detail.add_child(UiKit.label(String(Crag.SHOES[Crag.shoes]["text"]), UiTokens.TEXT_S, UiTokens.INK_MUTED, false, 190.0))
	climb_button = UiKit.button("Climb" if open else "Locked: send the route before it", _climb, "primary", UiTokens.TEXT_L)
	climb_button.name = "Climb"
	climb_button.disabled = not (open or id == "daily") or (id == "daily" and not Crag.unlocked("daily"))
	if id == "daily" and not Crag.unlocked("daily"):
		climb_button.text = "Opens after First Climb"
	detail.add_child(climb_button)


func _shoes(s: String) -> void:
	Crag.shoes = s
	Crag.save_progress()
	pick(picked)


func _climb() -> void:
	if Crag.navigate:
		Crag.climb(picked)


func _go(path: String) -> void:
	if Crag.navigate and is_inside_tree():
		Transition.go(get_tree(), path)
