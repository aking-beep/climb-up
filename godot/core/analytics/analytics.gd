extends Node
## Product analytics (autoload `Analytics`), local only. Events for the
## playtest questions (does the tutorial get finished, are routes replayed,
## do people come back) are written to a file on the device and go nowhere
## else: there is no network code here and no third-party SDK.
##
## What is recorded: an event name from EVENTS, a few game facts (route id,
## style, falls, seconds...), the time to the second, and a session id made
## up at launch (random, not tied to the device or the player). No names,
## no device ids, no location, no advertising ids.
##
## Later, a consent-aware provider can be connected with add_sink(): a sink
## is only called when the player has said yes (Settings.share_usage), and
## gets the same events. See docs/analytics.md.

const PATH := "user://climb_up_events.jsonl"
## The file is trimmed to the newest MAX_LINES events.
const MAX_LINES := 2000
## Every event the game sends, and nothing else (anything else is dropped).
const EVENTS := [
	"game_launched", "session_ended", "mode_selected",
	"tutorial_started", "tutorial_completed",
	"route_started", "route_failed", "route_completed", "route_replayed",
	"daily_started", "daily_completed", "daily_shared",
	"expedition_started", "expedition_abandoned", "expedition_completed",
	"descent_completed", "achievement_earned", "settings_changed",
]

var session := ""
var _started_ms := 0
var _active_ms := 0
var _active_from := 0
var _buffer: Array = []
var _sinks: Array[Callable] = []
## Events kept in memory this session, for tests and a debug screen.
var recent: Array = []
## Set false in tests that do not want the file written.
var write_to_disk := true


func _ready() -> void:
	var bytes := Crypto.new().generate_random_bytes(8)
	session = bytes.hex_encode()
	_started_ms = Time.get_ticks_msec()
	_active_from = _started_ms
	event("game_launched", {"platform": OS.get_name(), "build": ProjectSettings.get_setting("application/config/version", "dev")})


## Records an event. Unknown names and anything but plain values in
## `props` are dropped.
func event(name: String, props: Dictionary = {}) -> void:
	if not name in EVENTS:
		push_warning("analytics: unknown event " + name)
		return
	var clean := {}
	for k in props:
		var v: Variant = props[k]
		if typeof(v) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]:
			clean[String(k)] = v if typeof(v) != TYPE_STRING_NAME else String(v)
	var e := {"e": name, "t": int(Time.get_unix_time_from_system()), "s": session, "p": clean}
	recent.append(e)
	if recent.size() > 200:
		recent.pop_front()
	_buffer.append(e)
	if Settings.share_usage:
		for sink in _sinks:
			if sink.is_valid():
				sink.call(e)
	if _buffer.size() >= 10 or name in ["session_ended", "route_completed", "route_failed", "daily_completed"]:
		flush()


## A provider's hook, called with each event once the player has agreed.
func add_sink(sink: Callable) -> void:
	_sinks.append(sink)


func count(name: String) -> int:
	return recent.filter(func(e: Dictionary) -> bool: return e["e"] == name).size()


## Seconds the game has been in the foreground this session.
func session_seconds() -> int:
	return int((_active_ms + (Time.get_ticks_msec() - _active_from if _active_from > 0 else 0)) / 1000)


func flush() -> void:
	if _buffer.is_empty() or not write_to_disk or not Settings.log_usage:
		_buffer.clear()
		return
	var lines: PackedStringArray = []
	if FileAccess.file_exists(PATH):
		lines = FileAccess.get_file_as_string(PATH).strip_edges().split("\n", false)
	for e in _buffer:
		lines.append(JSON.stringify(e))
	_buffer.clear()
	if lines.size() > MAX_LINES:
		lines = lines.slice(lines.size() - MAX_LINES)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")


## Everything recorded on this device (for the player to see, or delete).
func read_all() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(PATH):
		return out
	for line in FileAccess.get_file_as_string(PATH).split("\n", false):
		var e: Variant = JSON.parse_string(line)
		if typeof(e) == TYPE_DICTIONARY:
			out.append(e)
	return out


func erase() -> void:
	_buffer.clear()
	recent.clear()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _active_from > 0:
				_active_ms += Time.get_ticks_msec() - _active_from
				_active_from = 0
			event("session_ended", {"seconds": session_seconds()})
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _active_from == 0:
				_active_from = Time.get_ticks_msec()
		NOTIFICATION_WM_CLOSE_REQUEST:
			event("session_ended", {"seconds": session_seconds()})
