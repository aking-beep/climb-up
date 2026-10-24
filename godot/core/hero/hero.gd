class_name Hero
extends Node2D
## The CLIMB UP 2.0 climber, drawn in code (no bitmaps): one rig (HeroRig),
## a soft ink outline, a key light from the upper left, and every cosmetic
## slot of the look (jacket, headwear, pack, harness, chalk bag, rope,
## skin, hair, body) as its own layer. The node's origin is the point
## between the feet; `height` is the standing height in pixels.
##
## Ported from the design reference (design/magic-patterns/Hero.tsx).
## Original art: nothing is copied from another game.

const INK := Color("#1c1915")
const PANTS := Color("#3a342c")
const MOUTH := Color("#5a2a22")
const SHADE := Color(0.043, 0.102, 0.165, 0.18)

## A look: colours as "#rrggbb" strings, plus headwear, pack and pattern.
const DEFAULT_LOOK := {
	"jacket": "#6f7a3f", "jacketTrim": "#4f5a2c", "headwear": "helmet", "headwearColor": "#e9c46a",
	"pack": "crag", "packColor": "#a8432a", "harness": "#1f3d34", "chalkBag": "#d8c7a4",
	"bagPattern": "stripe", "rope": "#d9572b", "skin": "#c68a62", "hair": "#2a1d16", "body": "m",
}

## The party sprites' clips (Sheet.CLIPS) as poses, so a drawn person can
## follow the same state machine as a sprite.
const SPRITE_POSES := {"idle": "idle", "walk": "walk", "tired": "walk", "brace": "brace", "fall": "fall",
	"scramble": "climb", "climb": "climb", "hang": "hang", "mantle": "mantle", "rest": "sit",
	"slip": "fall", "help": "work", "celebrate": "celebrate"}

@export var height := 44.0
var look: Dictionary = DEFAULT_LOOK.duplicate()
var pose := "idle":
	set(v):
		pose = v
		view = HeroRig.VIEW.get(v, "front")
var view := "front"
## 1 faces right, -1 left (side view).
var facing := 1.0
## "climb" shows the harness and climbing shoes, "trek" boots, "camp" no pack.
var kit := "climb"
## "" uses the pose's own face.
var expression := ""
## Desyncs people standing together.
var phase := 0.0
## When set (>= 0), the pose is frozen at this time (tests, still frames).
var still := -1.0
## Eases from one pose to the next.
var smooth := true

var _t := 0.0
var _shown: Dictionary = {}
var _b: Dictionary = HeroRig.build("m")
var _body := "m"


## Copies what a (hidden) party sprite is doing: its clip, its facing,
## its tint. Teammates and you keep their sprites for the game's logic and
## show this instead.
func follow(sprite: AnimatedSprite2D) -> void:
	pose = SPRITE_POSES.get(String(sprite.animation), "idle")
	facing = -1.0 if sprite.flip_h else 1.0
	modulate = sprite.modulate


func set_look(l: Dictionary) -> void:
	look = DEFAULT_LOOK.duplicate()
	look.merge(l, true)
	if String(look.get("body", "m")) != _body:
		_body = String(look.get("body", "m"))
		_b = HeroRig.build(_body)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var t := (still if still >= 0.0 else _t) + phase
	var target := HeroRig.compute(_b, pose, view, t)
	if _shown.is_empty() or not smooth or still >= 0.0 or Settings.reduced_motion:
		_shown = target
	else:
		_shown = HeroRig.lerp_pose(_shown, target, 1.0 - exp(-minf(delta, 0.1) / 0.055))
	queue_redraw()


func current_pose() -> Dictionary:
	if _shown.is_empty():
		_shown = HeroRig.compute(_b, pose, view, maxf(still, 0.0) + phase)
	return _shown


func _c(key: String) -> Color:
	return Color(String(look.get(key, DEFAULT_LOOK.get(key, "#ff00ff"))))


