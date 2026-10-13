extends ClimbBot
## The body on the mountain: what lives there and hurts you (thistles,
## siafu, ravens) taking stamina, the one bar; a hit with nothing left is a
## collapse; and the camp's choices reaching into
## the climb (sleep, food, sickness, medicine), and back out again.


func _load(challenge: String, prep: Callable = Callable()) -> void:
	SaveGame.erase()
	Expedition.found = {}
	Settings.touch_controls = false
	Expedition.session = TestSessions.at(challenge)
	check(Expedition.pending() != null, "the careful party reached %s" % challenge)
	if prep.is_valid():
		prep.call()
	Expedition.climb = {}
	# A fresh go: nothing left over from an earlier test's climb.
	Expedition.climb = {}
	Expedition.resume_climb()
	outcome = null
	level = load(Expedition.LEVELS[challenge]).instantiate()
	root.add_child(level)
	level.finished.connect(func(o: ChallengeOutcome) -> void: outcome = o)
	await physics_frames(2)
	c = level.climber


func _start() -> void:
	check(level.panel.open, "the brief is shown first")
	level.panel.choose("start")
	await physics_frames(1)


func _done() -> void:
	GameInput.scripted = {}
	level.queue_free()
	await physics_frames(2)
	SaveGame.erase()


func _put(cell: Vector2i) -> void:
	c.global_position = Terrain.feet(cell)
	c.reset_physics_interpolation()
	c.velocity = Vector2.ZERO
	c.state = Climber.State.GROUND
	c.fall_from = c.global_position.y
	await physics_frames(3)


## A cell `dx` tiles along from `cell` with ground under it and air in it.
func _ground_near(cell: Vector2i, dirs: Array) -> Vector2i:
	for dx in dirs:
		var at := cell + Vector2i(dx, 0)
		if level.terrain.is_solid(at + Vector2i.DOWN) and not level.terrain.is_solid(at) and not level.terrain.is_solid(at + Vector2i.UP):
			return at
	return Vector2i(-1, -1)


func _still(seconds: float) -> void:
	for i in int(seconds * 60.0):
		GameInput.scripted = {"_": false}
		await tree.physics_frame


func test_a_thistle_stings_unless_you_hop_it() -> void:
	await _load("barranco-wall")
	await _start()
	var cr: Creatures = level.creatures
	check(not cr.plants.is_empty(), "nettles in the Barranco valley")
	var cell: Vector2i = cr.plants[0]["cell"]
	var from := _ground_near(cell, [-3, -4, -5])
	check(from.x >= 0, "room to walk up to it")
	await _put(from)
	await drive(["move_right"], func() -> bool: return tx() >= cell.x + 2.0, 6.0, "over the nettle")
	near(c.hurt_total, 0.0, 0.01, "hopped clean over")
	c.stamina.value = 50.0
	var breath := c.stamina.value
	await _put(cell)
	near(c.hurt_total, Creatures.PLANT_HURT, 0.01, "walking into it stings")
	check(c.stamina.value <= breath - Creatures.PLANT_HURT + 1.0, "and the sting is stamina gone (%.0f to %.0f)" % [breath, c.stamina.value])
	eq(cr.stings, 1, "one sting")
	await _still(0.5)
	near(c.hurt_total, Creatures.PLANT_HURT, 0.01, "and a moment's grace before the next")
	await _done()


func test_siafu_bite() -> void:
	await _load("barranco-wall")
	await _start()
	var cr: Creatures = level.creatures
	check(not cr.ants.is_empty(), "siafu in the valley")
	var a: Dictionary = cr.ants[0]
	var breath := c.stamina.value
	await _put(Terrain.cell_of(Vector2(a["x"], a["y"] - 4.0)))
	near(c.hurt_total, Creatures.ANT_HURT, 0.01, "the ants bite")
	check(c.stamina.value <= breath - Creatures.ANT_HURT + 1.0, "and the bites are stamina gone")
	await _still(3.0)
	check(absf(a["x"] - a["x0"]) <= Creatures.ANT_RANGE + 1.0, "the column marches back and forth on its stretch")
	await _done()


