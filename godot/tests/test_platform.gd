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


func test_panels_fit_a_short_screen() -> void:
	# A phone held sideways: 270 logical pixels tall.
	var screen_vp := SubViewport.new()
	screen_vp.size = Vector2i(480, 270)
	root.add_child(screen_vp)
	var p := StoryPanel.new()
	screen_vp.add_child(p)
	await tree.process_frame
	var long := "\n".join(PackedStringArray(range(30).map(func(i): return "Line %d of a long brief that will not fit." % i)))
	var choices: Array = []
	for i in 6:
		choices.append(["c%d" % i, "Choice %d" % i])
	p.show_panel("Kicker", "A long one", long, choices)
	await tree.process_frame
	await tree.process_frame
	var screen := p.get_viewport().get_visible_rect().size.y
	var tall: float = p._box.size.y
	check(tall <= screen, "a long panel fits the screen and scrolls (%.0f of %.0f)" % [tall, screen])
	check(p._scroll.get_v_scroll_bar().max_value > p._scroll.size.y, "with more to scroll to")
	eq(p._scroll.scroll_vertical, 0, "opening at the top")
	p.show_panel("Kicker", "A short one", "One line.", [["x", "Got it"]])
	await tree.process_frame
	await tree.process_frame
	check(p._box.size.y < tall * 0.6, "a short panel after it is short (%.0f, was %.0f)" % [p._box.size.y, tall])
	check(absf(p._box.get_global_rect().end.y - (screen - 10.0)) < 2.0, "and sits on the bottom edge")
	screen_vp.queue_free()
	await tree.process_frame


func test_characters_are_drawn_smooth() -> void:
	for who in ["you", "marco", "lena", "jun"]:
		var path := "res://assets/characters/%s.png" % who
		eq(Sheet.best(path), "res://assets/characters/%s-hd.png" % who, "%s has an HD sheet" % who)
		var s := Sheet.sprite(path)
		check(s.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "%s is filtered smooth, not pixelated" % who)
		var tex: Texture2D = s.sprite_frames.get_frame_texture("climb", 0)
		eq(tex.get_size(), Vector2(Sheet.FRAME * Sheet.HD), "%s: frames are HD times the pixel frame" % who)
		var on_screen: float = tex.get_size().y * s.scale.y
		check(absf(on_screen - Sheet.FRAME.y * Sheet.HD_SIZE) < 0.5, "%s shows at the figure's size in the world (%.1f px)" % [who, on_screen])
		var last: AtlasTexture = s.sprite_frames.get_frame_texture("celebrate", 1)
		check(last.region.end.x <= last.atlas.get_width() and last.region.end.y <= last.atlas.get_height(), "%s: every frame is inside the sheet" % who)
		s.free()
	await tree.process_frame


func test_terrain_and_props_are_drawn_smooth() -> void:
	# Props: the HD file is four times the pixel one but reports the pixel
	# size, so sprite regions and positions are unchanged.
	var pixel: Texture2D = load("res://assets/terrain/props/cairn.png")
	var hd := Art.tex("res://assets/terrain/props/cairn.png")
	eq(hd.get_size(), pixel.get_size(), "an HD prop keeps its world size")
	check(hd.get_image().get_width() == pixel.get_width() * Art.HD, "and has four times the pixels")
	# Terrain: smooth layers drawn over the pixel ones, which stay for collision.
	var level: Node = load(Expedition.LEVELS["barranco-wall"]).instantiate()
	root.add_child(level)
	await physics_frames(2)
	var ground: TileMapLayer = level.ground_layer
	var hd_ground: TileMapLayer = ground.get_parent().get_node_or_null("GroundHD")
	check(hd_ground != null, "the climb has an HD ground layer")
	if hd_ground:
		check(hd_ground.visible and not ground.visible, "the smooth layer shows, the pixel one does not")
		check(not hd_ground.collision_enabled and ground.collision_enabled, "collision stays on the pixel layer")
		eq(hd_ground.get_used_cells().size() >= ground.get_used_cells().size(), true, "every ground cell is drawn smooth")
	var y0: float = level.climber.global_position.y
	await physics_frames(60)
	check(absf(level.climber.global_position.y - y0) < 4.0, "the climber still stands on the hidden ground (moved %.1f px)" % (level.climber.global_position.y - y0))
	level.queue_free()
	await physics_frames(2)