func _draw() -> void:
	var b := _b
	var p := current_pose()
	var t := (still if still >= 0.0 else _t) + phase
	var s := HeroRig.scale_of(b) * height / HeroRig.STAND
	var G := HeroRig.ground_y(b)
	var f := HeroRig.frame(b, p["lean"], view)
	var armL := HeroRig.chain(f["sL"], p["uaL"], p["faL"], b["ua"], b["fa"])
	var armR := HeroRig.chain(f["sR"], p["uaR"], p["faR"], b["ua"], b["fa"])
	var legL := HeroRig.chain(f["hL"], p["thL"], p["shL"], b["th"], b["sh"])
	var legR := HeroRig.chain(f["hR"], p["thR"], p["shR"], b["th"], b["sh"])
	var oy: float = G - (maxf(legL[2].y, legR[2].y) + b["ankle"]) if p["grounded"] else 0.0
	var off := Vector2(p["dx"], oy - p["lift"] - G)
	var base := Transform2D().scaled(Vector2(s * facing, s)) * Transform2D(0.0, off)
	_base_m = base
	draw_set_transform_matrix(base)
	var ow := 1.35 / HeroRig.scale_of(b) * (44.0 / maxf(height, 1.0)) * 0.9
	var side := view == "side"
	var back := view == "back"
	var front := view == "front"
	var climb := kit == "climb"
	var show_pack: bool = String(look["pack"]) != "none" and kit != "camp"
	var tilt: float = p["lean"] + p["tilt"]
	var up2 := Vector2(sin(deg_to_rad(tilt)), -cos(deg_to_rad(tilt)))
	var hc: Vector2 = f["neckBase"] + up2 * (b["neck"] + b["headR"] * b["headRy"] * 0.9)
	var parts: Array[Callable] = []
	var arm := func(pts: Array, a: float, far: bool, thumb: float) -> void: _arm(pts, a, far, thumb, ow)
	var leg := func(pts: Array, th: float, sh: float, far: bool, toe: float) -> void: _leg(pts, th, sh, far, toe, ow, climb)
	if side:
		parts = [arm.bind(armL, p["faL"], true, 1.0), leg.bind(legL, p["thL"], p["shL"], true, 1.0),
			_pack_behind.bind(f, p, ow, show_pack), leg.bind(legR, p["thR"], p["shR"], false, 1.0),
			_pelvis.bind(f, ow), _torso.bind(f, ow), _harness.bind(f, p, ow, climb), _chalk.bind(f, ow, climb),
			_straps.bind(f, ow, show_pack), _neck.bind(f, up2, ow), _head.bind(hc, tilt, t, ow, p),
			arm.bind(armR, p["faR"], false, 1.0)]
	elif back:
		parts = [leg.bind(legL, p["thL"], p["shL"], false, -1.0), leg.bind(legR, p["thR"], p["shR"], false, 1.0),
			_pelvis.bind(f, ow), _torso.bind(f, ow), _harness.bind(f, p, ow, climb), _neck.bind(f, up2, ow),
			_pack_back.bind(f, p, ow, show_pack), _chalk.bind(f, ow, climb), _head.bind(hc, tilt, t, ow, p),
			arm.bind(armL, p["faL"], false, -1.0), arm.bind(armR, p["faR"], false, 1.0)]
	else:
		parts = [_pack_behind.bind(f, p, ow, show_pack), leg.bind(legL, p["thL"], p["shL"], false, -1.0),
			leg.bind(legR, p["thR"], p["shR"], false, 1.0), _pelvis.bind(f, ow), _torso.bind(f, ow),
			_harness.bind(f, p, ow, climb), _chalk.bind(f, ow, climb), _straps.bind(f, ow, show_pack),
			_neck.bind(f, up2, ow), _head.bind(hc, tilt, t, ow, p), arm.bind(armL, p["faL"], false, 1.0),
			arm.bind(armR, p["faR"], false, -1.0)]
	for part in parts:
		_base_m = base
		draw_set_transform_matrix(base)
		part.call()
	draw_set_transform_matrix(Transform2D())


# ---------------------------------------------------------------- shapes


func _seg(a: Vector2, b: Vector2, r1: float, r2: float) -> PackedVector2Array:
	var d := b - a
	var L := maxf(d.length(), 0.001)
	var n := Vector2(-d.y / L, d.x / L)
	return PackedVector2Array([a + n * r1, b + n * r2, b - n * r2, a - n * r1])


func _capsule(a: Vector2, b: Vector2, r1: float, r2: float, color: Color) -> void:
	if a.distance_to(b) > 0.01:
		draw_colored_polygon(_seg(a, b, r1, r2), color)
	draw_circle(a, r1, color)
	draw_circle(b, r2, color)


