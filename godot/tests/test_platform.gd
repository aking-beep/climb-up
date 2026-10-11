extends TestCase
## The phone around the game: the app going to the background mid-climb
## (pause, and save where you are), the Android back button, vibration as
## its own setting, and a settings file that cannot break the game.


func _crag(id: String) -> Node:
	Crag.navigate = false
	Crag.reset()
	Settings.touch_controls = false
	Crag.current = id
	var level: Node = load(Crag.LEVEL).instantiate()
	root.add_child(level)
	await physics_frames(2)
	level.panel.choose("start" if id == "first-climb" else "neutral")
	await physics_frames(2)
	return level


func test_backgrounding_mid_climb_pauses_the_crag() -> void:
	var level: Node = await _crag("warm-up")
	check(not level.panel.open, "climbing")
	level.climber.hang_at(level.clips[1]["hang"])
	await physics_frames(2)
	Settings.interrupted.emit()
	await physics_frames(1)
	check(level.panel.open, "the app went away: the pause menu is up")
	var clock: float = level.climber.clock
	var y: float = level.climber.global_position.y
	var stamina: float = level.climber.stamina.value
	await physics_frames(120)
	eq(level.climber.clock, clock, "the clock stops")
	eq(level.climber.global_position.y, y, "the climber stays put on the rock")
	eq(level.climber.stamina.value, stamina, "and nothing drains")
	level.panel.choose("resume")
	await physics_frames(2)
	eq(level.climber.state, Climber.State.CLIMB, "resume: back on the rock")
	# The back button pauses too, and a second interruption does not stack.
	Settings.back_requested.emit()
	await physics_frames(1)
	check(level.panel.open, "back opens the pause menu")
	Settings.interrupted.emit()
	await physics_frames(1)
	check(level.panel.open, "still one pause menu")
	level.queue_free()
	await physics_frames(2)
	Crag.reset()


func test_backgrounding_mid_climb_saves_the_expedition() -> void:
	SaveGame.erase()
	Expedition.new_expedition(7)
	Expedition.session = TestSessions.at("barranco-wall")
	Expedition.climb = {}
	Expedition.resume_climb()
	Expedition.remember({"checkpoint": 2, "slips": 0, "mate": "waiting", "seconds": 40.0})
	var level: Node = load(Expedition.LEVELS["barranco-wall"]).instantiate()
	root.add_child(level)
	await physics_frames(3)
	check(not level.panel.open, "resumed at cairn 2, climbing")
	level.climber.slips = 1
	Settings.interrupted.emit()
	await physics_frames(1)
	check(level.panel.open, "paused")
	# The app is killed in the background: a new launch reads the save.
	Expedition.climb = {}
	check(Expedition.load_saved(), "the save is there")
	eq(int(Expedition.climb.get("slips", -1)), 1, "with the climb as it was when the app went away")
	level.queue_free()
	await physics_frames(2)
	SaveGame.erase()


func test_vibration_is_its_own_setting() -> void:
	var was_touch: Variant = Settings.touch_controls
	var was_motion := Settings.reduced_motion
	Settings.touch_controls = true
	Settings.haptics = true
	Settings.reduced_motion = true
	Haptics.last_ms = 0
	Haptics.tap(25)
	eq(Haptics.last_ms, 25, "reduced motion does not turn vibration off")
	Settings.haptics = false
	Haptics.last_ms = 0
	Haptics.tap(25)
	eq(Haptics.last_ms, 0, "the vibration setting does")
	Settings.haptics = true
	Settings.touch_controls = was_touch
	Settings.reduced_motion = was_motion
	await tree.process_frame


func test_a_bad_settings_file_cannot_break_the_game() -> void:
	var keep := Settings.to_dict()
	Settings.apply_dict({"quality": "ultra", "volume": "loud", "touchControls": "maybe", "haptics": 3, "showFps": "yes"})
	eq(Settings.quality, Settings.Quality.FULL, "a bad quality falls back")
	eq(Settings.master_volume, 0.8, "a bad volume falls back")
	eq(Settings.touch_controls, null, "touch: automatic")
	check(Settings.haptics, "vibration stays on unless turned off")
	check(not Settings.show_fps, "no FPS")
	Settings.apply_dict("not a dictionary")
	Settings.apply_dict(keep)
	await tree.process_frame


func test_menus_go_back() -> void:
	Crag.navigate = false
	var menu: Node = load("res://modes/crag/crag_menu.tscn").instantiate()
	root.add_child(menu)
	await tree.process_frame
	check(menu.has_method("on_back"), "the crag menu handles back")
	check(Settings.back_requested.is_connected(menu.on_back), "and listens for it")
	menu.queue_free()
	await tree.process_frame
	check(not tree.is_quit_on_go_back(), "back no longer quits the app outright")
