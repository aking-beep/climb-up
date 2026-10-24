class_name HeroRig
extends RefCounted
## The climber's skeleton and pose library (CLIMB UP 2.0), ported from the
## design reference (design/magic-patterns/heroRig.ts). Pure functions: the
## renderer (Hero) reads these numbers, and tests can check a pose without
## drawing it.
##
## Angles are degrees: 0 points straight down the screen, +90 to the right,
## 180 straight up. dir(a) = (sin a, cos a).

## Build A ("trail storybook", 3.4 heads), the direction the design chose.
const BUILD := {
	"headR": 15.0, "neck": 3.0, "torso": 27.0, "chestR": 10.5, "waistR": 8.5,
	"shoulderW": 9.5, "hipW": 5.2, "ua": 16.0, "fa": 14.0, "th": 19.0, "sh": 18.0,
	"armW": [4.6, 3.7, 3.1], "legW": [6.2, 4.7, 3.7], "handR": 4.3, "foot": 10.5,
	"ankle": 3.0, "headRx": 1.0, "headRy": 0.96,
	"eye": {"x": 6.2, "y": 2.6, "rx": 2.15, "ry": 2.95, "hl": 0.85}, "brow": 1.25,
}

const POSES := ["idle", "walk", "run", "climb", "climbA", "climbB", "reach", "mantle", "rest",
	"fall", "celebrate", "talk", "sit", "clip", "hang", "shake", "wave", "brace", "work", "crouch", "jump"]
const WALL := ["climb", "climbA", "climbB", "reach", "clip", "hang", "shake", "mantle"]
## The natural view of each pose.
const VIEW := {
	"idle": "front", "walk": "side", "run": "side", "climb": "back", "climbA": "back", "climbB": "back",
	"reach": "back", "mantle": "back", "rest": "side", "fall": "front", "celebrate": "front", "talk": "front",
	"sit": "side", "clip": "back", "hang": "back", "shake": "back", "wave": "front", "brace": "side",
	"work": "side", "crouch": "side", "jump": "side",
}
const KEYS := ["lean", "tilt", "uaL", "faL", "uaR", "faR", "thL", "shL", "thR", "shR", "dx", "lift"]
## Every build is drawn the same standing height (view-box units).
const STAND := 124.0


## The build for a body: "f" is the same rig with narrower shoulders, a
## defined waist, wider hips and finer hands and feet. Same poses and kit.
static func build(body: String = "m") -> Dictionary:
	var b: Dictionary = BUILD.duplicate(true)
	if body == "f":
		b["shoulderW"] *= 0.86
		b["chestR"] *= 0.9
		b["waistR"] *= 0.84
		b["hipW"] *= 1.16
		b["armW"] = [b["armW"][0] * 0.86, b["armW"][1] * 0.86, b["armW"][2] * 0.86]
		b["legW"] = [b["legW"][0] * 1.04, b["legW"][1] * 0.92, b["legW"][2] * 0.88]
		b["handR"] *= 0.88
		b["foot"] *= 0.92
		b["eye"]["ry"] *= 1.06
		b["eye"]["rx"] *= 1.04
		b["brow"] *= 0.78
	return b


static func ground_y(b: Dictionary) -> float:
	return b["th"] + b["sh"] + b["ankle"]


static func stand_height(b: Dictionary) -> float:
	return ground_y(b) + b["torso"] + b["neck"] + b["headR"] * 2.0 * b["headRy"] + 2.0


static func scale_of(b: Dictionary) -> float:
	return STAND / stand_height(b)


static func dir(a: float) -> Vector2:
	return Vector2(sin(deg_to_rad(a)), cos(deg_to_rad(a)))


static func _ang(v: Vector2) -> float:
	return rad_to_deg(atan2(v.x, v.y))


