class_name ExpeditionState
extends RefCounted
## The prototype's slice of the expedition: enough to brief the Barranco
## Wall, land its outcome, and save. The full rules stay in the Expo engine
## (src/game/engine) until the engine decision is made; the numbers here
## follow the Barranco card and its challenge policy there
## (src/expeditions/kilimanjaro/events.ts and challenges.ts).

const PHASES := ["ascent", "summit", "descent", "home"]

var seed := 7
var day := 5
var hours := 96.0          # expedition clock, hours since the gate
var camp := "Barranco Camp"
var altitude := 3960
var health := 88
var energy := 74
var acclimatization := 46
var team_condition := 82
var weather_risk := 28
var phase := "ascent"
var summit_reached := false
var returned_safely := false
## Once-only score notes: {bucket, label, delta, mark}.
var ledger: Array = []
var last_note := "Barranco Camp. The wall is above the tents, and it is a morning's work."


func clamp_stats() -> void:
	health = clampi(health, 0, 100)
	energy = clampi(energy, 0, 100)
	acclimatization = clampi(acclimatization, 0, 100)
	team_condition = clampi(team_condition, 0, 100)
	weather_risk = clampi(weather_risk, 0, 100)


func note(bucket: String, label: String, delta: int, mark: String) -> void:
	for entry in ledger:
		if entry.get("mark") == mark:
			return
	ledger.append({"bucket": bucket, "label": label, "delta": delta, "mark": mark})


## "Rest beneath the wall": a day at Barranco, no climb.
func rest_day() -> String:
	hours += 24.0
	day += 1
	energy += 10
	team_condition += 4
	note("judgment", "You rested under the wall", 4, "wall-rest")
	clamp_stats()
	last_note = "You rest under the wall. Tomorrow it is still there, and so are you."
	return last_note


## The Barranco card's own effect plus the bounded challenge policy.
func apply_wall(outcome: ChallengeOutcome) -> String:
	var lost_day := 24.0 - 12.0
	match outcome.result:
		"complete":
			camp = "Karanga Camp"
			altitude = 4035
			hours += 12.0
			energy -= 8
			acclimatization += 4
			team_condition += 2
			note("judgment", "You kept the wall day short", 6, "wall-short")
			note("teamwork", "The team came off the wall together", 4, "wall-team")
			var bits := ["You top out on the wall, and Karanga is pitched as the light goes"]
			if outcome.slips > 0:
				health -= mini(6, outcome.slips * 2)
				bits.append("after %d slip%s" % [outcome.slips, "" if outcome.slips == 1 else "s"])
			if outcome.stamina_left < 25:
				energy -= 4
				bits.append("with nothing left in your arms")
			if outcome.assisted == true:
				team_condition += 5
				energy += 3
				note("teamwork", "You stopped for Marco on the Barranco Wall", 6, "wall-assist")
				bits.append("and Marco is beside you")
			elif outcome.assisted == false:
				team_condition -= 6
				note("teamwork", "You left Marco for Lena on the Barranco Wall", -6, "wall-left")
				bits.append("and Lena brings Marco up later")
			if outcome.regrouped:
				energy += 2
				hours += 1.0
				note("judgment", "You regrouped halfway up the Barranco Wall", 3, "wall-regroup")
			last_note = " ".join(bits) + "."
		"retreat":
			hours += 12.0 + lost_day
			energy += 4
			note("judgment", "You backed off the Barranco Wall while it was still your choice", 3, "wall-backoff")
			last_note = "You back off the wall and the party walks down to the Barranco tents again."
		_:
			hours += 12.0 + lost_day
			health -= 6
			energy -= 4
			team_condition -= 4
			note("riskManagement", "The Barranco Wall took more than the team had", -6, "wall-fail")
			last_note = "The wall takes more than the party has. You climb down to Barranco, slowly."
	day = 1 + int(hours / 24.0)
	clamp_stats()
	return last_note


func to_dict() -> Dictionary:
	return {
		"seed": seed, "day": day, "hours": hours, "camp": camp, "altitude": altitude,
		"health": health, "energy": energy, "acclimatization": acclimatization,
		"teamCondition": team_condition, "weatherRisk": weather_risk, "phase": phase,
		"summitReached": summit_reached, "returnedSafely": returned_safely,
		"ledger": ledger.duplicate(true), "lastNote": last_note,
	}


## Rebuilds a state from a save, repairing anything out of range. Null when
## the data is not an expedition at all.
static func from_dict(d: Variant) -> ExpeditionState:
	if typeof(d) != TYPE_DICTIONARY or not d.has("energy") or not d.has("camp"):
		return null
	var s := ExpeditionState.new()
	s.seed = int(d.get("seed", 7))
	s.day = clampi(int(d.get("day", 5)), 1, 30)
	s.hours = clampf(float(d.get("hours", 96.0)), 0.0, 24.0 * 30.0)
	s.camp = String(d.get("camp", "Barranco Camp"))
	s.altitude = clampi(int(d.get("altitude", 3960)), 0, 9000)
	s.health = int(d.get("health", 88))
	s.energy = int(d.get("energy", 74))
	s.acclimatization = int(d.get("acclimatization", 46))
	s.team_condition = int(d.get("teamCondition", 82))
	s.weather_risk = int(d.get("weatherRisk", 28))
	s.phase = String(d.get("phase", "ascent")) if String(d.get("phase", "")) in PHASES else "ascent"
	s.summit_reached = d.get("summitReached") == true
	s.returned_safely = d.get("returnedSafely") == true
	var ledger_in: Variant = d.get("ledger", [])
	if typeof(ledger_in) == TYPE_ARRAY:
		for entry in ledger_in:
			if typeof(entry) == TYPE_DICTIONARY and entry.has("mark") and entry.has("delta"):
				s.ledger.append({
					"bucket": String(entry.get("bucket", "judgment")),
					"label": String(entry.get("label", "")),
					"delta": clampi(int(entry["delta"]), -8, 8),
					"mark": String(entry["mark"]),
				})
	s.last_note = String(d.get("lastNote", s.last_note))
	s.clamp_stats()
	return s


func time_of_day() -> String:
	var h := fposmod(9.0 + hours, 24.0)
	if h < 5.0 or h >= 20.0:
		return "night"
	if h < 8.0:
		return "dawn"
	if h >= 17.0:
		return "dusk"
	return "day"
