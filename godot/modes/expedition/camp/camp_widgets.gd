class_name CampWidgets
extends RefCounted
## The camp screen's small pieces, drawn in code so they are sharp at any
## size: stat icons, a stat chip (icon, value, bar, and a preview of what
## the chosen option would do to it), a party portrait with a status ring,
## and consequence chips for a choice card. Built the way mobile strategy
## games show a decision: every option's cost readable at a glance, as
## coloured gains and losses, before you commit.

const GOOD := Color("#3f8a4a")
const WARN := Color("#c9922e")
const BAD := Color("#b8432a")
const INK := Color(0.11, 0.098, 0.082)
const PAPER := Color(0.97, 0.955, 0.92)
const SPRUCE := Color("#1f3d34")

## Stat → [icon, short name, higher is bad].
const STAT := {
	"health": ["heart", "Health", false],
	"energy": ["bolt", "Energy", false],
	"acclimatization": ["peak", "Used to height", false],
	"teamCondition": ["team", "Team spirit", false],
	"supplies": ["crate", "Food & supplies", false],
	"weatherRisk": ["cloud", "Bad weather", true],
	"objectiveRisk": ["rock", "Falling rocks", true],
}
const ICON_COLOR := {
	"heart": Color("#e05a5a"), "bolt": Color("#f2c14e"), "peak": Color("#9fc4e0"), "team": Color("#8fd16b"),
	"crate": Color("#d8a868"), "cloud": Color("#b9c4d0"), "rock": Color("#b0a090"), "clock": Color("#e8e2d0"),
}


## Draws `icon` centred at `c`, `r` its radius.
static func draw_icon(ci: CanvasItem, icon: String, c: Vector2, r: float, col: Color = Color(0, 0, 0, 0)) -> void:
	var k: Color = col if col.a > 0.0 else ICON_COLOR.get(icon, Color.WHITE)
	var line := Color(0.1, 0.08, 0.08, 0.85)
	match icon:
		"heart":
			var pts := PackedVector2Array()
			for i in 24:
				var t := i / 24.0 * TAU
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				pts.append(c + Vector2(x, y) * r / 17.0)
			ci.draw_colored_polygon(pts, k)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), line, 0.8, true)
		"bolt":
			var pts := PackedVector2Array([Vector2(0.15, -1), Vector2(-0.55, 0.15), Vector2(-0.05, 0.15), Vector2(-0.2, 1), Vector2(0.55, -0.2), Vector2(0.05, -0.2)])
			for i in pts.size():
				pts[i] = c + pts[i] * r
			ci.draw_colored_polygon(pts, k)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), line, 0.8, true)
		"peak", "rock":
			var pts := PackedVector2Array([c + Vector2(-1, 0.75) * r, c + Vector2(0, -0.85) * r, c + Vector2(1, 0.75) * r])
			ci.draw_colored_polygon(pts, Color("#8a8e9a") if icon == "peak" else k)
			if icon == "peak":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.38, -0.2) * r, c + Vector2(0, -0.85) * r, c + Vector2(0.38, -0.2) * r, c + Vector2(0.1, -0.05) * r, c + Vector2(-0.1, -0.15) * r]), Color("#f4f8fc"))
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), line, 0.8, true)
		"team":
			for dx in [-0.42, 0.42]:
				ci.draw_circle(c + Vector2(dx, -0.35) * r, r * 0.3, k)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(dx - 0.42, 0.85) * r, c + Vector2(dx - 0.3, 0.05) * r, c + Vector2(dx + 0.3, 0.05) * r, c + Vector2(dx + 0.42, 0.85) * r]), k)
		"crate":
			var box := Rect2(c - Vector2(0.85, 0.7) * r, Vector2(1.7, 1.4) * r)
			ci.draw_rect(box, k)
			ci.draw_rect(box, line, false, 0.8)
			ci.draw_line(box.position + Vector2(0, box.size.y * 0.4), box.position + Vector2(box.size.x, box.size.y * 0.4), line, 0.7)
		"cloud":
			for p in [[Vector2(-0.45, 0.15), 0.45], [Vector2(0.1, -0.15), 0.55], [Vector2(0.55, 0.2), 0.4]]:
				ci.draw_circle(c + p[0] * r, p[1] * r, k)
			ci.draw_rect(Rect2(c + Vector2(-0.85, 0.15) * r, Vector2(1.75, 0.45) * r), k)
		"clock":
			ci.draw_circle(c, r * 0.9, k)
			ci.draw_arc(c, r * 0.9, 0, TAU, 20, line, 0.8, true)
			ci.draw_line(c, c + Vector2(0, -0.6) * r, line, 0.9)
			ci.draw_line(c, c + Vector2(0.45, 0.1) * r, line, 0.9)


