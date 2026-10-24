extends TestCase
## Your climber (CLIMB UP 2.0): the look and gear are saved, locks open
## only from what you did, gear is a trade with effects that add up, the
## knowledge checks count, and the profile shows only real numbers.


func _fresh() -> void:
	Crag.navigate = false
	Expedition.navigate = false
	Crag.reset()
	Records.delete_all()
	Profile.delete_all()
	FeatureFlags.set_flag("gear_effects", true)


func _send(id: String, best: String = "redpoint", stars_challenge: bool = false) -> void:
	Crag.progress[id] = Crag.record(id).merged({"attempts": 2, "sends": 1, "best": best, "challenge": stars_challenge}, true)


func test_the_look_and_gear_are_kept() -> void:
	_fresh()
	check(Profile.choose_look("jacket", "ember"), "an open jacket")
	check(Profile.choose_look("headwear", "beanie"), "an open hat")
	check(Profile.choose_look("body", "f"), "a body")
	Profile.load_profile()
	eq(Profile.look["jacket"], "#b4512f", "the jacket is kept")
	eq(Profile.look["jacketTrim"], "#7e3520", "with its trim")
	eq(Profile.look["headwear"], "beanie", "the hat is kept")
	eq(Profile.look["body"], "f", "the body is kept")
	_fresh()


func test_locks_open_only_from_what_you_did() -> void:
	_fresh()
	check(not Profile.choose_look("jacket", "ochre"), "ochre is locked (2 stars on Warm-up Wall)")
	check(not Profile.equip("shoes", "rock-shoes"), "rock shoes are locked too")
	eq(Profile.item("shoes")["id"], "approach", "still the standard shoes")
	_send("first-climb")
	_send("warm-up")
	check(Crag.stars("warm-up") >= 2, "two stars on the warm-up (%d)" % Crag.stars("warm-up"))
	check(Profile.choose_look("jacket", "ochre"), "now the ochre jacket opens")
	check(Profile.equip("shoes", "rock-shoes"), "and the rock shoes")
	check(not Profile.equip("helmet", "alpine-helmet"), "the alpine helmet needs Leap of Faith")
	check(not Profile.equip("shoes", "no-such-shoes"), "unknown gear is refused")
	# Gear that is not open any more (records reset) falls back to standard.
	Crag.reset()
	eq(Profile.item("shoes")["id"], "approach", "a reset record takes the gear back")
	_fresh()


func test_every_lock_has_words_and_nothing_costs_money() -> void:
	for slot in CosmeticCatalog.ORDER:
		var open := 0
		for o in CosmeticCatalog.options(slot):
			if o.has("lock"):
				check(Unlocks.words(o["lock"]) != "", "%s/%s says what opens it" % [slot, o["id"]])
			else:
				open += 1
		check(open >= 1, "%s has something open from the start" % slot)
	for slot in EquipmentCatalog.SLOTS:
		var first: Dictionary = EquipmentCatalog.items(slot)[0]
		check(not first.has("lock") and first["effect"].is_empty(), "%s: the standard kit is open and does nothing" % slot)
		for g in EquipmentCatalog.items(slot):
			if g.has("lock"):
				check(Unlocks.words(g["lock"]) != "", "%s/%s says what opens it" % [slot, g["id"]])
			for k in g["effect"]:
				check(k in ["walk", "rock", "wet", "rest", "hurt", "rope_rest", "haul", "rests"], "%s: a known effect %s" % [g["id"], k])
			var text := JSON.stringify(g).to_lower()
			for word in ["buy", "price", "coin", "gem", "$"]:
				check(not word in text, "%s: no money (%s)" % [g["id"], word])


