class_name RainSchedule
extends RefCounted
## Rain in showers (the cloud forest): steady drizzle, then a warning (the
## sky darkens, the drops get heavier), then a downpour, then drizzle
## again. Deterministic for a seed, on the climber's clock, so a climb can
## be replayed and tested.
##
## What a downpour does (ClimbLevel._rain): wet rock costs WET_ROCK times
## as much to climb or hang on, and a rest out in it gives back only
## OPEN_REST as fast. Under rock (an overhang, a prow, a niche) or on a
## rest stone you are out of it. Read the sky: climb in the drizzle, wait
## out the downpour under rock.

enum Phase { DRIZZLE, COMING, POUR }

const COMING_S := 2.5
const POUR_S := 8.0
const WET_ROCK := 1.5
const OPEN_REST := 0.5

var period: float
var offset: float


func _init(seed: int = 1, every: float = 24.0) -> void:
	period = maxf(every, COMING_S + POUR_S + 6.0)
	offset = float(posmod(seed * 4931, 1000)) / 1000.0 * period


func phase_at(t: float) -> int:
	var p := fposmod(t + offset, period)
	var dry := period - COMING_S - POUR_S
	if p < dry:
		return Phase.DRIZZLE
	if p < dry + COMING_S:
		return Phase.COMING
	return Phase.POUR


func pouring(t: float) -> bool:
	return phase_at(t) == Phase.POUR


## Seconds until the downpour ends (0 when it is not pouring).
func pour_left(t: float) -> float:
	if not pouring(t):
		return 0.0
	return period - fposmod(t + offset, period)


## True when it does not pour from `t` for `seconds`.
func dry_for(t: float, seconds: float) -> bool:
	var s := 0.0
	while s <= seconds:
		if pouring(t + s):
			return false
		s += 0.1
	return true
