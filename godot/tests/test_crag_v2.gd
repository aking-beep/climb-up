extends CragBot
## Lion Rock in CLIMB UP 2.0: the guidebook page (every route with its
## topo, bolting, exposure and shoes), and the brief's optional partner
## check, which changes nothing in the climb or its score.


func _fresh() -> void:
	Crag.navigate = false
	Crag.reset()
	Records.delete_all()
	Profile.delete_all()


func _page() -> Node:
	var screen := SubViewport.new()
	screen.size = Vector2i(480, 270)
	root.add_child(screen)
	var p: Node = load(Crag.MENU).instantiate()
	screen.add_child(p)
	p.tree_exited.connect(screen.queue_free)
	await physics_frames(3)
	return p


func test_the_guidebook_lists_every_route_and_locks() -> void:
	_fresh()
	var p: Node = await _page()
	eq(p.rows.size(), Crag.ROUTES.size() + 1, "seven routes and the daily")
	eq(p.picked, "first-climb", "a new climber starts at the lesson")
	check(not p.climb_button.disabled, "the lesson is open")
	p.pick("thunderhead")
	await physics_frames(1)
	check(p.climb_button.disabled, "the hardest route is locked")
	p.pick("daily")
	await physics_frames(1)
	check(p.climb_button.disabled, "the daily opens after the lesson")
	p.queue_free()
	await physics_frames(1)


func test_the_topo_is_the_routes_own_map() -> void:
	_fresh()
	for r in Crag.ROUTES:
		var topo := RouteTopo.new()
		topo.show_route(r["id"])
		var t := Terrain.from_text(Crag.map_text(r["id"]))
		eq(topo.terrain.markers.get("Q", []).size(), t.markers.get("Q", []).size(), "%s: every bolt on the topo" % r["name"])
		eq(topo.terrain.markers.get("Q", []).size(), int(Crag.facts(r["id"])["bolts"]), "%s: as many as the brief says" % r["name"])
		topo.free()


func test_shoes_picked_on_the_page_are_the_crags_shoes() -> void:
	_fresh()
	var p: Node = await _page()
	(p.find_child("Shoes_aggressive", true, false) as Button).pressed.emit()
	await physics_frames(2)
	eq(Crag.shoes, "aggressive", "the crag's own shoe choice")
	Crag.load_progress()
	eq(Crag.shoes, "aggressive", "and it is kept")
	p.queue_free()
	await physics_frames(1)
	_fresh()


func test_the_partner_check_is_optional_and_changes_nothing() -> void:
	_fresh()
	Crag.progress["first-climb"] = Crag.record("first-climb").merged({"attempts": 1, "sends": 1, "best": "onsight"}, true)
	await _load("warm-up", "")
	check(level.panel.has_choice("check"), "the brief offers a partner check")
	var before: Dictionary = Crag.record("warm-up").duplicate(true)
	level.panel.choose("check")
	await physics_frames(2)
	var card := KnowledgeChecks.card("knot-tie-in")
	var wrong := (int(card["answer"]) + 1) % 3
	check(level.panel.has_choice("kc%d" % wrong), "three answers")
	level.panel.choose("kc%d" % wrong)
	await physics_frames(2)
	check("Not quite" in level.panel.title_text() or "not quite" in level.panel.title_text().to_lower(), "a wrong answer says so: %s" % level.panel.title_text())
	check(not Profile.knowledge["knot-tie-in"]["right"], "and does not count")
	level.panel.choose("brief")
	await physics_frames(2)
	check(level.panel.has_choice("check"), "the check is still there")
	level.panel.choose("check")
	await physics_frames(2)
	level.panel.choose("kc%d" % int(card["answer"]))
	await physics_frames(2)
	check(Profile.knowledge["knot-tie-in"]["right"], "right counts")
	level.panel.choose("brief")
	await physics_frames(2)
	check(not level.panel.has_choice("check"), "and the check is done for this route")
	eq(Crag.record("warm-up"), before, "the route's record is untouched: no go, no style, no score")
	FeatureFlags.set_flag("knowledge", false)
	Profile.delete_all()
	level.brief()
	await physics_frames(1)
	check(not level.panel.has_choice("check"), "flag off: no check")
	FeatureFlags.set_flag("knowledge", true)
	await _done()
	_fresh()


func test_the_lesson_has_no_check() -> void:
	_fresh()
	await _load("first-climb", "")
	check(not level.panel.has_choice("check"), "First Climb teaches the moves; no quiz")
	await _done()
