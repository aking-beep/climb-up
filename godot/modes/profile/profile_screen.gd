extends JournalPage
## Your climber: who you are on the rock, from what you have done. Left,
## the climber as you dressed them. Right, three tabs: the numbers, the
## achievements (earned or how to earn them), and the World Passport.
## Everything shown comes from this phone's records; nothing is made up.

var tabs: SegmentedTabs
var pane: VBoxContainer
var hero: Hero
var summary: Dictionary


func build() -> void:
	set_title("Your climber")
	summary = ProfileData.summary()
	var row := UiKit.hbox(10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(row)
	var left := UiKit.vbox(4)
	left.custom_minimum_size = Vector2(130, 0)
	row.add_child(left)
	var stage := _Stage.new()
	stage.custom_minimum_size = Vector2(130, 120)
	left.add_child(stage)
	hero = Hero.new()
	hero.height = 92.0
	hero.set_look(Profile.look)
	hero.pose = "celebrate" if int(summary["summits"]) > 0 else "idle"
	hero.position = Vector2(65, 112)
	stage.add_child(hero)
	left.add_child(UiKit.label(String(summary["title"]), UiTokens.TEXT_L + 2, UiTokens.INK, true))
	left.add_child(UiKit.label(ProfileData.chip_line(summary), UiTokens.TEXT, UiTokens.INK_MUTED))
	var edit := UiKit.button("Change look and gear", func() -> void:
		if Crag.navigate:
			Transition.go(get_tree(), Hub.LOCKER), "primary", UiTokens.TEXT)
	edit.name = "EditLook"
	left.add_child(edit)
	var right := UiKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	tabs = SegmentedTabs.make(["Numbers", "Achievements", "Passport"])
	tabs.changed.connect(_show)
	right.add_child(tabs)
	pane = UiKit.vbox(4)
	right.add_child(JournalPage.scroller(pane))
	_show(0)


func _show(i: int) -> void:
	for c in pane.get_children():
		c.queue_free()
	match i:
		0:
			_numbers()
		1:
			_achievements()
		2:
			_passport()


func _stat(grid: GridContainer, value: String, what: String) -> void:
	var p := UiKit.panel(UiTokens.PAPER_RAISED, 6.0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(0)
	p.add_child(v)
	v.add_child(UiKit.label(value, UiTokens.TITLE, UiTokens.INK, true))
	v.add_child(UiKit.label(what, UiTokens.TEXT_S, UiTokens.INK_MUTED))
	grid.add_child(p)


func _numbers() -> void:
	var s := summary
	pane.add_child(UiKit.label("Lion Rock · the crag", UiTokens.TEXT, UiTokens.INK_MUTED))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	pane.add_child(g)
	_stat(g, "%d/%d" % [s["stars"], s["starsOf"]], "stars")
	_stat(g, "%d/%d" % [s["sends"], s["routes"]], "routes sent")
	_stat(g, String(s["topGrade"]) if String(s["topGrade"]) != "" else "—", "hardest grade sent")
	_stat(g, str(s["clean"]), "clean sends")
	_stat(g, str(s["dailies"]), "daily routes sent")
	_stat(g, "%d/%d" % [s["achievements"], s["achievementsOf"]], "achievements")
	pane.add_child(UiKit.label("Kilimanjaro · expeditions", UiTokens.TEXT, UiTokens.INK_MUTED))
	var g2 := GridContainer.new()
	g2.columns = 3
	g2.add_theme_constant_override("h_separation", 4)
	g2.add_theme_constant_override("v_separation", 4)
	pane.add_child(g2)
	_stat(g2, str(s["expeditions"]), "expeditions")
	_stat(g2, str(s["summits"]), "summits")
	_stat(g2, str(s["home"]), "came home safely")
	_stat(g2, str(s["bestPoints"]) if int(s["bestPoints"]) >= 0 else "—", "best leader points")
	_stat(g2, str(s["artifacts"]), "most artifacts home")
	_stat(g2, "%d/%d" % [s["knowledge"], s["knowledgeOf"]], "knowledge checks")


func _achievements() -> void:
	pane.add_child(UiKit.label("%d of %d earned at Lion Rock" % [summary["achievements"], summary["achievementsOf"]], UiTokens.TEXT, UiTokens.INK_MUTED))
	for id in Logbook.ACHIEVEMENTS:
		var a: Array = Logbook.ACHIEVEMENTS[id]
		var got := Crag.achievements.has(id)
		var p := UiKit.panel(UiTokens.PAPER_RAISED if got else UiTokens.PAPER_SUNK, 6.0)
		var r := UiKit.hbox(6)
		p.add_child(r)
		r.add_child(UiIcon.make("star" if got else "lock", UiTokens.STAR if got else UiTokens.INK_MUTED, 12.0))
		var t := UiKit.vbox(0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(t)
		t.add_child(UiKit.label(String(a[0]), UiTokens.TEXT_L, UiTokens.INK if got else UiTokens.INK_MUTED, true))
		t.add_child(UiKit.label(String(a[1]), UiTokens.TEXT_S, UiTokens.INK_MUTED, false, 220.0))
		r.add_child(UiKit.chip("EARNED" if got else "TO DO", UiTokens.GOOD if got else UiTokens.PAPER_EDGE, UiTokens.CHALK if got else UiTokens.INK_SOFT, 6))
		pane.add_child(p)


func _passport() -> void:
	var pp: Dictionary = Records.passport()
	pane.add_child(UiKit.label("World Passport: every place you finish gets a stamp.", UiTokens.TEXT, UiTokens.INK_MUTED, false, 260.0))
	for id in pp["places"]:
		var place: Dictionary = pp["places"][id]
		var p := UiKit.panel(UiTokens.PAPER_RAISED, 6.0)
		var r := UiKit.hbox(6)
		p.add_child(r)
		r.add_child(UiIcon.make("check" if place["done"] else "map", UiTokens.GOOD if place["done"] else UiTokens.INK_MUTED, 12.0))
		var t := UiKit.vbox(0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(t)
		t.add_child(UiKit.label(String(Records.PLACES[id]["name"]), UiTokens.TEXT_L, UiTokens.INK, true))
		t.add_child(UiKit.label("%s · %s" % [Records.CONTINENTS[Records.PLACES[id]["continent"]], place["progress"]], UiTokens.TEXT_S, UiTokens.INK_MUTED))
		if place["done"]:
			r.add_child(UiKit.chip("STAMPED", UiTokens.EMBER, UiTokens.CHALK, 6))
		pane.add_child(p)
	for a in pp["achievements"]:
		pane.add_child(UiKit.label("★ " + String(a), UiTokens.TEXT, UiTokens.INK))
	var world := UiKit.button("Open the world map", func() -> void:
		if Crag.navigate:
			Transition.go(get_tree(), Hub.WORLD), "paper", UiTokens.TEXT)
	pane.add_child(world)


class _Stage:
	extends Control

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiTokens.GLACIER)
		draw_rect(Rect2(Vector2(0, size.y - 12), Vector2(size.x, 12)), Color("#8a7a52"))
		draw_circle(Vector2(size.x * 0.8, 18), 10, Color(1, 0.9, 0.7, 0.7))
		draw_rect(Rect2(Vector2.ZERO, size), UiTokens.PAPER_EDGE, false, 1.0)