func _ellipse_pts(c: Vector2, rx: float, ry: float, n: int = 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _ellipse(c: Vector2, rx: float, ry: float, fill: Color, ow: float = 0.0) -> void:
	if ow > 0.0:
		draw_colored_polygon(_ellipse_pts(c, rx + ow, ry + ow), INK)
	draw_colored_polygon(_ellipse_pts(c, rx, ry), fill)


func _quad(a: Vector2, c: Vector2, b: Vector2, n: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var k := float(i) / float(n)
		pts.append(a.lerp(c, k).lerp(c.lerp(b, k), k))
	return pts


func _stroke(pts: PackedVector2Array, color: Color, w: float) -> void:
	draw_polyline(pts, color, w, true)


## A filled closed shape with an ink edge.
func _shape(pts: PackedVector2Array, fill: Color, ow: float) -> void:
	if pts.size() < 3:
		return
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, INK, ow, true)


func _rrect(r: Rect2, fill: Color, ow: float) -> void:
	var rad := minf(r.size.x, r.size.y) * 0.32
	var inner := Rect2(r.position + Vector2(rad, 0), Vector2(r.size.x - rad * 2.0, r.size.y))
	if ow > 0.0:
		_capsule(r.position + Vector2(rad, rad), r.position + Vector2(rad, r.size.y - rad), rad + ow, rad + ow, INK)
		_capsule(r.end - Vector2(rad, r.size.y - rad), r.end - Vector2(rad, rad), rad + ow, rad + ow, INK)
		draw_rect(inner.grow(ow), INK)
	_capsule(r.position + Vector2(rad, rad), r.position + Vector2(rad, r.size.y - rad), rad, rad, fill)
	_capsule(r.end - Vector2(rad, r.size.y - rad), r.end - Vector2(rad, rad), rad, rad, fill)
	draw_rect(inner, fill)
	draw_rect(Rect2(r.position + Vector2(0, rad), Vector2(r.size.x, r.size.y - rad * 2.0)), fill)


# ---------------------------------------------------------------- body


func _limb(pts: Array, ws: Array, fill: Color, ow: float, far: bool) -> void:
	for pass_i in 2:
		var g := ow if pass_i == 0 else 0.0
		var c := INK if pass_i == 0 else fill
		_capsule(pts[0], pts[1], ws[0] + g, ws[1] + g, c)
		_capsule(pts[1], pts[2], ws[1] + g, ws[2] + g, c)
	if far:
		_capsule(pts[0], pts[1], ws[0], ws[1], Color(SHADE, 0.24))
		_capsule(pts[1], pts[2], ws[1], ws[2], Color(SHADE, 0.24))


func _arm(pts: Array, a: float, far: bool, thumb: float, ow: float) -> void:
	var b := _b
	_limb(pts, b["armW"], _c("jacket"), ow, far)
	var cuff: Vector2 = (pts[1] as Vector2).lerp(pts[2], 0.86)
	draw_circle(cuff, b["armW"][2] * 1.08, _c("jacketTrim"))
	var at: Vector2 = pts[2] + HeroRig.dir(a) * (b["handR"] * 0.62)
	var r: float = b["handR"]
	draw_set_transform_matrix(_m() * Transform2D(deg_to_rad(-a), at))
	_ellipse(Vector2(thumb * r * 0.62, -r * 0.2), r * 0.36, r * 0.5, _c("skin"), ow)
	_ellipse(Vector2.ZERO, r * 0.8, r, _c("skin"), ow)
	if far:
		_ellipse(Vector2.ZERO, r * 0.8, r, Color(SHADE, 0.22))
	draw_set_transform_matrix(_m())


func _leg(pts: Array, th: float, sh: float, far: bool, toe: float, ow: float, climb: bool) -> void:
	var b := _b
	_limb(pts, b["legW"], PANTS, ow, far)
	if climb:
		_band((pts[0] as Vector2).lerp(pts[1], 0.24), th, b["legW"][0] + 0.5, 1.35, _c("harness"), ow * 0.8)
	_shoe(pts[2], sh, 1.0 if view == "side" else toe, view != "side", not climb, ow, far)


func _band(at: Vector2, a: float, half: float, th: float, fill: Color, ow: float) -> void:
	var m := _m()
	draw_set_transform_matrix(m * Transform2D(deg_to_rad(-a + 90.0), at))
	_capsule(Vector2(0, -half + th), Vector2(0, half - th), th + ow, th + ow, INK)
	_capsule(Vector2(0, -half + th), Vector2(0, half - th), th, th, fill)
	draw_set_transform_matrix(m)


func _shoe(at: Vector2, a: float, toe: float, frontal: bool, boot: bool, ow: float, far: bool) -> void:
	var k: float = _b["foot"] / 10.5
	var m := _m()
	var sx := (0.62 if frontal else 1.0) * toe * k
	draw_set_transform_matrix(m * Transform2D(deg_to_rad(-a), at) * Transform2D().scaled(Vector2(sx, k)))
	var body := Color("#5a3d2e") if boot else Color("#4a5a66")
	var pts := PackedVector2Array([Vector2(-3.6, -3), Vector2(-4.4, 1), Vector2(-2.6, 4.2), Vector2(7.4, 4.2),
		Vector2(10.6, 3.6), Vector2(11.4, 2), Vector2(9.4, -0.6), Vector2(4.2, -2.6), Vector2(2.6, -4)])
	_shape(pts, body, ow / k)
	_stroke(PackedVector2Array([Vector2(-2.8, 3.1), Vector2(10.8, 2.6)]), Color("#2a2420"), 1.8)
	if not boot:
		_stroke(PackedVector2Array([Vector2(0.6, -2.6), Vector2(3.4, -1.4)]), _c("rope"), 1.7)
	if far:
		draw_colored_polygon(pts, Color(SHADE, 0.24))
	draw_set_transform_matrix(m)


func _pelvis(f: Dictionary, ow: float) -> void:
	var w: float = _b["legW"][0]
	if view == "side":
		draw_circle(Vector2.ZERO, w + 0.8 + ow, INK)
		draw_circle(Vector2.ZERO, w + 0.8, PANTS)
	else:
		_capsule(f["hL"], f["hR"], w + 0.6 + ow, w + 0.6 + ow, INK)
		_capsule(f["hL"], f["hR"], w + 0.6, w + 0.6, PANTS)


func _torso(f: Dictionary, ow: float) -> void:
	var b := _b
	var k := 0.82 if view == "side" else 1.0
	_capsule(f["waist"], f["chest"], b["waistR"] * k + ow, b["chestR"] * k + ow, INK)
	_capsule(f["waist"], f["chest"], b["waistR"] * k, b["chestR"] * k, _c("jacket"))
	# Cool shade on the side away from the light (upper left).
	var shade_x: float = f["chest"].x + b["chestR"] * (-0.1 if view == "side" else 0.32)
	var pts := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var y := lerpf(f["chest"].y - b["chestR"], f["waist"].y + b["waistR"], float(i) / steps)
		var kk := clampf((y - f["chest"].y) / maxf(f["waist"].y - f["chest"].y, 0.01), 0.0, 1.0)
		var r := lerpf(b["chestR"], b["waistR"], kk) * k
		var cx := lerpf(f["chest"].x, f["waist"].x, kk)
		var dy := y - lerpf(f["chest"].y, f["waist"].y, kk)
		var half := sqrt(maxf(r * r - dy * dy * 0.2, 0.0))
		pts.append(Vector2(maxf(shade_x, cx - half), y))
	for i in range(steps, -1, -1):
		var y := lerpf(f["chest"].y - b["chestR"], f["waist"].y + b["waistR"], float(i) / steps)
		var kk := clampf((y - f["chest"].y) / maxf(f["waist"].y - f["chest"].y, 0.01), 0.0, 1.0)
		var r := lerpf(b["chestR"], b["waistR"], kk) * k
		var cx := lerpf(f["chest"].x, f["waist"].x, kk)
		pts.append(Vector2(maxf(shade_x, cx + r * 0.95), y))
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, Color(SHADE, 0.16))
	var trim := _c("jacketTrim")
	if view == "front":
		_stroke(PackedVector2Array([Vector2(f["chest"].x * 0.9, f["chest"].y - b["chestR"] * 0.7), f["waist"] + Vector2(0, b["waistR"] * 0.2)]), trim, ow * 1.1)
		var nb: Vector2 = f["neckBase"]
		_stroke(PackedVector2Array([nb + Vector2(-b["chestR"] * 0.45, 1), nb + Vector2(0, b["chestR"] * 0.55), nb + Vector2(b["chestR"] * 0.45, 1)]), trim, ow * 1.4)
	elif view == "side":
		var c: Vector2 = f["chest"]
		_stroke(_quad(c + Vector2(b["chestR"] * 0.35, -b["chestR"] * 0.5), c + Vector2(b["chestR"] * 0.6, 3), f["waist"] + Vector2(b["waistR"] * 0.45, 0)), trim, ow)


