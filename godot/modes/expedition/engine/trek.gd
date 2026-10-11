class_name Trek
extends RefCounted
## The harder strategy layer, on top of the ported Expo engine (which it
## leaves exactly as it is, so the parity test still holds). It reads each
## change the engine makes and adds what the engine leaves out:
##
## - a route, chosen at the gate, that sets the permit (how many days you
##   have), the stores, and how hard every day up is;
## - the permit: every choice spends hours, and when the days run out while
##   you are still going up, the rangers walk you down;
## - sickness, per person: altitude sickness when the party climbs faster than
##   it adapts, a stomach bug from untreated water, the cold at night up high.
##   It worsens if ignored and eases with descent, rest, or Jun's care; at its
##   worst it becomes an emergency card that only has hard answers;
## - people leaving: someone sent down with porters does not come back, and
##   the climbs go on without them;
## - endings: how the expedition finished, not just whether.
##
## Game fiction. The sickness here is a mechanic, not medical advice.

const ROUTES := {
	"lemosho": {
		"name": "The long way", "line": "Lemosho, 10-day permit",
		"text": "Ten days. The slow walk in through forest and over the Shira plateau. The body has time to catch the air.",
		"permit": 10, "supplies": 86, "medicine": 3, "upEnergy": 0, "upAcclim": 0, "upHealth": 0, "risk": 0, "climb": 1.0,
	},
	"machame": {
		"name": "The steep way", "line": "Machame-style, 8-day permit",
		"text": "Eight days. A steep first day straight up to Shira 1, then shorter, steeper days with less food carried. Every day up costs more, and sickness comes sooner.",
		"start": "ebc", "startHours": 24,
		"permit": 8, "supplies": 72, "medicine": 2, "upEnergy": -5, "upAcclim": -3, "upHealth": 0, "risk": 10, "climb": 1.15,
	},
	"umbwe": {
		"name": "The direct way", "line": "Umbwe-style, 7-day permit",
		"text": "Seven days, straight up a forest ridge to Shira 2 in a day and a half. The least food, the fastest height, the hardest climbs. Only for a party that is fit and lucky.",
		"start": "camp1", "startHours": 36,
		"permit": 7, "supplies": 68, "medicine": 1, "upEnergy": -7, "upAcclim": -5, "upHealth": -2, "risk": 16, "climb": 1.3,
	},
}

## How each person takes the height: positive is more prone to sickness.
const PRONE := {"marco": 14, "you": 6, "jun": 2, "lena": -10}
const NAMES := {"jun": "Jun", "marco": "Marco", "you": "You", "lena": "Lena"}

const SICK_WORDS := {
	"ams": ["a headache that will not lift", "sick and dizzy, off food", "confused and unsteady, a wet cough"],
	"stomach": ["a stomach that has turned", "unable to keep water down"],
	"cold": ["numb fingers", "shivering that does not stop"],
}


static func ensure(session: Dictionary) -> Dictionary:
	if not session.has("trek") or typeof(session["trek"]) != TYPE_DICTIONARY:
		# Sessions made outside the game (tests) start on the long way.
		session["trek"] = fresh("lemosho")
	return session["trek"]


static func fresh(route: String = "") -> Dictionary:
	# base: the height the party has slept at (adapted to), in metres.
	# medicine: doses in the kit. sleep: how the last night went (well,
	# badly, or "" before the first), for the climbs.
	var doses: int = ROUTES[route]["medicine"] if ROUTES.has(route) else 0
	return {"route": route, "sick": {}, "gone": [], "emergency": null, "ending": "", "treated": {}, "base": 0,
		"medicine": doses, "sleep": ""}


static func route(session: Dictionary) -> Dictionary:
	var r: String = ensure(session)["route"]
	return ROUTES.get(r if r != "" else "lemosho", ROUTES["lemosho"])


static func permit_days(session: Dictionary) -> int:
	return int(route(session)["permit"])


## Days left on the permit, in hours, from the state's clock.
static func hours_left(session: Dictionary) -> float:
	return permit_days(session) * 24.0 - float(session["state"]["elapsedHours"])


static func is_gone(session: Dictionary, id: String) -> bool:
	return ensure(session)["gone"].has(id)


static func sickness(session: Dictionary, id: String) -> Dictionary:
	return ensure(session)["sick"].get(id, {})


static func describe(kind: String, stage: int) -> String:
	var words: Array = SICK_WORDS.get(kind, ["unwell"])
	return words[clampi(stage - 1, 0, words.size() - 1)]


