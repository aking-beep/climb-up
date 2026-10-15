extends TestCase
## The music is made as it plays, a style per place; footsteps and hand
## sounds sit under it.


func test_each_place_has_its_own_music() -> void:
	var want := {
		"res://modes/expedition/levels/kilimanjaro/lava_tower/lava_tower.gd": "lava",
		"res://modes/expedition/levels/kilimanjaro/barranco/barranco.gd": "barranco",
		"res://modes/expedition/levels/kilimanjaro/summit_night/summit_night.gd": "summit",
		"res://modes/expedition/levels/kilimanjaro/descent/descent.gd": "descent",
	}
	for path in want:
		var lvl: Node = load(path).new()
		eq(String(lvl.spec.get("music", "")), want[path], "%s plays %s" % [path.get_file(), want[path]])
		check(MusicBox.STYLES.has(want[path]), "and the style exists")
		lvl.free()
	for name in ["camp", "crag"]:
		check(MusicBox.STYLES.has(name), "%s has music" % name)


func test_every_style_makes_music_without_clipping() -> void:
	for name in MusicBox.STYLES:
		var box := MusicBox.new()
		box._ring.resize(MusicBox.RING)
		box._style = MusicBox.STYLES[name]
		box._rng.seed = hash(name)
		var n := MusicBox.RATE * 12
		var peak := 0.0
		var energy := 0.0
		for i in n:
			if box._sched < i + MusicBox.RATE:
				box._schedule_bar()
			var k := i % MusicBox.RING
			var v: float = box._ring[k] * float(box._style.get("level", 1.0)) * MusicBox.LOUD
			box._ring[k] = 0.0
			peak = maxf(peak, absf(v))
			energy += v * v
		var rms := sqrt(energy / n)
		check(rms > 0.05, "%s is audible (rms %.3f)" % [name, rms])
		check(peak < 0.95, "%s never clips (peak %.2f)" % [name, peak])
		box.free()


func test_the_summit_turns_to_a_major_key_at_dawn() -> void:
	var box := MusicBox.new()
	box._style = MusicBox.STYLES["summit"]
	var night: Array = box._scale()
	box.mood = 1.0
	var dawn: Array = box._scale()
	check(night.has(3) and not night.has(4), "night: a minor third")
	check(dawn.has(4) and not dawn.has(3), "dawn: a major third")
	box.free()


func test_footsteps_and_hands_sit_under_the_music() -> void:
	for kind in ["step_dirt", "step_rock", "grip", "jug", "sloper", "pocket", "chalk", "breath"]:
		check(float(Audio.TRIM.get(kind, 0.0)) <= -16.0, "%s is faint under the music (%.0f dB)" % [kind, Audio.TRIM.get(kind, 0.0)])
	# The loudest a footstep is ever asked for (-4 dB, a landing) still
	# plays well under the music.
	check(-4.0 + Audio.EFFECTS_DB + float(Audio.TRIM["step_dirt"]) < Audio.MUSIC_DB - 20.0, "footsteps at least 20 dB under the music")
	Audio.play_music("lava")
	eq(Audio.music_playing(), "lava", "a climb's music starts")
	Audio.play_music("")
	eq(Audio.music_playing(), "", "and stops")
