class_name SummitDawn
extends CanvasLayer
## Sunrise over the summit: the reason for the whole night. Drawn over the
## night sky and behind the mountain (between the Sky and Distance layers),
## it fades in as the climber nears the top (`amount`, 0 to 1): a glow
## along the horizon, gold into rose into violet, the sun lifting out of the
## cloud sea with soft rays, and the stars going out. Pure drawing, no
## textures, so it costs nothing to ship.

## 0: night, 1: full sunrise. Set by the level as you climb the last part.
var amount := 0.0:
	set(v):
		amount = clampf(v, 0.0, 1.0)
		if _canvas:
			_canvas.queue_redraw()
		_fade_stars()
var _canvas: Control
var _glow: Control
var _clock := 0.0


func _ready() -> void:
	layer = -19
	name = "SummitDawn"
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_dawn)
	add_child(_canvas)
	# Over the far mountains and the cloud sea: the light they catch.
	var front := CanvasLayer.new()
	front.layer = -14
	front.name = "DawnGlow"
	add_child(front)
	_glow = Control.new()
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	front.add_child(_glow)


func _process(delta: float) -> void:
	_clock += delta
	if amount > 0.0:
		_canvas.queue_redraw()
		_glow.queue_redraw()


func _fade_stars() -> void:
	var sky := get_parent().get_node_or_null("Sky")
	if sky and sky.get_node_or_null("Stars"):
		(sky.get_node("Stars") as CanvasItem).modulate.a = 1.0 - amount * 0.9


func _draw_dawn() -> void:
	if amount <= 0.0:
		return
	var size := _canvas.size
	var horizon := size.y * 0.62
	var a := amount
	# The sky warms from the horizon up: bands, each a little higher as the
	# sun rises.
	var bands := [
		[Color("#2a2350"), 1.0],   # violet, high
		[Color("#7a3f78"), 0.62],  # plum
		[Color("#e0708a"), 0.38],  # rose
		[Color("#ffa86a"), 0.2],   # apricot
		[Color("#ffd98a"), 0.08],  # gold, at the horizon
	]
	# One smooth strip, colours blended between rows (no banding).
	var steps := 24
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var y := horizon * (1.0 - t)
		var c := _band_color(bands, t)
		c.a = a * lerpf(0.95, 0.55, t)
		pts.append(Vector2(0, y))
		pts.append(Vector2(size.x, y))
		cols.append(c)
		cols.append(c)
	for i in steps:
		var k := i * 2
		_canvas.draw_polygon(PackedVector2Array([pts[k], pts[k + 1], pts[k + 3], pts[k + 2]]),
			PackedColorArray([cols[k], cols[k + 1], cols[k + 3], cols[k + 2]]))
	# Under the horizon: the cloud sea catches the light.
	_canvas.draw_rect(Rect2(0, horizon, size.x, size.y - horizon), Color(1.0, 0.78, 0.66, 0.35 * a))
	# The sun: lifts out of the cloud sea as the amount grows.
	var sun := Vector2(size.x * 0.72, horizon + 40.0 - a * 110.0)
	var r := size.y * 0.06
	# Rays, slowly turning.
	for k in 12:
		var ang := _clock * 0.05 + k * TAU / 12.0
		var tip := sun + Vector2(cos(ang), sin(ang)) * size.y * 0.75
		var side := Vector2(-sin(ang), cos(ang)) * r * 0.9
		_canvas.draw_colored_polygon(PackedVector2Array([sun + side, sun - side, tip]), Color(1.0, 0.9, 0.6, 0.06 * a))
	for g in [[4.0, 0.08], [2.6, 0.14], [1.7, 0.25]]:
		_canvas.draw_circle(sun, r * g[0], Color(1.0, 0.85, 0.55, g[1] * a))
	_canvas.draw_circle(sun, r, Color(1.0, 0.95, 0.78, a))
	# A line of light along the cloud tops.
	_canvas.draw_rect(Rect2(0, horizon - 2.0, size.x, 4.0), Color(1.0, 0.92, 0.7, 0.5 * a))


## Warm light on the far mountains and the cloud sea, added on top of them,
## strongest at the horizon under the sun.
func _draw_glow() -> void:
	if amount <= 0.0:
		return
	var size := _glow.size
	var horizon := size.y * 0.62
	var a := amount
	var top := Color(1.0, 0.55, 0.35, 0.0)
	var mid := Color(1.0, 0.62, 0.38, 0.28 * a)
	var low := Color(0.9, 0.45, 0.4, 0.12 * a)
	_glow.draw_polygon(PackedVector2Array([Vector2(0, horizon - size.y * 0.2), Vector2(size.x, horizon - size.y * 0.2), Vector2(size.x, horizon), Vector2(0, horizon)]),
		PackedColorArray([top, top, mid, mid]))
	_glow.draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(size.x, horizon), Vector2(size.x, size.y), Vector2(0, size.y)]),
		PackedColorArray([mid, mid, low, low]))


static func _band_color(bands: Array, t: float) -> Color:
	# bands run from the top (t = 1) to the horizon (t = 0).
	for i in range(bands.size() - 1):
		var hi: float = bands[i][1]
		var lo: float = bands[i + 1][1]
		if t <= hi and t >= lo:
			return (bands[i + 1][0] as Color).lerp(bands[i][0], (t - lo) / maxf(0.001, hi - lo))
	return bands[bands.size() - 1][0] if t < 0.5 else bands[0][0]