func test_gear_is_a_trade_and_effects_add_up() -> void:
	for slot in EquipmentCatalog.SLOTS:
		for g in EquipmentCatalog.items(slot).slice(1):
			var good := 0
			var bad := 0
			for k in g["effect"]:
				if EquipmentCatalog.helps(k, float(g["effect"][k])):
					good += 1
				else:
					bad += 1
			check(good >= 1, "%s helps with something" % g["id"])
			check(bad >= 1 or g["id"] in ["dry", "thermos"] or slot == "rope", "%s costs something too" % g["id"])
	var e := EquipmentCatalog.effects({"shoes": "boots", "helmet": "alpine-helmet", "supplies": "gels"})
	near(e["walk"], 0.88 * 1.03 * 1.04, 0.0001, "walking: the boots, the helmet and the gels together")
	near(e["rock"], 1.08, 0.0001, "the boots on rock")
	near(e["hurt"], 0.75, 0.0001, "the helmet")
	eq(e["rests"], 1, "one more rest")
	eq(EquipmentCatalog.effect_words({"walk": 0.88, "rock": 1.08}), "walking −12%, climbing +8%", "in words")


func test_gear_effects_follow_the_flag() -> void:
	_fresh()
	_send("first-climb")
	_send("warm-up")
	Profile.equip("shoes", "rock-shoes")
	near(Profile.effects()["rock"], 0.9, 0.0001, "rock shoes on")
	FeatureFlags.set_flag("gear_effects", false)
	near(Profile.effects()["rock"], 1.0, 0.0001, "flag off: no effect")
	FeatureFlags.set_flag("gear_effects", true)
	_fresh()


func test_knowledge_checks_count_and_open_gear() -> void:
	_fresh()
	eq(Profile.knowledge_right(), 0, "none yet")
	check(not Profile.equip("clothing", "hardshell"), "the hard shell needs three right")
	Profile.answer("knot-tie-in", false)
	eq(Profile.knowledge_right(), 0, "a wrong answer does not count")
	for id in ["knot-tie-in", "belay-brake", "clip-back"]:
		Profile.answer(id, true)
	eq(Profile.knowledge_right(), 3, "three right")
	Profile.answer("belay-brake", false)
	eq(Profile.knowledge_right(), 3, "a later wrong answer keeps the right one")
	check(Profile.equip("clothing", "hardshell"), "the hard shell opens")
	_fresh()


func test_knowledge_cards_are_well_formed() -> void:
	var ids := {}
	for c in KnowledgeChecks.CARDS:
		check(not ids.has(c["id"]), "unique id %s" % c["id"])
		ids[c["id"]] = true
		check(KnowledgeChecks.TOPICS.has(c["topic"]), "%s: a known topic" % c["id"])
		eq(c["options"].size(), 3, "%s: three answers" % c["id"])
		check(int(c["answer"]) >= 0 and int(c["answer"]) < 3, "%s: the answer is one of them" % c["id"])
		check(String(c["why"]).length() > 30, "%s: says why" % c["id"])
	for t in KnowledgeChecks.TOPICS:
		check(KnowledgeChecks.topic_cards(t).size() >= 3, "%s: at least three cards" % t)
	# The right answer is not always in the same place.
	var places := {}
	for c in KnowledgeChecks.CARDS:
		places[int(c["answer"])] = true
	eq(places.size(), 3, "right answers in every position")
	check("not a lesson" in KnowledgeChecks.DISCLAIMER and "instructor" in KnowledgeChecks.DISCLAIMER, "the disclaimer")


