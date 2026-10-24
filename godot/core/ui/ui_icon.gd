class_name UiIcon
extends Control
## Small line icons drawn in code (no icon font, no bitmaps): trophy,
## gear (settings), map, pack, book, back, lock, check, star, tent, sun.

var kind := "trophy":
	set(v):
		kind = v
		queue_redraw()
var color := UiTokens.CHALK:
	set(v):
		color = v
		queue_redraw()


static func make(k: String, c: Color = UiTokens.CHALK, s: float = 12.0) -> UiIcon:
	var i := UiIcon.new()
	i.kind = k
	i.color = c
	i.custom_minimum_size = Vector2(s, s)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


## A round button on the world with an icon and an accessible name.
static func button(k: String, label: String, on_press: Callable, dark: bool = true) -> Button:
	var b := UiKit.button("", on_press, "dark" if dark else "paper")
	b.custom_minimum_size = Vector2(UiTokens.TAP, UiTokens.TAP)
	b.tooltip_text = label
	b.name = label.replace(" ", "")
	var icon := make(k, UiTokens.CHALK if dark else UiTokens.INK, 12.0)
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -6
	icon.offset_top = -6
	icon.offset_right = 6
	icon.offset_bottom = 6
	b.add_child(icon)
	return b


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var w := maxf(1.0, s / 10.0)
	var k := s / 12.0
	match kind:
		"trophy":
			draw_arc(c + Vector2(0, -1.5 * k), 3.6 * k, 0.0, PI, 10, color, w)
			draw_line(c + Vector2(-3.6, -1.5) * k, c + Vector2(-3.6, -4.2) * k, color, w)
			draw_line(c + Vector2(3.6, -1.5) * k, c + Vector2(3.6, -4.2) * k, color, w)
			draw_line(c + Vector2(-3.8, -4.2) * k, c + Vector2(3.8, -4.2) * k, color, w)
			draw_line(c + Vector2(0, 2.1) * k, c + Vector2(0, 4) * k, color, w)
			draw_line(c + Vector2(-2.6, 4.4) * k, c + Vector2(2.6, 4.4) * k, color, w)
			draw_arc(c + Vector2(-4.4, -2.4) * k, 1.4 * k, PI * 0.5, PI * 1.5, 6, color, w * 0.8)
			draw_arc(c + Vector2(4.4, -2.4) * k, 1.4 * k, -PI * 0.5, PI * 0.5, 6, color, w * 0.8)
		"gear":
			draw_arc(c, 2.0 * k, 0.0, TAU, 12, color, w)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 3.4 * k, c + Vector2(cos(a), sin(a)) * 5.0 * k, color, w * 1.3)
			draw_arc(c, 3.6 * k, 0.0, TAU, 16, color, w)
		"map":
			var pts := PackedVector2Array([c + Vector2(-5, -4) * k, c + Vector2(-1.7, -5) * k, c + Vector2(1.7, -4) * k,
				c + Vector2(5, -5) * k, c + Vector2(5, 4) * k, c + Vector2(1.7, 5) * k, c + Vector2(-1.7, 4) * k, c + Vector2(-5, 5) * k, c + Vector2(-5, -4) * k])
			draw_polyline(pts, color, w, true)
			draw_line(c + Vector2(-1.7, -5) * k, c + Vector2(-1.7, 4) * k, color, w * 0.8)
			draw_line(c + Vector2(1.7, -4) * k, c + Vector2(1.7, 5) * k, color, w * 0.8)
		"pack":
			draw_rect(Rect2(c + Vector2(-3.6, -3.2) * k, Vector2(7.2, 8.2) * k), color, false, w)
			draw_arc(c + Vector2(0, -3.2) * k, 2.0 * k, PI, TAU, 8, color, w)
			draw_line(c + Vector2(-3.6, 0.4) * k, c + Vector2(3.6, 0.4) * k, color, w)
		"book":
			draw_rect(Rect2(c + Vector2(-5, -4) * k, Vector2(4.6, 8.4) * k), color, false, w)
			draw_rect(Rect2(c + Vector2(0.4, -4) * k, Vector2(4.6, 8.4) * k), color, false, w)
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(2, -4.5) * k, c + Vector2(-2.5, 0), c + Vector2(2, 4.5) * k]), color, w * 1.3, true)
		"lock":
			draw_rect(Rect2(c + Vector2(-3.6, -0.6) * k, Vector2(7.2, 5.4) * k), color)
			draw_arc(c + Vector2(0, -0.8) * k, 2.4 * k, PI, TAU, 8, color, w)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-4, 0) * k, c + Vector2(-1.2, 3) * k, c + Vector2(4.2, -3.4) * k]), color, w * 1.4, true)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var r := 5.0 * k if i % 2 == 0 else 2.2 * k
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, color)
		"tent":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5.5, 4) * k, c + Vector2(0, -4.5) * k, c + Vector2(5.5, 4) * k]), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-1.4, 4) * k, c + Vector2(0, 0.8) * k, c + Vector2(1.4, 4) * k]), Color(0, 0, 0, 0.45))
		"sun":
			draw_circle(c, 2.4 * k, color)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 3.6 * k, c + Vector2(cos(a), sin(a)) * 5.2 * k, color, w)
		"person":
			draw_circle(c + Vector2(0, -2.6) * k, 2.0 * k, color)
			draw_arc(c + Vector2(0, 5) * k, 4.2 * k, PI, TAU, 10, color, w * 1.4)
