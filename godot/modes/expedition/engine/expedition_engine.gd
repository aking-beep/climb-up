class_name ExpeditionEngine
extends RefCounted
## The expedition rules, ported from the Expo game's TypeScript engine
## (src/game/engine: create, select, apply, rules, score). States, cards and
## effects are plain Dictionaries with the same keys as the TypeScript
## types, so tests can compare them with states the original produced
## (tests/fixtures/expeditions.json, from tools/godot/export_content.ts).
##
## JavaScript semantics are kept where they change results: Math.round
## (halves toward +infinity), 32-bit FNV hashing, integer division.

const STAT_KEYS := ["health", "energy", "acclimatization", "oxygen", "supplies", "weatherRisk", "objectiveRisk", "teamCondition"]
const BUCKETS := ["judgment", "riskManagement", "teamwork", "preparation"]
const BUCKET_LABEL := {"judgment": "Judgment", "riskManagement": "Risk management", "teamwork": "Teamwork", "preparation": "Preparation"}


# --- JavaScript arithmetic -----------------------------------------------------

## Math.round: halves go up, including negatives (-2.5 → -2).
static func js_round(x: float) -> int:
	return int(floor(x + 0.5))


## The app's FNV-1a style hash over 32-bit integers (src/utils/number.ts).
static func hash32(nums: Array) -> int:
	var h := 2166136261
	for n in nums:
		var v := int(n) & 0xFFFFFFFF
		h = (h ^ v) & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	return h


static func format_meters(meters: float) -> String:
	var s := str(js_round(meters))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0 and s[i - 1] != "-":
			out = "," + out
	return out


static func to_base36(n: int) -> String:
	if n == 0:
		return "0"
	var digits := "0123456789abcdefghijklmnopqrstuvwxyz"
	var out := ""
	while n > 0:
		out = digits[n % 36] + out
		n = n / 36
	return out


static func bound_stat(v: float) -> int:
	return clampi(js_round(v), 0, 100)


static func bound_altitude(v: float) -> int:
	return clampi(js_round(v), 0, 8849)


# --- Creation and rules --------------------------------------------------------

static func create(seed: int, def: Dictionary) -> Dictionary:
	var safe := seed & 0xFFFFFFFF
	if safe == 0:
		safe = 1
	var start: Dictionary = def["route"][0]
	return {
		"seed": safe, "checkpoint": start["id"], "altitude": int(start["meters"]), "highestAltitude": int(start["meters"]),
		"health": 92, "energy": 88, "acclimatization": 18, "oxygen": 72, "supplies": 86,
		"weatherRisk": 16, "objectiveRisk": 10, "teamCondition": 90, "elapsedHours": 0,
		"summitReached": false, "retreating": false, "returnedSafely": false, "status": "active",
		"history": [], "seen": [], "marks": {}, "lastNote": "",
		"ledger": {"judgment": [], "riskManagement": [], "teamwork": [], "preparation": []},
	}


static func acclimatization_need(meters: float) -> int:
	if meters < 3000:
		return 8
	if meters < 4500:
		return 28
	if meters < 5600:
		return 46
	if meters < 6600:
		return 62
	if meters < 7600:
		return 76
	return 90


static func altitude_strain(acclimatization: float, meters: float) -> Dictionary:
	var gap := acclimatization_need(meters) - acclimatization
	if gap > 30:
		return {"health": -14, "energy": -12}
	if gap > 12:
		return {"health": -7, "energy": -6}
	return {"health": 0, "energy": 0}


static func pressure(s: Dictionary) -> float:
	var gap := maxf(0.0, acclimatization_need(s["altitude"]) - float(s["acclimatization"]))
	var high := 18.0 if s["altitude"] >= 8000 else (10.0 if s["altitude"] >= 7000 else 0.0)
	return clampf(float(s["weatherRisk"]) * 0.38 + float(s["objectiveRisk"]) * 0.32 + gap * 0.2 + (100.0 - float(s["energy"])) * 0.1 + high, 0.0, 100.0)