## Joints relative to the hip, before the limbs.
static func frame(b: Dictionary, lean: float, view: String) -> Dictionary:
	var up := Vector2(sin(deg_to_rad(lean)), -cos(deg_to_rad(lean)))
	var right := Vector2(cos(deg_to_rad(lean)), sin(deg_to_rad(lean)))
	var side := view == "side"
	var chest: Vector2 = up * (b["torso"] - b["chestR"] * 0.9)
	var shoulder_mid: Vector2 = chest + up * (b["chestR"] * 0.35)
	var sw: float = 1.2 if side else b["shoulderW"]
	var hw: float = 1.0 if side else b["hipW"]
	return {
		"up": up, "right": right, "waist": up * (b["waistR"] * 0.35), "chest": chest,
		"neckBase": up * b["torso"], "sL": shoulder_mid - right * sw, "sR": shoulder_mid + right * sw,
		"hL": -right * hw, "hR": right * hw,
	}


## Two-bone IK: the [upper, lower] angles that put the end of a limb from
## `s` at `t`. `out` picks the side the elbow or knee bends to (-1 or 1).
static func ik2(s: Vector2, t: Vector2, a: float, b: float, out: float) -> Array:
	var d := t - s
	var dist := maxf(d.length(), 0.001)
	var most := a + b - 0.01
	if dist > most:
		d *= most / dist
		dist = most
	var least := absf(a - b) + 0.01
	if dist < least:
		d *= least / dist
		dist = least
	var base := atan2(d.x, d.y)
	var alpha := acos(clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0))
	var u1 := base + alpha
	var u2 := base - alpha
	var e1 := s + Vector2(sin(u1), cos(u1)) * a
	var e2 := s + Vector2(sin(u2), cos(u2)) * a
	var pick_first := (e1.x - e2.x) * out >= 0.0
	var u := u1 if pick_first else u2
	var e := e1 if pick_first else e2
	return [rad_to_deg(u), _ang(s + d - e)]


static func _base(side: bool) -> Dictionary:
	if side:
		return {"lean": 3.0, "tilt": 0.0, "uaL": 2.0, "faL": 10.0, "uaR": 6.0, "faR": 16.0, "thL": -2.0,
			"shL": -3.0, "thR": 2.0, "shR": 0.0, "dx": 0.0, "lift": 0.0, "grounded": true, "expr": "neutral"}
	return {"lean": 0.0, "tilt": 0.0, "uaL": -9.0, "faL": -4.0, "uaR": 9.0, "faR": 4.0, "thL": -4.0,
		"shL": -2.0, "thR": 4.0, "shR": 2.0, "dx": 0.0, "lift": 0.0, "grounded": true, "expr": "neutral"}


static func _with(base: Dictionary, over: Dictionary) -> Dictionary:
	var o := base.duplicate()
	o.merge(over, true)
	return o


## Hand and foot targets on the wall, as fractions of reach.
static func wall_targets(b: Dictionary, pose: String, t: float) -> Dictionary:
	var f := frame(b, 0.0, "back")
	var arm: float = b["ua"] + b["fa"]
	var leg: float = b["th"] + b["sh"]
	var H := func(p: Vector2, v: Vector2) -> Vector2: return p + v * arm
	var F := func(p: Vector2, v: Vector2) -> Vector2: return p + v * leg
	var A := {"hL": H.call(f["sL"], Vector2(-0.22, -0.93)), "hR": H.call(f["sR"], Vector2(0.36, -0.55)),
		"fL": F.call(f["hL"], Vector2(-0.26, 0.9)), "fR": F.call(f["hR"], Vector2(0.42, 0.52))}
	var B := {"hL": H.call(f["sL"], Vector2(-0.36, -0.55)), "hR": H.call(f["sR"], Vector2(0.22, -0.93)),
		"fL": F.call(f["hL"], Vector2(-0.42, 0.52)), "fR": F.call(f["hR"], Vector2(0.26, 0.9))}
	match pose:
		"climbA":
			return A
		"climbB":
			return B
		"climb":
			var p := (sin(t / 1.3 * TAU) + 1.0) / 2.0
			var s := p * p * (3.0 - 2.0 * p)
			var o := {}
			for k in A:
				o[k] = (A[k] as Vector2).lerp(B[k], s)
			return o
		"reach":
			return {"hL": H.call(f["sL"], Vector2(-0.12, -0.62)), "hR": H.call(f["sR"], Vector2(0.3, -0.99)),
				"fL": F.call(f["hL"], Vector2(-0.2, 0.96)), "fR": F.call(f["hR"], Vector2(0.36, 0.74))}
		"clip":
			return {"hL": H.call(f["sL"], Vector2(-0.08, -0.97)), "hR": Vector2(b["waistR"] * 0.2, -b["torso"] * 0.32),
				"fL": F.call(f["hL"], Vector2(-0.3, 0.86)), "fR": F.call(f["hR"], Vector2(0.3, 0.86))}
		"hang":
			return {"hL": H.call(f["sL"], Vector2(0.26, -0.96)), "hR": H.call(f["sR"], Vector2(-0.26, -0.96)),
				"fL": F.call(f["hL"], Vector2(-0.04, 1.0)), "fR": F.call(f["hR"], Vector2(0.08, 0.99))}
		"shake":
			return {"hL": H.call(f["sL"], Vector2(0.1, -0.98)), "hR": H.call(f["sR"], Vector2(0.12 + 0.06 * sin(t * 14.0), 0.97)),
				"fL": F.call(f["hL"], Vector2(-0.3, 0.86)), "fR": F.call(f["hR"], Vector2(0.32, 0.82))}
		"mantle":
			var k := (sin(t * 2.2) + 1.0) / 2.0
			return {"hL": H.call(f["sL"], Vector2(-0.1, 0.18)), "hR": H.call(f["sR"], Vector2(0.1, 0.18)),
				"fL": F.call(f["hL"], Vector2(-0.36, 0.22 + 0.08 * k)), "fR": F.call(f["hR"], Vector2(0.06, 0.98))}
	return A


