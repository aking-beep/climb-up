extends TestCase
## The expedition's new screens (CLIMB UP 2.0): the route picker, the prep
## screen and the walkable camp. They only ever act through the
## expedition's own calls (Expedition.choose, tend, the camp jobs), so the
## same choice made in the camp or on the board leaves the same session.


func _fresh() -> void:
	Crag.navigate = false
	Expedition.navigate = false
	SaveGame.erase()
	Profile.delete_all()
	Records.delete_all()
	Crag.reset()
	Expedition.session = {}
	Expedition.climb = {}


func _open(path: String) -> Node:
	var screen := SubViewport.new()
	screen.size = Vector2i(480, 270)
	root.add_child(screen)
	var n: Node = load(path).instantiate()
	screen.add_child(n)
	n.tree_exited.connect(screen.queue_free)
	await physics_frames(3)
	return n


func test_the_picker_starts_the_route_you_pick() -> void:
	_fresh()
	var p: Node = await _open(Expedition.MENU)
	check(p.cards.size() == 3, "three routes")
	check(p.find_child("Continue", true, false) == null, "nothing to continue yet")
	p.start("umbwe")
	eq(Trek.ensure(Expedition.session)["route"], "umbwe", "the fastest way")
	check(Expedition.card().get("id", "") != "trek-route", "the route card is spent")
	check(Expedition.has_save(), "and saved")
	p.queue_free()
	await physics_frames(1)
	_fresh()


func test_starting_over_asks_first() -> void:
	_fresh()
	Expedition.new_expedition(3)
	Expedition.choose(0)
	Expedition.choose(0)
	var before: Dictionary = Expedition.session.duplicate(true)
	var p: Node = await _open(Expedition.MENU)
	check(p.find_child("Continue", true, false) != null, "the expedition under way can be continued")
	p._pick("machame")
	await physics_frames(2)
	check(p.confirm != null and p.confirm.is_inside_tree(), "a new one asks first")
	eq(Expedition.session, before, "and nothing has changed yet")
	p.confirm.close()
	await physics_frames(2)
	eq(Expedition.session, before, "keep it: the same expedition")
	p.queue_free()
	await physics_frames(1)
	_fresh()


func test_the_briefing_comes_from_the_levels() -> void:
	var rain := Briefing.for_climb("lava-tower", "umbwe")
	eq(rain["weather"], "rain", "the Umbwe Ridge has showers")
	eq(rain["place"], Places.climb_name("lava-tower", "umbwe"), "named for the route")
	check("Showers" in Briefing.line(rain), "the briefing says so: %s" % Briefing.line(rain))
	var night := Briefing.for_climb("summit-night", "lemosho")
	check(float(night["low"]) < 0.0, "the summit night is below freezing")
	check("freezing" in Briefing.line(night), "and the briefing says so")
	eq(Briefing.for_climb("lava-tower", "machame")["weather"], "", "no rain on the Lava Tower")


func test_the_camp_sky_is_a_pure_function_of_the_state() -> void:
	var calm := Briefing.sky({"weatherRisk": 10, "elapsedHours": 4})
	var storm := Briefing.sky({"weatherRisk": 90, "elapsedHours": 4})
	eq(calm, Briefing.sky({"weatherRisk": 10, "elapsedHours": 4}), "the same state, the same sky")
	eq(calm["rain"], 0.0, "no rain when it is settled")
	check(storm["rain"] > 0.5 and storm["cloud"] > calm["cloud"], "a storm rains")
	check(Briefing.sky({"weatherRisk": 10, "elapsedHours": 14})["night"], "night falls")


func test_walking_up_to_lena_and_deciding() -> void:
	_fresh()
	Expedition.new_expedition(9)
	Expedition.choose(0)
	var twin: Dictionary = Expedition.session.duplicate(true)
	var camp: CampWorld = await _open(Expedition.CAMP_WORLD)
	check(camp.sheet != null, "the first time, a tip on how camp works")
	camp.sheet.close()
	await physics_frames(1)
	var start: float = camp.you.position.x
	camp.walk_to(start - 100.0)
	await physics_frames(90)
	check(camp.you.position.x < start - 60.0, "a tap walks you there (%.0f → %.0f)" % [start, camp.you.position.x])
	camp.walk_to(float(camp.spots["lena"]["x"]) - 10.0, "lena")
	await physics_frames(150)
	eq(camp.near_id, "lena", "next to Lena")
	check(camp.sheet != null and camp.sheet.name == "Decision", "she has today's decision")
	var card := Expedition.card()
	var n := 0
	for c in camp.sheet.find_children("Choice*", "Button", true, false):
		n += 1
	eq(n, card["choices"].size(), "every choice on the card")
	var b: Button = camp.sheet.find_child("Choice1", true, false)
	b.pressed.emit()
	await physics_frames(1)
	eq(Expedition.session["state"]["history"].size(), twin["state"]["history"].size(), "the first tap only shows what it does")
	b.pressed.emit()
	await physics_frames(2)
	# The same choice made on the board, on a copy.
	var board := Coordinator.choose(twin, 1, Expedition.def)
	eq(Expedition.session["state"]["history"].size(), board["session"]["state"]["history"].size(), "the camp made the board's move")
	eq(Expedition.session["state"]["checkpoint"], board["session"]["state"]["checkpoint"], "to the same place")
	camp.queue_free()
	await physics_frames(1)
	_fresh()


