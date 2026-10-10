class_name Diorama
extends Control
## The expedition seen as a painted diorama, ported from the Expo game's
## world view (src/features/world): the zone's plate, the party walking the
## trail or around the fire, tents, the time of day, fog, drifting motes or
## snow, and a route map. Placement follows src/features/world/layout.ts.

const FRAME := Vector2(32, 40)
const PERSON_UNITS := 4.8
const FIGURE_PX := 30.0
const LEAD_Y := 0.64
const GAP := 8
const LAG_GAP := 6
const CAMP_SPREAD := 2.2
const FORESHORTEN := 0.5
const SEATS := {
	"lena": [-2.6, 1.2, "idle"], "you": [0.2, -2.2, "sit"],
	"marco": [2.8, 0.4, "sit"], "jun": [-1.6, -1.6, "idle"],
}
const CLIPS := {
	"back": [[0, 1, 2, 3], 0.17], "front": [[4, 5, 6, 7], 0.17],
	"idle": [[8, 9], 0.65], "kneel": [[10], 1.0], "sit": [[11], 1.0],
}
const ROUTE_MAP := {
	"briefing": Vector2(0.07, 0.5), "approach": Vector2(0.14, 0.47), "ebc": Vector2(0.23, 0.42),
	"camp1": Vector2(0.32, 0.41), "camp2": Vector2(0.43, 0.58), "camp3": Vector2(0.55, 0.67),
	"camp4": Vector2(0.7, 0.58), "summit": Vector2(0.56, 0.46), "descent": Vector2(0.66, 0.8),
	"complete": Vector2(0.68, 0.93),
}
const ROUTE_ORDER := ["briefing", "approach", "ebc", "camp1", "camp2", "camp3", "camp4", "summit", "descent", "complete"]
const PARTICLES := {
	"rainforest": [Color(0.93, 0.94, 0.67, 0.6), Vector2(0.3, -1), 6.0],
	"moorland": [Color(0.96, 0.93, 0.84, 0.7), Vector2(1, -0.2), 10.0],
	"desert": [Color(0.93, 0.84, 0.7, 0.6), Vector2(1, 0.1), 16.0],
	"snow": [Color(1, 1, 1, 0.9), Vector2(0.3, 1), 14.0],
}

var zone := ""
var meta: Dictionary = {}
var camping := false
var retreating := false
var phase := "day"
var checkpoint := "briefing"
var members: Array = []
var weather := 0.2
var show_map := true

var _plate: TextureRect
var _sky: TextureRect
var _sky_grad: Gradient
var _figures: Control
var _tint: ColorRect
var _warm: ColorRect
var _fog: Array[TextureRect] = []
var _particles: CPUParticles2D
var _sheets := {}
var _props: Texture2D
var _parchment: Texture2D
var _t := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The plates are painted with an open sky; it is drawn behind them.
	_sky = TextureRect.new()
	_sky_grad = Gradient.new()
	var gt := GradientTexture2D.new()
	gt.gradient = _sky_grad
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	_sky.texture = gt
	_sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)
	_plate = TextureRect.new()
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_SCALE
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	var fog_tex: Texture2D = load("res://assets/world/fog.png")
	for i in 2:
		var f := TextureRect.new()
		f.texture = fog_tex
		f.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.stretch_mode = TextureRect.STRETCH_TILE
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(f)
		_fog.append(f)
	_figures = Control.new()
	_figures.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_figures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figures.draw.connect(_draw_figures)
	add_child(_figures)
	_particles = CPUParticles2D.new()
	_particles.amount = 40
	_particles.lifetime = 8.0
	_particles.preprocess = 8.0
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.gravity = Vector2.ZERO
	_particles.spread = 25.0
	add_child(_particles)
	_tint = ColorRect.new()
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tint.material = mul
	add_child(_tint)
	_warm = ColorRect.new()
	_warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_warm.material = add
	add_child(_warm)
	var glow := Control.new()
	glow.name = "Glow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add2 := CanvasItemMaterial.new()
	add2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add2
	glow.draw.connect(_draw_glow.bind(glow))
	add_child(glow)
	var lens := Control.new()
	lens.name = "Lens"
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lens.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	lens.draw.connect(_draw_lens.bind(lens))
	add_child(lens)
	for who in ["you", "lena", "marco", "jun"]:
		_sheets[who] = load("res://assets/world/%s-map.png" % who)
	_props = load("res://assets/world/props.png")
	_parchment = load("res://assets/world/map.png")
	resized.connect(_layout)


