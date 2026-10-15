class_name MusicBox
extends AudioStreamPlayer
## Music made as it plays: soft pads under a slow chord progression, a
## warm bass on the bar, and a kalimba-like pluck finding a melody in the
## scale, never quite the same twice. One mood per place (STYLES): the
## camp at night, the warm afternoon of the Lava Tower, a bright morning on
## the Barranco Wall, the long dark of the summit night (it opens into a
## major key as the sun comes up: set `mood`), the relief of the way down,
## and an easy lo-fi groove at the crag. Nothing is shipped but this code.
##
## How: notes are rendered once into small cached buffers (pads and bass
## at a quarter of the rate, plucks at the full rate) and added into a ring
## buffer a bar ahead of the playhead, which feeds an AudioStreamGenerator.

const RATE := 22050
const RING := RATE * 14
## Output gain: peaks near 0.75 of full scale.
const LOUD := 1.25

## Each style: root (MIDI), scale (semitones from the root), the chords
## (each a list of scale steps; one chord a bar), the chords to use in the
## bright mood (optional), tempo (bpm), pluck density (0..1 per eighth),
## the pluck's voice (kalimba, bell, keys) and its octave, the overall level.
const STYLES := {
	"camp": {"root": 50, "scale": [0, 2, 4, 7, 9], "chords": [[0, 2, 4], [4, 0, 2], [3, 0, 2], [1, 3, 0]],
		"bpm": 60, "density": 0.22, "voice": "kalimba", "octave": 2, "level": 0.9},
	"lava": {"root": 57, "scale": [0, 2, 4, 7, 9], "chords": [[0, 2, 4], [3, 0, 1], [4, 1, 2], [2, 4, 0]],
		"bpm": 72, "density": 0.34, "voice": "kalimba", "octave": 1, "level": 0.95},
	"barranco": {"root": 55, "scale": [0, 2, 4, 5, 7, 9, 11], "chords": [[0, 2, 4], [3, 5, 0], [5, 0, 2], [4, 6, 1]],
		"bpm": 76, "density": 0.38, "voice": "kalimba", "octave": 1, "level": 0.95},
	"summit": {"root": 50, "scale": [0, 2, 3, 5, 7, 8, 10], "chords": [[0, 2, 4], [5, 0, 2], [3, 5, 0], [4, 6, 1]],
		"bright": [[0, 2, 4], [4, 6, 1], [5, 0, 2], [3, 5, 0]], "brightScale": [0, 2, 4, 5, 7, 9, 11],
		"bpm": 56, "density": 0.16, "voice": "bell", "octave": 2, "level": 1.0},
	"descent": {"root": 53, "scale": [0, 2, 4, 5, 7, 9, 11], "chords": [[0, 2, 4], [5, 0, 2], [3, 5, 0], [4, 6, 1]],
		"bpm": 66, "density": 0.28, "voice": "kalimba", "octave": 1, "level": 0.9},
	"crag": {"root": 48, "scale": [0, 2, 4, 5, 7, 9, 11], "chords": [[0, 2, 4, 6], [5, 0, 2, 4], [1, 3, 5, 0], [4, 6, 1, 3]],
		"bpm": 70, "density": 0.3, "voice": "keys", "octave": 2, "level": 0.95, "swing": 0.12},
}

## 0..1: the summit's dawn. Above one half, the bright chords and scale.
var mood := 0.0
var style_name := ""
var _style: Dictionary = {}
var _gen: AudioStreamGeneratorPlayback
var _ring := PackedFloat32Array()
var _read := 0
var _sched := 0
var _bar := 0
var _last_step := 2
var _rng := RandomNumberGenerator.new()
var _cache := {}
var _frames := PackedVector2Array()


func _ready() -> void:
	var g := AudioStreamGenerator.new()
	g.mix_rate = RATE
	g.buffer_length = 0.4
	stream = g
	_ring.resize(RING)
	# The web build has no audio thread: mix this one in the engine's own
	# mixer, as a stream (the default there is browser samples).
	if OS.has_feature("web"):
		playback_type = AudioServer.PLAYBACK_TYPE_STREAM


## Starts a style ("" for silence). Keeps going if it is the same one.
func set_style(name: String) -> void:
	if name == style_name:
		return
	style_name = name
	_style = STYLES.get(name, {})
	if _style.is_empty():
		stop()
		_gen = null
		return
	_rng.seed = hash(name)
	_ring.fill(0.0)
	_bar = 0
	_last_step = 2
	mood = 0.0
	if not playing:
		play()
	_gen = get_stream_playback()
	_read = 0
	_sched = int(RATE * 0.1)


func _process(_delta: float) -> void:
	if _gen == null or not playing:
		return
	var n := _gen.get_frames_available()
	if n <= 0:
		return
	while _sched < _read + n + RATE:
		_schedule_bar()
	if _frames.size() != n:
		_frames.resize(n)
	var lvl: float = _style.get("level", 1.0) * LOUD
	for i in n:
		var k := (_read + i) % RING
		var v := _ring[k] * lvl
		_ring[k] = 0.0
		_frames[i] = Vector2(v, v)
	_gen.push_buffer(_frames)
	_read += n


func _bar_len() -> int:
	return int(RATE * 60.0 / float(_style["bpm"]) * 4.0)


func _scale() -> Array:
	return _style.get("brightScale", _style["scale"]) if mood > 0.5 else _style["scale"]


func _midi(step: int, octave: int) -> int:
	var sc: Array = _scale()
	var o := int(floor(float(step) / sc.size()))
	return int(_style["root"]) + 12 * (octave + o) + int(sc[posmod(step, sc.size())])