# --- The route card -----------------------------------------------------------

static func route_card() -> Dictionary:
	var choices: Array = []
	for id in ["lemosho", "machame", "umbwe"]:
		var r: Dictionary = ROUTES[id]
		choices.append({"label": "%s (%s)" % [r["name"], r["line"]], "detail": r["text"], "route": id})
	return {"id": "trek-route", "title": "Which way up?",
		"text": "The permit office wants a route and a number of days. Fewer days is less to carry and less to pay, and less time for four bodies to get used to the air. The days you name are the days you have.",
		"choices": choices, "trek": true}


static func choose_route(session: Dictionary, id: String) -> void:
	var t := ensure(session)
	t["route"] = id
	t["medicine"] = int(ROUTES[id]["medicine"])
	var s: Dictionary = session["state"].duplicate(true)
	s["supplies"] = int(ROUTES[id]["supplies"])
	t["base"] = float(s["altitude"])
	# The shorter routes skip the long walk in: higher on day one, unadapted.
	var start: String = ROUTES[id].get("start", "")
	if start != "":
		for stop in Kili.def()["route"]:
			if stop["id"] == start:
				s["checkpoint"] = start
				s["altitude"] = int(stop["meters"])
				s["highestAltitude"] = int(stop["meters"])
				s["elapsedHours"] = float(ROUTES[id]["startHours"])
				s["energy"] -= 10
		var hour_note := " A hard first push: you sleep tonight at %s, higher than the body is ready for." % Kili.checkpoint_name(start)
		s["lastNote"] = hour_note.strip_edges()
	s["lastNote"] = ("%s. The permit says %d days. %s" % [ROUTES[id]["name"], int(ROUTES[id]["permit"]), s["lastNote"] if start != "" else ""]).strip_edges()
	session["state"] = s


# --- After every change --------------------------------------------------------

static func _roll(s: Dictionary, salt: int, who: int = 0) -> int:
	return ExpeditionEngine.hash32([s["seed"], s["history"].size(), int(s["elapsedHours"]), salt, who]) % 100


## Reads what the engine just did (from `before` to the session's state) and
## adds the trek's consequences. Mutates the session.
static func advance(session: Dictionary, before: Dictionary, def: Dictionary) -> void:
	var t := ensure(session)
	var s: Dictionary = session["state"].duplicate(true)
	if before.is_empty() or s["status"] != "active":
		session["state"] = s
		_settle_ending(session)
		return
	var hours := float(s["elapsedHours"]) - float(before["elapsedHours"])
	var r := route(session)
	var notes: Array = []
	var climbed: bool = int(s["altitude"]) > int(before["altitude"])
	var descended: bool = int(s["altitude"]) < int(before["altitude"])
	# A night is a long stop that does not go up: it was sleep if it gave
	# energy back, and a bad night if it did not.
	if hours >= 8.0 and not climbed:
		t["sleep"] = "well" if int(s["energy"]) > int(before["energy"]) else "badly"
	if climbed:
		s["energy"] += r["upEnergy"]
		s["acclimatization"] += r["upAcclim"]
		s["health"] += r["upHealth"]
		if r["upEnergy"] < 0:
			notes.append("The route takes its toll on the way up.")
	if float(t.get("base", 0)) <= 0.0:
		t["base"] = float(before["altitude"])
	var rise := float(s["altitude"]) - float(t["base"])
	if hours >= 4.0:
		_sicken(session, s, before, climbed, descended, rise, notes)
	# A night at a height adapts the party to it.
	if not climbed and hours >= 10.0:
		t["base"] = maxf(float(t["base"]), float(s["altitude"]))
	# Every sick person costs the party something each day.
	for id in t["sick"]:
		var sick: Dictionary = t["sick"][id]
		var k := hours / 12.0
		var stage: int = sick["stage"]
		s["health"] -= ExpeditionEngine.js_round(stage * 1.5 * k)
		s["teamCondition"] -= ExpeditionEngine.js_round(stage * 2.0 * k)
		s["energy"] -= ExpeditionEngine.js_round((4.0 if sick["kind"] == "stomach" else stage * 1.5) * k)
		s["supplies"] -= ExpeditionEngine.js_round(1.0 * k)
	# The permit.
	if not s["retreating"] and not s["summitReached"] and float(s["elapsedHours"]) > permit_days(session) * 24.0:
		ExpeditionEngine._step_down(s, def)
		t["ending"] = "permit"
		notes.append("The permit has run out. The rangers walk the party down.")
	ExpeditionEngine._clamp_stats(s)
	ExpeditionEngine._evaluate(s, def)
	if not notes.is_empty():
		s["lastNote"] = (String(s["lastNote"]) + " " + " ".join(notes)).strip_edges()
	session["state"] = s
	_settle_ending(session)


