extends JournalPage
## Kilimanjaro (CLIMB UP 2.0): carry on with the expedition under way, or
## pick a route for a new one. Each route card says what it asks of you
## (days, how big your stamina bar is, the three climbs). Starting a new
## expedition while one is under way asks first: it gives that one up.

const PREP := "res://modes/expedition/prep.tscn"

var cards: Dictionary = {}
var confirm: JournalSheet


func build() -> void:
	set_title("Kilimanjaro")
	back_to = Hub.PATH
	Audio.play_music("camp")
	var has_save := Expedition.has_save() and (not Expedition.session.is_empty() or Expedition.load_saved())
	var col := UiKit.vbox(5)
	var scroll := JournalPage.scroller(col)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(scroll)
	if has_save and Expedition.active():
		var plan := Hub.continue_plan()
		var cont := UiKit.button("", _continue, "primary", UiTokens.TEXT)
		cont.name = "Continue"
		cont.custom_minimum_size = Vector2(0, 34)
		var v := UiKit.vbox(0)
		v.position = Vector2(8, 3)
		cont.add_child(v)
		v.add_child(UiKit.label(String(plan["title"]), UiTokens.TEXT_L, UiTokens.SPRUCE_INK, true))
		v.add_child(UiKit.label(String(plan["line"]), UiTokens.TEXT_S, Color(UiTokens.SPRUCE_INK, 0.8)))
		col.add_child(cont)
		cont.grab_focus.call_deferred()
	col.add_child(UiKit.label("A new expedition · pick your way up", UiTokens.TEXT, UiTokens.INK_MUTED))
	var row := UiKit.hbox(5)
	col.add_child(row)
	for id in ["lemosho", "machame", "umbwe"]:
		var c := _route_card(id)
		row.add_child(c)
		cards[id] = c
	col.add_child(UiKit.label("A game, not a guide: altitude, illness and medicine here are simplified game rules, not advice for a real mountain.", UiTokens.TEXT_S, UiTokens.INK_MUTED, false, 440.0))
	var more := UiKit.hbox(4)
	col.add_child(more)
	more.add_child(UiKit.button("Records", func() -> void: Records.open("expedition", Expedition.MENU), "paper", UiTokens.TEXT))
	more.add_child(UiKit.button("Classic menu", func() -> void: _go(Expedition.CLASSIC_MENU), "ghost", UiTokens.TEXT))


func _route_card(id: String) -> Button:
	var r: Dictionary = Trek.ROUTES[id]
	var b := UiKit.button("", _pick.bind(id), "paper", UiTokens.TEXT)
	b.name = "Route_" + id
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 150)
	var v := UiKit.vbox(2)
	v.position = Vector2(7, 5)
	b.add_child(v)
	var diff: String = String(r["line"]).split("·")[1].strip_edges() if "·" in String(r["line"]) else ""
	var tone: Color = {"easy": UiTokens.GOOD, "medium": UiTokens.WARN, "hard": UiTokens.BAD}.get(diff, UiTokens.INK_MUTED)
	var head := UiKit.hbox(4)
	v.add_child(head)
	head.add_child(UiKit.label(String(r["name"]), UiTokens.TEXT_L, UiTokens.INK, true))
	head.add_child(UiKit.chip(diff.to_upper(), tone, UiTokens.CHALK, 6))
	v.add_child(UiKit.label("%d days · stamina bar %s" % [int(r["permit"]), {"lemosho": "full", "machame": "half", "umbwe": "a quarter"}[id]], UiTokens.TEXT_S, UiTokens.INK_SOFT))
	var bar := Meter.make({"lemosho": 1.0, "machame": 0.5, "umbwe": 0.25}[id], 120.0, 4.0)
	bar.color = UiTokens.SPRUCE
	v.add_child(bar)
	for climb in Briefing.CLIMBS:
		v.add_child(UiKit.label("· " + Places.climb_name(climb, id), UiTokens.TEXT_S, UiTokens.INK_MUTED))
	var people := Control.new()
	people.custom_minimum_size = Vector2(120, 40)
	v.add_child(people)
	var x := 12.0
	for who in ["you", "lena", "marco", "jun"]:
		var h := Hero.new()
		h.height = 34.0
		h.set_look(Profile.look if who == "you" else TeamLooks.look(who))
		h.kit = "trek"
		h.pose = "walk" if id == "umbwe" else "idle"
		h.phase = x
		h.position = Vector2(x, 38)
		people.add_child(h)
		x += 26.0
	return b


func _pick(id: String) -> void:
	if Expedition.has_save() and Expedition.active() and ExpeditionEngine.day_of(Expedition.state()) + Expedition.state()["history"].size() > 0:
		confirm = JournalSheet.open(self, "Start over?", 260.0)
		confirm.name = "Overwrite"
		confirm.text("You have an expedition under way (%s). A new one gives it up for good." % Hub.continue_plan()["line"])
		var row := UiKit.hbox(4)
		confirm.add(row)
		var yes := UiKit.button("Give it up and start", start.bind(id), "danger", UiTokens.TEXT)
		yes.name = "Yes"
		row.add_child(yes)
		row.add_child(UiKit.button("Keep it", confirm.close, "paper", UiTokens.TEXT))
		return
	start(id)


## A new expedition on this route, then the prep screen.
func start(id: String) -> void:
	if confirm and is_instance_valid(confirm):
		confirm.close()
	Expedition.new_expedition(int(Time.get_unix_time_from_system()) % 100000 + 1)
	var card := Expedition.card()
	if String(card.get("id", "")) == "trek-route":
		for i in card["choices"].size():
			if String(card["choices"][i].get("route", "")) == id:
				Expedition.choose(i)
				break
	_go(PREP)


func _continue() -> void:
	if Expedition.pending() != null:
		if Crag.navigate:
			Expedition.resume_climb()
	else:
		_go(Expedition.camp_scene())


func _go(path: String) -> void:
	if Crag.navigate and is_inside_tree():
		Transition.go(get_tree(), path)
