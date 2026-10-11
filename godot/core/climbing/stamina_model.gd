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
	"brace": 1.0,      # braced against a gust
	"walk": 0.5,       # walking costs breath, more as the air thins
	"walk_up": 1.6,    # walking uphill
	"ice": 0.9,        # short careful steps on ice
	"still": -10.0,
	"rest": -18.0,     # sitting down on ordinary ground
	"rest_stone": -26.0,
	"helping": 0.0,
}
const LOOSE_FACTOR := 1.6

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
const ON_ROCK := ["climb", "hang", "traverse"]
const WALKING := ["walk", "walk_up", "ice"]


static func max_for_energy(energy: float) -> float:
	return clampf(round(55.0 + energy * 0.45), 55.0, 100.0)


func _init(energy: float = 80.0, recovery_factor: float = 1.0, drain_factor: float = 1.0) -> void:
	max_value = max_for_energy(energy)
	value = max_value
	recovery = clampf(recovery_factor, 0.2, 1.2)
	drain = clampf(drain_factor, 0.5, 2.0)


## How hard walking is at `meters` for a party with `acclimatization` (the
## expedition stat): 1 at 4,000 m for an acclimatized party, rising with
## height, and up to twice that again for a party that has not adapted.
static func thin_air_for(meters: float, acclimatization: float) -> float:
	var height := clampf(1.0 + (meters - 4000.0) / 2000.0, 0.6, 2.0)
	var gap := maxf(0.0, ExpeditionEngine.acclimatization_need(meters) - acclimatization)
	return snappedf(height * (1.0 + minf(gap, 40.0) / 40.0), 0.01)


## Advances `dt` seconds of `activity`. Returns the new value.
func tick(dt: float, activity: String, loose: bool = false) -> float:
	var rate: float = RATES.get(activity, 0.0)
	if activity in WALKING:
		rate *= thin_air
	elif activity in ON_ROCK:
		rate *= grip
	if rate > 0.0:
		value -= rate * drain * (LOOSE_FACTOR if loose else 1.0) * dt
	else:
		value -= rate * recovery * dt
	value = clampf(value, 0.0, max_value)
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
