class_name ChallengeOutcome
extends RefCounted
## How a played climb ended. `to_expo()` has exactly the shape of
## ChallengeOutcome in src/game/hybrid/types.ts, so the Expo coordinator
## could resolve it unchanged; the rest is Godot-only detail.

const RESULTS := ["complete", "retreat", "fail"]

var attempt_id := ""
var challenge_id := "barranco-wall"
var result := "retreat"
var stamina_left := 100  # percent of the bar
var slips := 0
## true: helped the teammate. false: left them. null: never met them.
var assisted: Variant = null
var regrouped := false
var seconds := 0
# Godot-only detail.
var caught := 0
var wind_strikes := 0
var loose_seconds := 0.0
var rest_seconds := 0.0
var checkpoint := 0
var gear_found := 0
var flowers := 0
var flowers_total := 0
var stars := 0
## Health lost on the climb (thorns, ants, ravens), and medicine taken for it.
var hurt := 0
var dosed := false
## Camp supplies eaten on the climb (snacks once the rests ran out).
var food := 0


func to_expo() -> Dictionary:
	return {
		"attemptId": attempt_id,
		"challengeId": challenge_id,
		"result": result,
		"staminaLeft": stamina_left,
		"slips": slips,
		"assisted": assisted,
		"regrouped": regrouped,
		"seconds": seconds,
	}


func to_dict() -> Dictionary:
	var d := to_expo()
	d["caught"] = caught
	d["windStrikes"] = wind_strikes
	d["looseSeconds"] = snappedf(loose_seconds, 0.1)
	d["restSeconds"] = snappedf(rest_seconds, 0.1)
	d["checkpoint"] = checkpoint
	d["gearFound"] = gear_found
	d["flowers"] = flowers
	d["flowersTotal"] = flowers_total
	d["stars"] = stars
	d["hurt"] = hurt
	d["dosed"] = dosed
	d["food"] = food
	return d


## Repairs an outcome from a save; null when it cannot be trusted.
static func from_dict(d: Variant) -> ChallengeOutcome:
	if typeof(d) != TYPE_DICTIONARY:
		return null
	if not (d.get("result") in RESULTS):
		return null
	if typeof(d.get("attemptId")) != TYPE_STRING or String(d.get("attemptId")).is_empty():
		return null
	var o := ChallengeOutcome.new()
	o.attempt_id = d["attemptId"]
	o.challenge_id = String(d.get("challengeId", "barranco-wall"))
	o.result = d["result"]
	o.stamina_left = clampi(int(d.get("staminaLeft", 0)), 0, 100)
	o.slips = clampi(int(d.get("slips", 0)), 0, 99)
	var a: Variant = d.get("assisted")
	o.assisted = a if typeof(a) == TYPE_BOOL else null
	o.regrouped = d.get("regrouped") == true
	o.seconds = clampi(int(d.get("seconds", 0)), 0, 24 * 3600)
	o.caught = clampi(int(d.get("caught", 0)), 0, 99)
	o.wind_strikes = clampi(int(d.get("windStrikes", 0)), 0, 999)
	o.checkpoint = clampi(int(d.get("checkpoint", 0)), 0, 99)
	return o
