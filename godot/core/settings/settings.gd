extends Node
## Player settings (autoload `Settings`). Quality changes presentation only:
## particles, fog layers, lights. The simulation never reads it.

signal changed
## The game lost the player: the app went to the background, the window or
## browser tab lost focus, or the phone locked. Levels pause and save.
signal interrupted
## The Android back button (or gesture). Levels open their pause menu,
## menus go back a screen.
signal back_requested

enum Quality { FULL, REDUCED, LOW_POWER }

const PATH := "user://climb_up_settings.json"

var quality: int = Quality.FULL
var reduced_motion := false
## null: automatic (on for touch devices). true / false: the player's choice.
var touch_controls: Variant = null
var master_volume := 0.8
## A frame-rate readout in the corner, for playtests.
var show_fps := false
## Short buzzes on phones (grabs, clips, falls). Apart from reduced motion.
var haptics := true
## Sound effects and music, each 0 … 1, under master_volume.
var effects_volume := 1.0
var music_volume := 0.6
## The touch buttons and stick: 0.85 … 1.3 of their size, and the buttons
## on the left (the stick on the right) for left-handed play.
var touch_scale := 1.0
var left_handed := false
## Usage events written on this device (Analytics); and whether they may
## be sent anywhere. Nothing sends them yet: share_usage stays off until a
## consent screen and a provider exist (docs/analytics.md).
var log_usage := true
var share_usage := false


func _ready() -> void:
	# The back button is the game's to handle (pause, or back a screen).
	get_tree().set_quit_on_go_back(false)
	_drop_shader_cache()
	load_settings()
	get_tree().root.size_changed.connect(_fit_view)
	_fit_view()


## A short notice over any screen (a save that did not land). The same
## words are not shown again within `quiet` seconds.
var last_notice := ""
var _notice_label: Label
var _notice_at := {}


func notice(text: String, quiet: float = 0.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if quiet > 0.0 and _notice_at.has(text) and now - float(_notice_at[text]) < quiet:
		return
	_notice_at[text] = now
	last_notice = text
	if _notice_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_notice_label = Label.new()
		_notice_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_notice_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_notice_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_notice_label.offset_bottom = -8
		_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_notice_label.custom_minimum_size = Vector2(300, 0)
		_notice_label.add_theme_font_size_override("font_size", 8)
		_notice_label.add_theme_color_override("font_color", Color("#fff3e0"))
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.45, 0.16, 0.1, 0.92)
		bg.set_content_margin_all(4)
		bg.set_corner_radius_all(2)
		_notice_label.add_theme_stylebox_override("normal", bg)
		layer.add_child(_notice_label)
	_notice_label.text = text
	_notice_label.visible = true
	get_tree().create_timer(5.0, true, false, true).timeout.connect(func() -> void:
		if _notice_label and _notice_label.text == text:
			_notice_label.visible = false)


## The shader cache is off (project.godot): some GPU drivers report a
## compiled shader's size wrongly, and the cache then grew to gigabytes on
## the device and got the game killed for memory at start. Builds before
## that may have left one behind: remove it. The game's shaders are few and
## small, so compiling them each start costs little.
static func _drop_shader_cache(root: String = "user://shader_cache") -> void:
	if not DirAccess.dir_exists_absolute(root):
		return
	var stack: Array[String] = [root]
	var dirs: Array[String] = []
	while not stack.is_empty():
		var d: String = stack.pop_back()
		dirs.append(d)
		for f in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d.path_join(f))
		for sub in DirAccess.get_directories_at(d):
			stack.append(d.path_join(sub))
	dirs.reverse()
	for d in dirs:
		DirAccess.remove_absolute(d)


## Pixel art stays sharp at a whole-number scale. The scale is the one that
## makes the view closest to 270 pixels tall, and the view is then sized to
## fill the whole screen at that scale: no blurry fractional pixels, and no
## black bars on phones whose height is not a multiple of 270.
func _fit_view() -> void:
	var root := get_tree().root
	var screen := Vector2(root.size)
	if screen.y <= 0:
		return
	var k := maxf(1.0, roundf(screen.y / 270.0))
	root.content_scale_size = Vector2i(ceili(screen.x / k), ceili(screen.y / k))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			interrupted.emit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			back_requested.emit()


func touch_enabled() -> bool:
	if touch_controls != null:
		return touch_controls
	if _touch_auto == null:
		_touch_auto = _detect_touch()
	return _touch_auto


