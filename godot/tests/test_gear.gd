extends ClimbBot
## Gear in the expedition's climbs (CLIMB UP 2.0): what you packed changes
## the climb as its card says, and nothing at all with the flag off.


func _load(climb: String, route: String) -> void:
	SaveGame.erase()
	Expedition.found = {}
	Settings.touch_controls = false
	Expedition.session = TestSessions.at(climb)
	Trek.ensure(Expedition.session)["route"] = route
	Expedition.state()["energy"] = 100
	Expedition.climb = {}
	Expedition.resume_climb()
	outcome = null
	level = load(Expedition.LEVELS[climb]).instantiate()
	root.add_child(level)
	await physics_frames(2)
	c = level.climber


func _done() -> void:
	GameInput.scripted = {}
	level.queue_free()
	level = null
	await physics_frames(2)
	SaveGame.erase()


func _open_everything() -> void:
	Crag.navigate = false
	Profile.delete_all()
	Records.delete_all()
	Crag.reset()
	for r in Crag.ROUTES:
		Crag.progress[r["id"]] = Crag.record(r["id"]).merged({"attempts": 1, "sends": 1, "best": "onsight", "challenge": true}, true)
	Crag.achievements = {"no-sitting": true, "redpoint": true}
	Records.data["expedition"]["runs"].append({"score": 60, "points": 70, "summit": true, "returned": true, "difficulty": "standard", "artifacts": 0})
	for id in ["knot-tie-in", "knot-check", "knot-tail", "belay-brake", "belay-assisted", "belay-attention"]:
		Profile.answer(id, true)


func _clean() -> void:
	Profile.delete_all()
	Records.delete_all()
	Crag.reset()
	FeatureFlags.set_flag("gear_effects", true)


func test_the_standard_kit_changes_nothing() -> void:
	_clean()
	await _load("lava-tower", "machame")
	near(level.stamina.walk_gear, 1.0, 0.0001, "walking as before")
	near(level.stamina.rock_gear, 1.0, 0.0001, "climbing as before")
	near(float(level.kit["hurt"]), 1.0, 0.0001, "hits as before")
	await _done()


func test_packed_gear_changes_the_climb() -> void:
	_clean()
	await _load("lava-tower", "machame")
	var rests: int = level.rest_limit
	var hurt: float = c.hurt_scale
	var recovery: float = level.stamina.recovery
	await _done()
	_open_everything()
	check(Profile.equip("shoes", "boots"), "boots")
	check(Profile.equip("helmet", "alpine-helmet"), "the alpine helmet")
	check(Profile.equip("supplies", "gels"), "gels")
	await _load("lava-tower", "machame")
	near(level.stamina.walk_gear, 0.88 * 1.03 * 1.04, 0.0001, "boots, helmet and gels on the walk")
	near(level.stamina.rock_gear, 1.08, 0.0001, "the boots on rock")
	eq(level.rest_limit, rests + 1, "the gels: one more rest")
	near(c.hurt_scale, hurt * 0.75, 0.0001, "the helmet takes a quarter off every hit")
	await _done()
	check(Profile.equip("supplies", "thermos"), "a thermos instead")
	await _load("lava-tower", "machame")
	check(level.stamina.recovery > recovery, "rests give back more (%.2f > %.2f)" % [level.stamina.recovery, recovery])
	await _done()
	FeatureFlags.set_flag("gear_effects", false)
	await _load("lava-tower", "machame")
	near(level.stamina.walk_gear, 1.0, 0.0001, "flag off: the boots do nothing")
	eq(level.rest_limit, rests, "nor the gels")
	await _done()
	_clean()


func test_a_hard_shell_in_the_rain() -> void:
	_clean()
	_open_everything()
	check(Profile.equip("clothing", "hardshell"), "the hard shell")
	await _load("lava-tower", "umbwe")
	var rain: RainSchedule = level.rain
	var t := c.clock
	while not rain.pouring(t):
		t += 0.5
	c.clock = t + 1.0
	await physics_frames(2)
	near(c.stamina.wet, 1.0 + (RainSchedule.WET_ROCK - 1.0) * 0.6, 0.0001, "a downpour costs less in a hard shell")
	await _done()
	_clean()


func test_the_rope_on_an_alpine_pitch() -> void:
	_clean()
	await _load("lava-tower", "umbwe")
	var al: Alpine = level.alpine
	var share := al.rope_left
	await _done()
	_open_everything()
	check(Profile.equip("rope", "dry"), "the dry rope")
	await _load("lava-tower", "umbwe")
	near(level.alpine.rope_left, share * 1.4, 0.01, "more rest hanging on a dry rope")
	await _done()
	_clean()
