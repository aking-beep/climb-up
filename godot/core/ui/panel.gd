class_name StoryPanel
extends CanvasLayer
## The one dialogue surface: a speaker or title, a few lines, and choices.
## Used for camp conversations, signs, Marco, the decision after him, and
## the pause menu. Keyboard, gamepad and touch all work: choices are
## buttons, focus moves with up/down, interact confirms.

signal chosen(id: String)

const PAPER := Color(0.953, 0.937, 0.902, 0.97)
const INK := Color(0.11, 0.098, 0.082)
const MUTED := Color(0.42, 0.39, 0.35)
const SPRUCE := Color(0.122, 0.239, 0.204)

var _box: PanelContainer
var _title: Label
var _body: Label
var _buttons: VBoxContainer
var _kicker: Label
var _scroll: ScrollContainer
var _v: VBoxContainer
var open := false
## Taller than this share of the screen and the panel scrolls.
const MAX_SHARE := 0.94


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_box = PanelContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_box.anchor_left = 0.18
	_box.anchor_right = 0.82
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_bottom = -10
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color(0.36, 0.3, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 8
	_box.add_theme_stylebox_override("panel", style)
	root.add_child(_box)
	# A long brief on a short phone scrolls instead of running off the top.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_box.add_child(_scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(v)
	_v = v
	_kicker = _label(8, MUTED, UiFont.body())
	v.add_child(_kicker)
	_title = _label(12, INK, UiFont.display())
	v.add_child(_title)
	_body = _label(8, INK, UiFont.body())
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(240, 0)
	v.add_child(_body)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	v.add_child(_buttons)
	visible = false


func _label(size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l


## choices: Array of [id, label] (or [id, label, disabled]).
func show_panel(kicker: String, title: String, body: String, choices: Array) -> void:
	choice_ids = choices.map(func(c: Array) -> String: return c[0])
	_kicker.text = kicker.to_upper()
	_kicker.visible = not kicker.is_empty()
	_title.text = Plain.say(title)
	_title.visible = not title.is_empty()
	_body.text = Plain.say(body)
	_body.visible = not body.is_empty()
	for c in _buttons.get_children():
		# Out of the layout now, so the new panel is measured without them.
		_buttons.remove_child(c)
		c.queue_free()
	var first: Button = null
	for choice in choices:
		var b := Button.new()
		b.text = Plain.say(choice[1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 9)
		if UiFont.display():
			b.add_theme_font_override("font", UiFont.display())
		b.disabled = choice.size() > 2 and choice[2] == true
		UiStyle.paper_button(b)
		# About 36 CSS px on a phone: big enough for a thumb.
		b.custom_minimum_size = Vector2(0, 24)
		var id: String = choice[0]
		b.pressed.connect(func() -> void: _choose(id))
		_buttons.add_child(b)
		if first == null and not b.disabled:
			first = b
	visible = true
	open = true
	_fit.call_deferred()
	if first:
		first.call_deferred("grab_focus")


func _fit() -> void:
	if not is_inside_tree():
		return
	_size_box()
	# Open at the top (the title first), after focus has had its say; and
	# measure again once the labels have wrapped.
	await get_tree().process_frame
	if is_inside_tree():
		_size_box()
		_scroll.scroll_vertical = 0


func _size_box() -> void:
	var want := _v.get_combined_minimum_size().y
	var room := get_viewport().get_visible_rect().size.y * MAX_SHARE - 16.0
	_scroll.custom_minimum_size = Vector2(0, minf(want, room))
	# Shrink to this panel's content (it grows from the bottom edge, and
	# would otherwise keep the height of a taller panel before it).
	_box.offset_bottom = -10
	_box.offset_top = _box.offset_bottom - _box.get_combined_minimum_size().y


func _choose(id: String) -> void:
	hide_panel()
	chosen.emit(id)


func hide_panel() -> void:
	visible = false
	open = false


## The ids of the choices showing (or last shown).
var choice_ids: Array = []


func has_choice(id: String) -> bool:
	return open and choice_ids.has(id)


func kicker_text() -> String:
	return _kicker.text


func body_text() -> String:
	return _body.text


func title_text() -> String:
	return _title.text


## Picks a choice by id, as a tap or key press would. For tests and replays.
func choose(id: String) -> void:
	if open:
		_choose(id)
