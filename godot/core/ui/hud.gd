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
var title := "Climb"
var _route: ProgressBar
var _route_label: Label
var _fps: Label


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
	var kicker := _label(8, Color(0.95, 0.94, 0.91, 0.8))
	kicker.text = title.to_upper()
	v.add_child(kicker)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(140, 6)
	_bar.show_percentage = false
	_bar.max_value = 100
	v.add_child(_bar)
	_stats = _label(9, Color(0.95, 0.94, 0.91))
	v.add_child(_stats)
	_wind = _label(9, Color(1.0, 0.85, 0.55))
	v.add_child(_wind)
	_hint = _label(9, Color(0.95, 0.94, 0.91))
	_hint.position = Vector2(8, 66)
	_backed(_hint)
	root.add_child(_hint)
	_flash = _label(11, Color(1, 0.97, 0.88))
	_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash.anchor_left = 0.2
	_flash.anchor_right = 0.8
	_flash.offset_top = 84
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_flash)
	# Top right (left of pause): the everlastings carried.
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.anchor_left = 1.0
	top.anchor_right = 1.0
	top.offset_left = -190
	top.offset_right = -40
	top.offset_top = 8
	top.add_theme_constant_override("separation", 1)
	root.add_child(top)
	_route_label = _label(8, Color(0.98, 0.97, 0.94))
	_route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_route_label)
	# How far along is not shown: the climb is about the next move.
	_route = ProgressBar.new()
	_route.visible = false
	_route.custom_minimum_size = Vector2(150, 4)
	_route.show_percentage = false
	_route.max_value = 1.0
	var rf := StyleBoxFlat.new()
	rf.bg_color = Color("#e9c46a")
	_route.add_theme_stylebox_override("fill", rf)
	var rb := StyleBoxFlat.new()
	rb.bg_color = Color(0, 0, 0, 0.45)
	_route.add_theme_stylebox_override("background", rb)
	top.add_child(_route)
	_fps = _label(8, Color(0.7, 1.0, 0.7))
	_fps.position = Vector2(210, 2)
	root.add_child(_fps)
	_prompt = _label(10, Color(1, 0.97, 0.88))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.anchor_left = 0.3
	_prompt.anchor_right = 0.7
	_prompt.offset_top = -40
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt)


## A dark backing behind text drawn over the sky and the rock.
func _backed(l: Label) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.05, 0.07, 0.55)
	st.set_corner_radius_all(2)
	st.content_margin_left = 4
	st.content_margin_right = 4
	st.content_margin_top = 1
	st.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", st)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 1)
	if UiFont.body():
		l.add_theme_font_override("font", UiFont.body())
	return l


func flash(text: String, seconds: float = 2.6) -> void:
	_flash.text = text
	_flash_time = seconds


## The message showing now (or the last one), for tests.
func flash_text() -> String:
	return _flash.text


