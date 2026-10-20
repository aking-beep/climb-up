class_name Skyline
extends Node2D
## A distant shape drawn in code, not painted: a forest's crowns, a heath's
## rolling hills, a jagged ridge, a glacier's ice cliffs, the notch of the
## Western Breach, the crater's rim, a sea of cloud. It sits in a
## CanvasLayer and moves with the camera like a Backdrop (`factor`, `anchor`,
## `screen_y`), repeating sideways, and fills down to the bottom of the
## screen so nothing shows under it. Each place mixes a few at different
## distances (ClimbLevel spec theme "skylines"), which is what makes the
## nine climbs look like nine places at no cost to the download.

const KINDS := ["ridge", "hills", "forest", "glacier", "breach", "crater", "clouds"]
const TILE_W := 640.0

var kind := "ridge"
var color := Color("#3a4250")
## Lit edges, ice and highlights.
var light := Color("#6a7484")
var factor := Vector2(0.1, 0.1)
var anchor := Vector2.ZERO
var screen_y := 220.0
## Height of the shape on screen at zoom 1, in pixels.
var tall := 120.0
var seed_value := 1
var drift := 0.0
var _t := 0.0
## The shape, worked out once: polygons [points, colour] in a TILE_W wide
## tile whose ground line is y = 0 (shapes rise into negative y).
var _shapes: Array = []
var _lines: Array = []


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 7919 + KINDS.find(kind) * 104729
	return r


