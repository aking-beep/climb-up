class_name SummitTop
extends Node2D
## The top of Kilimanjaro, as it should feel: the wooden Uhuru Peak sign,
## a string of bright flags left by climbers, and everlastings in bloom in
## the first light. Placed at the summit (the X marker) instead of the
## plain exit post. Drawn and built in code, no new textures.

const BOARD := Color("#2f5d3a")
const WOOD := Color("#5a3b22")
const LETTERS := Color("#f4d35e")
const FLAGS := [Color("#3a78c8"), Color("#f2efe6"), Color("#d64a3a"), Color("#3f8a4a"), Color("#f4c542"), Color("#e8782c"), Color("#7a4f9e")]

## Ground to stand the flowers on, either side of the sign (pixels from the
## sign, left and right).
var spread := Vector2(-96, 40)
var _t := 0.0
var _flowers: Array[Sprite2D] = []


func _ready() -> void:
	z_index = -1
	# Everlastings in bloom on the summit ground, deterministic, both sides.
	var tex := Art.tex("res://assets/terrain/props/everlasting.png")
	var xs := [-90, -78, -66, -55, -44, -34, -16, 18, 28, 36]
	for i in xs.size():
		var s := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((i % 2) * 10, 0, 10, 10)
		s.texture = at
		s.position = Vector2(float(xs[i]), -5.0)
		s.modulate = [Color(1, 1, 1), Color(1.0, 0.86, 0.9), Color(1.0, 0.95, 0.75)][i % 3]
		add_child(s)
		_flowers.append(s)


func _process(delta: float) -> void:
	_t += delta
	for i in _flowers.size():
		_flowers[i].rotation = sin(_t * 1.6 + i) * 0.12
	queue_redraw()


func _draw() -> void:
	# Two posts and the board.
	draw_rect(Rect2(-24, -44, 4, 44), WOOD)
	draw_rect(Rect2(20, -44, 4, 44), WOOD)
	draw_rect(Rect2(-31, -44, 62, 22), Color("#1c1714"))
	draw_rect(Rect2(-30, -43, 60, 20), BOARD)
	draw_rect(Rect2(-30, -43, 60, 2), BOARD.lightened(0.2))
	# The words, centred on the board.
	var font: Font = UiFont.body() if UiFont.body() else ThemeDB.fallback_font
	for row in [["UHURU PEAK", -34.0, 7], ["TANZANIA 5,895 m", -26.0, 5]]:
		var w := font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, row[2]).x
		draw_string(font, Vector2(-w / 2.0, row[1]), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, row[2], LETTERS)
	# A string of flags from the sign to a pole, lifting in the wind.
	var a := Vector2(-28, -44)
	var b := Vector2(-80, -30)
	draw_line(Vector2(-82, 0), Vector2(-82, -34), WOOD, 2.0)
	var n := 9
	for i in n:
		var t := (i + 0.5) / float(n)
		var p := a.lerp(b, t) + Vector2(0, sin(t * PI) * 6.0)
		var flap := sin(_t * 5.0 + i) * 1.5
		var c: Color = FLAGS[i % FLAGS.size()]
		draw_colored_polygon(PackedVector2Array([p + Vector2(-2.5, 0), p + Vector2(2.5, 0), p + Vector2(flap, 7)]), c)
	draw_polyline(PackedVector2Array([a, a.lerp(b, 0.5) + Vector2(0, 6), b]), Color("#e6e0d0"), 0.6)