## Sickness comes from going up faster than the nights allow (`rise`, the
## metres above where the party last slept), from a gap in acclimatization,
## and from being worn out: pace and exhaustion, which is what care avoids.
static func _sicken(session: Dictionary, s: Dictionary, before: Dictionary, climbed: bool, descended: bool, rise: float, notes: Array) -> void:
	var t: Dictionary = session["trek"]
	var r := route(session)
	var alt := float(s["altitude"])
	var gap := ExpeditionEngine.acclimatization_need(alt) - float(s["acclimatization"])
	var rested: bool = not climbed and not descended
	var i := 0
	for id in Party.ORDER:
		i += 1
		if t["gone"].has(id):
			continue
		var sick: Dictionary = t["sick"].get(id, {})
		if sick.is_empty():
			# Altitude sickness: the gap between the height and the adapting.
			if alt >= 3000:
				var worn := maxf(0.0, 60.0 - float(s["energy"])) * 0.6
				var pace := maxf(0.0, rise - 350.0) / 9.0 if climbed else 0.0
				# Some of it is luck: up high, anyone can get sick.
				var luck := 10.0 if alt >= 3800 else 0.0
				var risk := clampi(int(maxf(gap, 0.0) * 2.0 + pace + worn + luck) + PRONE[id] + int(r["risk"]) - (8 if s["energy"] > 65 else 0), 0, 85)
				if _roll(s, 11, i) < risk:
					t["sick"][id] = {"kind": "ams", "stage": 1}
					notes.append("%s has %s." % [NAMES[id], describe("ams", 1)] if id != "you" else "You have %s." % describe("ams", 1))
					continue
			# A stomach bug, when the water was not put on at this camp.
			if s["marks"].get("water-" + String(before["checkpoint"])) != true and _roll(s, 23, i) < 9:
				t["sick"][id] = {"kind": "stomach", "stage": 1}
				notes.append("%s has %s." % [NAMES[id], describe("stomach", 1)])
				continue
			# Food gone bad: thin stores are old stores.
			if int(s["supplies"]) < 30 and _roll(s, 27, i) < 10:
				t["sick"][id] = {"kind": "stomach", "stage": 1}
				notes.append("The food has gone bad. %s has %s." % [NAMES[id], describe("stomach", 1)] if id != "you" else "The food has gone bad. You have %s." % describe("stomach", 1))
				continue
			# The cold, high and at night, with thin stores or tired bodies.
			var hour := Party.expedition_hour(float(s["elapsedHours"]))
			if alt >= 4500 and Party.day_phase(hour) == "night" and (s["supplies"] < 35 or s["energy"] < 40) and _roll(s, 31, i) < 18:
				t["sick"][id] = {"kind": "cold", "stage": 1}
				notes.append("%s has %s." % [NAMES[id], describe("cold", 1)])
			continue
		# Someone already unwell gets better or worse.
		var stage: int = sick["stage"]
		if sick["kind"] == "ams":
			if descended:
				stage -= 1
			elif climbed and s["summitReached"] and not before["summitReached"]:
				# The summit push is the night sickness catches up, and an
				# exhausted body has nothing left to hold it off.
				stage += 2 if s["energy"] < 20 else 1
			elif climbed and (gap > 0 or rise > 300.0 or s["energy"] < 25):
				stage += 1 if _roll(s, 41, i) < 80 else 0
			elif rested:
				stage += -1 if _roll(s, 43, i) < 45 else (1 if gap > 10 and _roll(s, 47, i) < 35 else 0)
			elif gap > 0 and _roll(s, 49, i) < 30:
				stage += 1
		else:
			stage += -1 if _roll(s, 53, i) < 40 else (1 if _roll(s, 57, i) < 20 else 0)
		if stage <= 0:
			t["sick"].erase(id)
			notes.append("%s is feeling better." % NAMES[id] if id != "you" else "You are feeling better.")
			continue
		var limit: int = SICK_WORDS[sick["kind"]].size()
		stage = mini(stage, limit)
		if stage > sick["stage"]:
			notes.append("%s is worse: %s." % [NAMES[id], describe(sick["kind"], stage)] if id != "you" else "You are worse: %s." % describe(sick["kind"], stage))
		sick["stage"] = stage
		if sick["kind"] == "ams" and stage >= 3 and t["emergency"] == null:
			t["emergency"] = {"who": id}