## Shows the expedition as it is in `s` (an engine state).
func show_state(s: Dictionary) -> void:
	var z := Kili.zone(s["checkpoint"], float(s["altitude"]))
	if z != zone:
		zone = z
		meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/%s.json" % zone))
		_plate.texture = load("res://assets/world/%s.webp" % zone)
		var p: Array = PARTICLES[zone]
		_particles.color = p[0]
		_particles.direction = p[1]
		_particles.initial_velocity_min = p[2] * 0.5
		_particles.initial_velocity_max = p[2]
		_particles.gravity = Vector2(0, 6) if zone == "snow" else Vector2.ZERO
	checkpoint = s["checkpoint"]
	camping = Kili.camping(checkpoint, float(s["altitude"])) and s["status"] == "active"
	retreating = s["retreating"]
	phase = Party.day_phase(Party.expedition_hour(float(s["elapsedHours"])))
	members = Party.members(s)
	weather = clampf(float(s["weatherRisk"]) / 100.0, 0.0, 1.0)
	var tints := {"day": Color(1, 1, 1), "dawn": Color(1.0, 0.86, 0.82), "dusk": Color(1.0, 0.8, 0.7), "night": Color(0.42, 0.5, 0.74)}
	_tint.color = tints[phase]
	var skies := {
		"night": ["#070b1a", "#121c38", "#26345a"], "dawn": ["#c47862", "#e7c3a4", "#f0e6d4"],
		"dusk": ["#7d403c", "#d39270", "#f0e2cc"], "day": ["#8fa6ae", "#d5ddd6", "#f3efe6"],
	}
	_sky_grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_sky_grad.colors = PackedColorArray([Color(skies[phase][0]), Color(skies[phase][1]), Color(skies[phase][2])])
	_sky.modulate = Color(1.6, 1.4, 1.2) if phase == "night" else Color(1, 1, 1)
	_warm.color = Color(0.12, 0.05, 0.02) if phase == "dusk" or phase == "dawn" else Color(0, 0, 0)
	_particles.amount = 60 if zone == "snow" else 36
	_particles.emitting = Settings.quality != Settings.Quality.LOW_POWER
	_layout()


func _fit() -> Rect2:
	if meta.is_empty():
		return Rect2(Vector2.ZERO, size)
	var mw := float(meta["width"])
	var mh := float(meta["height"])
	var k := maxf(size.x / mw, size.y / mh)
	var w := mw * k
	var h := mh * k
	return Rect2((size.x - w) / 2.0, (size.y - h) * 0.62, w, h)


func _layout() -> void:
	var fit := _fit()
	_plate.position = fit.position
	_plate.size = fit.size
	_sky.size = size
	for i in _fog.size():
		_fog[i].size = Vector2(size.x * 3.0, size.y * 0.45)
		_fog[i].position.y = size.y * (0.35 + i * 0.3)
		_fog[i].modulate = Color(1, 1, 1, minf(0.5, 0.14 + weather * 0.35) * (0.8 if i == 0 else 0.55))
	_figures.size = size
	_tint.size = size
	_warm.size = size
	_particles.position = size / 2.0
	_particles.emission_rect_extents = size / 2.0
	for n in ["Glow", "Lens"]:
		get_node(n).size = size
	_figures.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	for i in _fog.size():
		_fog[i].position.x = -fposmod(_t * (5.0 + i * 4.0), size.x) - size.x * 0.5
	_figures.queue_redraw()
	get_node("Glow").queue_redraw()
	get_node("Lens").queue_redraw()