static func day_of(s: Dictionary) -> int:
	return int(floor(float(s["elapsedHours"]) / 24.0))


# --- Selecting the card --------------------------------------------------------

static func _condition_holds(when: Variant, s: Dictionary) -> bool:
	if when == null:
		return true
	if when.has("mark"):
		return s["marks"].get(when["mark"]) == true
	var v := float(s[when["stat"]])
	if when.has("lt"):
		return v < float(when["lt"])
	return v > float(when["gt"])


static func _available(card: Dictionary, s: Dictionary) -> bool:
	var repeat: String = String(card.get("repeat", ""))
	if repeat == "day" and s["marks"].has("day-" + card["id"]) and int(s["marks"]["day-" + card["id"]]) == day_of(s):
		return false
	if repeat != "day" and not card.get("ephemeral", false) and s["seen"].has(card["id"]):
		return false
	var phase: String = String(card.get("phase", "any"))
	if phase == "up" and s["retreating"]:
		return false
	if phase == "down" and not s["retreating"]:
		return false
	if card.has("checkpoints") and card["checkpoints"] != null and not card["checkpoints"].has(s["checkpoint"]):
		return false
	return _condition_holds(card.get("when"), s)


static func _pick(cards: Array, s: Dictionary) -> Dictionary:
	var total := 0
	for c in cards:
		total += int(c.get("weight", 1))
	var roll := hash32([s["seed"], day_of(s), s["altitude"], s["seen"].size(), 1 if s["retreating"] else 0]) % total
	for c in cards:
		roll -= int(c.get("weight", 1))
		if roll < 0:
			return c
	return cards[cards.size() - 1]


static func current_event(s: Dictionary, def: Dictionary) -> Dictionary:
	var matching: Array = []
	for card in def["events"]:
		if _available(card, s):
			matching.append(card)
	var urgent: Array = matching.filter(func(c: Dictionary) -> bool: return c.get("urgent", false) == true)
	var pool := urgent if not urgent.is_empty() else matching
	if pool.is_empty():
		return route_event(s, def)
	return _pick(pool, s)


static func _route_index(def: Dictionary, id: String) -> int:
	var route: Array = def["route"]
	for i in route.size():
		if route[i]["id"] == id:
			return i
	return -1


static func route_event(s: Dictionary, def: Dictionary) -> Dictionary:
	var route: Array = def["route"]
	var here_i := _route_index(def, s["checkpoint"])
	var place: String = route[here_i]["name"] if here_i >= 0 else ("Descent" if s["checkpoint"] == "descent" else "The route")
	var next: Variant = route[here_i + 1] if here_i + 1 < route.size() and here_i + 1 >= 0 else null
	if s["retreating"] or s["checkpoint"] == "descent":
		return {
			"id": "route-down-%d" % int(s["altitude"]),
			"title": "The way down is the expedition",
			"text": "You are at %s, %s m on this simplified route. Down still has weather, fatigue, and a team attached to it." % [place, format_meters(s["altitude"])],
			"category": "descent", "ephemeral": true,
			"choices": [
				{"label": "Continue down", "detail": "Lose height while the team can still move.",
					"effect": {"note": "You keep the descent moving.", "hours": 8, "move": "down", "supplies": -2, "energy": -4}},
				{"label": "Stop and put the team back together", "detail": "Time and supplies, spent on people.",
					"effect": {"note": "You stop. Water, food, and a quieter hour.", "hours": 8, "move": "hold", "energy": 6, "supplies": -4, "teamCondition": 6,
						"scores": {"teamwork": {"label": "You stopped the descent for the team", "delta": 8, "mark": "descent-stop"}}}},
			],
		}
	var choices: Array = []
	if next != null:
		choices.append({
			"label": "Go for the summit bid" if next["id"] == "summit" else "Move on toward %s" % next["name"],
			"detail": "Height, if the body and the weather still allow a return.",
			"effect": {"note": "You leave %s for %s." % [place, next["name"]], "hours": 10, "move": "up", "energy": -6, "supplies": -3},
		})
	choices.append({
		"label": "Hold a day", "detail": "No height. Lungs, food, and a calmer team.",
		"effect": {"note": "You hold at %s." % place, "hours": 16, "move": "hold", "supplies": -4,
			"scores": {"judgment": {"label": "You spent a day not going higher", "delta": 4, "mark": "hold-%s" % s["checkpoint"]}}},
	})
	if s["checkpoint"] != "briefing":
		choices.append({
			"label": "Turn around", "detail": "The summit stays. The walk out starts.",
			"effect": {"note": "You turn the expedition around at %s." % place, "hours": 6, "move": "retreat",
				"scores": {
					"judgment": {"label": "You turned around while the way down still existed", "delta": 14 + here_i * 2, "mark": "turned"},
					"riskManagement": {"label": "You left before the margin was gone", "delta": 10, "mark": "turned-risk"},
				}},
		})
	return {
		"id": "route-%s-%d" % [s["checkpoint"], day_of(s)], "title": place,
		"text": "The route is open. This is a game beat, not a plan for a real mountain.",
		"category": "route", "ephemeral": true, "choices": choices,
	}


