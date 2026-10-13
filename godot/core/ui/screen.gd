class_name Screen
extends Control
## Shared look for the menu, briefing and outcome screens: a painted
## backdrop of Kibo over the Barranco valley, and a paper card.

const PAPER := Color(0.953, 0.937, 0.902, 0.96)
const INK := Color(0.11, 0.098, 0.082)
const MUTED := Color(0.42, 0.39, 0.35)

var card: VBoxContainer
## The card scrolls when it is taller than the screen (a short phone held
## sideways): the list never runs off the top or bottom.
var scroll: ScrollContainer
const EDGE := 10.0


func _ready() -> void:
	Settings.back_requested.connect(on_back)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sky := ColorRect.new()
	sky.color = Color("#7f98a6")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var kibo := TextureRect.new()
	kibo.texture = load("res://assets/scenery/barranco-kibo.png")
	kibo.set_anchors_preset(Control.PRESET_FULL_RECT)
	kibo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kibo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	kibo.modulate = Color(0.95, 0.96, 1.0)
	add_child(kibo)
	var valley := TextureRect.new()
	valley.texture = load("res://assets/scenery/barranco-valley.png")
	valley.set_anchors_preset(Control.PRESET_FULL_RECT)
	valley.anchor_top = 0.45
	valley.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	valley.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	valley.modulate = Color(0.8, 0.82, 0.8)
	add_child(valley)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(3)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card)
	get_viewport().size_changed.connect(fit)
	# Measure again whenever the content changes size: wrapped text only
	# knows its height a frame after it is laid out, and measuring before
	# that left the card too short (the second choice behind a scrollbar).
	card.minimum_size_changed.connect(func() -> void: fit.call_deferred())
	fit.call_deferred()


## Sizes the card's window to its content, up to the height of the screen.
func fit() -> void:
	if not is_inside_tree():
		return
	var want := card.get_combined_minimum_size()
	var room := get_viewport_rect().size.y - 2.0 * EDGE - 22.0
	scroll.custom_minimum_size = Vector2(want.x, minf(want.y, room))


## The Android back button on this screen.
func on_back() -> void:
	pass


func kicker(text: String) -> Label:
	return _add(text.to_upper(), 7, MUTED, UiFont.body())


func title(text: String, size: int = 16) -> Label:
	return _add(text, size, INK, UiFont.display())


func text(value: String, size: int = 8, color: Color = INK) -> Label:
	var l := _add(value, size, color, UiFont.body())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(290, 0)
	return l


func _add(value: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	card.add_child(l)
	return l


func button(label: String, on_press: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 20)
	b.add_theme_font_size_override("font_size", 10)
	if UiFont.display():
		b.add_theme_font_override("font", UiFont.display())
	if not primary:
		UiStyle.paper_button(b)
	if primary:
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#1f3d34")
		st.content_margin_left = 8
		b.add_theme_stylebox_override("normal", st)
		var hover := st.duplicate()
		hover.bg_color = Color("#2b5246")
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("focus", hover)
		b.add_theme_color_override("font_color", Color("#e8f0e8"))
	b.pressed.connect(on_press)
	card.add_child(b)
	return b
