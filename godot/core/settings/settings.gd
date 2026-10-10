extends Node
## Player settings (autoload `Settings`). Quality changes presentation only:
## particles, fog layers, lights. The simulation never reads it.

signal changed

enum Quality { FULL, REDUCED, LOW_POWER }

const PATH := "user://climb_up_settings.json"

var quality: int = Quality.FULL
var reduced_motion := false
## null: automatic (on for touch devices). true / false: the player's choice.
var touch_controls: Variant = null
var master_volume := 0.8


func _ready() -> void:
	load_settings()


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


func set_touch_controls(value: Variant) -> void:
	touch_controls = value
	save_settings()
	changed.emit()


func to_dict() -> Dictionary:
	return {"quality": quality, "reducedMotion": reduced_motion, "touchControls": touch_controls, "volume": master_volume}


func apply_dict(d: Variant) -> void:
	if typeof(d) != TYPE_DICTIONARY:
		return
	quality = clampi(int(d.get("quality", Quality.FULL)), 0, 2)
	reduced_motion = d.get("reducedMotion") == true
	var t: Variant = d.get("touchControls")
	touch_controls = t if typeof(t) == TYPE_BOOL else null
	master_volume = clampf(float(d.get("volume", 0.8)), 0.0, 1.0)


func save_settings() -> void:
	SaveGame.write(to_dict(), PATH)


func load_settings() -> void:
	var data: Variant = SaveGame.read(PATH)
	if data != null:
		apply_dict(data)