## The one place a card is spent. `adjust` (effect, card) → effect lets a
## played climb reshape the choice's effect before it lands.
static func resolve_decision(s: Dictionary, index: int, def: Dictionary, adjust: Callable = Callable()) -> Dictionary:
	if s["status"] != "active":
		return s
	var card := current_event(s, def)
	var choice: Dictionary = card["choices"][index]
	var base: Dictionary = choice["effect"]
	var effect: Dictionary = adjust.call(base, card) if adjust.is_valid() else base
	var next := apply_effect(s, effect, def)
	if String(card.get("repeat", "")) == "day":
		next["marks"]["day-" + card["id"]] = day_of(s)
	elif not card.get("ephemeral", false):
		next["seen"].append(card["id"])
	var hist: Array = next["history"]
	hist[hist.size() - 1]["choice"] = choice["label"]
	return next


# --- Applying an effect --------------------------------------------------------

static func _home_meters(def: Dictionary) -> int:
	var ladder: Array = def["descentLadder"]
	return int(ladder[ladder.size() - 1]) if not ladder.is_empty() else int(def["route"][0]["meters"])


static func _finish(s: Dictionary, def: Dictionary) -> void:
	s["checkpoint"] = "complete"
	s["altitude"] = mini(int(s["altitude"]), _home_meters(def))
	if s["health"] > 0 and s["teamCondition"] > 0:
		s["returnedSafely"] = true
		s["status"] = "complete"
	else:
		s["returnedSafely"] = false
		s["status"] = "failed"


static func _step_up(s: Dictionary, def: Dictionary, notes: Array) -> void:
	if s["retreating"]:
		return
	var i := _route_index(def, s["checkpoint"])
	var route: Array = def["route"]
	if i + 1 >= route.size():
		return
	var next: Dictionary = route[i + 1]
	s["checkpoint"] = next["id"]
	s["altitude"] = int(next["meters"])
	if next["meters"] > s["highestAltitude"]:
		s["highestAltitude"] = int(next["meters"])
	if next["id"] == "summit":
		s["summitReached"] = true
	var strain := altitude_strain(s["acclimatization"], next["meters"])
	if strain["health"] != 0:
		s["health"] += strain["health"]
		s["energy"] += strain["energy"]
		notes.append("Inside this game, the air arrives before the body does.")
	match next["id"]:
		"camp1":
			s["objectiveRisk"] += 8
		"camp3":
			s["objectiveRisk"] += 6
		"camp4":
			s["weatherRisk"] += 8
		"summit":
			s["objectiveRisk"] += 10


