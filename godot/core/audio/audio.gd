extends Node
## Sound (autoload `Audio`): one-shot effects with variation, and looping
## ambience whose level follows the world (wind on exposed ground, camp
## sounds near the tents), and quiet music (play_music: one loop at a time,
## crossfaded). Quiet by design: the mountain is often silent but for wind
## and breath. Footsteps and hand sounds sit low (TRIM) under the music.
## The music is made as it plays (MusicBox). Effects and music have their own volume (Settings), under
## the master volume; at zero they are silent and the game plays the same.
## All sounds are placeholders (assets/audio/README.md).

const DIR := "res://assets/audio/placeholder/"
const SETS := {
	"step_dirt": ["step_dirt_0", "step_dirt_1", "step_dirt_2"],
	"step_rock": ["step_rock_0", "step_rock_1", "step_rock_2"],
	"grip": ["grip_0", "grip_1"],
	"rockfall": ["rockfall"],
	"breath": ["breath"],
	"slip": ["slip"],
	"chime": ["chime"],
	"cairn": ["cairn"],
	"gust": ["gust"],
	"clip": ["clip"],
	"chalk": ["chalk"],
	"whip": ["whip"],
	"thud": ["thud"],
	"catch": ["catch"],
	"sloper": ["sloper"],
	"pocket": ["pocket"],
	"jug": ["jug"],
	"topout": ["topout"],
	"record": ["record"],
	"perfect": ["perfect"],
}
## Music styles (MusicBox.STYLES): made as it plays, nothing shipped.
const MUSIC := ["camp", "crag", "lava", "barranco", "summit", "descent"]
## Movement sounds sit under the music: footsteps, hops, holds and chalk
## are this many dB quieter than the level they are asked for at.
const TRIM := {"step_dirt": -10.0, "step_rock": -10.0, "grip": -8.0, "jug": -7.0, "sloper": -7.0, "pocket": -7.0,
	"chalk": -6.0, "breath": -5.0, "catch": -3.0, "clip": -3.0}

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _wind: AudioStreamPlayer
var _camp: AudioStreamPlayer
var _wind_target := 0.0
var _camp_target := 0.0
var _music: MusicBox
var _music_name := ""
## The last effect played (for tests: the game asked for a sound).
var last := ""


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_wind = _loop("wind_loop")
	_camp = _loop("camp_loop")
	_music = MusicBox.new()
	_music.name = "Music"
	_music.volume_db = -60.0
	add_child(_music)


func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var path := DIR + name + ".wav"
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[name]


func _loop(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := _stream(name)
	if s is AudioStreamWAV:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		# In samples. (Not from the data's size: imported sounds are
		# compressed.)
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	p.stream = s
	p.volume_db = -60.0
	add_child(p)
	return p


func play(kind: String, volume_db: float = -6.0, pitch_spread: float = 0.08) -> void:
	var names: Array = SETS.get(kind, [])
	if names.is_empty():
		return
	last = kind
	if Settings.effects_volume <= 0.001 or Settings.master_volume <= 0.001:
		return
	var s := _stream(names[randi() % names.size()])
	if s == null:
		return
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = s
	p.volume_db = volume_db + float(TRIM.get(kind, 0.0)) + linear_to_db(Settings.master_volume * Settings.effects_volume)
	p.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	p.play()


## 0 … 1: how much wind the climber hears.
func set_wind(level: float) -> void:
	_wind_target = clampf(level, 0.0, 1.0)


func set_camp(level: float) -> void:
	_camp_target = clampf(level, 0.0, 1.0)


func stop_ambience() -> void:
	_wind_target = 0.0
	_camp_target = 0.0


## Starts a music style (a MUSIC name), or "" for none (it fades out).
func play_music(name: String) -> void:
	if name == _music_name:
		return
	_music_name = name
	if name != "":
		_music.volume_db = -40.0
		_music.set_style(name)


func music_playing() -> String:
	return _music_name


## 0..1: the summit's dawn, for the music (it turns to a major key).
func set_music_mood(m: float) -> void:
	_music.mood = clampf(m, 0.0, 1.0)


func _process(delta: float) -> void:
	_fade(_wind, _wind_target, delta, -4.0)
	_fade(_camp, _camp_target, delta, -10.0)
	var level := Settings.master_volume * Settings.music_volume
	var want := -60.0 if _music_name == "" or level <= 0.001 else -10.0 + linear_to_db(level)
	_music.volume_db = move_toward(_music.volume_db, want, 12.0 * delta)
	if _music.volume_db <= -59.0 and _music_name == "" and _music.style_name != "":
		_music.set_style("")


func _fade(p: AudioStreamPlayer, target: float, delta: float, loudest_db: float) -> void:
	if p.stream == null:
		return
	var want := -60.0 if target <= 0.01 or Settings.effects_volume <= 0.001 else lerpf(-34.0, loudest_db, target) + linear_to_db(Settings.master_volume * Settings.effects_volume)
	p.volume_db = move_toward(p.volume_db, want, 30.0 * delta)
	if target > 0.01 and not p.playing:
		p.play()
	elif target <= 0.01 and p.playing and p.volume_db <= -59.0:
		p.stop()
