class_name UiKit
extends RefCounted
## Building blocks of the CLIMB UP 2.0 screens: paper panels, ink labels,
## buttons at least a thumb tall, chips, and the short eased motion the
## design asks for. Everything is made in code from UiTokens: no theme file.


static func box(bg: Color, radius: int = UiTokens.RADIUS, border: Color = Color(0, 0, 0, 0), border_w: int = 0, margin: float = 6.0) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_corner_radius_all(radius)
	if border_w > 0:
		st.border_color = border
		st.set_border_width_all(border_w)
	st.content_margin_left = margin
	st.content_margin_right = margin
	st.content_margin_top = margin * 0.7
	st.content_margin_bottom = margin * 0.7
	st.anti_aliasing = true
	return st


static func panel(bg: Color = UiTokens.PAPER, margin: float = 8.0, border: Color = UiTokens.PAPER_EDGE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, UiTokens.RADIUS, border, 1 if border.a > 0.0 else 0, margin))
	return p


static func label(text: String, size: int = UiTokens.TEXT, color: Color = UiTokens.INK, display: bool = false, wrap: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var font := UiFont.display() if display else UiFont.body()
	if font:
		l.add_theme_font_override("font", font)
	if wrap > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Text that reads on top of the painted world: chalk with a dark edge.
static func world_label(text: String, size: int = UiTokens.TEXT, display: bool = true) -> Label:
	var l := label(text, size, UiTokens.CHALK, display)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	return l


static func vbox(sep: int = 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


## kind: "primary" (spruce), "paper", "ghost" (flat), "dark" (on the world), "danger".
static func button(text: String, on_press: Callable, kind: String = "paper", size: int = UiTokens.TEXT_L) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, UiTokens.TAP)
	b.add_theme_font_size_override("font_size", size)
	if UiFont.display():
		b.add_theme_font_override("font", UiFont.display())
	style_button(b, kind)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	b.pressed.connect(func() -> void: press_feel(b))
	return b


static func style_button(b: Button, kind: String) -> void:
	var bg := UiTokens.PAPER_RAISED
	var fg := UiTokens.INK
	var edge := UiTokens.PAPER_EDGE
	var hover_bg := Color(1, 0.99, 0.96)
	match kind:
		"primary":
			bg = UiTokens.SPRUCE
			fg = UiTokens.SPRUCE_INK
			edge = UiTokens.SPRUCE
			hover_bg = UiTokens.SPRUCE_HOVER
		"danger":
			bg = UiTokens.EMBER
			fg = UiTokens.CHALK
			edge = UiTokens.EMBER
			hover_bg = UiTokens.EMBER_SOFT
		"dark":
			bg = UiTokens.SCRIM
			fg = UiTokens.CHALK
			edge = Color(1, 1, 1, 0.15)
			hover_bg = Color(0, 0, 0, 0.75)
		"ghost":
			bg = Color(0, 0, 0, 0)
			edge = Color(0, 0, 0, 0)
			hover_bg = Color(0, 0, 0, 0.06)
	var radius := 11 if kind == "dark" else UiTokens.RADIUS
	var normal := box(bg, radius, edge, 1, 8.0)
	var hover := box(hover_bg, radius, UiTokens.SPRUCE if kind == "paper" else edge, 1, 8.0)
	var pressed := box(bg.darkened(0.12), radius, edge, 1, 8.0)
	var disabled := box(Color(bg, bg.a * 0.55), radius, edge, 1, 8.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.5))


## A small tag: a word on a coloured pill.
static func chip(text: String, bg: Color = UiTokens.PAPER_SUNK, fg: Color = UiTokens.INK_SOFT, size: int = UiTokens.TEXT_S) -> PanelContainer:
	var p := PanelContainer.new()
	var st := box(bg, 6, Color(0, 0, 0, 0), 0, 4.0)
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", st)
	p.add_child(label(text, size, fg))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func stars(n: int) -> StarRow:
	var s := StarRow.new()
	s.count = n
	return s


static func spacer(h: float = 4.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expand() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A press that feels like one: a quick squash and a click.
static func press_feel(c: Control) -> void:
	if not c.is_inside_tree():
		return
	Audio.play("tap", -14.0, 0.05, false, 1.4)
	if Settings.reduced_motion:
		return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.96, 0.96), 0.05)
	tw.tween_property(c, "scale", Vector2.ONE, UiTokens.FAST).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Comes in from a little below, fading up.
static func rise_in(c: Control, delay: float = 0.0) -> void:
	if Settings.reduced_motion or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, UiTokens.MEDIUM)


## Fills `parent`, anchored to its edges.
static func fill(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Places `c` at a corner (or edge middle) of its parent, at its minimum
## size, `inset` in from the edges and the phone's safe area. Call after
## adding it to the parent.
static func pin(c: Control, corner: int, inset: Vector2 = Vector2(UiTokens.EDGE, UiTokens.EDGE)) -> Control:
	var safe: Dictionary = Settings.safe_insets()
	var ms := c.get_combined_minimum_size()
	var ax := 0.0
	var ay := 0.0
	match corner:
		Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_RIGHT:
			ax = 1.0
		Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM, Control.PRESET_CENTER:
			ax = 0.5
	match corner:
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM:
			ay = 1.0
		Control.PRESET_CENTER_LEFT, Control.PRESET_CENTER_RIGHT, Control.PRESET_CENTER:
			ay = 0.5
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	var x0 := 0.0
	if ax == 0.0:
		x0 = inset.x + float(safe.get("left", 0.0))
		c.grow_horizontal = Control.GROW_DIRECTION_END
	elif ax == 1.0:
		x0 = -(inset.x + float(safe.get("right", 0.0))) - ms.x
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	else:
		x0 = -ms.x / 2.0
		c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var y0 := 0.0
	if ay == 0.0:
		y0 = inset.y + float(safe.get("top", 0.0))
		c.grow_vertical = Control.GROW_DIRECTION_END
	elif ay == 1.0:
		y0 = -(inset.y + float(safe.get("bottom", 0.0))) - ms.y
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		y0 = -ms.y / 2.0
		c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.offset_left = x0
	c.offset_right = x0 + ms.x
	c.offset_top = y0
	c.offset_bottom = y0 + ms.y
	return c