static func _step_down(s: Dictionary, def: Dictionary) -> void:
	s["retreating"] = true
	var lower: Variant = null
	for m in def["descentLadder"]:
		if m < s["altitude"] - 30:
			lower = m
			break
	if lower == null:
		_finish(s, def)
		return
	s["altitude"] = int(lower)
	if lower <= _home_meters(def) + 1:
		_finish(s, def)
	else:
		s["checkpoint"] = "descent"


static func _resolve_move(s: Dictionary, move: String, def: Dictionary, notes: Array) -> void:
	if move == "summit" or move == "up":
		_step_up(s, def, notes)
	elif move == "retreat" or move == "down":
		_step_down(s, def)
	elif move == "hold" and s["altitude"] >= 3000:
		s["acclimatization"] += 8
		s["energy"] += 5
		notes.append("The rest is spent letting the expedition catch the altitude.")


static func _advance_time(s: Dictionary, hours: float, notes: Array) -> void:
	var span := maxf(0.0, hours)
	s["elapsedHours"] += span
	s["supplies"] -= js_round(span / 8.0) * 2
	s["energy"] -= js_round(span / 10.0)
	if s["altitude"] >= 7200 and s["oxygen"] < 30:
		s["health"] -= 4
		s["energy"] -= 4
		notes.append("The oxygen reserve is thin for this height, in the game’s terms.")
	if s["supplies"] <= 0:
		s["health"] -= 5
		s["teamCondition"] -= 5
		notes.append("The supplies are gone. The team starts spending itself.")
	var drift := (hash32([s["seed"], s["elapsedHours"], 3]) % 5) - 2
	s["weatherRisk"] += drift
	if s["weatherRisk"] >= 75 and s["altitude"] >= 6400:
		s["objectiveRisk"] += 4


static func _apply_pressure(s: Dictionary, notes: Array) -> void:
	var level := pressure(s)
	if level <= 40:
		return
	var roll := hash32([s["seed"], s["elapsedHours"], s["altitude"], s["history"].size()]) % 100
	if roll < level - 35:
		var hit := 3 + int(floor((level - 35.0) / 20.0))
		s["health"] -= hit
		s["energy"] -= 2
		notes.append("Conditions take a piece of the team’s margin.")


static func notes_of(entry: Variant) -> Array:
	if entry == null:
		return []
	return entry if typeof(entry) == TYPE_ARRAY else [entry]


static func _add_scores(s: Dictionary, effect: Dictionary) -> void:
	var scores: Variant = effect.get("scores")
	if scores == null:
		return
	for bucket in BUCKETS:
		for note in notes_of(scores.get(bucket)):
			var mark: Variant = note.get("mark")
			if mark != null and s["marks"].get(mark):
				continue
			if mark != null:
				s["marks"][mark] = true
			var entry := {"label": note["label"], "delta": note["delta"]}
			if mark != null:
				entry["mark"] = mark
			s["ledger"][bucket].append(entry)


static func _clamp_stats(s: Dictionary) -> void:
	for key in STAT_KEYS:
		s[key] = bound_stat(s[key])
	s["altitude"] = bound_altitude(s["altitude"])
	if s["altitude"] > s["highestAltitude"]:
		s["highestAltitude"] = s["altitude"]


static func _evaluate(s: Dictionary, def: Dictionary) -> void:
	if s["status"] != "active":
		return
	if s["health"] <= 0 or s["teamCondition"] <= 0:
		s["returnedSafely"] = false
		s["status"] = "failed"
		return
	if s["elapsedHours"] >= 24 * 36:
		if s["altitude"] <= 3600 and s["health"] > 0 and s["teamCondition"] > 0:
			_finish(s, def)
		else:
			s["returnedSafely"] = false
			s["status"] = "failed"


