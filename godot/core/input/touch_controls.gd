class_name TouchControls
extends CanvasLayer
## Two-thumb touch overlay for landscape phones. Left thumb: a four-way pad.
## Right thumb: ACT (climb / talk / choose), BRACE, REST. Top right: pause.
## Buttons press the same input actions as keys, so gameplay never knows
## the difference. Shown automatically on touch devices (Settings).

const SIZE := 34.0


static func attach(level: Node) -> void:
	var existing := level.get_node_or_null("TouchControls")
	if existing:
		existing.queue_free()
	if not Settings.touch_enabled():
		return
	var t := TouchControls.new()
	t.name = "TouchControls"
	level.add_child(t)


func _ready() -> void:
	layer = 15
	var vp := get_viewport().get_visible_rect().size
	var pad := Vector2(14, vp.y - 14 - SIZE * 3)
	_button("move_left", "◀", pad + Vector2(0, SIZE))
	_button("move_right", "▶", pad + Vector2(SIZE * 2, SIZE))
	_button("climb_up", "▲", pad + Vector2(SIZE, 0))
	_button("climb_down", "▼", pad + Vector2(SIZE, SIZE * 2))
	var right := Vector2(vp.x - 14 - SIZE * 2.4, vp.y - 14 - SIZE * 2.2)
	_button("interact", "ACT", right + Vector2(SIZE * 1.3, SIZE * 0.6), 1.25)
	_button("brace", "BRACE", right + Vector2(0, SIZE * 1.2))
	_button("rest", "REST", right + Vector2(0, 0))
	_button("pause", "II", Vector2(vp.x - 14 - SIZE * 0.8, 8), 0.8)


func _button(action: String, glyph: String, at: Vector2, scale_by: float = 1.0) -> void:
	var b := TouchScreenButton.new()
	var size := SIZE * scale_by
	var img := Image.create(int(size), int(size), false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	for y in int(size):
		for x in int(size):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d < size / 2.0 - 1.0:
				img.set_pixel(x, y, Color(0.07, 0.066, 0.06, 0.42))
			elif d < size / 2.0:
				img.set_pixel(x, y, Color(0.95, 0.94, 0.91, 0.5))
	b.texture_normal = ImageTexture.create_from_image(img)
	b.action = action
	b.passby_press = true
	b.position = at
	add_child(b)
	var l := Label.new()
	l.text = glyph
	l.add_theme_font_size_override("font_size", 8 if glyph.length() > 2 else 11)
	l.add_theme_color_override("font_color", Color(0.95, 0.94, 0.91, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(size, size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