func test_a_bad_profile_file_loads_as_new() -> void:
	_fresh()
	var f := FileAccess.open(Profile.PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	Profile.load_profile()
	eq(Profile.look["jacket"], Hero.DEFAULT_LOOK["jacket"], "a corrupt file: the default look")
	SaveGame.write({"look": {"jacket": "#123456", "headwear": 5}, "equipped": {"shoes": "jetpack"}, "seen": [1, "hub"]}, Profile.PATH)
	Profile.load_profile()
	eq(Profile.look["jacket"], Hero.DEFAULT_LOOK["jacket"], "an unknown colour is not kept")
	eq(Profile.item("shoes")["id"], "approach", "unknown gear is not kept")
	eq(Profile.seen, ["hub"], "only tips with names")
	_fresh()


func test_the_profile_shows_real_numbers() -> void:
	_fresh()
	var s := ProfileData.summary()
	eq(s["stars"], 0, "no stars")
	eq(s["expeditions"], 0, "no expeditions")
	eq(s["title"], "New climber", "a new climber")
	eq(s["bestPoints"], -1, "no best: nothing made up")
	_send("first-climb", "onsight")
	_send("warm-up")
	_send("sundown")
	_send("the-pinch")
	s = ProfileData.summary()
	eq(s["sends"], 4, "four sends")
	eq(s["topGrade"], "6a", "the hardest grade sent")
	eq(s["title"], "Sport climber", "a title from what you did")
	Records.data["expedition"]["runs"].append({"score": 70, "points": 88, "summit": true, "returned": true, "difficulty": "standard", "artifacts": 3})
	s = ProfileData.summary()
	eq(s["summits"], 1, "a summit from the records")
	eq(s["bestPoints"], 88, "its points")
	eq(s["title"], "Summiteer", "the title follows")
	_fresh()


func test_the_new_pages_open() -> void:
	_fresh()
	for path in [Hub.PROFILE, Hub.LOCKER, Hub.WORLD, Hub.SCHOOL]:
		var screen := SubViewport.new()
		screen.size = Vector2i(480, 270)
		root.add_child(screen)
		var page: Node = load(path).instantiate()
		screen.add_child(page)
		await physics_frames(3)
		check(page is JournalPage, "%s is a journal page" % path.get_file())
		check(page.heading.text != "", "%s has a title" % path.get_file())
		screen.queue_free()
		await physics_frames(1)


func test_the_school_asks_explains_and_counts() -> void:
	_fresh()
	var screen := SubViewport.new()
	screen.size = Vector2i(480, 270)
	root.add_child(screen)
	var page: Node = load(Hub.SCHOOL).instantiate()
	screen.add_child(page)
	await physics_frames(3)
	check(page.find_child("Disclaimer", true, false) != null, "the disclaimer is on the page")
	var card: Dictionary = page.current
	var right: Button = page.find_child("Option%d" % int(card["answer"]), true, false)
	right.pressed.emit()
	await physics_frames(2)
	check(Profile.knowledge.get(card["id"], {}).get("right", false), "a right answer is kept")
	check(page.find_child("Next", true, false) != null, "then why, and the next question")
	(page.find_child("Next", true, false) as Button).pressed.emit()
	await physics_frames(2)
	check(page.current["id"] != card["id"], "the next one")
	screen.queue_free()
	await physics_frames(1)
	_fresh()


func test_the_locker_dresses_and_packs() -> void:
	_fresh()
	var screen := SubViewport.new()
	screen.size = Vector2i(480, 270)
	root.add_child(screen)
	var page: Node = load(Hub.LOCKER).instantiate()
	screen.add_child(page)
	await physics_frames(3)
	(page.find_child("jacket_spruce", true, false) as Button).pressed.emit()
	await physics_frames(2)
	eq(Profile.look["jacket"], "#2d5a4b", "a tap on a swatch dresses you")
	eq(page.hero.look["jacket"], "#2d5a4b", "and the climber shows it")
	(page.find_child("jacket_ochre", true, false) as Button).pressed.emit()
	await physics_frames(2)
	eq(Profile.look["jacket"], "#2d5a4b", "a locked one does not")
	check("Opens with" in page.note.text, "it says how to open it: %s" % page.note.text)
	page.tabs.select(1)
	await physics_frames(2)
	var take: Button = page.find_child("shoes_boots", true, false)
	check(take != null and take.disabled, "locked gear cannot be taken")
	screen.queue_free()
	await physics_frames(1)
	_fresh()
