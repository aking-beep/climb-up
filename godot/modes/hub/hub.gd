class_name Hub
extends Control
## The front door of CLIMB UP 2.0: the title is a place. Lion Rock (the
## crag) and Kilimanjaro (the expedition) are the two ways in, tagged on
## the landscape. Your climber warms up on a boulder (tap it for your
## profile). Bottom left, the one thing most players come back for (carry
## on where you were); bottom right, today's route. Records and settings
## top right. A new player is pointed at the crag's lesson.

const PATH := "res://modes/hub/hub.tscn"
const CLASSIC := "res://modes/title/title.tscn"
const PROFILE := "res://modes/profile/profile_screen.tscn"
const LOCKER := "res://modes/profile/locker_screen.tscn"
const WORLD := "res://modes/hub/world_map.tscn"
const SCHOOL := "res://modes/crag/school_screen.tscn"

var land: HubLandscape
var climber: Hero
var crag_tag: Button
var expedition_tag: Button
var continue_card: Button
var daily_ticket: Button
var profile_chip: Button
var coach: Control
var _leaving := false


func _ready() -> void:
	if not FeatureFlags.hub:
		# The classic title instead (only when the hub is the scene).
		if get_tree().current_scene == self:
			get_tree().change_scene_to_file.call_deferred(CLASSIC)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Settings.back_requested.connect(on_back)
	Audio.play_music("camp")
	if Expedition.session.is_empty() and Expedition.has_save():
		Expedition.load_saved()
	land = HubLandscape.new()
	add_child(land)
	climber = Hero.new()
	climber.height = 40.0
	climber.set_look(Profile.look)
	climber.pose = "idle"
	climber.z_index = 1
	add_child(climber)
	var tap := Button.new()
	tap.flat = true
	tap.name = "ClimberTap"
	tap.tooltip_text = "Your climber"
	tap.size = Vector2(40, 50)
	tap.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	tap.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	tap.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	tap.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tap.pressed.connect(open_profile)
	add_child(tap)
	climber.set_meta("tap", tap)
	_chrome()
	_tags()
	_cards()
	if not Profile.has_seen("hub") and is_new_player():
		_coach()
	Analytics.event("screen_opened", {"screen": "hub"})
	_pose_loop()


static func is_new_player() -> bool:
	return int(Crag.record("first-climb")["attempts"]) == 0 and not Expedition.has_save() and Records.data.get("expedition", {}).get("runs", []).is_empty()


func _process(_delta: float) -> void:
	if land == null:
		return
	climber.position = land.boulder_top()
	var tap: Control = climber.get_meta("tap")
	tap.position = climber.position - Vector2(20, 48)
	if crag_tag:
		crag_tag.position = land.far_point(Vector2(0.22, 0.33), "mid")
	if expedition_tag:
		expedition_tag.position = land.far_point(Vector2(0.5, 0.47))


## The climber does what a climber does on a boulder between goes.
func _pose_loop() -> void:
	var poses := ["idle", "shake", "idle", "wave", "idle", "crouch", "idle", "reach"]
	var i := 0
	while is_inside_tree():
		climber.pose = poses[i % poses.size()]
		i += 1
		await get_tree().create_timer(2.6 if climber.pose == "idle" else 1.6).timeout


func _chrome() -> void:
	var title := UiKit.world_label("Climb Up", 20, true)
	add_child(title)
	UiKit.pin(title, Control.PRESET_TOP_LEFT, Vector2(14, 8))
	var links := UiKit.hbox(4)
	add_child(links)
	UiKit.pin(links, Control.PRESET_TOP_LEFT, Vector2(14, 38))
	for l in [["map", "World", open_world], ["pack", "Gear and look", open_locker], ["book", "School", open_school]]:
		var b := UiKit.button(l[1], l[2], "dark", UiTokens.TEXT)
		b.name = String(l[1]).replace(" ", "")
		var ic := UiIcon.make(l[0], UiTokens.CHALK, 10.0)
		b.icon = null
		b.add_child(ic)
		ic.position = Vector2(6, 6)
		b.add_theme_constant_override("h_separation", 2)
		b.text = "    " + String(l[1])
		links.add_child(b)
	var right := UiKit.hbox(4)
	add_child(right)
	UiKit.pin(right, Control.PRESET_TOP_RIGHT, Vector2(12, 8))
	profile_chip = _profile_chip()
	right.add_child(profile_chip)
	right.add_child(UiIcon.button("trophy", "Records", open_records))
	right.add_child(UiIcon.button("gear", "Settings", open_settings))


