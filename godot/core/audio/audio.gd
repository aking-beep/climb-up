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
	# The action button: a short click, pitched by the verb that took the tap.
	"tap": ["clip"],
	# A new achievement on the results card.
	"sting": ["perfect"],
}
## Music styles (MusicBox.STYLES): made as it plays, nothing shipped.
const MUSIC := ["camp", "crag", "lava", "barranco", "summit", "descent"]
## The music leads. The climber's own sounds (footsteps, hops, hands on
## holds, chalk, breathing) sit underneath it: this many dB quieter than
## the level they are asked for at. Footsteps are faintest; a hand landing
## on a hold is one tick that still carries over the music. Everything else
## (clips, catches, cairns, stones) is a little quieter too (EFFECTS_DB).
## A sound that answers the player's own tap (an accepted squeeze, the
## clip's gate) skips the trim: play(..., body = false).
const TRIM := {"step_dirt": -24.0, "step_rock": -24.0, "grip": -8.0, "jug": -8.0, "sloper": -8.0, "pocket": -8.0,
	"chalk": -18.0, "breath": -16.0, "catch": -10.0, "clip": -10.0}
const EFFECTS_DB := -4.0
## The music's level at full volume settings (dB).
const MUSIC_DB := -4.0

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _wind: AudioStreamPlayer
var _camp: AudioStreamPlayer
var _wind_target := 0.0
var _camp_target := 0.0
var _music: MusicBox
var _music_name := ""
## The last effect played (for tests: the game asked for a sound), and
## its level before the volume settings (dB).
var last := ""
var last_db := 0.0
## Every effect asked for, newest last (for tests; the last 32).
var history: Array = []


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


## Plays one of SETS. `body`: apply TRIM (the climber's own sounds sit
## under the music); false for a sound that answers a tap. `pitch` moves
## the whole sound (a lower tick for a squeeze that was too soon).
func play(kind: String, volume_db: float = -6.0, pitch_spread: float = 0.08, body: bool = true, pitch: float = 1.0) -> void:
	var names: Array = SETS.get(kind, [])
	if names.is_empty():
		return
	last = kind
	history.append(kind)
	if history.size() > 32:
		history.pop_front()
	if Settings.effects_volume <= 0.001 or Settings.master_volume <= 0.001:
		return
	var s := _stream(names[randi() % names.size()])
	if s == null:
		return
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = s
	last_db = volume_db + EFFECTS_DB + (float(TRIM.get(kind, 0.0)) if body else 0.0)
	p.volume_db = last_db + linear_to_db(Settings.master_volume * Settings.effects_volume)
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_spread, pitch_spread))
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
	# Wind and camp sounds sit under the music too.
	_fade(_wind, _wind_target, delta, -12.0)
	_fade(_camp, _camp_target, delta, -18.0)
	var level := Settings.master_volume * Settings.music_volume
	var want := -60.0 if _music_name == "" or level <= 0.001 else MUSIC_DB + linear_to_db(level)
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
