class_name Haptics
extends RefCounted
## A short buzz on phones for grabs, slips and gusts: the hands feel the
## mountain even when the eyes are on the route. Off with reduced motion,
## and a no-op wherever the platform has no vibration.


static func tap(ms: int) -> void:
	if Settings.reduced_motion or not Settings.touch_enabled():
		return
	if OS.has_feature("mobile") or OS.has_feature("web_android"):
		Input.vibrate_handheld(ms)
