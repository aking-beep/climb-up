class_name Haptics
extends RefCounted
## A short buzz on phones for grabs, clips, slips and gusts: the hands feel
## the mountain even when the eyes are on the route. Its own setting
## (Settings.haptics), and a no-op wherever the platform has no vibration
## (desktop, iOS browsers). Android needs the VIBRATE permission, set in the
## export preset.

## The last buzz asked for, for tests (a buzz is not observable headless).
static var last_ms := 0


static func tap(ms: int) -> void:
	if not Settings.haptics or not Settings.touch_enabled():
		return
	last_ms = ms
	if OS.has_feature("mobile") or OS.has_feature("web_android"):
		Input.vibrate_handheld(ms)
