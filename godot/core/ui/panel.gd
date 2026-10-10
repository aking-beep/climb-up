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
var open := false


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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_box.add_child(v)
	_kicker = _label(7, MUTED, UiFont.body())
	v.add_child(_kicker)
	_title = _label(12, INK, UiFont.display())
	v.add_child(_title)
	_body = _label(8, INK, UiFont.body())
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(240, 0)
	v.add_child(_body)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 2)
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
	_kicker.text = kicker.to_upper()
	_kicker.visible = not kicker.is_empty()
	_title.text = title
	_title.visible = not title.is_empty()
	_body.text = body
	_body.visible = not body.is_empty()
	for c in _buttons.get_children():
		c.queue_free()
	var first: Button = null
	for choice in choices:
		var b := Button.new()
		b.text = choice[1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 9)
		if UiFont.display():
			b.add_theme_font_override("font", UiFont.display())
		b.disabled = choice.size() > 2 and choice[2] == true
		UiStyle.paper_button(b)
		b.custom_minimum_size = Vector2(0, 18)
		var id: String = choice[0]
		b.pressed.connect(func() -> void: _choose(id))
		_buttons.add_child(b)
		if first == null and not b.disabled:
			first = b
	visible = true
	open = true
	if first:
		first.call_deferred("grab_focus")


func _choose(id: String) -> void:
	hide_panel()
	chosen.emit(id)


func hide_panel() -> void:
	visible = false
	open = false


## Picks a choice by id, as a tap or key press would. For tests and replays.
func choose(id: String) -> void:
	if open:
		_choose(id)