func _harness(f: Dictionary, p: Dictionary, ow: float, climb: bool) -> void:
	if not climb:
		return
	var b := _b
	var at: Vector2 = f["up"] * (b["waistR"] * 0.12)
	_band(at, 180.0 - p["lean"], b["waistR"] * (0.84 if view == "side" else 1.04), 1.8, _c("harness"), ow)
	_quickdraw(at + f["right"] * ((-0.7 if view == "side" else 0.82) * b["waistR"]), ow)
	if view != "side":
		_quickdraw(at + f["right"] * (-0.82 * b["waistR"]), ow)


func _quickdraw(at: Vector2, ow: float) -> void:
	var o := at + Vector2(0, 1.4)
	draw_line(o + Vector2(-0.9, 0), o + Vector2(-0.9, 3.4), Color("#b9c2c8"), 0.9)
	draw_line(o + Vector2(0.9, 0), o + Vector2(0.9, 3.4), Color("#b9c2c8"), 0.9)
	draw_rect(Rect2(o + Vector2(-1.1 - ow * 0.6, 3 - ow * 0.6), Vector2(2.2 + ow * 1.2, 3.2 + ow * 1.2)), INK)
	draw_rect(Rect2(o + Vector2(-1.1, 3), Vector2(2.2, 3.2)), Color("#e9c46a"))