## The pose at time `t` (seconds).
static func compute(b: Dictionary, pose: String, view: String, t: float) -> Dictionary:
	var side := view == "side"
	var base := _base(side)
	var br := sin(t / 2.4 * TAU)
	if pose in WALL:
		var T := wall_targets(b, pose, t)
		var lean := 5.0 if pose == "reach" else (-3.0 if pose == "mantle" else 0.0)
		var f := frame(b, lean, "back")
		var expr := "effort" if pose in ["reach", "mantle"] else ("tired" if pose == "hang" else "determined")
		var o := _with(base, {"lean": lean, "grounded": false, "expr": expr})
		var r: Array = ik2(f["sL"], T["hL"], b["ua"], b["fa"], -1.0)
		o["uaL"] = r[0]
		o["faL"] = r[1]
		r = ik2(f["sR"], T["hR"], b["ua"], b["fa"], 1.0)
		o["uaR"] = r[0]
		o["faR"] = r[1]
		r = ik2(f["hL"], T["fL"], b["th"], b["sh"], -1.0)
		o["thL"] = r[0]
		o["shL"] = r[1]
		r = ik2(f["hR"], T["fR"], b["th"], b["sh"], 1.0)
		o["thR"] = r[0]
		o["shR"] = r[1]
		return o
	match pose:
		"idle":
			if side:
				return _with(base, {"uaR": 6 + br * 1.5, "faR": 16 + br * 2, "uaL": 2 - br, "faL": 10 - br, "lift": br * 0.4})
			return _with(base, {"uaL": -9 - br * 1.2, "faL": -4 - br * 1.5, "uaR": 9 + br * 1.2, "faR": 4 + br * 1.5, "lift": br * 0.4, "tilt": br * 0.8})
		"walk":
			var ph := t / 0.8 * TAU
			var o := _with(_base(true), {"lean": 5.0, "tilt": sin(ph * 2.0) * 1.2})
			_legs(o, ph, 3.0, 24.0, 6.0, 40.0, 1.3)
			_arms(o, ph, 20.0, 14.0, 8.0)
			return o
		"run":
			var ph := t / 0.5 * TAU
			var o := _with(_base(true), {"lean": 15.0, "lift": 2.5 * maxf(0.0, sin(ph * 2.0)), "expr": "determined"})
			_legs(o, ph, 10.0, 42.0, 18.0, 78.0, 1.0)
			for s in [["R", ph], ["L", ph + PI]]:
				var u := -46.0 * sin(s[1])
				o["ua" + s[0]] = u
				o["fa" + s[0]] = u + 85.0
			return o
		"jump":
			return _with(_base(true), {"lean": 10.0, "thR": 70, "shR": 10, "thL": 30, "shL": -40, "uaR": 150, "faR": 165,
				"uaL": 120, "faL": 150, "grounded": false, "expr": "effort"})
		"talk":
			var g := sin(t * 2.1)
			if side:
				return _with(base, {"uaR": 30 + 12 * g, "faR": 100 + 16 * sin(t * 3.1), "tilt": 3 * sin(t * 1.3), "expr": "talk"})
			return _with(base, {"uaR": 24 + 10 * g, "faR": 95 + 18 * sin(t * 3.1), "uaL": -9 - br, "faL": -4, "tilt": 3 * sin(t * 1.3), "expr": "talk"})
		"sit":
			return _with(_base(true), {"lean": 8 + br * 1.2, "thR": 86, "shR": 8, "thL": 80, "shL": 2, "uaR": 34, "faR": 80, "uaL": 28, "faL": 74, "expr": "calm"})
		"rest":
			var hb := sin(t / 1.5 * TAU)
			return _with(_base(true), {"lean": 38 + hb * 2, "thR": 26, "shR": -8, "thL": 14, "shL": -14, "uaR": 30, "faR": 6,
				"uaL": 24, "faL": 2, "tilt": -18, "expr": "tired", "lift": hb * 0.5})
		"brace":
			return _with(_base(true), {"lean": 26, "thR": 52, "shR": -20, "thL": -10, "shL": -34, "uaR": 60, "faR": 20, "uaL": 30, "faL": 8, "tilt": -6, "expr": "determined"})
		"work":
			var w := sin(t * 3.4)
			return _with(_base(true), {"lean": 18, "thR": 10, "shR": -4, "thL": -4, "shL": -8, "uaR": 46 + 10 * w, "faR": 92 + 8 * w, "uaL": 36 - 6 * w, "faL": 86, "tilt": 10})
		"crouch":
			var w := sin(t * 2.6)
			return _with(_base(true), {"lean": 30, "thR": 100, "shR": -20, "thL": 60, "shL": -60, "uaR": 60 + 8 * w, "faR": 40 + 10 * w, "uaL": 50, "faL": 30, "tilt": 14})
		"fall":
			var w := sin(t * 9.0)
			return _with(_base(false), {"lean": -8, "uaL": -140 + w * 14, "faL": -170 + w * 18, "uaR": 145 - w * 14, "faR": 175 - w * 16,
				"thL": -22, "shL": 6, "thR": 30, "shR": 60, "grounded": false, "expr": "worried"})
		"celebrate":
			var hop := absf(sin(t / 0.7 * PI))
			return _with(_base(false), {"uaL": -148, "faL": -166, "uaR": 148, "faR": 166, "thL": -6, "thR": 6, "lift": hop * 3, "expr": "happy"})
		"wave":
			var w := sin(t * 7.0)
			return _with(_base(false), {"uaR": 140, "faR": 170 + w * 18, "uaL": -9 - br, "lift": br * 0.4, "expr": "happy"})
	return base


