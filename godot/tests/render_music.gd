extends SceneTree
## Renders each music style to a WAV (for listening and level checks), and
## times how long the music takes to make. Not a test:
##   godot --headless --path godot --script res://tests/render_music.gd -- out=/tmp/music seconds=40

func _init() -> void:
	var out := "/tmp/music"
	var seconds := 40.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("seconds="):
			seconds = float(a.substr(8))
	DirAccess.make_dir_recursive_absolute(out)
	for name in MusicBox.STYLES:
		var box := MusicBox.new()
		box._ring.resize(MusicBox.RING)
		box.style_name = name
		box._style = MusicBox.STYLES[name]
		box._rng.seed = hash(name)
		var n := int(seconds * MusicBox.RATE)
		var t0 := Time.get_ticks_usec()
		var data := PackedByteArray()
		data.resize(n * 2)
		var peak := 0.0
		var sum := 0.0
		var lvl: float = box._style.get("level", 1.0) * MusicBox.LOUD
		if name == "summit":
			pass
		for i in n:
			if box._sched < i + MusicBox.RATE:
				# The summit brightens halfway, as the dawn would.
				if name == "summit" and i > n / 2:
					box.mood = 1.0
				box._schedule_bar()
			var k := i % MusicBox.RING
			var v: float = box._ring[k] * lvl
			box._ring[k] = 0.0
			peak = maxf(peak, absf(v))
			sum += v * v
			data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var f := FileAccess.open("%s/%s.wav" % [out, name], FileAccess.WRITE)
		f.store_string("RIFF")
		f.store_32(36 + data.size())
		f.store_string("WAVEfmt ")
		f.store_32(16)
		f.store_16(1)
		f.store_16(1)
		f.store_32(MusicBox.RATE)
		f.store_32(MusicBox.RATE * 2)
		f.store_16(2)
		f.store_16(16)
		f.store_string("data")
		f.store_32(data.size())
		f.store_buffer(data)
		f.close()
		print("%s: %.0f ms to make %.0f s (%.1f%% of real time), peak %.2f, rms %.3f" % [name, ms, seconds, ms / (seconds * 10.0), peak, sqrt(sum / n)])
		box.free()
	quit(0)