## A resource on the HUD: icon, value, a bar, and the preview of a choice.
class StatChip extends Control:
	var key := ""
	var value := 0
	var preview := 0
	var bad_high := false

	func _init() -> void:
		custom_minimum_size = Vector2(96, 15)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := UiFont.body() if UiFont.body() else ThemeDB.fallback_font
		var info: Array = CampWidgets.STAT[key]
		CampWidgets.draw_icon(self, info[0], Vector2(6, 7), 5.0)
		# The name in words, then the number: nobody has to learn the icons.
		var shown := "%s %d" % [info[1], value]
		var col := Color(0.98, 0.97, 0.94)
		draw_string_outline(font, Vector2(14, 9.5), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(14, 9.5), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		var bar := Rect2(14, 11.5, size.x - 16, 2.6)
		draw_rect(bar, Color(0, 0, 0, 0.45))
		var v := clampf(value / 100.0, 0.0, 1.0)
		var bad: bool = value > 55 if bad_high else value < 35
		var warn: bool = value > 35 if bad_high else value < 55
		var fill := CampWidgets.BAD if bad else (CampWidgets.WARN if warn else Color("#8fbf7a"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * v, bar.size.y)), fill)
		if preview != 0:
			# The chosen option: the bar's change, and the number.
			var after := clampf((value + preview) / 100.0, 0.0, 1.0)
			var lo := minf(v, after)
			var good: bool = (preview < 0) == bad_high
			draw_rect(Rect2(bar.position + Vector2(bar.size.x * lo, -0.6), Vector2(bar.size.x * absf(after - v), bar.size.y + 1.2)), Color("#7ce07c") if good else Color("#ff6a50"))
			var w := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			var tag := "%+d" % preview
			draw_string_outline(font, Vector2(16 + w, 9.5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.7))
			draw_string(font, Vector2(16 + w, 9.5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#9cf09c") if good else Color("#ff8a70"))


## A party member's face in a ring coloured by how they are.
class Portrait extends Control:
	var who := ""
	var tex: Texture2D
	var state := "ok"   # ok, tired, down, sick
	var label := ""

	func _init() -> void:
		custom_minimum_size = Vector2(30, 34)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, 13)
		var ring: Color = {"ok": Color("#8fd16b"), "tired": CampWidgets.WARN, "down": CampWidgets.BAD, "sick": Color("#b06ad0")}[state]
		draw_circle(c, 13, Color(0.08, 0.07, 0.07, 0.75))
		draw_circle(c, 11.2, Color("#cfe0e8"))
		if tex:
			# The head from the front-facing idle frame.
			draw_texture_rect_region(tex, Rect2(c - Vector2(8.5, 9.5), Vector2(17, 19)), Rect2(7.5, 40.0, 17, 19))
		draw_arc(c, 12, 0, TAU, 32, ring, 2.0, true)
		var font := UiFont.body() if UiFont.body() else ThemeDB.fallback_font
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		draw_string_outline(font, Vector2((size.x - w) / 2.0, 33), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 3, Color(0, 0, 0, 0.75))
		draw_string(font, Vector2((size.x - w) / 2.0, 33), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.98, 0.97, 0.94))
		if state != "ok":
			var b := c + Vector2(9, -9)
			draw_circle(b, 4, ring)
			draw_string(font, b + Vector2(-1.6, 2.6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)


## A little icon drawn in a fixed box (for chips).
class Icon extends Control:
	var icon := ""
	var tint := Color(0, 0, 0, 0)

	func _init() -> void:
		custom_minimum_size = Vector2(9, 9)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		CampWidgets.draw_icon(self, icon, size / 2.0, size.y * 0.42, tint)


## A rounded chip: optional icon, text; fill and text colours.
static func chip(text: String, fill: Color, fg: Color, icon: String = "", size: int = 7) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = fill
	st.set_corner_radius_all(5)
	st.content_margin_left = 3
	st.content_margin_right = 4
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 1)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	if icon != "":
		var ic := Icon.new()
		ic.icon = icon
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", fg)
	if UiFont.body():
		l.add_theme_font_override("font", UiFont.body())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	return p
