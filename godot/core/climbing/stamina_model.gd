class_name StaminaModel
extends RefCounted
## Climbing stamina: the arms and lungs for this climb, second to second.
##
## Separate from expedition energy, which sets how big the bar is at the
## start. Rates carry over from the Expo simulation (src/features/climbing/
## sim.ts) so both versions of the Barranco Wall ask the same of the player.

const TIRED := 0.30  # fraction of the bar below which the climber is tired

## Per second. Positive drains, negative recovers.
const RATES := {
	"climb": 6.0,      # moving on a face
	"hang": 2.0,       # holding still on a face
	"scramble": 3.0,   # moving on easy boulders
	"traverse": 6.5,   # moving sideways on a face
	"walk": 0.5,       # walking costs breath, more as the air thins
	"walk_up": 1.6,    # walking uphill
	"ice": 0.9,        # short careful steps on ice
	"still": -10.0,
	"rest": -22.0,     # sitting down (REST) on ordinary ground: the only way back on the mountain
	"rest_gust": -6.0, # hunkered down on windy ground with goggles and a buff
	"sit": 0.0,        # sitting with no rest left, or on windy ground: safe, nothing back
	"rest_stone": -30.0,
	"helping": 0.0,
	"crimp": 14.0,      # moving on small holds (the crag)
	"crimp_hang": 12.0, # holding still on them: don't
	"jug": -8.0,        # hanging off a big hold: a shake-out
	"sloper": 7.0,      # moving on rounded holds: steady, not fast
	"sloper_hang": 4.0, # holding a sloper costs a little, but lets the grip settle
	"pocket": 0.0,      # a good two-finger pocket: hang there for free
}
## Loose rock costs a third more: you test every hold.
const LOOSE_FACTOR := 1.35

var max_value: float
var value: float
## 0.2 – 1.2: how much of normal recovery this climb allows (cold slows it).
var recovery: float = 1.0
## Multiplies drain (thin air, cold).
var drain: float = 1.0
## Multiplies what walking costs: how thin the air is for this party, from
## the climb's altitude and how acclimatized they are (thin_air_for).
var thin_air: float = 1.0
## Multiplies what holding on to rock costs (numb fingers in the cold).
var grip: float = 1.0
## Multiplies what being on rock costs: the shoes (crag mode).
var shoes: float = 1.0
## False on expedition climbs: there, standing about gives nothing back;
## only REST (and a rest stone) does.
var still_recovers := true
## Gear found on this attempt: multiplies what walking (trekking poles),
## ice (crampons) and rock (gloves) cost. 1 without it.
var walk_gear: float = 1.0
var ice_gear: float = 1.0
var rock_gear: float = 1.0
const ON_ROCK := ["climb", "hang", "traverse", "crimp", "crimp_hang", "sloper", "sloper_hang"]
const WALKING := ["walk", "walk_up", "ice"]


static func max_for_energy(energy: float) -> float:
	return clampf(round(55.0 + energy * 0.45), 55.0, 100.0)


func _init(energy: float = 80.0, recovery_factor: float = 1.0, drain_factor: float = 1.0) -> void:
	max_value = max_for_energy(energy)
	value = max_value
	recovery = clampf(recovery_factor, 0.2, 1.2)
	drain = clampf(drain_factor, 0.5, 2.0)


## How hard walking is at `meters` for a party with `acclimatization` (the
## expedition stat). The height part rises gently, a little for every
## few hundred metres: 1 at 4,000 m, about 1.5 at the crater rim, never
## more than 1.6, so the top of the mountain is harder breathing, not a
## wall. Not being used to the height adds up to two thirds again: the
## camp's choices (rest days, climb high and sleep low) are what keep it
## off.
static func thin_air_for(meters: float, acclimatization: float) -> float:
	return snappedf(height_factor(meters) * gap_factor(meters, acclimatization), 0.01)


static func height_factor(meters: float) -> float:
	return clampf(1.0 + (meters - 4000.0) / 3500.0, 0.7, 1.6)


static func gap_factor(meters: float, acclimatization: float) -> float:
	var gap := maxf(0.0, ExpeditionEngine.acclimatization_need(meters) - acclimatization)
	return 1.0 + minf(gap, 40.0) / 60.0


## What `activity` costs a second right now (negative: it gives back), with
## everything that scales it: thin air, grip, shoes, the climb's drain or
## recovery.
func rate(activity: String, loose: bool = false) -> float:
	var r: float = RATES.get(activity, 0.0)
	if activity == "still" and not still_recovers:
		return 0.0
	if activity in WALKING:
		r *= thin_air * (ice_gear if activity == "ice" else walk_gear)
	elif activity in ON_ROCK:
		r *= grip * shoes * rock_gear
	if r > 0.0:
		return r * drain * (LOOSE_FACTOR if loose else 1.0)
	return r * recovery


## Seconds until the bar is empty doing `activity`, or INF if it does not
## drain.
func seconds_left(activity: String) -> float:
	var r := rate(activity)
	return value / r if r > 0.0 else INF


## Advances `dt` seconds of `activity`. Returns the new value.
func tick(dt: float, activity: String, loose: bool = false) -> float:
	value = clampf(value - rate(activity, loose) * dt, 0.0, max_value)
	return value


func spend(amount: float) -> bool:
	if value < amount:
		return false
	value -= amount
	return true


func fraction() -> float:
	return value / max_value if max_value > 0.0 else 0.0


func is_tired() -> bool:
	return fraction() < TIRED


func is_empty() -> bool:
	return value <= 0.0


func refill(fraction_of_max: float = 1.0) -> void:
	value = maxf(value, max_value * clampf(fraction_of_max, 0.0, 1.0))
