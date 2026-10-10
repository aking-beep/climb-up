class_name Coordinator
extends RefCounted
## Cards and climbs together, ported from src/game/hybrid (coordinator,
## reconcile) and src/expeditions/kilimanjaro/challenges.ts.
##
## A choice that moves the party up out of a gated camp opens a pending
## climb instead of spending the card. The climb's outcome lands exactly
## once: the card's own effect plus a bounded modifier from how the climb
## went. A session is {state, prior, pending, resolvedAttempts}.

const LIMITS := {"statMin": -12, "statMax": 6, "hoursMax": 12, "scoreMin": -8, "scoreMax": 8}

## The three climbs, easiest first. Same words and stakes as the Expo game.
const CLIMBS := {
	"lava-tower": {
		"title": "the Lava Tower", "gate": "camp1", "mark": "tower", "mate": null,
		"topOut": "You touch the top of the Lava Tower and drop to Barranco to sleep low",
		"backOff": "You turn back under the tower and the party walks down to the Shira 2 tents again.",
		"fail": "The tower scree keeps sliding out from under you. You go back down to Shira 2, slowly.",
		"stakes": {"slip": 1, "slipMax": 4, "failHealth": -4, "failEnergy": -3, "assistTeam": 0, "assistScore": 0, "assistEnergy": 0, "leftTeam": 0, "leftScore": 0},
	},
	"barranco-wall": {
		"title": "the Barranco Wall", "gate": "camp2", "mark": "wall", "mate": "Marco",
		"topOut": "You top out on the wall, and Karanga is pitched as the light goes",
		"backOff": "You back off the wall and the party walks down to the Barranco tents again.",
		"fail": "The wall takes more than the party has. You climb down to Barranco, slowly.",
		"stakes": {"slip": 2, "slipMax": 6, "failHealth": -6, "failEnergy": -4, "assistTeam": 5, "assistScore": 6, "assistEnergy": 3, "leftTeam": -6, "leftScore": -6},
	},
	"summit-night": {
		"title": "the summit night", "gate": "camp4", "mark": "summit", "mate": "Jun",
		"topOut": "You reach Stella Point as the sky goes pale, then walk the rim to Uhuru",
		"backOff": "You turn the headlamps around on the scree and the party is back at Barafu before dawn.",
		"fail": "The cold and the scree win tonight. The party comes down to Barafu in the dark.",
		"stakes": {"slip": 3, "slipMax": 9, "failHealth": -10, "failEnergy": -6, "assistTeam": 6, "assistScore": 8, "assistEnergy": 4, "leftTeam": -10, "leftScore": -8},
	},
}


static func create_session(state: Dictionary) -> Dictionary:
	return {"state": state, "prior": null, "pending": null, "resolvedAttempts": []}


## The climb a choice launches, if any.
static func challenge_for(state: Dictionary, card: Dictionary, index: int) -> String:
	if index < 0 or index >= card["choices"].size() or state["status"] != "active" or state["retreating"]:
		return ""
	for id in CLIMBS:
		if CLIMBS[id]["gate"] == state["checkpoint"]:
			var move: String = String(card["choices"][index]["effect"].get("move", ""))
			return id if move == "up" or move == "summit" else ""
	return ""


static func attempt_id(def: Dictionary, state: Dictionary, event_id: String) -> String:
	return "%s:%s:%s:%d" % [def["id"], ExpeditionEngine.to_base36(int(state["seed"])), event_id, state["history"].size()]


## A card choice. Returns {session, launched} where launched is the pending
## climb (or null when the choice was spent).
static func choose(session: Dictionary, index: int, def: Dictionary) -> Dictionary:
	var state: Dictionary = session["state"]
	if state["status"] != "active":
		return {"session": session, "launched": null}
	if session["pending"] != null:
		return {"session": session, "launched": session["pending"]}
	var card := ExpeditionEngine.current_event(state, def)
	var climb := challenge_for(state, card, index)
	if climb != "":
		var pending := {
			"attemptId": attempt_id(def, state, card["id"]), "challengeId": climb, "expeditionId": def["id"],
			"eventId": card["id"], "choiceIndex": index, "choiceLabel": card["choices"][index]["label"],
			"historyLength": state["history"].size(),
			"seed": ExpeditionEngine.hash32([state["seed"], state["history"].size(), 0xc11b]),
		}
		var s2 := session.duplicate()
		s2["pending"] = pending
		return {"session": s2, "launched": pending}
	var next := ExpeditionEngine.resolve_decision(state, index, def)
	var s3 := session.duplicate()
	s3["state"] = next
	s3["prior"] = state
	return {"session": s3, "launched": null}