func _to_view(fit: Rect2, p: Vector2) -> Vector2:
	return fit.position + p * fit.size


func _px(fit: Rect2, scale_at: float) -> float:
	return clampf(PERSON_UNITS * scale_at * fit.size.y / FIGURE_PX, 0.42, 1.4)


func _camp_point(x: float, z: float) -> Dictionary:
	var c: Dictionary = meta["camp"]
	return {
		"p": Vector2(float(c["x"]) + x * CAMP_SPREAD * float(c["scale"]) * float(meta["height"]) / float(meta["width"]),
			float(c["y"]) - z * CAMP_SPREAD * float(c["scale"]) * FORESHORTEN),
		"scale": float(c["scale"]),
	}


## The party's figures: [{id, at, px, frames, flip, phase, tempo}], far first.
func placed() -> Array:
	var out: Array = []
	if meta.is_empty():
		return out
	var fit := _fit()
	if camping:
		var i := 0
		for m in members:
			var seat: Array = SEATS[m["id"]]
			var cp := _camp_point(seat[0], seat[1])
			out.append({"id": m["id"], "at": _to_view(fit, cp["p"]), "px": _px(fit, cp["scale"]),
				"frames": "kneel" if m["pose"] == "kneel" else seat[2], "flip": seat[0] > 0, "phase": i * 0.26, "tempo": 1.0})
			i += 1
	else:
		var trail: Array = meta["trail"]
		var lead := 0
		for j in trail.size():
			if absf(float(trail[j]["y"]) - LEAD_Y) < absf(float(trail[lead]["y"]) - LEAD_Y):
				lead = j
		var at := lead
		var order := members.duplicate()
		order.reverse()
		for j in order.size():
			var m: Dictionary = order[j]
			if j > 0:
				at -= GAP
				if m["pose"] == "lag":
					at -= LAG_GAP
			var pt: Dictionary = trail[clampi(at, 0, trail.size() - 1)]
			var nx: Dictionary = trail[mini(trail.size() - 1, at + 2)]
			out.append({"id": m["id"], "at": _to_view(fit, Vector2(pt["x"], pt["y"])), "px": _px(fit, float(pt["scale"])),
				"frames": "kneel" if m["pose"] == "kneel" else ("front" if retreating else "back"),
				"flip": float(nx["x"]) < float(pt["x"]), "phase": j * 0.17, "tempo": 0.65 if m["pose"] == "lag" else 1.0})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"].y < b["at"].y)
	return out


func _frame(frames: String, t: float) -> int:
	var clip: Array = CLIPS[frames]
	var list: Array = clip[0]
	return list[int(floor(maxf(0.0, t) / clip[1])) % list.size()]


func _draw_figures() -> void:
	if meta.is_empty():
		return
	var fit := _fit()
	if camping:
		var c: Dictionary = meta["camp"]
		var tents := [_camp_point(-5.2, 6.2), _camp_point(4.6, 7.4)]
		for i in tents.size():
			var v := _to_view(fit, tents[i]["p"])
			var px := _px(fit, tents[i]["scale"]) * 1.9
			_figures.draw_rect(Rect2(v.x - 16 * px, v.y - 2 * px, 32 * px, 4 * px), Color(0.04, 0.05, 0.06, 0.3))
			_figures.draw_texture_rect_region(_props, Rect2(v.x - 16 * px, v.y - 24 * px, 32 * px, 24 * px), Rect2(i * 32, 0, 32, 24))
		var fv := _to_view(fit, Vector2(c["x"], c["y"]))
		var fpx := _px(fit, float(c["scale"])) * 1.3
		var f := int(_t * 8.0) % 4
		_figures.draw_texture_rect_region(_props, Rect2(fv.x - 16 * fpx, fv.y - 22 * fpx, 32 * fpx, 24 * fpx), Rect2(64 + f * 32, 0, 32, 24))
	for p in placed():
		var px: float = p["px"]
		var v: Vector2 = p["at"]
		_figures.draw_rect(Rect2(v.x - 9 * px, v.y - 2 * px, 18 * px, 4 * px), Color(0.03, 0.04, 0.05, 0.32))
		var frame := _frame(p["frames"], (_t + p["phase"]) * p["tempo"])
		var src := Rect2((frame % 8) * FRAME.x, floor(frame / 8.0) * FRAME.y, FRAME.x, FRAME.y)
		var dst := Rect2(v.x - FRAME.x * px / 2.0, v.y - FRAME.y * px, FRAME.x * px, FRAME.y * px)
		if p["flip"]:
			dst = Rect2(dst.position.x + dst.size.x, dst.position.y, -dst.size.x, dst.size.y)
		_figures.draw_texture_rect_region(_sheets[p["id"]], dst, src)