func update_from(level: Node) -> void:
	var c: Climber = level.climber
	var pct := int(round(c.stamina.fraction() * 100.0))
	_bar.value = pct
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#c0573e") if pct < 25 else (Color("#d9a441") if pct < 50 else Color("#7fa36b"))
	_bar.add_theme_stylebox_override("fill", fill)
	var mate := ""
	if level.mate_state == "helped" and level.get("mate_winded"):
		mate = " · %s: winded" % level.mate_name()
	elif level.mate_state == "helped":
		mate = " · %s %d%%" % [level.mate_name(), int(level.mate_breath)]
	var gear := ""
	var hz: Hazards = level.get("hazards")
	if hz and hz.gear_total() > 0:
		gear = " · Gear %d/%d" % [hz.gear_count, hz.gear_total()]
	if level.has_method("route_progress"):
		_route.value = level.route_progress()
		var flowers := ""
		if hz and hz.flowers_total > 0:
			flowers = "  ·  everlastings %d/%d" % [hz.flowers, hz.flowers_total]
		_route_label.text = ("Everlastings %d" % hz.flowers) if hz and hz.flowers_total > 0 else ""
	if level.has_method("stats_line"):
		_stats.text = level.stats_line(pct)
	else:
		_stats.text = "Stamina %d%% · Slips %d/%d · Cairn %d/%d%s%s" % [pct, c.slips, level.max_slips, level.checkpoint, level.cairns.size() - 1, gear, mate]
	if level.get("mate_winded"):
		_wind.text = "%s is out of breath: go back and REST beside them" % level.mate_name()
	elif hz and hz.warned_here():
		_wind.text = "Rocks coming down: step aside!"
	elif hz and hz.slab_breaking():
		_wind.text = "The slab is cracking: keep moving!"
	elif c.cramp > 0.0:
		_wind.text = "Cramp: wait for it to pass"
	elif c.dizzy > 0.0:
		_wind.text = "Dizzy: slow down"
	elif level.get("creatures") and level.creatures.raven_coming():
		_wind.text = "A raven is diving: keep moving!"
	elif c.on_ice and c.state == Climber.State.GROUND:
		_wind.text = "Ice: small steps, it slides"
	else:
		_wind_line(c)
	_hint.text = _hint_for(level)
	_hint.visible = _hint.text != ""
	# On touch the context button says what it does; keys need the reminder.
	_prompt.text = ("E: %s" % level.prompt) if level.prompt != "" and not Settings.touch_enabled() else ""


func _wind_line(c: Climber) -> void:
	match c.gust:
		WindSchedule.Phase.WARN:
			_wind.text = "Wind rising: stop and brace"
		WindSchedule.Phase.BLOW:
			_wind.text = "Gust: brace!" if c.state != Climber.State.BRACE else "Gust: braced"
		_:
			_wind.text = "Exposed: walk between gusts" if c.exposed else ""


func _hint_for(level: Node) -> String:
	var c: Climber = level.climber
	if level.has_method("hint_now"):
		var own: String = level.hint_now()
		if own != "":
			return own
	if c.state == Climber.State.SLIP:
		return ""
	if c.state == Climber.State.REST:
		return "Resting. Move to get up."
	if c.stamina.fraction() < 0.2:
		return "Arms are going. Get onto a ledge." if c.is_climbing() else "Out of breath. Sit and REST."
	if c.state == Climber.State.CLIMB:
		if c.terrain.hold_at(c.body_rect(c.global_position + Vector2(0, -4))) == Terrain.Kind.AIR:
			return "Top of the face. Keep pushing UP to pull over."
		return ""
	var key := "JUMP" if Settings.touch_enabled() else "SPACE"
	if c.state == Climber.State.GROUND and (c.gap_ahead(c.facing) and not c.on_ice):
		return "A gap: %s to hop across." % key
	if c.state == Climber.State.GROUND and c.hurdle_ahead(c.facing):
		return "A boulder in the way: %s to hop over." % key
	var cr: Creatures = level.get("creatures")
	if cr and c.state == Climber.State.GROUND and cr.danger_ahead(c.global_position.x, c.global_position.y, c.facing, 40.0):
		return "Thorns or ants ahead: %s over them." % key
	var hz: Hazards = level.get("hazards")
	if hz and c.state == Climber.State.GROUND and hz.roller_near(c.global_position.x, c.global_position.y, 6.0 * Terrain.TILE):
		return "A stone is rolling at you: %s!" % key
	if c.state == Climber.State.GROUND and c.can_grab():
		return "Rock. Tap CLIMB, or push UP." if Settings.touch_enabled() else "Rock. Hold UP to climb (DOWN to climb down)."
	return ""


func _process(delta: float) -> void:
	_fps.text = ("%d FPS" % Engine.get_frames_per_second()) if Settings.show_fps else ""
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash.modulate.a = clampf(_flash_time, 0.0, 1.0)