## A camp beat that does not spend the card. Blocked while a climb is open.
static func play(session: Dictionary, effect: Variant, def: Dictionary) -> Dictionary:
	if effect == null or session["pending"] != null or session["state"]["status"] != "active":
		return session
	var s2 := session.duplicate()
	s2["prior"] = session["state"]
	s2["state"] = ExpeditionEngine.apply_effect(session["state"], effect, def)
	return s2


static func _still_current(session: Dictionary, pending: Dictionary, def: Dictionary) -> bool:
	var state: Dictionary = session["state"]
	if state["status"] != "active" or state["history"].size() != int(pending["historyLength"]):
		return false
	var card := ExpeditionEngine.current_event(state, def)
	if card["id"] != pending["eventId"]:
		return false
	var i := int(pending["choiceIndex"])
	return i < card["choices"].size() and card["choices"][i]["label"] == pending["choiceLabel"]


## Lands a climb's outcome once. Returns {session, status}: applied,
## duplicate, stale, or invalid.
static func resolve(session: Dictionary, raw: Dictionary, def: Dictionary) -> Dictionary:
	var outcome := sanitize(raw)
	if outcome.is_empty():
		return {"session": session, "status": "invalid"}
	if session["resolvedAttempts"].has(outcome["attemptId"]):
		return {"session": session, "status": "duplicate"}
	var pending: Variant = session["pending"]
	if pending == null or pending["attemptId"] != outcome["attemptId"]:
		return {"session": session, "status": "stale"}
	if not _still_current(session, pending, def):
		var closed := session.duplicate()
		closed["pending"] = null
		closed["resolvedAttempts"] = session["resolvedAttempts"] + [pending["attemptId"]]
		return {"session": closed, "status": "stale"}
	if not CLIMBS.has(pending["challengeId"]) or outcome["challengeId"] != pending["challengeId"]:
		return {"session": session, "status": "invalid"}
	var before: Dictionary = session["state"]
	var id: String = pending["challengeId"]
	var next := ExpeditionEngine.resolve_decision(before, int(pending["choiceIndex"]), def, func(base: Dictionary, _card: Dictionary) -> Dictionary:
		return combine_effect(base, modifier(id, outcome, base)))
	var s2 := session.duplicate()
	s2["state"] = next
	s2["prior"] = before
	s2["pending"] = null
	s2["resolvedAttempts"] = session["resolvedAttempts"] + [pending["attemptId"]]
	return {"session": s2, "status": "applied"}


## Leaving the climb without finishing it counts as backing off.
static func abandon(session: Dictionary, def: Dictionary) -> Dictionary:
	var pending: Variant = session["pending"]
	if pending == null:
		return {"session": session, "status": "stale"}
	return resolve(session, {
		"attemptId": pending["attemptId"], "challengeId": pending["challengeId"], "result": "retreat",
		"staminaLeft": 100, "slips": 0, "assisted": null, "regrouped": false, "seconds": 0,
	}, def)


# --- The climbs' policies (challenges.ts) ---------------------------------------

static func _lost_day(base: Dictionary) -> float:
	return maxf(0.0, 24.0 - float(base.get("hours", 6)))


static func modifier(id: String, o: Dictionary, base: Dictionary) -> Dictionary:
	var c: Dictionary = CLIMBS[id]
	var stakes: Dictionary = c["stakes"]
	var refund := ExpeditionEngine.js_round(-float(base["energy"]) / 2.0) if base.get("energy", 0) < 0 else 0
	var unlearn := -int(base["acclimatization"]) if base.get("acclimatization", 0) > 0 else 0
	var unsettle := -int(base["teamCondition"]) if base.get("teamCondition", 0) > 0 else 0
	if o["result"] == "retreat":
		return {
			"note": c["backOff"], "move": "wait", "hours": _lost_day(base), "keepBaseScores": false,
			"stats": {"energy": refund, "acclimatization": unlearn, "teamCondition": unsettle},
			"scores": {"judgment": {"label": "You backed off %s while it was still your choice" % c["title"], "delta": 3, "mark": "%s-backoff" % c["mark"]}},
		}
	if o["result"] == "fail":
		return {
			"note": c["fail"], "move": "wait", "hours": _lost_day(base), "keepBaseScores": false,
			"stats": {"health": stakes["failHealth"], "energy": stakes["failEnergy"], "acclimatization": unlearn, "teamCondition": unsettle - 4},
			"scores": {"riskManagement": {"label": "%s took more than the team had" % c["title"], "delta": -6, "mark": "%s-fail" % c["mark"]}},
		}
	var stats := {}
	var scores := {}
	var bits: Array = [c["topOut"]]
	if o["slips"] > 0:
		stats["health"] = -mini(int(stakes["slipMax"]), int(o["slips"]) * int(stakes["slip"]))
		bits.append("after one slip" if o["slips"] == 1 else "after %d slips" % int(o["slips"]))
	if o["staminaLeft"] < 25:
		stats["energy"] = -4
		bits.append("with nothing left in your arms")
	if c["mate"] != null and o["assisted"] == true:
		stats["teamCondition"] = stakes["assistTeam"]
		stats["energy"] = stats.get("energy", 0) + stakes["assistEnergy"]
		scores["teamwork"] = {"label": "You stopped for %s on %s" % [c["mate"], c["title"]], "delta": stakes["assistScore"], "mark": "%s-assist" % c["mark"]}
		bits.append("and %s is beside you" % c["mate"])
	elif c["mate"] != null and o["assisted"] == false:
		stats["teamCondition"] = stakes["leftTeam"]
		scores["teamwork"] = {"label": "You left %s for Lena on %s" % [c["mate"], c["title"]], "delta": stakes["leftScore"], "mark": "%s-left" % c["mark"]}
		bits.append("and Lena brings %s up later" % c["mate"])
	if o["regrouped"]:
		stats["energy"] = stats.get("energy", 0) + 2
		scores["judgment"] = {"label": "You regrouped halfway up %s" % c["title"], "delta": 3, "mark": "%s-regroup" % c["mark"]}
	return {"note": " ".join(bits) + ".", "stats": stats, "hours": 1 if o["regrouped"] else 0, "keepBaseScores": true, "scores": scores}


