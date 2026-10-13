class_name SettingsMenu
extends RefCounted
## The settings page, the same in every level's pause menu: graphics,
## motion, sound (music and effects apart), vibration, the touch controls
## (on, size, which hand) and the usage log. Each choice steps to the next
## value and the page shows again.

const MUSIC := [0.0, 0.3, 0.6, 1.0]
const EFFECTS := [0.0, 0.5, 1.0]
const SIZES := [0.85, 1.0, 1.15, 1.3]


static func _pct(v: float) -> String:
	return "Off" if v <= 0.001 else "%d%%" % int(round(v * 100.0))


static func choices() -> Array:
	return [
		["s_music", "Music: %s" % _pct(Settings.music_volume)],
		["s_effects", "Sound effects: %s" % _pct(Settings.effects_volume)],
		["s_haptics", "Vibration: %s" % ("On" if Settings.haptics else "Off")],
		["s_touch", "Touch controls: %s" % ("On" if Settings.touch_enabled() else "Off")],
		["s_size", "Control size: %s" % ["Small", "Normal", "Large", "Extra large"][maxi(0, SIZES.find(Settings.touch_scale))]],
		["s_hand", "Controls for: %s hand" % ("left" if Settings.left_handed else "right")],
		["s_quality", "Graphics: %s" % ["Full", "Reduced", "Low power"][Settings.quality]],
		["s_motion", "Reduced motion: %s" % ("On" if Settings.reduced_motion else "Off")],
		["s_usage", "Usage log on this device: %s" % ("On" if Settings.log_usage else "Off")],
		["s_export", "Copy my usage log (for playtests)"],
		["s_fps", "Show FPS: %s" % ("On" if Settings.show_fps else "Off")],
	]


static func _next(list: Array, now: float) -> float:
	var i := 0
	for k in list.size():
		if absf(list[k] - now) < 0.01:
			i = k
	return list[(i + 1) % list.size()]


## Applies a settings choice. Returns false when `id` is not one.
static func apply(id: String, level: Node) -> bool:
	match id:
		"s_music":
			Settings.set_value("music_volume", _next(MUSIC, Settings.music_volume))
		"s_effects":
			Settings.set_value("effects_volume", _next(EFFECTS, Settings.effects_volume))
			Audio.play("chalk", -6.0)
		"s_haptics":
			Settings.set_haptics(not Settings.haptics)
			Haptics.tap(30)
		"s_touch":
			Settings.set_touch_controls(not Settings.touch_enabled())
			TouchControls.attach(level)
		"s_size":
			Settings.set_value("touch_scale", _next(SIZES, Settings.touch_scale))
			TouchControls.attach(level)
		"s_hand":
			Settings.set_value("left_handed", not Settings.left_handed)
			TouchControls.attach(level)
		"s_quality":
			Settings.set_quality((Settings.quality + 1) % 3)
			Scenery.apply_quality(level)
		"s_motion":
			Settings.set_reduced_motion(not Settings.reduced_motion)
		"s_usage":
			Settings.set_value("log_usage", not Settings.log_usage)
		"s_fps":
			Settings.set_show_fps(not Settings.show_fps)
		"s_export":
			# For playtesters: the device's log as text, to paste into the
			# survey. Nothing is sent by the game.
			Analytics.flush()
			DisplayServer.clipboard_set(Analytics.export_text())
			var hud: Variant = level.get("hud")
			if hud != null:
				hud.flash("Usage log copied: %d events. Paste it into the playtest form." % Analytics.read_all().size(), 3.0)
			return true
		_:
			return false
	Analytics.event("settings_changed", {"setting": id.substr(2)})
	return true