func _build() -> void:
	_shapes.clear()
	_lines.clear()
	var r := _rng()
	var h := tall
	match kind:
		"ridge", "hills":
			var pts := PackedVector2Array([Vector2(0, 0)])
			var n := 18 if kind == "ridge" else 8
			var y0 := -h * 0.5
			for i in n + 1:
				var x := TILE_W * i / n
				var y := -h * (0.35 + r.randf() * 0.65) if kind == "ridge" else -h * (0.45 + 0.35 * sin(i * 1.3 + r.randf()))
				if i == 0 or i == n:
					y = y0
				pts.append(Vector2(x, y))
			pts.append(Vector2(TILE_W, 0))
			if kind == "hills":
				pts = _smooth(pts)
			_shapes.append([pts, color])
			# Lit ridgeline: a thin band along the top.
			var lit := PackedVector2Array()
			for i in range(1, pts.size() - 1):
				lit.append(pts[i])
			_lines.append([lit, light, 2.0])
		"forest":
			# Crowns along the ground, overlapping, with trunks under the gaps.
			var x := -20.0
			while x < TILE_W + 20.0:
				var rr := h * (0.18 + r.randf() * 0.16)
				var top := -h * (0.45 + r.randf() * 0.5)
				_shapes.append([PackedVector2Array([Vector2(x - 3, 0), Vector2(x - 2, top), Vector2(x + 2, top), Vector2(x + 3, 0)]), color.darkened(0.25)])
				_shapes.append([_circle(Vector2(x, top), rr, 14), color])
				_shapes.append([_circle(Vector2(x - rr * 0.35, top - rr * 0.3), rr * 0.45, 10), light])
				# Old man's beard hanging from the crown.
				for k in 3:
					var sx := x - rr * 0.5 + k * rr * 0.5
					_lines.append([PackedVector2Array([Vector2(sx, top + rr * 0.5), Vector2(sx, top + rr * (0.9 + r.randf() * 0.8))]), light.lightened(0.3), 1.0])
				x += rr * (1.1 + r.randf() * 0.5)
			_shapes.push_front([PackedVector2Array([Vector2(0, 0), Vector2(0, -h * 0.4), Vector2(TILE_W, -h * 0.4), Vector2(TILE_W, 0)]), color.darkened(0.2)])
		"glacier":
			# A band of ice cliffs: a flat-topped mass, vertical fluting, a
			# bright snow lip.
			var pts := PackedVector2Array([Vector2(0, 0)])
			var n := 10
			for i in n + 1:
				var x := TILE_W * i / n
				pts.append(Vector2(x, -h * (0.7 + r.randf() * 0.25)))
			pts.append(Vector2(TILE_W, 0))
			_shapes.append([pts, color])
			for i in 26:
				var x := r.randf() * TILE_W
				_lines.append([PackedVector2Array([Vector2(x, -h * 0.65), Vector2(x + r.randf_range(-4, 4), -h * 0.05)]), light.darkened(0.15), 2.0])
			var lip := PackedVector2Array()
			for i in range(1, pts.size() - 1):
				lip.append(pts[i] + Vector2(0, 3))
			_lines.append([lip, light.lightened(0.5), 5.0])
		"breach":
			# A steep wall with a deep V notch in the middle and streaks of
			# ice down its gullies.
			var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, -h * 0.8), Vector2(TILE_W * 0.3, -h), Vector2(TILE_W * 0.46, -h * 0.35),
				Vector2(TILE_W * 0.54, -h * 0.4), Vector2(TILE_W * 0.7, -h * 0.98), Vector2(TILE_W, -h * 0.8), Vector2(TILE_W, 0)])
			_shapes.append([pts, color])
			for i in 9:
				var x := TILE_W * (0.1 + 0.09 * i) + r.randf() * 20.0
				var y := -h * (0.5 + r.randf() * 0.4)
				_lines.append([PackedVector2Array([Vector2(x, y), Vector2(x + r.randf_range(-12, 12), y + h * 0.35)]), light, 2.5])
		"crater":
			var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, -h * 0.5)])
			for i in 9:
				pts.append(Vector2(TILE_W * (i + 1) / 10.0, -h * (0.5 + r.randf() * 0.12)))
			pts.append(Vector2(TILE_W, -h * 0.5))
			pts.append(Vector2(TILE_W, 0))
			_shapes.append([pts, color])
			# The ash cone in the middle.
			_shapes.append([PackedVector2Array([Vector2(TILE_W * 0.35, -h * 0.5), Vector2(TILE_W * 0.47, -h * 0.85), Vector2(TILE_W * 0.53, -h * 0.85),
				Vector2(TILE_W * 0.65, -h * 0.5)]), color.lightened(0.12)])
			_lines.append([PackedVector2Array([Vector2(TILE_W * 0.47, -h * 0.85), Vector2(TILE_W * 0.53, -h * 0.85)]), light, 3.0])
		"clouds":
			var x := -30.0
			while x < TILE_W + 30.0:
				var rr := h * (0.2 + r.randf() * 0.25)
				_shapes.append([_circle(Vector2(x, -rr * 0.4), rr, 14), color])
				_shapes.append([_circle(Vector2(x - rr * 0.2, -rr * 0.65), rr * 0.6, 12), light])
				x += rr * 1.2
			_shapes.push_front([PackedVector2Array([Vector2(0, 0), Vector2(0, -h * 0.25), Vector2(TILE_W, -h * 0.25), Vector2(TILE_W, 0)]), color])


static func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a), sin(a) * 0.8) * r)
	return out


static func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 2):
		var a := pts[i]
		var b := pts[i + 1]
		for k in 4:
			var t := k / 4.0
			out.append(a.lerp(b, t) + Vector2(0, -sin(t * PI) * 6.0))
	out.append(pts[pts.size() - 2])
	out.append(pts[pts.size() - 1])
	return out


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var vp := get_viewport_rect().size
	var center := cam.get_screen_center_position() if cam else anchor
	var zoom := cam.zoom.x if cam else 1.0
	var x := vp.x / 2.0 + (anchor.x - center.x) * factor.x * zoom + _t * drift
	var bottom := screen_y + (anchor.y - center.y) * factor.y * zoom
	if bottom - tall * zoom > vp.y:
		return
	var w := TILE_W * zoom
	if bottom < vp.y:
		draw_rect(Rect2(0, bottom - 1.0, vp.x, vp.y - bottom + 2.0), color)
	var start := fposmod(x, w) - w
	while start < vp.x:
		draw_set_transform(Vector2(start, bottom), 0.0, Vector2(zoom, zoom))
		for s in _shapes:
			draw_colored_polygon(s[0], s[1])
		for l in _lines:
			if (l[0] as PackedVector2Array).size() >= 2:
				draw_polyline(l[0], l[1], l[2], true)
		start += w
	draw_set_transform(Vector2.ZERO)
