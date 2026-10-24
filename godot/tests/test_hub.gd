extends TestCase
## CLIMB UP 2.0's front door: the hub is the main scene, shows both ways
## in, the profile chip, records, settings, "continue" and today's route,
## and "continue" always does the one thing the player came back for.


func _fresh() -> void:
	Crag.navigate = false
	Expedition.navigate = false
	Crag.reset()
	Records.delete_all()
	Profile.delete_all()
	SaveGame.erase()
	Expedition.session = {}
	Expedition.climb = {}


## On a phone-sized screen (480 × 270), as the game runs.
func _hub(width: int = 480) -> Hub:
	var screen := SubViewport.new()
	screen.size = Vector2i(width, 270)
	root.add_child(screen)
	var h: Hub = load(Hub.PATH).instantiate()
	screen.add_child(h)
	h.tree_exited.connect(screen.queue_free)
	await physics_frames(3)
	return h


func test_the_hub_is_the_front_door() -> void:
	_fresh()
	eq(ProjectSettings.get_setting("application/run/main_scene"), Hub.PATH, "the game opens on the hub")
	eq(Crag.TITLE, Hub.PATH, "home from the crag is the hub")
	for width in [480, 585]:
		await _fits(width)


## Everything on the screen, a thumb tall, nothing on top of anything
## else, on a 16:9 phone and a long one (19.5:9).
func _fits(width: int) -> void:
	var h := await _hub(width)
	for n in ["CragTag", "ExpeditionTag", "ContinueCard", "DailyTicket", "ProfileChip", "Records", "Settings", "World", "Gearandlook", "School"]:
		check(h.find_child(n, true, false) != null, "the hub has %s" % n)
	check(h.climber is Hero, "your climber is on the boulder")
	check(h.coach != null and h.coach.is_inside_tree(), "a new player is pointed at the lesson")
	var vp := h.get_viewport_rect()
	for c in [h.continue_card, h.daily_ticket, h.profile_chip, h.crag_tag, h.expedition_tag]:
		var r: Rect2 = (c as Control).get_global_rect()
		check(vp.encloses(r), "%s is on the screen (%s in %s)" % [c.name, r, vp])
		check(r.size.y >= UiTokens.TAP - 0.5, "%s is a thumb tall" % c.name)
	var boxes := [h.continue_card, h.daily_ticket, h.profile_chip, h.crag_tag, h.expedition_tag, h.find_child("World", true, false), h.find_child("Settings", true, false)]
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: Rect2 = (boxes[i] as Control).get_global_rect()
			var b: Rect2 = (boxes[j] as Control).get_global_rect()
			check(not a.grow(-1).intersects(b.grow(-1)), "%d px wide: %s and %s do not overlap" % [width, boxes[i].name, boxes[j].name])
	h.queue_free()
	await physics_frames(1)


func test_continue_does_what_you_came_back_for() -> void:
	_fresh()
	eq(Hub.continue_plan()["kind"], "start", "a new player: the lesson")
	Crag.progress["first-climb"] = Crag.record("first-climb").merged({"attempts": 1, "sends": 1, "best": "onsight"}, true)
	var plan := Hub.continue_plan()
	eq(plan["kind"], "crag", "after the lesson: the next route")
	check("Warm-up Wall" in String(plan["title"]), "named: %s" % plan["title"])
	Expedition.new_expedition(11)
	Expedition.save()
	eq(Hub.continue_plan()["kind"], "camp", "an expedition under way comes first")
	check("day 1" in String(Hub.continue_plan()["line"]), "with the day: %s" % Hub.continue_plan()["line"])
	Expedition.session = TestSessions.at("lava-tower")
	Expedition.save()
	eq(Hub.continue_plan()["kind"], "climb", "a climb waiting: back onto the rock")
	_fresh()


func test_the_tags_say_where_you_are() -> void:
	_fresh()
	var h := await _hub()
	var crag_text := _texts(h.crag_tag)
	check("First Climb" in crag_text and "0 of 21 stars" in crag_text, "the crag tag: %s" % crag_text)
	check("Three routes" in _texts(h.expedition_tag), "a new expedition: what it is")
	h.queue_free()
	await physics_frames(1)
	Expedition.new_expedition(5)
	Expedition.save()
	h = await _hub()
	check("day 1" in _texts(h.expedition_tag), "under way: the day (%s)" % _texts(h.expedition_tag))
	h.queue_free()
	await physics_frames(1)
	_fresh()


func test_settings_open_over_the_hub_and_back_closes_them() -> void:
	_fresh()
	var h := await _hub()
	var s := h.open_settings()
	await physics_frames(2)
	check(s.sheet.is_inside_tree(), "the settings sheet is open")
	var before := Settings.haptics
	var b: Button = s.sheet.find_child("s_haptics", true, false)
	check(b != null, "vibration is there")
	b.pressed.emit()
	await physics_frames(2)
	eq(Settings.haptics, not before, "and it changes")
	Settings.set_haptics(before)
	Settings.back_requested.emit()
	await physics_frames(2)
	check(not is_instance_valid(s.sheet) or not s.sheet.is_inside_tree(), "back closes the sheet, not the game")
	check(h.is_inside_tree(), "the hub is still there")
	h.queue_free()
	await physics_frames(1)


func test_the_classic_title_is_still_there() -> void:
	FeatureFlags.set_flag("hub", false)
	var h: Node = load(Hub.PATH).instantiate()
	root.add_child(h)
	await physics_frames(2)
	check(h.get("land") == null, "with the hub off, the hub builds nothing")
	FeatureFlags.set_flag("hub", true)
	h.queue_free()
	await physics_frames(1)


func _texts(n: Node) -> String:
	var out := ""
	for l in n.find_children("*", "Label", true, false):
		out += (l as Label).text + " | "
	return out
