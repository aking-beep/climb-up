class_name UiStyle
extends RefCounted
## Buttons in the app's paper-and-ink look, shared by the screens and the
## story panel: a raised paper button, ink text, a spruce edge when focused.


static func paper_button(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.98, 0.97, 0.94)
	normal.border_color = Color(0.8, 0.76, 0.68)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	var hover := normal.duplicate()
	hover.bg_color = Color(1, 0.99, 0.96)
	hover.border_color = Color("#1f3d34")
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.92, 0.9, 0.85)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.93, 0.92, 0.89)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(key, Color(0.11, 0.098, 0.082))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.48))