func _chalk(f: Dictionary, ow: float, climb: bool) -> void:
	if not climb:
		return
	var b := _b
	var belt: Vector2 = f["up"] * (b["waistR"] * 0.12)
	var at: Vector2
	if view == "back":
		at = belt + Vector2(0, 1.2)
	elif view == "side":
		at = belt - f["right"] * (b["waistR"] * 0.95)
	else:
		at = belt + f["right"] * (b["waistR"] * 1.05)
	var k: float = b["waistR"] / 8.5
	var w := 5.4 * k
	var h := 6.2 * k
	_rrect(Rect2(at + Vector2(-w / 2.0, 0), Vector2(w, h)), _c("chalkBag"), ow)
	match String(look.get("bagPattern", "plain")):
		"stripe":
			draw_line(at + Vector2(-w / 2.0, h * 0.5), at + Vector2(w / 2.0, h * 0.4), Color("#a8432a"), 1.2)
		"topo":
			_stroke(_quad(at + Vector2(-w / 2.0, h * 0.45), at + Vector2(0, h * 0.25), at + Vector2(w / 2.0, h * 0.5)), Color(INK, 0.5), 0.6)
		"dots":
			draw_circle(at + Vector2(-w * 0.18, h * 0.45), 0.6, Color("#f7f4ee"))
			draw_circle(at + Vector2(w * 0.2, h * 0.65), 0.6, Color("#f7f4ee"))
	_capsule(at + Vector2(-w / 2.0, 0), at + Vector2(w / 2.0, 0), 0.9 + ow * 0.8, 0.9 + ow * 0.8, INK)
	_capsule(at + Vector2(-w / 2.0, 0), at + Vector2(w / 2.0, 0), 0.9, 0.9, Color("#f7f4ee"))


func _pack_size() -> Vector2:
	var b := _b
	match String(look["pack"]):
		"daypack":
			return Vector2(b["chestR"] * 1.5, b["torso"] * 0.6)
		"expedition":
			return Vector2(b["chestR"] * 1.95, b["torso"] * 0.95)
	return Vector2(b["chestR"] * 1.7, b["torso"] * 0.74)


func _pack_back(f: Dictionary, p: Dictionary, ow: float, show: bool) -> void:
	if not show:
		return
	var pk := _pack_size()
	var m := _m()
	draw_set_transform_matrix(m * Transform2D(deg_to_rad(p["lean"]), f["chest"]))
	var r := Rect2(Vector2(-pk.x / 2.0, -pk.y * 0.6), pk)
	_rrect(r, _c("packColor"), ow)
	draw_rect(Rect2(Vector2(pk.x * 0.08, -pk.y * 0.6 + 1), Vector2(pk.x * 0.36, pk.y - 2)), Color(SHADE, 0.16))
	_stroke(_quad(Vector2(-pk.x / 2.0 + 1, -pk.y * 0.32), Vector2(0, -pk.y * 0.18), Vector2(pk.x / 2.0 - 1, -pk.y * 0.32)), Color(INK, 0.5), ow)
	draw_rect(Rect2(Vector2(-pk.x * 0.26, pk.y * 0.02), Vector2(pk.x * 0.52, pk.y * 0.24)), Color(0, 0, 0, 0.14))
	if String(look["pack"]) == "expedition":
		_rrect(Rect2(Vector2(-pk.x / 2.0 - 1.5, -pk.y * 0.6 - 5), Vector2(pk.x + 3, 6)), Color("#cdbf9f"), ow)
	draw_set_transform_matrix(m)


func _pack_behind(f: Dictionary, p: Dictionary, ow: float, show: bool) -> void:
	if not show:
		return
	var b := _b
	var pk := _pack_size()
	var m := _m()
	if view == "side":
		var at: Vector2 = f["chest"] - f["right"] * (b["chestR"] * 0.8 + pk.x * 0.26)
		draw_set_transform_matrix(m * Transform2D(deg_to_rad(p["lean"]), at))
		_rrect(Rect2(Vector2(-pk.x * 0.3, -pk.y * 0.6), Vector2(pk.x * 0.6, pk.y)), _c("packColor"), ow)
		if String(look["pack"]) == "expedition":
			_rrect(Rect2(Vector2(-pk.x * 0.34, -pk.y * 0.6 - 5), Vector2(pk.x * 0.68, 6)), Color("#cdbf9f"), ow)
	else:
		draw_set_transform_matrix(m * Transform2D(deg_to_rad(p["lean"]), f["chest"]))
		_rrect(Rect2(Vector2(-pk.x / 2.0 - 1.5, -pk.y * 0.62), Vector2(pk.x + 3, pk.y * 0.9)), _c("packColor"), ow)
	draw_set_transform_matrix(m)