func test_the_settings_page_covers_sound_controls_and_privacy() -> void:
	var keep := Settings.to_dict()
	var level: Node = await _crag("warm-up")
	level.settings_menu()
	for id in ["s_music", "s_effects", "s_haptics", "s_touch", "s_size", "s_hand", "s_quality", "s_motion", "s_usage"]:
		check(level.panel.has_choice(id), "settings has %s" % id)
	# Music and effects are apart, and each steps down to off.
	Settings.music_volume = 0.6
	Settings.effects_volume = 1.0
	level.panel.choose("s_music")
	await tree.process_frame
	eq(Settings.music_volume, 1.0, "music steps up")
	level.panel.choose("s_music")
	await tree.process_frame
	eq(Settings.music_volume, 0.0, "and round to off")
	eq(Settings.effects_volume, 1.0, "without touching the effects")
	check(level.panel.open and level.panel.has_choice("s_music"), "the page stays open")
	# Saved and read back.
	Settings.load_settings()
	eq(Settings.music_volume, 0.0, "music off is saved")
	# Bad values in the file fall back or are clamped.
	Settings.apply_dict({"music": "loud", "effects": 9, "touchScale": 0.1, "leftHanded": "yes", "logUsage": 0})
	eq(Settings.music_volume, 0.6, "a bad music volume falls back")
	eq(Settings.effects_volume, 1.0, "an effects volume is clamped to 1")
	eq(Settings.touch_scale, 0.85, "control size is clamped")
	check(not Settings.left_handed and Settings.log_usage, "bad flags fall back")
	check(not Settings.share_usage, "usage is never shared by default")
	level.queue_free()
	Settings.apply_dict(keep)
	Settings.save_settings()
	await physics_frames(2)


func test_the_game_plays_with_the_sound_off() -> void:
	var keep := Settings.to_dict()
	Settings.effects_volume = 0.0
	Settings.music_volume = 0.0
	var level: Node = await _crag("warm-up")
	Audio.last = ""
	# Climb a little: grabs and moves ask for sounds, none play, nothing breaks.
	for i in 300:
		GameInput.scripted = {"move_right": true} if level.climber.state == Climber.State.GROUND and not level.climber.can_grab() else {"climb_up": true}
		await tree.physics_frame
	GameInput.scripted = {}
	eq(level.climber.state, Climber.State.CLIMB, "climbing with the sound off")
	check(Audio.last != "", "the game still asked for its sounds (%s)" % Audio.last)
	level.queue_free()
	Settings.apply_dict(keep)
	await physics_frames(2)