static func _legs(o: Dictionary, ph: float, th0: float, th_amp: float, knee0: float, knee_amp: float, power: float) -> void:
	for s in [["R", ph], ["L", ph + PI]]:
		var th := th0 + th_amp * sin(s[1])
		o["th" + s[0]] = th
		o["sh" + s[0]] = th - (knee0 + knee_amp * pow(maxf(0.0, cos(s[1])), power))


static func _arms(o: Dictionary, ph: float, swing: float, bend: float, extra: float) -> void:
	for s in [["R", ph], ["L", ph + PI]]:
		var u := -swing * sin(s[1])
		o["ua" + s[0]] = u
		o["fa" + s[0]] = u + bend + extra * maxf(0.0, -sin(s[1]))


## Eases the shown pose toward the target (k in 0..1), the short way round.
static func lerp_pose(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var o := b.duplicate()
	for key in KEYS:
		var av: float = a.get(key, 0.0)
		var d: float = float(b.get(key, 0.0)) - av
		if key != "dx" and key != "lift":
			d = wrapf(d, -180.0, 180.0)
		o[key] = av + d * k
	return o


## Shoulder, elbow, hand (or hip, knee, foot) from the angles.
static func chain(s: Vector2, u: float, l: float, l1: float, l2: float) -> Array:
	var e := s + dir(u) * l1
	return [s, e, e + dir(l) * l2]