func _straps(f: Dictionary, ow: float, show: bool) -> void:
	if not show:
		return
	var b := _b
	var c := _c("packColor")
	if view == "side":
		_stroke(_quad(f["sR"] - Vector2(1, 0), f["chest"] + Vector2(b["chestR"] * 0.9, 2), f["waist"] + Vector2(b["waistR"] * 0.5, -1)), c, 2.4)
	else:
		_stroke(PackedVector2Array([f["sL"] + Vector2(2.5, -1), f["waist"] + Vector2(-b["waistR"] * 0.55, 0)]), c, 2.4)
		_stroke(PackedVector2Array([f["sR"] + Vector2(-2.5, -1), f["waist"] + Vector2(b["waistR"] * 0.55, 0)]), c, 2.4)
		_stroke(PackedVector2Array([f["chest"] + Vector2(-b["chestR"] * 0.55, 0), f["chest"] + Vector2(b["chestR"] * 0.55, 0)]), c, 1.4)


func _neck(f: Dictionary, up2: Vector2, ow: float) -> void:
	var b := _b
	var a: Vector2 = f["neckBase"] - f["up"] * 1.5
	var c: Vector2 = f["neckBase"] + up2 * (b["neck"] + 2.5)
	var r: float = b["headR"] * 0.24
	_capsule(a, c, r + ow, r + ow, INK)
	_capsule(a, c, r, r, _c("skin"))
	if String(look["headwear"]) == "headlamp":
		_capsule(a + f["up"] * 1.0, a + f["up"] * 3.2, b["headR"] * 0.32, b["headR"] * 0.3, _c("headwearColor"))


## The current transform (the base for local shapes).
var _base_m := Transform2D()


func _m() -> Transform2D:
	return _base_m


# ---------------------------------------------------------------- head (authored at R = 15)


func _head(hc: Vector2, tilt: float, t: float, ow: float, p: Dictionary) -> void:
	var b := _b
	var m := _m()
	var k: float = b["headR"] / 15.0
	draw_set_transform_matrix(m * Transform2D(deg_to_rad(tilt), hc) * Transform2D().scaled(Vector2(k, k)))
	ow = ow / k
	var rx: float = 15.0 * b["headRx"]
	var ry: float = 15.0 * b["headRy"]
	var side := view == "side"
	var back := view == "back"
	var fem := _body == "f"
	var hair := _c("hair")
	var skin := _c("skin")
	var sway := sin(t * 2.6) * 1.6
	if fem and side:
		_shape(_quad(Vector2(-11, -7), Vector2(-25, sway), Vector2(-21 + sway, 17)) + _quad(Vector2(-21 + sway, 17), Vector2(-17, 5), Vector2(-7, -1)), hair, ow)
	if fem and not side and not back:
		_shape(PackedVector2Array([Vector2(-rx - 2, -2), Vector2(-rx - 3, 10), Vector2(-rx + 3, 18), Vector2(rx - 3, 18), Vector2(rx + 3, 10), Vector2(rx + 2, -2)]), hair, ow)
	if not back:
		_ellipse(Vector2(-0.8 if side else 0.0, -1.5), rx + 0.8, ry + 0.4, hair, ow)
	if not side:
		_ellipse(Vector2(-rx + (0.4 if back else 0.0), 3), 2.6, 3.4, skin, ow)
		_ellipse(Vector2(rx - (0.4 if back else 0.0), 3), 2.6, 3.4, skin, ow)
	_ellipse(Vector2.ZERO, rx, ry, hair if back else skin, ow)
	if back:
		_stroke(_quad(Vector2(-rx * 0.8, ry * 0.55), Vector2(0, ry * 0.95), Vector2(rx * 0.8, ry * 0.55)), Color(0, 0, 0, 0.2), 2.0)
		if fem:
			_shape(PackedVector2Array([Vector2(-4.5, -4), Vector2(-6 + sway, 14), Vector2(-2 + sway, 25), Vector2(1 + sway, 28),
				Vector2(3.5 + sway, 24), Vector2(5.5, 12), Vector2(4.5, -4)]), hair, ow)
	if side:
		_ellipse(Vector2(-3.6, 3), 2.4, 3.3, skin, ow)
	if not back:
		_face(side, expression if expression != "" else String(p["expr"]), t, ow, fem)
		var fringe := PackedVector2Array()
		if side:
			fringe = _quad(Vector2(-15.2, 4), Vector2(-16, -15.5), Vector2(0, -16)) + _quad(Vector2(0, -16), Vector2(14, -15.8), Vector2(15.3, -3)) \
				+ _quad(Vector2(15.3, -3), Vector2(11, -8.5), Vector2(5, -9)) + _quad(Vector2(5, -9), Vector2(1, -6), Vector2(-4, -8)) \
				+ _quad(Vector2(-4, -8), Vector2(-6, -1), Vector2(-8.6, 1.5)) + _quad(Vector2(-8.6, 1.5), Vector2(-11.5, 6), Vector2(-15.2, 4))
		else:
			fringe = _quad(Vector2(-15.2, 1), Vector2(-16, -15.5), Vector2(0, -16)) + _quad(Vector2(0, -16), Vector2(16, -15.5), Vector2(15.2, 1)) \
				+ _quad(Vector2(15.2, 1), Vector2(14, -6), Vector2(9, -8.5)) + _quad(Vector2(9, -8.5), Vector2(4, -5.5), Vector2(-1, -8.8)) \
				+ _quad(Vector2(-1, -8.8), Vector2(-6, -6), Vector2(-10, -8)) + _quad(Vector2(-10, -8), Vector2(-13.5, -4), Vector2(-15.2, 1))
		_shape(_dedupe(fringe), hair, ow)
	_headwear(String(look["headwear"]), _c("headwearColor"), ow)
	draw_set_transform_matrix(m)