func test_touch_controls_fit_the_hand_and_the_screen() -> void:
	var keep := Settings.to_dict()
	# A phone-shaped view (the headless window is tiny), and a stand-in level.
	var screen := SubViewport.new()
	screen.size = Vector2i(480, 270)
	root.add_child(screen)
	var level := Node2D.new()
	screen.add_child(level)
	Settings.touch_controls = true
	Settings.left_handed = false
	Settings.touch_scale = 1.0
	TouchControls.attach(level)
	await physics_frames(2)
	var t: TouchControls = level.get_node("TouchControls")
	var vp := Vector2(480, 270)
	var act: TouchScreenButton = t.buttons["interact"]
	var size: float = act.texture_normal.get_size().x
	check(act.position.x > vp.x / 2.0, "right hand: the action button on the right (%s)" % act.position)
	var right_x := act.position.x
	# Bigger controls.
	Settings.touch_scale = 1.3
	TouchControls.attach(level)
	await physics_frames(2)
	t = level.get_node("TouchControls")
	check(absf(t.buttons["interact"].texture_normal.get_size().x - size * 1.3) < 1.0, "buttons grow with the setting (%s)" % t.buttons["interact"].texture_normal.get_size())
	check(absf(t.radius() - TouchControls.STICK_RADIUS * 1.3) < 0.01, "and the stick")
	# Left hand: buttons mirrored to the left; pause stays top right.
	Settings.touch_scale = 1.0
	Settings.left_handed = true
	TouchControls.attach(level)
	await physics_frames(2)
	t = level.get_node("TouchControls")
	act = t.buttons["interact"]
	check(act.position.x < vp.x / 2.0, "left hand: the action button on the left (%s)" % act.position)
	check(absf((act.position.x + size) - (vp.x - right_x)) < 1.0, "mirrored exactly")
	check(t.buttons["pause"].position.x > vp.x / 2.0, "pause stays top right, clear of the stats")
	# The stick takes touches on the right for the left hand, not the left.
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(vp.x * 0.15, vp.y * 0.7)
	t._input(touch)
	check(not t.stick_state()["active"], "left hand: a left-side touch is not the stick")
	touch.position = Vector2(vp.x * 0.85, vp.y * 0.7)
	t._input(touch)
	check(t.stick_state()["active"], "the stick claims a right-side touch")
	touch.pressed = false
	t._input(touch)
	# A notch: insets move everything inside the safe area.
	Settings.left_handed = false
	var win := Vector2i(tree.root.size)
	Settings.safe_override = Rect2i(Vector2i(int(win.x * 0.05), 0), Vector2i(int(win.x * 0.9), win.y))
	var inset := Settings.safe_insets()
	check(inset["left"] > 0.0 and inset["right"] > 0.0, "a cutout gives insets (%s)" % inset)
	TouchControls.attach(level)
	await physics_frames(2)
	t = level.get_node("TouchControls")
	check(t.buttons["pause"].position.x + 32.0 <= vp.x - inset["right"] + 0.5, "pause clears the right cutout")
	check(t.buttons["jump"].position.x + t.buttons["jump"].texture_normal.get_size().x <= vp.x - inset["right"], "so do the thumb buttons")
	var hud := Hud.new()
	level.add_child(hud)
	await tree.process_frame
	check(absf((hud.get_child(0) as Control).offset_left - inset["left"]) < 0.5, "the HUD sits inside the safe area")
	Settings.safe_override = null
	screen.queue_free()
	Settings.apply_dict(keep)
	Settings.touch_controls = false
	await physics_frames(2)


func test_analytics_are_local_and_private() -> void:
	var keep_disk := Analytics.write_to_disk
	Analytics.write_to_disk = true
	Analytics.erase()
	Analytics.event("route_started", {"route": "warm-up", "name": "Pat", "where": Vector2(1, 2), "pos": [1, 2]})
	Analytics.event("totally_made_up", {"x": 1})
	eq(Analytics.count("totally_made_up"), 0, "unknown events are dropped")
	var e: Dictionary = Analytics.recent[-1]
	eq(e["e"], "route_started", "known events are kept")
	check(not e["p"].has("where") and not e["p"].has("pos"), "only plain values are kept (%s)" % e["p"])
	check(not e.has("device") and not e.has("user") and e["s"].length() == 16, "a random session id, nothing about the device or player")
	Analytics.flush()
	var all := Analytics.read_all()
	check(not all.is_empty() and all[-1]["e"] == "route_started", "written to this device")
	# A climb records what the playtest plan measures.
	var level: Node = await _crag("warm-up")
	check(Analytics.count("route_started") >= 2, "tying in is a route start")
	level.finish(true)
	await physics_frames(70)
	check(Analytics.count("route_completed") >= 1, "a send is a route completion")
	level.queue_free()
	# Turned off: nothing written.
	Analytics.erase()
	Settings.log_usage = false
	Analytics.event("route_started", {"route": "x"})
	Analytics.flush()
	eq(Analytics.read_all().size(), 0, "the usage log off writes nothing")
	Settings.log_usage = true
	Analytics.event("route_started", {"route": "warm-up"})
	Analytics.flush()
	check(Analytics.export_text().contains("\"route_started\""), "a playtester can export the log as text")
	# No sink is called without consent.
	var called := [0]
	Analytics.add_sink(func(_e: Dictionary) -> void: called[0] += 1)
	Analytics.event("route_started", {"route": "x"})
	eq(called[0], 0, "no provider hears anything without consent")
	Analytics._sinks.clear()
	Analytics.erase()
	Analytics.write_to_disk = keep_disk
	Crag.reset()
	await physics_frames(2)
