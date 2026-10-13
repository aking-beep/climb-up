class_name StarRow
extends Control
## Three stars, `count` of them filled: route mastery on the menu and the
## results card. Drawn, so they need no glyph in the fonts.

var count := 0:
	set(v):
		count = clampi(v, 0, 3)
		queue_redraw()
var star := 4.5
var on := Color("#f2b33d")
var off := Color(0.45, 0.42, 0.38, 0.45)


func _init() -> void:
	custom_minimum_size = Vector2(star * 2.0 * 3.0 + 8.0, star * 2.0 + 2.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	for i in 3:
		var c := Vector2(star + 1.0 + i * (star * 2.0 + 3.0), size.y / 2.0)
		var pts := PackedVector2Array()
		for k in 10:
			var r := star if k % 2 == 0 else star * 0.45
			var a := -PI / 2.0 + k * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, on if i < count else off)
		if i < count:
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.55, 0.36, 0.08, 0.7), 0.6, true)
