class_name Hud
extends CanvasLayer
## Stamina, slips, cairns, wind, and one line of advice. Every state shown
## in colour is also shown in words.

var _bar: ProgressBar
var _stats: Label
var _hint: Label
var _flash: Label
var _prompt: Label
var _wind: Label
var _flash_time := 0.0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var box := PanelContainer.new()
	box.position = Vector2(8, 6)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.066, 0.06, 0.55)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", style)
	root.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	box.add_child(v)
	var kicker := _label(6, Color(0.95, 0.94, 0.91, 0.8))
	kicker.text = "BARRANCO WALL"
	v.add_child(kicker)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(110, 5)
	_bar.show_percentage = false
	_bar.max_value = 100
	v.add_child(_bar)
	_stats = _label(7, Color(0.95, 0.94, 0.91))
	v.add_child(_stats)
	_wind = _label(7, Color(1.0, 0.85, 0.55))
	v.add_child(_wind)
	_hint = _label(7, Color(0.95, 0.94, 0.91))
	_hint.position = Vector2(8, 52)
	root.add_child(_hint)
	_flash = _label(9, Color(1, 0.97, 0.88))
	_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash.anchor_left = 0.2
	_flash.anchor_right = 0.8
	_flash.offset_top = 64
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_flash)
	_prompt = _label(8, Color(1, 0.97, 0.88))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.anchor_left = 0.3
	_prompt.anchor_right = 0.7
	_prompt.offset_top = -40
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 1)
	if UiFont.body():
		l.add_theme_font_override("font", UiFont.body())
	return l


func flash(text: String) -> void:
	_flash.text = text
	_flash_time = 2.6


func update_from(level: Node) -> void:
	var c: Climber = level.climber
	var pct := int(round(c.stamina.fraction() * 100.0))
	_bar.value = pct
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#c0573e") if pct < 25 else (Color("#d9a441") if pct < 50 else Color("#7fa36b"))
	_bar.add_theme_stylebox_override("fill", fill)
	var mate := ""
	if level.mate_state == "helped":
		mate = " · Marco: has your back" if c.spotter else " · Marco with you"
	_stats.text = "Stamina %d%% · Slips %d/%d · Cairn %d/%d%s" % [pct, c.slips, level.MAX_SLIPS, level.checkpoint, level.cairns.size() - 1, mate]
	match c.gust:
		WindSchedule.Phase.WARN:
			_wind.text = "Wind rising: stop and brace"
		WindSchedule.Phase.BLOW:
			_wind.text = "Gust: brace!" if c.state != Climber.State.BRACE else "Gust: braced"
		_:
			_wind.text = "Exposed: walk between gusts" if c.exposed else ""
	_hint.text = _hint_for(level)
	var key := "Tap" if Settings.touch_enabled() else "E:"
	_prompt.text = ("%s %s" % [key, level.prompt]) if level.prompt != "" else ""


func _hint_for(level: Node) -> String:
	var c: Climber = level.climber
	if c.state == Climber.State.SLIP:
		return ""
	if c.state == Climber.State.REST:
		return "Resting. Move to get up."
	if c.stamina.fraction() < 0.2:
		return "Arms are going. Get onto a ledge." if c.is_climbing() else "Out of breath. Sit and rest (REST)."
	if c.state == Climber.State.CLIMB:
		if c.terrain.hold_at(c.body_rect(c.global_position + Vector2(0, -4))) == Terrain.Kind.AIR:
			return "Top of the face. Hold UP to pull over."
		return ""
	if c.state == Climber.State.GROUND and c.terrain.touches_climbable(c.body_rect()):
		return "Rock. Hold UP to climb."
	return ""


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash.modulate.a = clampf(_flash_time, 0.0, 1.0)