# --- Emergencies --------------------------------------------------------------

static func emergency_card(session: Dictionary) -> Dictionary:
	var t := ensure(session)
	var e: Variant = t["emergency"]
	if e == null:
		return {}
	var who: String = e["who"]
	var name: String = NAMES[who]
	var me := who == "you"
	var choices: Array = [
		{"label": "Everyone goes down, now", "detail": "In this game, the cure for this is height lost. The summit goes with it.", "act": "descend"},
		{"label": "Go down with the porters" if me else "Send %s down with porters" % name,
			"detail": "Your expedition ends here, safely." if me else "%s will be safe. The rest of you go on without them." % name, "act": "evacuate"},
		{"label": "Wait for the morning and see", "detail": "Twelve hours. It might settle. It might not.", "act": "wait"},
	]
	return {"id": "trek-emergency-" + who, "trek": true,
		"title": "You can't think straight" if me else "%s can't walk a straight line" % name,
		"text": ("Your head is pounding and the tent will not stay still. Jun says, in this game, that this is the sign you go down tonight." if me
			else "%s is %s. Jun says, in this game, that this is the one you do not wait on. Game fiction, not medical advice." % [name, describe("ams", 3)]),
		"choices": choices}


## Resolves the emergency card. Returns the effect to play through the
## engine (time, stats, scores), after the trek's own changes.
static func resolve_emergency(session: Dictionary, act: String, def: Dictionary) -> Dictionary:
	var t := ensure(session)
	var who: String = t["emergency"]["who"]
	var name: String = NAMES[who]
	t["emergency"] = null
	match act:
		"descend":
			t["sick"][who]["stage"] = 1
			return {"note": "The whole party goes down in the dark. By the bottom, %s can walk straight again." % ("you" if who == "you" else name),
				"move": "down", "hours": 6, "teamCondition": 4,
				"scores": {"judgment": {"label": "You took everyone down for %s" % ("yourself" if who == "you" else name), "delta": 8, "mark": "trek-down-" + who}}}
		"evacuate":
			t["sick"].erase(who)
			t["gone"].append(who)
			if who == "you":
				t["ending"] = "evacuated"
				return {"note": "You go down with the porters. The others follow you off the mountain.", "move": "down", "hours": 8,
					"scores": {"judgment": {"label": "You went down when your body said so", "delta": 4, "mark": "trek-evac-you"}}}
			return {"note": "%s goes down with two porters. The tents feel bigger tonight." % name, "move": "hold", "hours": 3, "teamCondition": -14,
				"scores": {"teamwork": {"label": "You sent %s down to save them" % name, "delta": -2, "mark": "trek-evac-" + who}}}
		_:
			# Waiting: it may settle; more often it does not.
			var s: Dictionary = session["state"]
			if _roll(s, 61, Party.ORDER.find(who)) < 35:
				t["sick"][who]["stage"] = 2
				return {"note": "The night is long. By morning %s is a little better. That was luck." % ("you are" if who == "you" else name + " is"), "move": "hold", "hours": 12,
					"scores": {"riskManagement": {"label": "You waited out a dangerous night", "delta": -6, "mark": "trek-wait-" + who}}}
			t["sick"].erase(who)
			t["gone"].append(who)
			if who == "you":
				t["ending"] = "evacuated"
				return {"note": "By midnight you cannot stand. A rescue team carries you down.", "move": "down", "hours": 12, "health": -20,
					"scores": {"riskManagement": {"label": "You waited on the one sign you do not wait on", "delta": -8, "mark": "trek-wait-you"}}}
			return {"note": "By midnight %s cannot stand. Rescue carries them down. The party is shaken." % name, "move": "hold", "hours": 12, "teamCondition": -24, "health": -6,
				"scores": {"riskManagement": {"label": "You waited on %s's worst night" % name, "delta": -8, "mark": "trek-wait-" + who}}}


# --- Care at camp ----------------------------------------------------------------

## Jun can look after someone once per camp, if he is here and well enough.
static func can_treat(session: Dictionary, id: String) -> bool:
	var t := ensure(session)
	if t["gone"].has("jun") or not t["sick"].has(id):
		return false
	if t["sick"].get("jun", {}).get("stage", 0) >= 2 and id != "jun":
		return false
	return t["treated"].get(id) != session["state"]["checkpoint"]