func _dedupe(pts: PackedVector2Array) -> PackedVector2Array:
	var o := PackedVector2Array()
	for q in pts:
		if o.is_empty() or o[o.size() - 1].distance_to(q) > 0.05:
			o.append(q)
	if o.size() > 1 and o[0].distance_to(o[o.size() - 1]) < 0.05:
		o.remove_at(o.size() - 1)
	return o


func _face(side: bool, expr: String, t: float, ow: float, fem: bool) -> void:
	var e: Dictionary = _b["eye"]
	var blink := fmod(t, 3.7) < 0.12 and expr != "happy"
	var closed := blink or expr == "calm"
	var xs := [7.4, 0.6] if side else [-e["x"], e["x"]]
	var sc := [1.0, 0.72] if side else [1.0, 1.0]
	var mx := 6.6 if side else 0.0
	var my: float = e["y"] + 8.6
	var w := 3.3
	var brow_lift := -1.6 if expr == "worried" else (1.3 if expr in ["effort", "determined"] else (-0.6 if expr == "happy" else 0.0))
	for i in 2:
		var x: float = xs[i]
		draw_circle(Vector2(x + (1.0 if side else (-2.2 if x < 0 else 2.2)), e["y"] + 5.4), 2.6 * sc[i], Color("#e07a5f", 0.3))
	for i in 2:
		var x: float = xs[i]
		var rx: float = e["rx"] * sc[i]
		var ry: float = e["ry"]
		var y: float = e["y"]
		if closed:
			_stroke(_quad(Vector2(x - rx, y), Vector2(x, y + ry * 0.75), Vector2(x + rx, y)), INK, ow * 1.2)
		elif expr == "happy":
			_stroke(_quad(Vector2(x - rx, y + ry * 0.35), Vector2(x, y - ry * 1.05), Vector2(x + rx, y + ry * 0.35)), INK, ow * 1.4)
		else:
			var tired := expr == "tired"
			_ellipse(Vector2(x + (0.4 if side else 0.0), y + (ry * 0.25 if tired else 0.0)), rx, ry * 0.6 if tired else ry, INK)
			draw_circle(Vector2(x - rx * 0.28, y - ry * 0.32), e["hl"] * sc[i], Color.WHITE)
			if tired:
				draw_line(Vector2(x - rx * 1.1, y - ry * 0.25), Vector2(x + rx * 1.1, y - ry * 0.25), INK, ow)
			if fem:
				var out := 1.0 if side else (-1.0 if x < 0 else 1.0)
				var ex := x + out * rx * 0.85
				draw_line(Vector2(ex, y - ry * 0.55), Vector2(ex + out * 1.6, y - ry * 0.55 - 1.4), INK, ow * 0.9)
		var by: float = e["y"] - e["ry"] - 2.1
		var d := -1.0 if side else (1.0 if x < 0 else -1.0)
		var hw: float = 2.4 * sc[i]
		draw_line(Vector2(x - d * hw, by), Vector2(x + d * hw, by + brow_lift), INK, _b["brow"])
	draw_colored_polygon(_ellipse_pts(Vector2(12.5 if side else 0.0, e["y"] + 4.2), 1.1, 0.8, 10), Color(0, 0, 0, 0.14))
	_mouth(expr, mx, my, w * 0.75 if side else w, t, ow)