static func apply_effect(state: Dictionary, effect: Dictionary, def: Dictionary) -> Dictionary:
	if state["status"] != "active":
		return state
	var s: Dictionary = state.duplicate(true)
	var notes: Array = []
	if String(effect.get("note", "")) != "":
		notes.append(effect["note"])
	for key in STAT_KEYS:
		s[key] += effect.get(key, 0)
	_resolve_move(s, String(effect.get("move", "hold")), def, notes)
	if effect.has("visitMeters") and effect["visitMeters"] != null:
		var visited := bound_altitude(effect["visitMeters"])
		if visited > s["highestAltitude"]:
			s["highestAltitude"] = visited
	_advance_time(s, float(effect.get("hours", 6)), notes)
	_apply_pressure(s, notes)
	_add_scores(s, effect)
	if effect.has("mark") and effect["mark"] != null:
		s["marks"][effect["mark"]] = true
	_clamp_stats(s)
	_evaluate(s, def)
	var text := " ".join(notes.filter(func(n: String) -> bool: return n != ""))
	s["lastNote"] = text
	s["history"].append({"checkpoint": state["checkpoint"], "hours": s["elapsedHours"], "choice": effect.get("note", ""), "note": text})
	return s


# --- Scoring --------------------------------------------------------------------

static func _bucket(notes: Array, base: float) -> int:
	var sum := 0.0
	for n in notes:
		sum += float(n["delta"])
	return clampi(js_round(base + sum), 0, 100)


static func score(s: Dictionary) -> Dictionary:
	var l: Dictionary = s["ledger"]
	var judgment := _bucket(l["judgment"], 52)
	var risk := _bucket(l["riskManagement"], 50)
	var team_core := _bucket(l["teamwork"], 58)
	var prep_core := _bucket(l["preparation"], 56)
	var teamwork := clampi(js_round(team_core * 0.7 + s["teamCondition"] * 0.3), 0, 100)
	var preparation := clampi(js_round(prep_core * 0.65 + s["supplies"] * 0.15 + s["oxygen"] * 0.2), 0, 100)
	var overall := judgment * 0.34 + risk * 0.28 + teamwork * 0.18 + preparation * 0.2
	if s["returnedSafely"]:
		overall += 6
	else:
		overall = minf(overall, 40)
	var strong: bool = s["summitReached"] and s["returnedSafely"] and judgment >= 68 and s["teamCondition"] >= 35 and s["health"] >= 25
	if strong:
		overall += 12
	if s["summitReached"] and not s["returnedSafely"]:
		overall = minf(overall, 36)
	var final := clampi(js_round(overall), 0, 100)
	var lines: Array = []
	for key in BUCKETS:
		for n in l[key]:
			lines.append({"bucket": BUCKET_LABEL[key], "label": n["label"], "delta": n["delta"]})
	return {
		"highestAltitude": s["highestAltitude"], "summitReached": s["summitReached"], "returnedSafely": s["returnedSafely"],
		"successful": s["returnedSafely"], "judgment": judgment, "riskManagement": risk, "teamwork": teamwork,
		"preparation": preparation, "overall": final, "lines": lines,
		"explanation": _explain(s, judgment, risk, teamwork, preparation),
	}


static func _explain(s: Dictionary, j: int, r: int, t: int, p: int) -> String:
	var opening := "The expedition ended on the mountain. Getting back was the result that counted."
	if s["summitReached"] and s["returnedSafely"]:
		opening = "You stood on the summit and still brought the expedition down. That is the rare result."
	elif s["returnedSafely"] and not s["summitReached"]:
		opening = "You came back without the summit. How high you climbed is not how this is scored."
	elif s["summitReached"] and not s["returnedSafely"]:
		opening = "The summit is recorded. The expedition is not a success, because it did not come back."
	var parts := [opening, "Judgment %d. Risk management %d. Teamwork %d. Preparation %d." % [j, r, t, p]]
	var all: Array = []
	for key in BUCKETS:
		all.append_array(s["ledger"][key])
	var best: Variant = null
	var worst: Variant = null
	for n in all:
		if best == null or n["delta"] > best["delta"]:
			best = n
		if worst == null or n["delta"] < worst["delta"]:
			worst = n
	if best != null and best["delta"] > 0:
		parts.append(best["label"])
	if worst != null and worst["delta"] < 0 and worst != best:
		parts.append(worst["label"])
	return " ".join(parts)