func test_a_raven_hits_someone_standing_still_and_misses_someone_moving() -> void:
	await _load("summit-night")
	await _start()
	var cr: Creatures = level.creatures
	check(not cr.ravens.is_empty(), "ravens over the summit path")
	var home: Vector2i = level.terrain.markers["v"][0]
	var spot := home + Vector2i(0, 3)
	await _put(spot)
	await _still(Creatures.RAVEN_WARN + Creatures.RAVEN_DIVE + 0.3)
	eq(cr.raven_hits, 1, "it dives at a climber who stands still")
	near(c.hurt_total, Creatures.RAVEN_HURT, 0.01, "and it takes stamina")
	# Next time, step aside while it calls.
	var aside := _ground_near(spot, [3, -3, 4, -4])
	check(aside.x >= 0, "somewhere to step to")
	var rv: Dictionary = cr.ravens[0]
	for i in 60 * 8:
		GameInput.scripted = {"_": false}
		await tree.physics_frame
		if rv["phase"] == "warn":
			break
	check(rv["phase"] == "warn", "it calls again")
	await _put(aside)
	await _still(Creatures.RAVEN_DIVE + 0.5)
	eq(cr.raven_hits, 1, "and misses a climber who moved")
	await _done()


func test_a_hit_with_no_stamina_left_is_a_collapse_that_counts_as_a_slip() -> void:
	await _load("lava-tower")
	await _start()
	c.stamina.value = 30.0
	check(c.hurt(10.0, "test"), "hurt")
	near(c.stamina.value, 20.0, 0.01, "a hit with stamina to spare just costs it")
	eq(c.slips, 0, "no slip")
	await _still(Climber.HURT_GUARD + 0.1)
	c.stamina.value = 5.0
	check(c.hurt(10.0, "test"), "hurt again")
	eq(c.state, Climber.State.SLIP, "with nothing left, you collapse")
	eq(c.slips, 1, "and it counts")
	await drive([], func() -> bool: return c.state == Climber.State.GROUND, 4.0, "back at the cairn")
	check(c.stamina.value > 0.0, "you come round with some stamina back (%.0f)" % c.stamina.value)
	await _done()


func test_the_camp_reaches_into_the_climb() -> void:
	await _load("lava-tower")
	var fresh := c.stamina.max_value
	var fresh_recovery := c.stamina.recovery
	await _done()
	await _load("lava-tower", func() -> void:
		var t := Expedition.trek()
		t["sleep"] = "badly"
		t["sick"]["you"] = {"kind": "ams", "stage": 2}
		Expedition.state()["supplies"] = 20)
	check(c.stamina.max_value < fresh, "a bad night and sickness shrink the bar (%.0f vs %.0f)" % [c.stamina.max_value, fresh])
	check(c.stamina.recovery < fresh_recovery, "hunger and a bad night slow recovery")
	var brief: String = level.panel.all_text()
	check("slept badly" in brief and "hungry" in brief and "dizzy" in brief, "the brief says why: " + brief)
	var med := false
	for b in level.panel._buttons.get_children():
		if "painkiller" in (b as Button).text.to_lower() and "tylenol" in (b as Button).text.to_lower() and not (b as Button).is_queued_for_deletion():
			med = true
	check(med, "a painkiller (like Tylenol) is offered for altitude sickness")
	await _start()
	var dizzy := false
	for i in int((Condition.spell_period(2, false) + 1.0) * 60.0):
		GameInput.scripted = {"_": false}
		await tree.physics_frame
		dizzy = dizzy or c.dizzy > 0.0
	check(dizzy, "altitude sickness brings a dizzy spell")
	await _done()
	# The same climb, with a dose first.
	await _load("lava-tower", func() -> void:
		Expedition.trek()["sick"]["you"] = {"kind": "ams", "stage": 2})
	var doses: int = Expedition.trek()["medicine"]
	level.panel.choose("medicine")
	await physics_frames(1)
	eq(Expedition.trek()["medicine"], doses - 1, "a dose from the kit")
	check(level.dosed and level.condition["dizzy"] == 0, "the symptoms stay off")
	for i in int((Condition.spell_period(2, false) + 1.0) * 60.0):
		GameInput.scripted = {"_": false}
		await tree.physics_frame
		check(c.dizzy == 0.0, "no dizzy spells on medicine")
		if c.dizzy > 0.0:
			break
	await _done()


func test_poor_party_health_is_a_smaller_bar() -> void:
	await _load("lava-tower")
	var fresh := c.stamina.max_value
	await _done()
	await _load("lava-tower", func() -> void: Expedition.state()["health"] = 30)
	check(c.stamina.max_value < fresh * 0.9, "health 30 at camp: a smaller bar (%.0f vs %.0f)" % [c.stamina.max_value, fresh])
	check("health is low (30)" in level.panel.all_text(), "and the brief says so")
	await _done()


