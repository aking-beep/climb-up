class_name HubLandscape
extends Control
## The hub's world, drawn in code in depth layers (HD-2D staging: a warm
## key light from the upper right, haze that grows with distance, a dark
## frame at the edges). Far: the sky, Kibo and Mawenzi. Middle: the
## savanna and Lion Rock. Near: the boulder you warm up on, the grass.
## Each layer moves a little with your finger (parallax) and drifts slowly.

## Layer depths: how far each moves for a full swipe, in pixels.
const DEPTH := {"far": 8.0, "clouds": 12.0, "mid": 16.0, "rock": 26.0, "near": 34.0}
const PAD := 40.0

var layers: Dictionary = {}
## -0.5 .. 0.5 on each axis: where the finger (or mouse) is.
var look := Vector2.ZERO
var _look_target := Vector2.ZERO
var _t := 0.0
## Time of day, 0..24 (the device's clock), sets the sky.
var hour := 17.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	var now := Time.get_datetime_dict_from_system()
	hour = float(now.get("hour", 17)) + float(now.get("minute", 0)) / 60.0
	for name in ["sky", "far", "clouds", "mid", "rock", "near", "frame"]:
		var l := _Layer.new()
		l.name = name.capitalize()
		l.painter = Callable(self, "_paint_" + name)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		layers[name] = l
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	for name in layers:
		var l: Control = layers[name]
		var pad := 0.0 if name in ["sky", "frame"] else PAD
		l.position = Vector2(-pad, -pad)
		l.size = size + Vector2(pad, pad) * 2.0
		l.queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion or e is InputEventScreenDrag:
		_look_target = (e.position / size - Vector2(0.5, 0.5)).clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))


func _process(delta: float) -> void:
	_t += delta
	var drift := Vector2(sin(_t * 0.21), cos(_t * 0.17) * 0.5) * 0.12 if not Settings.reduced_motion else Vector2.ZERO
	look = look.lerp(_look_target + drift, 1.0 - exp(-delta * 3.0))
	for name in DEPTH:
		var l: Control = layers.get(name)
		if l:
			l.position = Vector2(-PAD, -PAD) - look * DEPTH[name]
	if not Settings.reduced_motion:
		(layers["clouds"] as Control).queue_redraw()


## Where a point of the far layer is on screen now (for the tags pinned to
## the mountains): `frac` is a fraction of the screen.
func far_point(frac: Vector2, layer: String = "far") -> Vector2:
	var l: Control = layers[layer]
	return l.position + Vector2(PAD, PAD) + frac * size


# --- painting ----------------------------------------------------------------


func _sky_colors() -> Array:
	# Night, dawn, day, golden hour.
	if hour < 5.5 or hour >= 20.5:
		return [Color("#141a33"), Color("#2b3256"), Color("#4a4f6e")]
	if hour < 8.0:
		return [Color("#5d7aa0"), Color("#e8b48c"), Color("#f2d2a8")]
	if hour < 16.5:
		return [Color("#5f8fb3"), Color("#a9c6d6"), Color("#e6e0cc")]
	return [Color("#5a6f96"), Color("#d9a07a"), Color("#f2cf9a")]


func _night() -> bool:
	return hour < 5.5 or hour >= 20.5


func _paint_sky(c: Control) -> void:
	var s := c.size
	var cols := _sky_colors()
	c.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, s.y * 0.45), Vector2(0, s.y * 0.45)]),
		PackedColorArray([cols[0], cols[0], cols[1], cols[1]]))
	c.draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.45), Vector2(s.x, s.y * 0.45), Vector2(s.x, s.y), Vector2(0, s.y)]),
		PackedColorArray([cols[1], cols[1], cols[2], cols[2]]))
	if _night():
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 70:
			c.draw_circle(Vector2(rng.randf() * s.x, rng.randf() * s.y * 0.5), rng.randf_range(0.3, 0.9), Color(1, 1, 0.9, rng.randf_range(0.3, 0.9)))
	# The key light: a warm glow, upper right.
	var sun := Vector2(s.x * 0.78, s.y * 0.1)
	for i in 6:
		var r := s.y * (0.1 + 0.11 * i)
		c.draw_circle(sun, r, Color(1.0, 0.84, 0.63, 0.07 if not _night() else 0.02))
	if not _night():
		c.draw_circle(sun, s.y * 0.035, Color(1, 0.95, 0.82, 0.85))


func _haze(base: Color, amount: float) -> Color:
	var cols := _sky_colors()
	return base.lerp(cols[1], amount)