func _profile_chip() -> Button:
	var s := ProfileData.summary()
	var b := UiKit.button("", open_profile, "dark", UiTokens.TEXT)
	b.name = "ProfileChip"
	b.custom_minimum_size = Vector2(112, UiTokens.TAP + 2)
	var face := Control.new()
	face.clip_contents = true
	face.custom_minimum_size = Vector2(20, 20)
	face.position = Vector2(3, 2)
	face.size = Vector2(20, 20)
	b.add_child(face)
	var disc := ColorRect.new()
	disc.color = UiTokens.GLACIER
	disc.size = Vector2(20, 20)
	face.add_child(disc)
	var bust := Hero.new()
	bust.height = 44.0
	bust.set_look(Profile.look)
	bust.pose = "idle"
	bust.position = Vector2(10, 44)
	face.add_child(bust)
	var col := UiKit.vbox(0)
	col.position = Vector2(27, 2)
	b.add_child(col)
	col.add_child(UiKit.label("Your climber", UiTokens.TEXT, UiTokens.CHALK, true))
	col.add_child(UiKit.label(ProfileData.chip_line(s), UiTokens.TEXT_S, Color(UiTokens.CHALK, 0.75)))
	return b


## A tag pinned to a place on the landscape.
func _tag(place: String, mode: String, line: String, extra: String, on_press: Callable) -> Button:
	var b := UiKit.button("", on_press, "dark", UiTokens.TEXT)
	b.custom_minimum_size = Vector2(118, 40)
	var col := UiKit.vbox(0)
	col.position = Vector2(7, 3)
	b.add_child(col)
	var top := UiKit.hbox(4)
	col.add_child(top)
	top.add_child(UiKit.label(place, UiTokens.TEXT_L, UiTokens.CHALK, true))
	top.add_child(UiKit.chip(mode.to_upper(), UiTokens.ROUTE, UiTokens.INK, 6))
	col.add_child(UiKit.label(line, UiTokens.TEXT_S, Color(UiTokens.CHALK, 0.85)))
	col.add_child(UiKit.label(extra, UiTokens.TEXT_S, Color(UiTokens.CHALK, 0.7)))
	add_child(b)
	return b


func _tags() -> void:
	var next := Crag.next_route()
	var line := "Every route sent" if next == "" else "Next up · %s %s" % [Crag.route(next)["name"], Crag.route(next)["grade"]]
	crag_tag = _tag("Lion Rock", "Crag", line, "%d of %d stars" % [Crag.total_stars(), Crag.ROUTES.size() * 3], go_crag)
	crag_tag.name = "CragTag"
	var plan := expedition_line()
	expedition_tag = _tag("Kilimanjaro", "Expedition", plan[0], plan[1], go_expedition)
	expedition_tag.name = "ExpeditionTag"


## The expedition tag's two lines, from the save (or what it is, new).
static func expedition_line() -> Array:
	if Expedition.has_save() and not Expedition.session.is_empty():
		var s: Dictionary = Expedition.state()
		var r := String(Trek.ensure(Expedition.session).get("route", ""))
		var route: String = Trek.ROUTES[r]["name"] if Trek.ROUTES.has(r) else "On the mountain"
		return ["%s · day %d" % [route, ExpeditionEngine.day_of(s) + 1], camp_name()]
	var runs: Array = Records.data.get("expedition", {}).get("runs", [])
	if not runs.is_empty():
		return ["Three routes, 8 to 13 days", "%d expedition%s so far" % [runs.size(), "" if runs.size() == 1 else "s"]]
	return ["Three routes, 8 to 13 days", "A team of four"]


## Where the party is, in the route's own names.
static func camp_name() -> String:
	var s: Dictionary = Expedition.state()
	var r := Places.route_of(Expedition.session)
	return Places.stop_name(String(s["checkpoint"]), r)


## What "Continue" does now: {kind, title, line}. kind is "climb" (back
## onto the rock where you left it), "camp" (the expedition's camp),
## "crag" (the next crag route) or "start" (a new player: the lesson).
static func continue_plan() -> Dictionary:
	if Expedition.has_save() and not Expedition.session.is_empty():
		var s: Dictionary = Expedition.state()
		if Expedition.pending() != null:
			return {"kind": "climb", "title": "Continue the climb", "line": "%s · day %d" % [camp_name(), ExpeditionEngine.day_of(s) + 1]}
		return {"kind": "camp", "title": "Continue the expedition", "line": "%s · day %d" % [camp_name(), ExpeditionEngine.day_of(s) + 1]}
	var next := Crag.next_route()
	if next == "first-climb" or int(Crag.record("first-climb")["attempts"]) == 0:
		return {"kind": "start", "title": "Start here: First Climb", "line": "Learn every move in a few minutes"}
	if next != "":
		var r := Crag.route(next)
		return {"kind": "crag", "title": "Next up: %s" % r["name"], "line": "%s · %s" % [r["grade"], r.get("skill", "")]}
	return {"kind": "crag", "title": "Lion Rock", "line": "Every route sent: chase three stars"}