func test_a_bad_stomach_brings_cramps_and_cold_hands_cost_grip() -> void:
	await _load("lava-tower", func() -> void:
		Expedition.trek()["sick"]["you"] = {"kind": "stomach", "stage": 2})
	await _start()
	var cramped := false
	for i in int((Condition.spell_period(2, true) + 1.0) * 60.0):
		GameInput.scripted = {"move_right": true}
		await tree.physics_frame
		if c.cramp > 0.0:
			cramped = true
			check(absf(c.velocity.x) < Climber.WALK, "doubled over, you slow to a stop")
			break
	check(cramped, "a cramp comes")
	await _done()
	await _load("lava-tower", func() -> void:
		Expedition.trek()["sick"]["you"] = {"kind": "cold", "stage": 2})
	check(c.stamina.grip > 1.0, "numb fingers: holding on costs more")
	await _done()


func _land(base: Dictionary, hurt: int) -> int:
	Expedition.session = base.duplicate(true)
	var p: Dictionary = Expedition.pending()
	Expedition.climb = {"attemptId": p["attemptId"], "challengeId": p["challengeId"], "checkpoint": 0}
	var o := TestSessions.complete(p)
	o["hurt"] = hurt
	eq(Expedition.finish_climb(o), "applied", "landed")
	return int(Expedition.state()["energy"])


func test_what_hurt_you_on_the_climb_costs_the_party() -> void:
	SaveGame.erase()
	Expedition.new_expedition(7)
	var base := TestSessions.at("barranco-wall")
	var clean := _land(base, 0)
	var hurt := _land(base, 40)
	eq(hurt, clean - 8, "forty stamina lost to hits on the rock is eight energy at camp")
	check("Stings and bites" in String(Expedition.state()["lastNote"]), "and the camp says so")
	await tree.process_frame
	SaveGame.erase()


func test_sleep_and_medicine_at_camp() -> void:
	SaveGame.erase()
	Expedition.new_expedition(7)
	Expedition.session = TestSessions.at("lava-tower")
	Expedition.session["pending"] = null
	var t := Expedition.trek()
	eq(t["medicine"], 3, "the long way carries three doses")
	t["sick"]["marco"] = {"kind": "ams", "stage": 2, "cause": "fast"}
	t["sick"]["jun"] = {"kind": "stomach", "stage": 1, "cause": "water"}
	# What each one has, why, and what helps, in plain words.
	var why := Trek.explain_sickness(Expedition.session, "marco")
	check("faster than" in why["why"] and "Tylenol" in why["helps"], "Marco's altitude sickness explained: %s" % [why])
	check("boiled" in Trek.explain_sickness(Expedition.session, "jun")["why"], "Jun's stomach explained")
	# The kit offers what fits: a painkiller for altitude sickness...
	eq(Trek.medicine_label(Expedition.session, "marco"), "Painkiller (like Tylenol)", "a painkiller for the headache")
	Expedition.medicate("marco")
	eq(Expedition.trek()["sick"]["marco"]["stage"], 2, "it eases the headache but does not cure altitude sickness")
	check("does not fix altitude sickness" in String(Expedition.state()["lastNote"]), "and the camp says so")
	check(not Trek.can_medicate(Expedition.session, "marco"), "one painkiller per camp")
	eq(Expedition.trek()["medicine"], 2, "one dose fewer")
	# ...and stomach pills settle a stomach.
	eq(Trek.medicine_label(Expedition.session, "jun"), "Stomach pills", "stomach pills for Jun")
	Expedition.medicate("jun")
	check(not Expedition.trek()["sick"].has("jun"), "Jun is better")
	eq(Expedition.trek()["medicine"], 1, "another dose")
	# A night: energy back is a good sleep; none back is a bad one. Sleep
	# gives some back (Trek.camp_recovery), but hungry and badly ill it
	# cannot make up for a hard night.
	Expedition.trek()["sick"]["marco"]["stage"] = 3
	Expedition.state()["supplies"] = 10
	var before: Dictionary = Expedition.state().duplicate(true)
	var s: Dictionary = Expedition.state()
	s["elapsedHours"] = float(s["elapsedHours"]) + 10.0
	s["energy"] = int(before["energy"]) - 5
	Trek.advance(Expedition.session, before, Expedition.def)
	eq(Expedition.trek()["sleep"], "badly", "a night that gave nothing back")
	check("slept badly" in " ".join(Condition.of(Expedition.session)["lines"]), "and the next climb knows it")
	await tree.process_frame
	SaveGame.erase()