var _touch_auto: Variant = null


## Desktop test displays can report a touchscreen, so trust the platform:
## mobile builds always, and browsers whose primary pointer is a finger.
static func _detect_touch() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		# The bridge hands booleans back as numbers.
		var coarse: Variant = JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches ? 1 : 0", true)
		return int(coarse) == 1
	return false


## The screen's safe margins (notches, rounded corners, gesture bars) in
## view units: {left, right, top, bottom}. Zero where there is no cutout.
## Tests can set safe_override to a Rect2i in screen pixels.
var safe_override: Variant = null


func safe_insets() -> Dictionary:
	var out := {"left": 0.0, "right": 0.0, "top": 0.0, "bottom": 0.0}
	var root := get_tree().root
	var win := Vector2(root.size)
	if win.x <= 0 or win.y <= 0:
		return out
	var safe: Rect2i
	if safe_override != null:
		safe = safe_override
	elif OS.has_feature("mobile"):
		safe = DisplayServer.get_display_safe_area()
	else:
		return out
	if safe.size.x <= 0 or safe.size.y <= 0:
		return out
	var k := Vector2(root.content_scale_size) / win if root.content_scale_size.x > 0 else Vector2.ONE
	out["left"] = maxf(0.0, safe.position.x * k.x)
	out["top"] = maxf(0.0, safe.position.y * k.y)
	out["right"] = maxf(0.0, (win.x - safe.end.x) * k.x)
	out["bottom"] = maxf(0.0, (win.y - safe.end.y) * k.y)
	return out


func particle_scale() -> float:
	return [1.0, 0.5, 0.2][quality]


func fog_layers() -> int:
	return [3, 2, 1][quality]


func lights_enabled() -> bool:
	return quality != Quality.LOW_POWER


func set_quality(value: int) -> void:
	quality = clampi(value, 0, 2)
	save_settings()
	changed.emit()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	save_settings()
	changed.emit()


func set_show_fps(value: bool) -> void:
	show_fps = value
	save_settings()
	changed.emit()


func set_haptics(value: bool) -> void:
	haptics = value
	save_settings()
	changed.emit()


func set_touch_controls(value: Variant) -> void:
	touch_controls = value
	save_settings()
	changed.emit()


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	save_settings()
	changed.emit()


func to_dict() -> Dictionary:
	return {"quality": quality, "reducedMotion": reduced_motion, "touchControls": touch_controls, "volume": master_volume, "showFps": show_fps, "haptics": haptics,
		"effects": effects_volume, "music": music_volume, "touchScale": touch_scale, "leftHanded": left_handed, "logUsage": log_usage}


func apply_dict(d: Variant) -> void:
	if typeof(d) != TYPE_DICTIONARY:
		return
	var q: Variant = d.get("quality", Quality.FULL)
	quality = clampi(int(q), 0, 2) if typeof(q) == TYPE_INT or typeof(q) == TYPE_FLOAT else Quality.FULL
	reduced_motion = _flag(d.get("reducedMotion"), false)
	var t: Variant = d.get("touchControls")
	touch_controls = t if typeof(t) == TYPE_BOOL else null
	var v: Variant = d.get("volume", 0.8)
	master_volume = clampf(float(v), 0.0, 1.0) if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT else 0.8
	show_fps = _flag(d.get("showFps"), false)
	haptics = _flag(d.get("haptics"), true)
	effects_volume = _level(d.get("effects"), 1.0, 0.0, 1.0)
	music_volume = _level(d.get("music"), 0.6, 0.0, 1.0)
	touch_scale = _level(d.get("touchScale"), 1.0, 0.85, 1.3)
	left_handed = _flag(d.get("leftHanded"), false)
	log_usage = _flag(d.get("logUsage"), true)


## A number from a saved file, kept in [lo, hi], or `default`.
static func _level(v: Variant, default: float, lo: float, hi: float) -> float:
	return clampf(float(v), lo, hi) if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT else default


## A yes/no from a saved file, or `default` when it is anything else.
static func _flag(v: Variant, default: bool) -> bool:
	return v if typeof(v) == TYPE_BOOL else default


func save_settings() -> void:
	SaveGame.write(to_dict(), PATH)


func load_settings() -> void:
	var data: Variant = SaveGame.read(PATH)
	if data != null:
		apply_dict(data)
