extends Node
## Sound (autoload `Audio`): one-shot effects with variation, and looping
## ambience whose level follows the world (wind on exposed ground, camp
## sounds near the tents). Quiet by design: the mountain is often silent
## but for wind and breath. All sounds are placeholders (assets/audio/README.md).

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
}

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _wind: AudioStreamPlayer
var _camp: AudioStreamPlayer
var _wind_target := 0.0
var _camp_target := 0.0


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_wind = _loop("wind_loop")
	_camp = _loop("camp_loop")


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
		s.loop_end = s.data.size() / 2
	p.stream = s
	p.volume_db = -60.0
	add_child(p)
	return p


func play(kind: String, volume_db: float = -6.0, pitch_spread: float = 0.08) -> void:
	var names: Array = SETS.get(kind, [])
	if names.is_empty():
		return
	var s := _stream(names[randi() % names.size()])
	if s == null:
		return
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = s
	p.volume_db = volume_db + linear_to_db(Settings.master_volume)
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


func _process(delta: float) -> void:
	_fade(_wind, _wind_target, delta, -4.0)
	_fade(_camp, _camp_target, delta, -10.0)


func _fade(p: AudioStreamPlayer, target: float, delta: float, loudest_db: float) -> void:
	if p.stream == null:
		return
	var want := -60.0 if target <= 0.01 else lerpf(-34.0, loudest_db, target) + linear_to_db(Settings.master_volume)
	p.volume_db = move_toward(p.volume_db, want, 30.0 * delta)
	if target > 0.01 and not p.playing:
		p.play()
	elif target <= 0.01 and p.playing and p.volume_db <= -59.0:
		p.stop()