func _mouth(expr: String, x: float, y: float, w: float, t: float, ow: float) -> void:
	match expr:
		"happy":
			_shape(_quad(Vector2(x - w, y - 0.6), Vector2(x, y + 5.4), Vector2(x + w, y - 0.6)), MOUTH, ow)
		"effort":
			draw_rect(Rect2(Vector2(x - w * 0.85, y - 0.6), Vector2(w * 1.7, 2.4)), Color("#f7f4ee"))
			draw_rect(Rect2(Vector2(x - w * 0.85, y - 0.6), Vector2(w * 1.7, 2.4)), INK, false, ow)
		"determined":
			draw_line(Vector2(x - w * 0.7, y + 0.6), Vector2(x + w * 0.7, y), INK, ow * 1.1)
		"worried":
			_ellipse(Vector2(x, y + 0.8), w * 0.4, 1.5, MOUTH, ow * 0.7)
		"talk":
			_ellipse(Vector2(x, y + 0.6), w * 0.55, 1.9 if sin(t * 11.0) > 0.0 else 0.6, MOUTH, ow * 0.7)
		"tired":
			_ellipse(Vector2(x, y + 0.8), w * 0.38, 1.1 + 0.4 * sin(t * 4.0), MOUTH, ow * 0.7)
		"calm":
			_stroke(_quad(Vector2(x - w * 0.7, y), Vector2(x, y + 2), Vector2(x + w * 0.7, y)), INK, ow * 1.1)
		_:
			_stroke(_quad(Vector2(x - w * 0.8, y), Vector2(x, y + 1.8), Vector2(x + w * 0.8, y)), INK, ow * 1.1)


func _dome(x0: float, x1: float, y: float, top: float) -> PackedVector2Array:
	var mid := (x0 + x1) / 2.0
	return _dedupe(_quad(Vector2(x0, y), Vector2(x0, top), Vector2(mid, top)) + _quad(Vector2(mid, top), Vector2(x1, top), Vector2(x1, y)))


func _headwear(hw: String, c: Color, ow: float) -> void:
	var side := view == "side"
	var front := view == "front"
	match hw:
		"helmet":
			var strap := _c("harness")
			if front:
				_stroke(_quad(Vector2(-14, -1), Vector2(-13, 9), Vector2(-4, 13.5)), strap, 1.0)
				_stroke(_quad(Vector2(14, -1), Vector2(13, 9), Vector2(4, 13.5)), strap, 1.0)
			elif side:
				_stroke(_quad(Vector2(-6, -2), Vector2(-4, 8), Vector2(4, 13)), strap, 1.0)
			_shape(_dome(-16.2, 16.4 if side else 16.2, -2.5, -22.5), c, ow)
			draw_line(Vector2(-16.8, -2.5), Vector2(16.8, -2.5), INK, 3.2)
			draw_line(Vector2(-16.8, -2.5), Vector2(16.8, -2.5), c, 1.6)
			for vx in [-6.0, -1.2, 3.6]:
				draw_rect(Rect2(Vector2(vx, -16.5 if vx != -1.2 else -17.0), Vector2(2.4, 4.4)), Color(0, 0, 0, 0.22))
			_stroke(_quad(Vector2(-9, -15.5), Vector2(-4, -18.6), Vector2(2, -18.4)), Color(1, 1, 1, 0.55), 1.8)
		"beanie":
			_shape(_dome(-15.8, 15.8, -3, -21.5), c, ow)
			_rrect(Rect2(Vector2(-16.6, -7), Vector2(33.2, 6.4)), c, ow)
			for x in [-11.0, -5.5, 0.0, 5.5, 11.0]:
				draw_line(Vector2(x, -6), Vector2(x, -1.6), Color(INK, 0.25), 0.7)
			_ellipse(Vector2(-2.0 if side else 0.0, -20.6), 3.6, 3.6, Color("#f7f4ee"), ow)
		"sunhat":
			_ellipse(Vector2(0, -4), 22.0 if side else 24.0, 3.6 if side else 5.2, c, ow)
			_shape(_dome(-11.5, 11.5, -4, -20.5), c, ow)
			draw_rect(Rect2(Vector2(-11.4, -8.4), Vector2(22.8, 3.2)), Color("#a8432a", 0.85))
		"headlamp":
			_shape(PackedVector2Array([Vector2(-15.6, -7.5), Vector2(0, -12), Vector2(15.6, -7.5), Vector2(15.6, -3.4), Vector2(0, -8), Vector2(-15.6, -3.4)]), c, ow)
			if front:
				_rrect(Rect2(Vector2(-4.6, -12), Vector2(9.2, 7)), Color("#2a2a2a"), ow)
				draw_circle(Vector2(0, -8.5), 2.4, Color("#ffd37a"))
			elif side:
				_rrect(Rect2(Vector2(11, -11.5), Vector2(6, 6.4)), Color("#2a2a2a"), ow)
				draw_circle(Vector2(16.4, -8.3), 1.8, Color("#ffd37a"))
		"cap":
			if side:
				_shape(PackedVector2Array([Vector2(9, -4.6), Vector2(21, -5), Vector2(23, -1.6), Vector2(11, -1.6)]), c, ow)
			_shape(_dome(-15.6, 15.6, -3, -21.5), c, ow)
			if front:
				_ellipse(Vector2(0, -2.6), 13, 3.2, c, ow)