func _draw_glow(node: Control) -> void:
	if meta.is_empty():
		return
	var fit := _fit()
	var night := phase == "night"
	var low := phase == "dawn" or phase == "dusk"
	if camping:
		var c: Dictionary = meta["camp"]
		var v := _to_view(fit, Vector2(c["x"], c["y"]))
		var r := _px(fit, float(c["scale"])) * 46.0
		var flick := 0.85 + 0.15 * sin(_t * 9.0) * sin(_t * 3.7)
		_glow(node, v, r, Color(1.0, 0.55, 0.2), (0.55 if night else (0.35 if low else 0.12)) * flick)
	elif night or low:
		for p in placed():
			_glow(node, p["at"] - Vector2(0, FRAME.y * p["px"] * 0.72), p["px"] * 22.0, Color(1, 0.92, 0.7), 0.4 if night else 0.2)


func _glow(node: Control, at: Vector2, r: float, color: Color, strength: float) -> void:
	for i in 6:
		var k := 1.0 - i / 6.0
		node.draw_circle(at, r * k, Color(color.r, color.g, color.b, strength * 0.12))


func _draw_lens(node: Control) -> void:
	# A vignette, then the route map in the corner.
	var night := phase == "night"
	for i in 10:
		var a := (0.04 if not night else 0.06) * (i + 1) / 10.0
		var inset := size.x * 0.035 * (10 - i)
		node.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, inset * 0.6)), Color(0.02, 0.03, 0.06, a * 0.6))
		node.draw_rect(Rect2(Vector2(0, size.y - inset * 0.7), Vector2(size.x, inset * 0.7)), Color(0.02, 0.03, 0.06, a))
	if not show_map:
		return
	var r := clampf(size.y * 0.13, 22.0, 34.0)
	var box := Rect2(Vector2(6, size.y - r * 2.0 - 6), Vector2(r * 2.0, r * 2.0))
	node.draw_rect(box.grow(2), Color(0.48, 0.35, 0.18))
	node.draw_texture_rect(_parchment, box, false, Color(0.62, 0.68, 0.9) if night else Color(1, 1, 1))
	var line := PackedVector2Array()
	for id in ROUTE_ORDER:
		line.append(box.position + ROUTE_MAP[id] * box.size)
		if id == "camp1":
			line.append(box.position + Vector2(0.42, 0.39) * box.size)
	for i in line.size() - 1:
		node.draw_dashed_line(line[i], line[i + 1], Color(0.59, 0.16, 0.08, 0.85), 1.0, 2.5)
	var m: Vector2 = box.position + ROUTE_MAP.get(checkpoint, ROUTE_MAP["briefing"]) * box.size
	var bob := sin(_t * 5.0) * 1.2
	node.draw_circle(m, 2.0, Color("#fff4c8"))
	node.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -1 + bob), m + Vector2(-4, -8 + bob), m + Vector2(4, -8 + bob)]), Color("#f6c445"))
	node.draw_polyline(PackedVector2Array([m + Vector2(0, -1 + bob), m + Vector2(-4, -8 + bob), m + Vector2(4, -8 + bob), m + Vector2(0, -1 + bob)]), Color("#5a3a10"), 0.8)