func _paint_far(c: Control) -> void:
	var s := c.size
	var o := Vector2(PAD, PAD)
	var w := s.x - PAD * 2.0
	var h := s.y - PAD * 2.0
	var base_y := o.y + h * 0.56
	# Mawenzi: jagged, further left.
	var maw := PackedVector2Array([Vector2(o.x + w * 0.38, base_y), Vector2(o.x + w * 0.45, o.y + h * 0.38), Vector2(o.x + w * 0.47, o.y + h * 0.33),
		Vector2(o.x + w * 0.49, o.y + h * 0.37), Vector2(o.x + w * 0.51, o.y + h * 0.31), Vector2(o.x + w * 0.535, o.y + h * 0.4), Vector2(o.x + w * 0.6, base_y)])
	c.draw_colored_polygon(maw, _haze(Color("#6c6a78"), 0.55))
	# Kibo: the broad cone with a flat top and the glaciers.
	var top_l := Vector2(o.x + w * 0.69, o.y + h * 0.17)
	var top_r := Vector2(o.x + w * 0.83, o.y + h * 0.16)
	var kibo := PackedVector2Array([Vector2(o.x + w * 0.42, base_y), Vector2(o.x + w * 0.6, o.y + h * 0.3), top_l,
		Vector2(o.x + w * 0.76, o.y + h * 0.15), top_r, Vector2(o.x + w * 0.95, o.y + h * 0.32), Vector2(o.x + w * 1.1, base_y)])
	c.draw_colored_polygon(kibo, _haze(Color("#5b5866"), 0.38))
	# Lit side (the light comes from the upper right).
	c.draw_colored_polygon(PackedVector2Array([Vector2(o.x + w * 0.76, o.y + h * 0.15), top_r, Vector2(o.x + w * 0.95, o.y + h * 0.32),
		Vector2(o.x + w * 1.1, base_y), Vector2(o.x + w * 0.86, base_y)]), Color(1.0, 0.85, 0.65, 0.16))
	# Glaciers and snow at the top.
	var snow := Color("#f3f1ea") if not _night() else Color("#aab2c8")
	c.draw_colored_polygon(PackedVector2Array([top_l + Vector2(-8, 6), top_l, Vector2(o.x + w * 0.76, o.y + h * 0.15), top_r,
		top_r + Vector2(14, 10), top_r + Vector2(6, 9), top_r + Vector2(-4, 13), Vector2(o.x + w * 0.76, o.y + h * 0.22),
		Vector2(o.x + w * 0.73, o.y + h * 0.19), top_l + Vector2(2, 12), top_l + Vector2(-4, 9)]), snow)
	# Glacier tongues on the slopes below the rim: broad and flat.
	for g in [[0.71, 0.24, 9.0], [0.79, 0.25, 12.0], [0.86, 0.27, 8.0], [0.66, 0.27, 6.0]]:
		var gc := Vector2(o.x + w * g[0], o.y + h * g[1])
		var pts := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			pts.append(gc + Vector2(cos(a) * g[2], sin(a) * g[2] * 0.32))
		c.draw_colored_polygon(pts, Color(snow, 0.85))


func _paint_clouds(c: Control) -> void:
	var s := c.size
	var t := _t if not Settings.reduced_motion else 0.0
	# Opaque, mixed with the sky, so the puffs merge into one cloud.
	var col: Color = (_sky_colors()[1] as Color).lerp(Color(1, 0.97, 0.92), 0.55 if not _night() else 0.18)
	for i in 6:
		var x := fposmod(float(i) * s.x / 5.0 + t * (3.0 + i), s.x + 160.0) - 80.0
		var y := s.y * (0.3 + 0.05 * float(i % 3))
		for k in 4:
			c.draw_circle(Vector2(x + k * 14.0, y - (6.0 if k % 2 == 1 else 0.0)), 10.0 + 3.0 * (k % 2), col)


