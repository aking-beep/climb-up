class_name Climate
extends RefCounted
## Temperature and light on a climb. Each level has its own day: the Lava
## Tower starts in hot afternoon sun on black rock and ends at a cold
## sunset, the summit night goes from cold to colder to dawn, the way down
## goes from frost into the heat of the lower slopes. How far along the
## route you are moves you through it, and the clock moves the sun on as
## you go (a slow climb gets colder).
##
## The cold slows you (stiff legs, numb hands) and slows getting your breath
## back; heat makes everything cost a little more. The sky is tinted to
## match, and the HUD says the temperature in degrees and in words.
## Game fiction: numbers picked to be felt, not a weather model.

## Below this it starts to slow you, and to slow recovery.
const COOL := 5.0
## Above this the heat makes moving cost more.
const WARM := 24.0
## Per degree of cold below COOL, and the most it can take.
const SLOW_PER_DEG := 0.008
const SLOWEST := 0.85
const REST_PER_DEG := 0.01
const REST_LEAST := 0.8
## Per degree of heat above WARM, and the most it can add.
const HEAT_PER_DEG := 0.015
const HEAT_MOST := 1.15

## [progress, degrees C] from start (0) to finish (1).
var temps: Array = [[0.0, 10.0], [1.0, 10.0]]
## [progress, colour] for the light: the tint laid over the world.
var light: Array = [[0.0, Color(1, 1, 1, 0)], [1.0, Color(1, 1, 1, 0)]]
## Degrees per minute of climbing the sun adds or takes (negative: the
## evening coming on), and the most it can move them.
var drift := 0.0
var drift_most := 4.0


static func from_spec(spec: Dictionary) -> Climate:
	var c := Climate.new()
	if spec.is_empty():
		return c
	c.temps = spec.get("temps", c.temps)
	c.light = []
	for k in spec.get("light", [[0.0, "#00000000"], [1.0, "#00000000"]]):
		c.light.append([float(k[0]), Color(k[1])])
	c.drift = float(spec.get("drift", 0.0))
	c.drift_most = float(spec.get("driftMost", 4.0))
	return c


static func _lerp_keys(keys: Array, p: float) -> Variant:
	if p <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if p <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var t := (p - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			if a[1] is Color:
				return (a[1] as Color).lerp(b[1], t)
			return lerpf(float(a[1]), float(b[1]), t)
	return keys[-1][1]


## Degrees C at `progress` (0 start, 1 finish) after `seconds` on the climb.
func degrees(progress: float, seconds: float) -> float:
	var base: float = _lerp_keys(temps, clampf(progress, 0.0, 1.0))
	return base + clampf(drift * seconds / 60.0, -drift_most, drift_most)


func tint(progress: float) -> Color:
	return _lerp_keys(light, clampf(progress, 0.0, 1.0))


## How fast you move at `deg` (1 = normal).
static func pace(deg: float) -> float:
	return clampf(1.0 - maxf(0.0, COOL - deg) * SLOW_PER_DEG, SLOWEST, 1.0)


## How fast stamina comes back at `deg` (1 = normal).
static func rest(deg: float) -> float:
	return clampf(1.0 - maxf(0.0, COOL - deg) * REST_PER_DEG, REST_LEAST, 1.0)


## What moving costs at `deg` (1 = normal).
static func heat(deg: float) -> float:
	return clampf(1.0 + maxf(0.0, deg - WARM) * HEAT_PER_DEG, 1.0, HEAT_MOST)


## The temperature in words, with what it does.
## Words follow the shown (rounded) degrees, so the number and the words
## never disagree, and a 0% effect is never claimed.
static func words(deg: float) -> String:
	var d := int(round(deg))
	var hot := int(round((heat(deg) - 1.0) * 100.0))
	var slow := int(round((1.0 - pace(deg)) * 100.0))
	if d >= int(WARM) and hot > 0:
		return "%d°C · hot: every move costs %d%% more" % [d, hot]
	if d >= int(COOL) or (d > 0 and slow == 0):
		return "%d°C · mild" % d
	if d >= 0 or slow == 0:
		return "%d°C · cool: a little slower" % d
	return "%d°C · freezing: %d%% slower, rest works less" % [d, slow]