static func bound_modifier(m: Dictionary) -> Dictionary:
	var stats := {}
	for key in ExpeditionEngine.STAT_KEYS:
		if m.get("stats", {}).has(key):
			stats[key] = ExpeditionEngine.js_round(clampf(float(m["stats"][key]), LIMITS["statMin"], LIMITS["statMax"]))
	var scores := {}
	for bucket in ExpeditionEngine.BUCKETS:
		var note: Variant = m.get("scores", {}).get(bucket)
		if note == null or note.get("mark") == null:
			continue
		scores[bucket] = {"label": note["label"], "mark": note["mark"], "delta": ExpeditionEngine.js_round(clampf(float(note["delta"]), LIMITS["scoreMin"], LIMITS["scoreMax"]))}
	return {
		"note": m.get("note", ""), "stats": stats,
		"hours": ExpeditionEngine.js_round(clampf(float(m.get("hours", 0)), 0, LIMITS["hoursMax"])),
		"move": "wait" if m.get("move") == "wait" else null, "keepBaseScores": m.get("keepBaseScores", false), "scores": scores,
	}


static func combine_effect(base: Dictionary, raw: Dictionary) -> Dictionary:
	var m := bound_modifier(raw)
	var out: Dictionary = base.duplicate(true)
	out["note"] = m["note"] if String(m["note"]) != "" else base.get("note", "")
	for key in ExpeditionEngine.STAT_KEYS:
		if m["stats"].has(key):
			out[key] = base.get(key, 0) + m["stats"][key]
	out["hours"] = base.get("hours", 6) + m["hours"]
	if m["move"] == "wait":
		out["move"] = "wait"
		out.erase("visitMeters")
	var scores := {}
	for bucket in ExpeditionEngine.BUCKETS:
		var own: Array = ExpeditionEngine.notes_of(base.get("scores", {}).get(bucket)) if m["keepBaseScores"] else []
		var list: Array = own.duplicate(true)
		if m["scores"].has(bucket):
			list.append(m["scores"][bucket])
		if list.size() == 1:
			scores[bucket] = list[0]
		elif list.size() > 1:
			scores[bucket] = list
	if scores.is_empty():
		out.erase("scores")
	else:
		out["scores"] = scores
	return out


## Repairs an outcome from the climb or a save; empty when untrustworthy.
static func sanitize(o: Variant) -> Dictionary:
	if typeof(o) != TYPE_DICTIONARY or typeof(o.get("attemptId")) != TYPE_STRING or String(o["attemptId"]).is_empty():
		return {}
	if not (o.get("result") in ["complete", "retreat", "fail"]):
		return {}
	var a: Variant = o.get("assisted")
	return {
		"attemptId": o["attemptId"], "challengeId": String(o.get("challengeId", "")), "result": o["result"],
		"staminaLeft": ExpeditionEngine.js_round(clampf(float(o.get("staminaLeft", 0)), 0, 100)),
		"slips": ExpeditionEngine.js_round(clampf(float(o.get("slips", 0)), 0, 99)),
		"assisted": a if typeof(a) == TYPE_BOOL else null,
		"regrouped": o.get("regrouped") == true,
		"seconds": ExpeditionEngine.js_round(clampf(float(o.get("seconds", 0)), 0, 24 * 3600)),
	}