func _paint_mid(c: Control) -> void:
	var s := c.size
	var o := Vector2(PAD, PAD)
	var w := s.x - PAD * 2.0
	var h := s.y - PAD * 2.0
	# Savanna, two bands of rolling hills.
	var band := PackedVector2Array([Vector2(0, s.y)])
	for i in 25:
		var x := float(i) / 24.0 * s.x
		band.append(Vector2(x, o.y + h * 0.56 + sin(x * 0.02) * 6.0 + sin(x * 0.051) * 3.0))
	band.append(Vector2(s.x, s.y))
	c.draw_colored_polygon(band, _haze(Color("#9a8a5a"), 0.3))
	var band2 := PackedVector2Array([Vector2(0, s.y)])
	for i in 25:
		var x := float(i) / 24.0 * s.x
		band2.append(Vector2(x, o.y + h * 0.66 + sin(x * 0.03 + 1.0) * 5.0))
	band2.append(Vector2(s.x, s.y))
	c.draw_colored_polygon(band2, _haze(Color("#8a7a4a"), 0.12))
	# Acacias: flat crowns on thin trunks.
	for a in [[0.56, 0.62, 1.0], [0.63, 0.6, 0.7], [0.9, 0.64, 1.2], [0.33, 0.66, 0.8]]:
		var base := Vector2(o.x + w * a[0], o.y + h * a[1])
		var k: float = a[2]
		var dark := _haze(Color("#3f4a2c"), 0.25)
		c.draw_line(base, base + Vector2(1, -11) * k, dark, 1.4 * k)
		c.draw_line(base + Vector2(0.5, -7) * k, base + Vector2(-4, -11) * k, dark, 1.0 * k)
		c.draw_colored_polygon(PackedVector2Array([base + Vector2(-11, -11) * k, base + Vector2(-6, -15) * k, base + Vector2(8, -15.5) * k,
			base + Vector2(13, -11.5) * k, base + Vector2(2, -10) * k]), dark)
	# Lion Rock: a granite tower on the left, lit on its right edge.
	var bx := o.x + w * 0.1
	var by := o.y + h * 0.7
	var rock := PackedVector2Array([Vector2(bx - 34, by), Vector2(bx - 30, by - 40), Vector2(bx - 22, by - 78), Vector2(bx - 10, by - 104),
		Vector2(bx + 6, by - 112), Vector2(bx + 22, by - 106), Vector2(bx + 30, by - 90), Vector2(bx + 36, by - 58), Vector2(bx + 44, by - 24), Vector2(bx + 52, by)])
	c.draw_colored_polygon(rock, Color("#8e4a2a").lerp(Color("#c98a4b"), 0.35))
	c.draw_colored_polygon(PackedVector2Array([Vector2(bx + 6, by - 112), Vector2(bx + 22, by - 106), Vector2(bx + 30, by - 90), Vector2(bx + 36, by - 58),
		Vector2(bx + 44, by - 24), Vector2(bx + 52, by), Vector2(bx + 24, by), Vector2(bx + 18, by - 60), Vector2(bx + 12, by - 100)]), Color(1, 0.82, 0.58, 0.22))
	# Cracks and ledges.
	for crack in [[Vector2(-14, -20), Vector2(-8, -70)], [Vector2(10, -10), Vector2(14, -50)], [Vector2(-20, -60), Vector2(10, -64)]]:
		c.draw_line(Vector2(bx, by) + crack[0], Vector2(bx, by) + crack[1], Color(0.25, 0.12, 0.06, 0.45), 1.0)
	# The route: chalk dots and bolts up the face.
	var route := [Vector2(-4, -4), Vector2(-6, -24), Vector2(-2, -44), Vector2(4, -64), Vector2(2, -86), Vector2(8, -104)]
	for i in route.size() - 1:
		c.draw_dashed_line(Vector2(bx, by) + route[i], Vector2(bx, by) + route[i + 1], Color(1, 0.96, 0.85, 0.55), 1.0, 3.0)
	for i in range(1, route.size()):
		c.draw_circle(Vector2(bx, by) + route[i] + Vector2(2, 0), 1.2, Color("#d9d4c8"))


func _paint_rock(c: Control) -> void:
	var s := c.size
	# The boulder where you warm up (your climber stands on it).
	var bx := s.x * 0.36
	var by := s.y - PAD - 28.0
	var b := PackedVector2Array([Vector2(bx - 46, by + 30), Vector2(bx - 40, by + 2), Vector2(bx - 24, by - 14), Vector2(bx + 4, by - 20),
		Vector2(bx + 30, by - 12), Vector2(bx + 44, by + 6), Vector2(bx + 50, by + 30)])
	c.draw_colored_polygon(b, Color("#7b6a58"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(bx + 4, by - 20), Vector2(bx + 30, by - 12), Vector2(bx + 44, by + 6), Vector2(bx + 50, by + 30), Vector2(bx + 20, by + 30), Vector2(bx + 12, by - 6)]), Color(1, 0.86, 0.66, 0.2))
	c.draw_polyline(b, Color(0.11, 0.1, 0.08, 0.6), 1.0, true)
	# Chalked holds.
	for p in [Vector2(-28, 0), Vector2(-12, -10), Vector2(16, -8), Vector2(30, 8)]:
		c.draw_circle(Vector2(bx, by) + p, 1.6, Color(1, 1, 1, 0.6))


## The top of the warm-up boulder, in hub coordinates (for the climber).
func boulder_top() -> Vector2:
	var l: Control = layers["rock"]
	return l.position + Vector2(l.size.x * 0.36 + 4.0, l.size.y - PAD - 48.0)


func _paint_near(c: Control) -> void:
	var s := c.size
	var g := PackedVector2Array([Vector2(0, s.y)])
	for i in 33:
		var x := float(i) / 32.0 * s.x
		g.append(Vector2(x, s.y - PAD - 6.0 + sin(x * 0.07) * 3.0))
	g.append(Vector2(s.x, s.y))
	c.draw_colored_polygon(g, Color("#5a5a2e"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 90:
		var x := rng.randf() * s.x
		var y := s.y - PAD - 4.0 + rng.randf() * 10.0
		c.draw_line(Vector2(x, y), Vector2(x + rng.randf_range(-2, 2), y - rng.randf_range(4, 9)), Color("#7a7a3a").lerp(Color("#c9b16a"), rng.randf() * 0.5), 1.0)


func _paint_frame(c: Control) -> void:
	# A soft dark frame (vignette) so the eye rests in the middle.
	var s := c.size
	for i in 10:
		var k := float(i) / 10.0
		var r := Rect2(Vector2(k, k) * 18.0, s - Vector2(k, k) * 36.0)
		c.draw_rect(r, Color(0.08, 0.055, 0.03, 0.045), false, 18.0 / 10.0 * 2.0)


class _Layer:
	extends Control
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)