## One bar: the chord (pad), the bass on the one, and the plucks.
func _schedule_bar() -> void:
	var bar := _bar_len()
	var chords: Array = _style.get("bright", _style["chords"]) if mood > 0.5 else _style["chords"]
	var chord: Array = chords[_bar % chords.size()]
	_add(_chord(chord, bar), _sched, 1.0)
	var eighth := bar / 8
	var swing := int(eighth * float(_style.get("swing", 0.0)))
	var voice: String = _style["voice"]
	var octave := int(_style["octave"])
	for e in 8:
		var p: float = _style["density"] * (1.6 if e == 0 or e == 4 else 1.0)
		if _rng.randf() >= p:
			continue
		# Mostly steps, now and then a leap; leaning on the chord's notes.
		var move: int = [-2, -1, -1, 1, 1, 2, 0, 3, -3][_rng.randi() % 9]
		var step := clampi(_last_step + move, -2, 9)
		if _rng.randf() < 0.45:
			step = int(chord[_rng.randi() % chord.size()]) + (_scale().size() if _rng.randf() < 0.4 else 0)
		_last_step = step
		var at := _sched + e * eighth + (swing if e % 2 == 1 else 0)
		_add(_note(voice, _midi(step, octave), 0), at, 0.22 * _rng.randf_range(0.7, 1.0))
	_sched += bar
	_bar += 1


func _add(note: Dictionary, at: int, gain: float) -> void:
	var buf: PackedFloat32Array = note["buf"]
	if not note["slow"]:
		for j in buf.size():
			var k := (at + j) % RING
			_ring[k] += buf[j] * gain
		return
	# Quarter-rate notes (pads, bass): linear between their samples.
	var m := buf.size() - 1
	for j in m * 4:
		var i := j >> 2
		var f := float(j & 3) * 0.25
		var k := (at + j) % RING
		_ring[k] += (buf[i] + (buf[i + 1] - buf[i]) * f) * gain


## A bar's pad chord and bass note, mixed once into one quarter-rate
## buffer and cached (one add a bar, not four).
func _chord(chord: Array, bar: int) -> Dictionary:
	var midis: Array = []
	for step in chord:
		midis.append(_midi(int(step), 0))
	var bass := _midi(int(chord[0]), -1)
	var key := "chord:%s:%d:%d" % [str(midis), bass, bar]
	if _cache.has(key):
		return _cache[key]
	var parts: Array = []
	for m in midis:
		parts.append([_note("pad", m, bar)["buf"], 0.11])
	parts.append([_note("bass", bass, bar)["buf"], 0.2])
	var size := 0
	for p in parts:
		size = maxi(size, (p[0] as PackedFloat32Array).size())
	var out := PackedFloat32Array()
	out.resize(size)
	for p in parts:
		var b: PackedFloat32Array = p[0]
		var g: float = p[1]
		for i in b.size():
			out[i] += b[i] * g
	var note := {"buf": out, "slow": true}
	_cache[key] = note
	return note


## A note's samples, cached: {buf, slow (quarter rate)}, by kind, MIDI note
## and, for pads and bass, the bar length.
func _note(kind: String, midi: int, bar: int) -> Dictionary:
	var key := "%s:%d:%d" % [kind, midi, bar]
	if _cache.has(key):
		return _cache[key]
	var f := 440.0 * pow(2.0, (midi - 69) / 12.0)
	var out := PackedFloat32Array()
	match kind:
		"pad", "bass":
			# Quarter rate. A pad swells in and out over the bar (and a
			# little past it); the bass is a soft round tone on the one.
			var r := RATE / 4.0
			var length := float(bar) / RATE + (1.2 if kind == "pad" else 0.6)
			var n := int(length * r)
			out.resize(n + 1)
			var w := TAU * f / r
			for i in n + 1:
				var t := i / r
				var env: float
				if kind == "pad":
					env = minf(1.0, t / 1.0) * minf(1.0, maxf(0.0, (length - t) / 1.4))
					out[i] = (sin(w * i) + 0.6 * sin(w * 1.004 * i) + 0.18 * sin(2.0 * w * i)) * env * 0.55
				else:
					env = minf(1.0, t / 0.02) * exp(-t * 1.6)
					out[i] = (sin(w * i) + 0.25 * sin(2.0 * w * i)) * env
		_:
			# Full rate, short. Kalimba: a round tine with a bright clink at
			# the start. Bell: longer, with a soft inharmonic shimmer. Keys:
			# an electric piano's gentle tremolo.
			var length: float = {"kalimba": 1.5, "bell": 2.6, "keys": 1.8}.get(kind, 1.5)
			var n := int(length * RATE)
			out.resize(n)
			var w := TAU * f / RATE
			# Overtones above 10 kHz would fold back (aliasing): leave them out.
			var hi := 1.0 if f * 5.4 < 10000.0 else 0.0
			var mid := 1.0 if f * 2.76 < 10000.0 else 0.0
			for i in n:
				var t := float(i) / RATE
				var att := minf(1.0, t / 0.004)
				var v: float
				match kind:
					"bell":
						v = (sin(w * i) * exp(-t * 1.3) + 0.35 * mid * sin(w * 2.76 * i) * exp(-t * 2.4) + 0.18 * hi * sin(w * 5.4 * i) * exp(-t * 4.0))
					"keys":
						v = (sin(w * i) + 0.25 * sin(w * 2.0 * i) * exp(-t * 3.0)) * exp(-t * 1.8) * (0.85 + 0.15 * sin(TAU * 4.5 * t))
					_:
						v = sin(w * i) * exp(-t * 3.0) + 0.3 * sin(w * 2.0 * i) * exp(-t * 6.0) + 0.22 * hi * sin(w * 5.4 * i) * exp(-t * 18.0)
				out[i] = v * att
	var note := {"buf": out, "slow": kind == "pad" or kind == "bass"}
	_cache[key] = note
	return note
