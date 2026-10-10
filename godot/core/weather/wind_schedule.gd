class_name WindSchedule
extends RefCounted
## Gusts on exposed ground: a long, readable warning, a short gust, then
## calm. Deterministic for a seed, so a climb can be replayed and tested.
## Same timing as the Expo sim: warn 1.5 s, gust 1.1 s, a period of 3.5–5.5 s
## (worse weather is shorter).

enum Phase { CALM, WARN, BLOW }

const WARN_S := 1.5
const BLOW_S := 1.1

var period: float
var offset: float


func _init(weather_risk: float = 25.0, seed: int = 1, extra_wind: float = 0.0) -> void:
	period = clampf(5.5 - (weather_risk + extra_wind) * 0.02, 3.0, 6.0)
	offset = float(posmod(seed * 7919, 1000)) / 1000.0 * period


func phase_at(t: float) -> int:
	var p := fposmod(t + offset, period)
	if p < WARN_S:
		return Phase.WARN
	if p < WARN_S + BLOW_S:
		return Phase.BLOW
	return Phase.CALM


## Seconds until the next gust starts blowing (0 while one blows).
func until_gust(t: float) -> float:
	var p := fposmod(t + offset, period)
	if p < WARN_S:
		return WARN_S - p
	if p < WARN_S + BLOW_S:
		return 0.0
	return period - p + WARN_S


## True when walking for `seconds` from `t` stays clear of a gust.
func calm_for(t: float, seconds: float) -> bool:
	var step := 0.05
	var s := 0.0
	while s <= seconds:
		if phase_at(t + s) == Phase.BLOW:
			return false
		s += step
	return true