static func treat(session: Dictionary, id: String) -> Dictionary:
	var t := ensure(session)
	t["treated"][id] = session["state"]["checkpoint"]
	var sick: Dictionary = t["sick"][id]
	sick["stage"] -= 1
	if sick["stage"] <= 0:
		t["sick"].erase(id)
	return {"note": "Jun sits with %s, with water and what the kit has. It helps." % ("you" if id == "you" else NAMES[id]),
		"move": "hold", "hours": 2, "supplies": -4, "teamCondition": 2,
		"scores": {"teamwork": {"label": "Jun cared for %s" % ("you" if id == "you" else NAMES[id]), "delta": 3, "mark": "trek-care-%s-%s" % [id, session["state"]["checkpoint"]]}}}


## A dose from the kit for someone unwell: no Jun needed, an hour, and one
## dose fewer for the climbs.
static func can_medicate(session: Dictionary, id: String) -> bool:
	var t := ensure(session)
	return int(t.get("medicine", 0)) > 0 and t["sick"].has(id)


static func medicate(session: Dictionary, id: String) -> Dictionary:
	var t := ensure(session)
	t["medicine"] = int(t["medicine"]) - 1
	var sick: Dictionary = t["sick"][id]
	sick["stage"] -= 1
	if sick["stage"] <= 0:
		t["sick"].erase(id)
	var who: String = "you" if id == "you" else NAMES[id]
	return {"note": "A dose from the kit for %s. %d left." % [who, int(t["medicine"])],
		"move": "hold", "hours": 1, "teamCondition": 1,
		"scores": {"judgment": {"label": "You used the medicine on %s" % who, "delta": 2, "mark": "trek-med-%s-%s" % [id, session["state"]["checkpoint"]]}}}


## A dose taken before a climb, to keep the symptoms off while you climb.
static func dose_for_climb(session: Dictionary) -> bool:
	var t := ensure(session)
	if int(t.get("medicine", 0)) <= 0:
		return false
	t["medicine"] = int(t["medicine"]) - 1
	return true


static func send_down(session: Dictionary, id: String) -> Dictionary:
	var t := ensure(session)
	t["sick"].erase(id)
	t["gone"].append(id)
	return {"note": "%s goes down with a porter while it is still a walk, not a rescue." % NAMES[id], "move": "hold", "hours": 2, "teamCondition": -10,
		"scores": {"judgment": {"label": "You sent %s down early" % NAMES[id], "delta": 3, "mark": "trek-send-" + id}}}


# --- Endings ---------------------------------------------------------------------

static func _settle_ending(session: Dictionary) -> void:
	var t := ensure(session)
	var s: Dictionary = session["state"]
	if s["status"] == "active" or t["ending"] in ["evacuated"]:
		return
	if t["ending"] == "permit" and s["status"] == "complete":
		return
	var together: bool = t["gone"].is_empty()
	if s["status"] == "failed":
		t["ending"] = "lost"
	elif s["summitReached"]:
		t["ending"] = "summit-together" if together else "summit-cost"
	else:
		t["ending"] = "turned-together" if together else "hard-walk-out"


const ENDINGS := {
	"summit-together": ["Summit, all four of you", "Stella Point at dawn and every one of you walked back through the gate. That is the whole thing, done well."],
	"summit-cost": ["Summit, but not all of you", "The summit is in the record. So is the person who went down early. Ask yourself whether the order was right."],
	"turned-together": ["Turned back together", "No summit, and nobody hurt. The mountain is still there. So are all four of you."],
	"hard-walk-out": ["A hard walk out", "No summit, and not everyone walked out with you. A day like that is learned from."],
	"permit": ["Out of days", "The permit ran out before the summit did. The days you named were the days you had."],
	"evacuated": ["Carried down", "Your body made the decision. The others brought the expedition down behind you."],
	"lost": ["The mountain kept the day", "The party ran out of margin. In this game, that is the ending every other choice is about avoiding."],
}


static func ending(session: Dictionary) -> Array:
	if ensure(session)["ending"] == "":
		_settle_ending(session)
	var key: String = ensure(session)["ending"]
	return ENDINGS.get(key, ["The expedition is over", ""])


## How the climbs feel the trek: the route's steepness, and being unwell.
static func climb_factor(session: Dictionary) -> Dictionary:
	var you := sickness(session, "you")
	var stage: int = you.get("stage", 0)
	return {"steep": float(route(session)["climb"]), "sick": stage, "stamina": 1.0 - 0.12 * stage}