func test_the_camp_jobs_and_people_use_the_expeditions_calls() -> void:
	_fresh()
	Expedition.new_expedition(9)
	Expedition.choose(0)
	var camp: CampWorld = await _open(Expedition.CAMP_WORLD)
	camp.open_cook()
	await physics_frames(2)
	var water: Button = camp.sheet.find_child("Routine_water", true, false)
	check(water != null and not water.disabled, "Baraka can put the water on")
	var hours: float = Expedition.state()["elapsedHours"]
	water.pressed.emit()
	await physics_frames(2)
	check(Expedition.state()["marks"].get("water-" + String(Expedition.state()["checkpoint"])) == true, "the camp job is done")
	check(Expedition.state()["elapsedHours"] >= hours, "and it took its time")
	camp.open_person("marco")
	await physics_frames(2)
	check(camp.sheet.is_inside_tree(), "Marco talks")
	camp.sheet.close()
	await physics_frames(1)
	camp.open_weather()
	await physics_frames(1)
	check("Next climb" in _texts(camp.sheet), "Neema briefs the next climb")
	camp.sheet.close()
	await physics_frames(1)
	camp.open_tent()
	await physics_frames(1)
	check("saved" in _texts(camp.sheet), "the tent is a checkpoint: %s" % _texts(camp.sheet))
	camp.queue_free()
	await physics_frames(1)
	_fresh()


func test_the_porter_swaps_gear_you_have_opened() -> void:
	_fresh()
	Crag.progress["first-climb"] = Crag.record("first-climb").merged({"attempts": 1, "sends": 1, "best": "onsight"}, true)
	Crag.progress["warm-up"] = Crag.record("warm-up").merged({"attempts": 1, "sends": 1, "best": "redpoint"}, true)
	Expedition.new_expedition(9)
	Expedition.choose(0)
	var camp: CampWorld = await _open(Expedition.CAMP_WORLD)
	camp.open_pack()
	await physics_frames(2)
	var swap: Button = camp.sheet.find_child("Swap_shoes", true, false)
	check(swap != null and not swap.disabled, "shoes to swap")
	swap.pressed.emit()
	await physics_frames(2)
	eq(Profile.item("shoes")["id"], "rock-shoes", "the rock shoes go in the pack")
	var helmet: Button = camp.sheet.find_child("Swap_helmet", true, false)
	check(helmet.disabled, "nothing else to swap for the helmet yet")
	camp.queue_free()
	await physics_frames(1)
	_fresh()


func test_someone_sent_down_is_not_in_camp() -> void:
	_fresh()
	Expedition.new_expedition(9)
	Expedition.choose(0)
	Expedition.trek()["gone"].append("marco")
	var camp: CampWorld = await _open(Expedition.CAMP_WORLD)
	check(not camp.people["marco"].visible, "Marco went down")
	check(not camp.spots.has("marco"), "so there is no one to talk to")
	camp.queue_free()
	await physics_frames(1)
	_fresh()


func test_the_end_shows_the_scorecard() -> void:
	_fresh()
	Expedition.new_expedition(9)
	Expedition.choose(0)
	var s := Expedition.state()
	s["status"] = "complete"
	s["returnedSafely"] = true
	var camp: CampWorld = await _open(Expedition.CAMP_WORLD)
	await physics_frames(2)
	check(camp.sheet != null and camp.sheet.name == "Scorecard", "the expedition is over: the scorecard")
	check("Score" in _texts(camp.sheet) or "score" in _texts(camp.sheet).to_lower(), "with the score")
	camp.queue_free()
	await physics_frames(1)
	_fresh()


func test_the_engine_files_are_untouched() -> void:
	# The engine, its content and the coordinator are protected (AGENTS.md):
	# the 2.0 screens must not need changes there. Pinned by size here; the
	# parity test pins their behaviour.
	for f in ["res://modes/expedition/engine/expedition_engine.gd", "res://modes/expedition/engine/coordinator.gd", "res://modes/expedition/data/kilimanjaro.json"]:
		check(FileAccess.file_exists(f), "%s is there" % f)
	var src := FileAccess.get_file_as_string("res://modes/expedition/engine/coordinator.gd")
	check(not "CampWorld" in src and not "Profile" in src, "the coordinator knows nothing of the new screens")


func _texts(n: Node) -> String:
	var out := ""
	for l in n.find_children("*", "Label", true, false):
		out += (l as Label).text + " | "
	return out