func _cards() -> void:
	var plan := continue_plan()
	continue_card = UiKit.button("", do_continue, "primary", UiTokens.TEXT)
	continue_card.name = "ContinueCard"
	continue_card.custom_minimum_size = Vector2(150, 34)
	var col := UiKit.vbox(0)
	col.position = Vector2(8, 3)
	continue_card.add_child(col)
	col.add_child(UiKit.label(String(plan["title"]), UiTokens.TEXT_L, UiTokens.SPRUCE_INK, true))
	col.add_child(UiKit.label(String(plan["line"]), UiTokens.TEXT_S, Color(UiTokens.SPRUCE_INK, 0.8)))
	add_child(continue_card)
	UiKit.pin(continue_card, Control.PRESET_BOTTOM_LEFT, Vector2(12, 10))
	var d := Crag.daily_route()
	var dr := Crag.daily_record()
	var status := "New today"
	if int(dr["sends"]) > 0:
		status = "Sent · %s" % Crag.STYLES[dr["best"]][0]
	elif int(dr["attempts"]) > 0:
		status = "%d go%s · try again" % [int(dr["attempts"]), "" if int(dr["attempts"]) == 1 else "s"]
	daily_ticket = UiKit.button("", go_daily, "paper", UiTokens.TEXT)
	daily_ticket.name = "DailyTicket"
	daily_ticket.custom_minimum_size = Vector2(132, 34)
	var dc := UiKit.vbox(0)
	dc.position = Vector2(8, 3)
	daily_ticket.add_child(dc)
	var row := UiKit.hbox(4)
	dc.add_child(row)
	row.add_child(UiKit.chip("TODAY", UiTokens.EMBER, UiTokens.CHALK, 6))
	row.add_child(UiKit.label("%s · %s" % [d["name"], d["grade"]], UiTokens.TEXT, UiTokens.INK, true))
	var opens := Crag.unlocked("daily")
	dc.add_child(UiKit.label(status if opens else "Opens after First Climb", UiTokens.TEXT_S, UiTokens.INK_MUTED))
	daily_ticket.disabled = not opens
	add_child(daily_ticket)
	UiKit.pin(daily_ticket, Control.PRESET_BOTTOM_RIGHT, Vector2(12, 10))
	(continue_card as Control).grab_focus.call_deferred()


func _coach() -> void:
	coach = UiKit.panel(UiTokens.PAPER, 8.0)
	coach.name = "Coach"
	var col := UiKit.vbox(4)
	coach.add_child(col)
	col.add_child(UiKit.label("New here?", UiTokens.TEXT_L, UiTokens.INK, true))
	col.add_child(UiKit.label("Start at Lion Rock: First Climb teaches every move, one at a time. The expedition uses the same moves.", UiTokens.TEXT, UiTokens.INK_SOFT, false, 170.0))
	var row := UiKit.hbox(4)
	col.add_child(row)
	row.add_child(UiKit.button("Start First Climb", func() -> void:
		Profile.see("hub")
		go_crag_lesson(), "primary", UiTokens.TEXT))
	row.add_child(UiKit.button("Look around", func() -> void:
		Profile.see("hub")
		coach.queue_free(), "paper", UiTokens.TEXT))
	add_child(coach)
	coach.position = Vector2(150, 64)


# --- actions -----------------------------------------------------------------


func _travel(path: String, toward: Vector2) -> void:
	if _leaving:
		return
	_leaving = true
	if Settings.reduced_motion or not Crag.navigate:
		_go(path)
		return
	land.pivot_offset = toward
	var tw := create_tween()
	tw.tween_property(land, "scale", Vector2(1.4, 1.4), 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_go.bind(path))


func _go(path: String) -> void:
	if Crag.navigate and is_inside_tree():
		Transition.go(get_tree(), path)


func go_crag() -> void:
	Analytics.event("mode_selected", {"mode": "crag"})
	_travel(Crag.MENU, crag_tag.position + crag_tag.size / 2.0)


func go_crag_lesson() -> void:
	Analytics.event("mode_selected", {"mode": "crag"})
	if Crag.navigate:
		Crag.climb("first-climb")


func go_expedition() -> void:
	Analytics.event("mode_selected", {"mode": "expedition"})
	_travel(Expedition.MENU, expedition_tag.position + expedition_tag.size / 2.0)


func go_daily() -> void:
	if Crag.unlocked("daily") and Crag.navigate:
		Crag.climb("daily")


func do_continue() -> void:
	var plan := continue_plan()
	match String(plan["kind"]):
		"climb":
			if Crag.navigate:
				Expedition.resume_climb()
		"camp":
			_go(Expedition.CAMP)
		"start":
			go_crag_lesson()
		_:
			var next := Crag.next_route()
			if next != "" and Crag.navigate:
				Crag.climb(next)
			else:
				go_crag()


func open_profile() -> void:
	_go(PROFILE)


func open_locker() -> void:
	_go(LOCKER)


func open_world() -> void:
	_go(WORLD)


func open_school() -> void:
	_go(SCHOOL)


func open_records() -> void:
	Records.open("crag", PATH)


func open_settings() -> SettingsSheet:
	return SettingsSheet.open_on(self)


func on_back() -> void:
	# A sheet open on top takes the back press itself.
	for c in get_children():
		if c is JournalSheet:
			return
	print("CLIMB UP: quit (Back on the title)")
	get_tree().quit()
