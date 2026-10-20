class_name Trek
extends RefCounted
## The harder strategy layer, on top of the ported Expo engine (which it
## leaves exactly as it is, so the parity test still holds). It reads each
## change the engine makes and adds what the engine leaves out:
##
## - a route, chosen at the gate, that sets the permit (how many days you
##   have), the stores, how hard every day up is, and the places it climbs
##   (Places: each route's own three climbs, and the stamina bar on them);
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
		"name": "The long way", "line": "13 days · easy",
		"text": "Twice the slips on each climb, your full stamina bar, and knocks hurt half as much. Slow and steady: time to get used to the thin air, the most food and medicine.",
		"permit": 13, "supplies": 90, "medicine": 3, "upEnergy": 0, "upAcclim": 0, "upHealth": 0, "risk": 0, "climb": 1.0, "porters": 0.4,
	},
	"machame": {
		"name": "The faster way", "line": "9 days · medium",
		"text": "One extra slip on each climb and half the stamina bar. Starts higher, less food, tiring days up; people get sick sooner.",
		"start": "ebc", "startHours": 24,
		"permit": 9, "supplies": 80, "medicine": 2, "upEnergy": -5, "upAcclim": -3, "upHealth": 0, "risk": 10, "climb": 1.15, "porters": 0.3,
	},
	"umbwe": {
		"name": "The fastest way", "line": "8 days · hard",
		"text": "Straight up, very fast. A quarter of the stamina bar, the least food and medicine, the hardest climbs with the most in the way, and the most altitude sickness. Pick your one or two rest days carefully.",
		"start": "camp1", "startHours": 36,
		"permit": 8, "supplies": 76, "medicine": 1, "upEnergy": -7, "upAcclim": -5, "upHealth": -2, "risk": 16, "climb": 1.3, "porters": 0.2,
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
	# descent: the played way down from the summit (Expedition): {attemptId,
	# choiceIndex, played, result}; empty until the party turns around up
	# there.
	return {"route": route, "sick": {}, "gone": [], "emergency": null, "ending": "", "treated": {}, "base": 0,
		"medicine": doses, "sleep": "", "goneAt": {}, "descent": {}}


static func route(session: Dictionary) -> Dictionary:
	var r: String = ensure(session)["route"]
	return ROUTES.get(r if r != "" else "lemosho", ROUTES["lemosho"])


## Slips allowed on the played climbs, by route: the easy way doubles each
## climb's own limit, the medium way adds one, the hard way keeps it. (No
## route chosen yet, as in the level tests: the climb's own limit.)
static func max_slips(session: Dictionary, base: int) -> int:
	match String(ensure(session)["route"]):
		"lemosho":
			return base * 2
		"machame":
			return base + 1
	return base


## The played climbs' stamina bar, by route: the long way's full bar, half
## of it on the faster way, a quarter on the fastest. (No route chosen yet,
## as in the level tests: the full bar.)
const BAR := {"lemosho": 1.0, "machame": 0.5, "umbwe": 0.25}
## However worn the party, the bar is never smaller than this on the route:
## every wall on that route's climbs fits in it (tools/levels/route_levels.py
## FACE_MAX), so a climb is always possible for someone who rests first.
const MIN_BAR := {"lemosho": 48.0, "machame": 30.0, "umbwe": 20.0}
## How much each hit hurts, by route: the long way's half.
const HURT := {"lemosho": 0.5, "machame": 1.0, "umbwe": 1.0}


static func bar_factor(session: Dictionary) -> float:
	return float(BAR.get(String(ensure(session)["route"]), 1.0))


static func min_bar(session: Dictionary) -> float:
	return float(MIN_BAR.get(String(ensure(session)["route"]), 48.0))


static func hurt_factor(session: Dictionary) -> float:
	return float(HURT.get(String(ensure(session)["route"]), 1.0))


## The fastest way grows its bar the way a Zelda hero gains hearts: every
## piece of gear and every artifact you pick up adds GROW to the bar, for
## good (once per find, kept for the rest of the expedition, up to the
## long way's full bar). A rest there gives back at most the starting
## quarter (ClimbLevel.rest_cap).
const GROW := 4.0
const GROWS := {"umbwe": true}
## What being on the rock costs, by route: the fastest way is a climbing
## route with a small bar, climbed by people who move light on the rock
## (a pitch's few rows between pitons on a quarter bar, with room to stop
## and look).
const ROCK := {"umbwe": 0.6}


static func rock_factor(session: Dictionary) -> float:
	return float(ROCK.get(String(ensure(session)["route"]), 1.0))


static func grows(session: Dictionary) -> bool:
	return GROWS.get(String(ensure(session)["route"]), false)


## Finds that have grown the bar so far (keys).
static func grown(session: Dictionary) -> Array:
	var t := ensure(session)
	if typeof(t.get("grown")) != TYPE_ARRAY:
		t["grown"] = []
	return t["grown"]


## Records a find; true when it is new (the bar grows).
static func grow(session: Dictionary, key: String) -> bool:
	if not grows(session):
		return false
	var g := grown(session)
	if g.has(key):
		return false
	g.append(key)
	return true


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
		# Each route climbs its own places (Places).
		var climbs: Array = []
		for climb in ["lava-tower", "barranco-wall", "summit-night"]:
			climbs.append(Places.climb_name(climb, id))
		choices.append({"label": "%s · %s" % [r["name"], r["line"]], "detail": "%s Climbs: %s." % [r["text"], ", ".join(climbs)], "route": id})
	return {"id": "trek-route", "title": "Pick your route up the mountain",
		"text": "Three ways up. More days is safer: your bodies get used to the thin air. Fewer days is faster but harder, and people get sick more. If you run out of days before the top, the park rangers send you home.",
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
	# The porters carry and cook: a share of what each day eats comes back,
	# more on the longer routes (that is what the long way is for).
	var eaten := int(before["supplies"]) - int(s["supplies"])
	if eaten > 0:
		s["supplies"] += ExpeditionEngine.js_round(eaten * float(r.get("porters", 0.0)))
	# A night's sleep gives energy back: most low down and well fed, less
	# high up, hungry or ill; a rest day gives more. Without it a party
	# that slept every night still reached the summit on empty.
	if hours >= 8.0 and not climbed:
		s["energy"] += camp_recovery(session, s, hours)
		s["health"] += 0 if not t["sick"].is_empty() else (3 if hours >= 20.0 else 2)
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
	# A smaller party feels it, for the rest of the trip.
	if not t["gone"].is_empty():
		var cap: int = 100 - 8 * t["gone"].size()
		if int(s["teamCondition"]) > cap:
			s["teamCondition"] = cap
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


## Energy a night (or a rest day, `hours` >= 20) gives back at camp.
static func camp_recovery(session: Dictionary, s: Dictionary, hours: float) -> int:
	var alt := float(s["altitude"])
	var base := clampf(RECOVER_LOW - maxf(0.0, alt - 3500.0) / RECOVER_PER_M, RECOVER_MIN, RECOVER_LOW)
	if int(s["supplies"]) < 20:
		base *= 0.5
	var worst := 0
	for id in ensure(session)["sick"]:
		worst = maxi(worst, int(ensure(session)["sick"][id]["stage"]))
	base *= 1.0 - 0.25 * worst
	if hours >= 20.0:
		base *= RECOVER_REST_DAY
	# Worn down by a hard push (a big gain in height since the last night
	# at a height): the body spends the night catching up, not recovering.
	var last_night := float(ensure(session).get("base", 0))
	if last_night > 0.0 and float(s["altitude"]) - last_night > 500.0:
		base *= 0.5
	return maxi(0, ExpeditionEngine.js_round(base))


## Energy back for a night low down (under 3,500 m), falling by one for
## every RECOVER_PER_M metres higher, never under RECOVER_MIN; a rest
## day gives RECOVER_REST_DAY times as much.
const RECOVER_LOW := 10.0
const RECOVER_PER_M := 300.0
const RECOVER_MIN := 3.0
const RECOVER_REST_DAY := 1.8


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
					t["sick"][id] = {"kind": "ams", "stage": 1, "cause": "fast" if pace > 0.0 or gap > 0 else ("tired" if worn > 0.0 else "luck")}
					notes.append("%s has %s." % [NAMES[id], describe("ams", 1)] if id != "you" else "You have %s." % describe("ams", 1))
					continue
			# A stomach bug, when the water was not put on at this camp.
			if s["marks"].get("water-" + String(before["checkpoint"])) != true and _roll(s, 23, i) < 9:
				t["sick"][id] = {"kind": "stomach", "stage": 1, "cause": "water"}
				notes.append("%s has %s." % [NAMES[id], describe("stomach", 1)])
				continue
			# Food gone bad: thin stores are old stores.
			if int(s["supplies"]) < 20 and _roll(s, 27, i) < 6:
				t["sick"][id] = {"kind": "stomach", "stage": 1, "cause": "food"}
				notes.append("The food has gone bad. %s has %s." % [NAMES[id], describe("stomach", 1)] if id != "you" else "The food has gone bad. You have %s." % describe("stomach", 1))
				continue
			# The cold, high and at night, with thin stores or tired bodies.
			var hour := Party.expedition_hour(float(s["elapsedHours"]))
			if alt >= 4500 and Party.day_phase(hour) == "night" and (s["supplies"] < 35 or s["energy"] < 40) and _roll(s, 31, i) < 18:
				t["sick"][id] = {"kind": "cold", "stage": 1, "cause": "cold"}
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


# --- Someone going down -----------------------------------------------------------

## The climb each teammate waits on, if any.
const CLIMB_MATE := {"barranco-wall": "marco", "summit-night": "jun"}

## What each one says as they go.
const FAREWELL := {
	"marco": "Marco hugs each of you too hard. \"Bring me a photo from the top. A good one.\"",
	"jun": "Jun presses the medicine kit into your hands. \"Water, rest, and go down if it gets worse. You know this.\"",
	"lena": "Lena gives you her route notes, folded small. \"Pole pole. Promise me.\"",
}

## How the camps feel after, one line per camp, oldest first. The last one
## repeats.
const ABSENCE := {
	"marco": [
		"Lena sets out four mugs out of habit, then puts one back.",
		"Nobody tells Marco's terrible jokes. Jun tries one. It is worse.",
		"Jun keeps looking down the trail Marco took.",
		"Marco's spot in the tent stays empty. Nobody spreads into it.",
	],
	"jun": [
		"Without Jun, Lena does the head count herself. She counts twice.",
		"The medicine kit rides in your pack now. It feels heavier than it is.",
		"Marco asks if his headache is the bad kind. Nobody here knows.",
		"You catch yourself waiting for Jun to say the day should wait.",
	],
	"lena": [
		"Nobody sets the pace. Marco walks too fast, then has to stop.",
		"Jun reads Lena's route notes by headlamp, twice.",
		"The trail forks and everyone looks at you.",
		"You set pole pole yourself. It is harder than she made it look.",
	],
	"you": ["", ],
}


## Someone leaves the expedition: they are off the climbs and the camps
## from here, and the camps remember it.
static func _depart(session: Dictionary, id: String) -> void:
	var t := ensure(session)
	t["sick"].erase(id)
	if not t["gone"].has(id):
		t["gone"].append(id)
	var at: Dictionary = t.get("goneAt", {})
	at[id] = String(session["state"]["checkpoint"])
	t["goneAt"] = at


## A line for this camp from each missing person's absence: what the
## party notices, a different one each camp since they left.
static func absence_lines(session: Dictionary, def: Dictionary) -> Array:
	var t := ensure(session)
	var out: Array = []
	var stops: Array = def["route"]
	var now := _stop_index(stops, String(session["state"]["checkpoint"]))
	for id in t["gone"]:
		if id == "you" or not ABSENCE.has(id):
			continue
		var since: int = maxi(0, now - _stop_index(stops, String(t.get("goneAt", {}).get(id, session["state"]["checkpoint"]))))
		var lines: Array = ABSENCE[id]
		out.append(lines[mini(since, lines.size() - 1)])
	return out


static func _stop_index(stops: Array, id: String) -> int:
	for i in stops.size():
		if stops[i]["id"] == id:
			return i
	return 0


## What the party has lost along with them, for the camp: the camp beats
## that were theirs to run.
static func lost_roles(session: Dictionary) -> Dictionary:
	var t := ensure(session)
	var out := {}
	if t["gone"].has("lena"):
		out["pole-pole"] = "No one to set pole pole since Lena went down."
	if t["gone"].has("jun"):
		out["head-count"] = "No head count since Jun went down."
	return out


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
			_depart(session, who)
			if who == "you":
				t["ending"] = "evacuated"
				return {"note": "You go down with the porters. The others follow you off the mountain.", "move": "down", "hours": 8,
					"scores": {"judgment": {"label": "You went down when your body said so", "delta": 4, "mark": "trek-evac-you"}}}
			return {"note": "%s goes down with two porters. %s The tents feel bigger tonight." % [name, FAREWELL.get(who, "")], "move": "hold", "hours": 3, "teamCondition": -14,
				"scores": {"teamwork": {"label": "You sent %s down to save them" % name, "delta": -2, "mark": "trek-evac-" + who}}}
		_:
			# Waiting: it may settle; more often it does not.
			var s: Dictionary = session["state"]
			if _roll(s, 61, Party.ORDER.find(who)) < 35:
				t["sick"][who]["stage"] = 2
				return {"note": "The night is long. By morning %s is a little better. That was luck." % ("you are" if who == "you" else name + " is"), "move": "hold", "hours": 12,
					"scores": {"riskManagement": {"label": "You waited out a dangerous night", "delta": -6, "mark": "trek-wait-" + who}}}
			_depart(session, who)
			if who == "you":
				t["ending"] = "evacuated"
				return {"note": "By midnight you cannot stand. A rescue team carries you down.", "move": "down", "hours": 12, "health": -20,
					"scores": {"riskManagement": {"label": "You waited on the one sign you do not wait on", "delta": -8, "mark": "trek-wait-you"}}}
			return {"note": "By midnight %s cannot stand. Rescue carries them down. The party is shaken." % name, "move": "hold", "hours": 12, "teamCondition": -24, "health": -6,
				"scores": {"riskManagement": {"label": "You waited on %s's worst night" % name, "delta": -8, "mark": "trek-wait-" + who}}}


# --- Foresight -----------------------------------------------------------------

## The camp screen's own names for the stats, so the two always match.
const STAT_WORDS := {"energy": "Energy", "supplies": "Supplies", "health": "Health", "teamCondition": "Team",
	"acclimatization": "Used to height", "weatherRisk": "Weather risk", "objectiveRisk": "Falling rock"}


## The risk bands: below RISK_MEDIUM a choice is low risk, from RISK_HIGH
## it is high.
const RISK_MEDIUM := 20.0
const RISK_HIGH := 45.0


## What a choice will cost before you pick it: the hours, the stats it moves
## (route included), and how risky it looks as a band, not a number, with
## the reasons. What actually happens still rolls on the day.
static func foresee(session: Dictionary, choice: Dictionary, def: Dictionary) -> Dictionary:
	var e: Dictionary = choice.get("effect", {})
	if e.is_empty():
		return {}
	var s: Dictionary = session["state"]
	var r := route(session)
	var t := ensure(session)
	var move := String(e.get("move", "hold"))
	var up := move == "up" or move == "summit"
	var hours := float(e.get("hours", 6))
	var deltas := {}
	for key in STAT_WORDS:
		if e.has(key) and int(e[key]) != 0:
			deltas[key] = int(e[key])
	if up:
		for pair in [["energy", "upEnergy"], ["acclimatization", "upAcclim"], ["health", "upHealth"]]:
			if int(r[pair[1]]) != 0:
				deltas[pair[0]] = deltas.get(pair[0], 0) + int(r[pair[1]])
	var costs: Array = []
	for key in deltas:
		costs.append("%s %+d" % [STAT_WORDS[key], deltas[key]])
	var why: Array = []
	var score := 0.0
	var energy_after: float = float(s["energy"]) + float(deltas.get("energy", 0))
	# What the choice itself does. The card's own verdict first: a call the
	# expedition scores as poor judgment or poor risk management is a risk.
	var verdict := 0.0
	for bucket in ["judgment", "riskManagement"]:
		for note in ExpeditionEngine.notes_of(e.get("scores", {}).get(bucket)):
			verdict += float(note.get("delta", 0))
	if verdict < 0.0:
		score += -verdict * 2.5
		why.append("it is a gamble with the team's margin")
	# What it takes out of the people.
	var hurt := -float(mini(0, int(deltas.get("health", 0))))
	var spent := -float(mini(0, int(e.get("energy", 0))))
	var morale := -float(mini(0, int(deltas.get("teamCondition", 0))))
	score += hurt * 2.5 + maxf(0.0, spent - 4.0) * 1.5 + morale * 1.0
	if hurt > 0.0:
		why.append("someone could get hurt")
	if spent >= 10.0:
		why.append("it costs a lot of energy")
	if int(deltas.get("weatherRisk", 0)) > 0:
		score += float(deltas["weatherRisk"])
		why.append("the weather gets worse")
	# A played climb waits behind it: the tower is a scramble, the wall a
	# real climb, the summit night the hardest thing on the mountain.
	var climb := ""
	if up and not s["retreating"]:
		for id in Coordinator.CLIMBS:
			if Coordinator.CLIMBS[id]["gate"] == s["checkpoint"]:
				climb = id
	if climb != "":
		score += {"lava-tower": 10.0, "barranco-wall": 22.0, "summit-night": 40.0}.get(climb, 15.0)
		why.append("%s is a climb you play, and slips cost the party" % Coordinator.CLIMBS[climb]["title"])
	elif move == "summit":
		score += 20.0
		why.append("it is the summit push")
	if up:
		var meters := float(s["altitude"])
		var stops: Array = def["route"]
		for i in stops.size():
			if stops[i]["id"] == s["checkpoint"] and i + 1 < stops.size():
				meters = float(stops[i + 1]["meters"])
		var gap: float = ExpeditionEngine.acclimatization_need(meters) - (float(s["acclimatization"]) + float(deltas.get("acclimatization", 0)))
		score += maxf(gap, 0.0) * 2.0 + float(r["risk"])
		if meters >= 3800:
			score += 10.0
		if gap > 0:
			why.append("going higher (%s m) than your bodies are used to" % ExpeditionEngine.format_meters(meters))
		if float(r["risk"]) > 0:
			why.append("your route is a fast one")
		if float(s["weatherRisk"]) >= 40:
			score += 10.0
			why.append("bad weather coming")
	# The party's state makes anything that asks more of it riskier; it
	# never makes resting riskier.
	var demanding := up or spent > 0.0
	if demanding and energy_after < 40:
		score += (40.0 - energy_after) * 0.8
		why.append("everyone is tired")
	if up:
		for m in Party.members(s):
			if m["pose"] == "kneel" and not t["gone"].has(m["id"]):
				score += 15.0
				why.append("%s is exhausted" % m["name"] if m["id"] != "you" else "you are exhausted")
	if not t["sick"].is_empty() and up:
		score += 10.0 * t["sick"].size()
		why.append("someone is already sick")
	if hours >= hours_left(session) and not (move == "down" or move == "retreat"):
		why.append("you'd run out of days")
		score += 30.0
	var band := "low" if score < RISK_MEDIUM else ("medium" if score < RISK_HIGH else "high")
	if move == "down" or move == "retreat":
		band = "low"
		why = ["going down helps sick people get better"]
	return {"hours": hours, "costs": costs, "risk": band, "why": why, "deltas": deltas, "move": move}


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
	if not t["sick"].has(id):
		return false
	var sick: Dictionary = t["sick"][id]
	match String(sick["kind"]):
		"cold":
			return int(session["state"]["supplies"]) >= 3
		"ams":
			# One painkiller per camp is enough; more does not help.
			return int(t.get("medicine", 0)) > 0 and sick.get("eased") != session["state"]["checkpoint"]
	return int(t.get("medicine", 0)) > 0


## What the kit offers for this person's illness, in plain words.
static func medicine_label(session: Dictionary, id: String) -> String:
	match String(sickness(session, id).get("kind", "")):
		"ams":
			return "Painkiller (like Tylenol)"
		"stomach":
			return "Stomach pills"
		"cold":
			return "Hot drink, dry gloves"
	return "Medicine"


## Treats someone with what fits their illness. A painkiller eases altitude
## sickness's headache (and keeps its dizziness off the next climb) but does
## not cure it: only rest or going down does. Stomach pills settle a
## stomach. The cold needs warmth, not pills. Game fiction, not advice.
static func medicate(session: Dictionary, id: String) -> Dictionary:
	var t := ensure(session)
	var sick: Dictionary = t["sick"][id]
	var who: String = "you" if id == "you" else NAMES[id]
	var mark := "trek-med-%s-%s" % [id, session["state"]["checkpoint"]]
	match String(sick["kind"]):
		"ams":
			t["medicine"] = int(t["medicine"]) - 1
			sick["eased"] = session["state"]["checkpoint"]
			var whose: String = "your" if id == "you" else NAMES[id] + "'s"
			var left := int(t["medicine"])
			return {"note": "A painkiller (like Tylenol) for %s headache. It eases the pain, but it does not fix altitude sickness: only rest or going lower does. %d dose%s left." % [whose, left, "" if left == 1 else "s"],
				"move": "hold", "hours": 1, "teamCondition": 1, "energy": 2,
				"scores": {"judgment": {"label": "You eased %s's headache" % who, "delta": 1, "mark": mark}}}
		"cold":
			sick["stage"] -= 1
			if sick["stage"] <= 0:
				t["sick"].erase(id)
			return {"note": "A hot drink and dry gloves for %s. Warmth helps." % who,
				"move": "hold", "hours": 1, "supplies": -3, "teamCondition": 1,
				"scores": {"teamwork": {"label": "You warmed %s up" % who, "delta": 2, "mark": mark}}}
	t["medicine"] = int(t["medicine"]) - 1
	sick["stage"] -= 1
	if sick["stage"] <= 0:
		t["sick"].erase(id)
	return {"note": "Stomach pills from the kit for %s. %d dose%s left." % [who, int(t["medicine"]), "" if int(t["medicine"]) == 1 else "s"],
		"move": "hold", "hours": 1, "teamCondition": 1,
		"scores": {"judgment": {"label": "You used the medicine on %s" % who, "delta": 2, "mark": mark}}}


## Someone's illness in plain words: what it is, why they have it, and what
## helps. Empty when they are well.
static func explain_sickness(session: Dictionary, id: String) -> Dictionary:
	var sick := sickness(session, id)
	if sick.is_empty():
		return {}
	var name: String = "You" if id == "you" else NAMES[id]
	var their: String = "your" if id == "you" else "their"
	var stage: int = sick["stage"]
	var how: String = ["mild", "getting worse", "serious"][clampi(stage - 1, 0, 2)]
	match String(sick["kind"]):
		"ams":
			var why: String = {
				"fast": "The team went up faster than %s body could get used to the thin air." % their,
				"tired": "Worn out bodies handle thin air badly.",
			}.get(String(sick.get("cause", "")), "Up high, anyone can get it, even when you do it right.")
			return {"what": "Altitude sickness (%s): %s." % [how, describe("ams", stage)], "why": why,
				"helps": "Rest a day, or go lower. A painkiller (like Tylenol) eases the headache but doesn't fix it." + (" At its worst it is an emergency: go down." if stage >= 2 else "")}
		"stomach":
			var why: String = "The drinking water wasn't boiled at the last camp." if sick.get("cause") == "water" else "The food went bad: the supplies are running low and old."
			return {"what": "A sick stomach (%s): %s." % [how, describe("stomach", stage)], "why": why,
				"helps": "Stomach pills from the kit, and rest. Boil the water at every camp to stop it happening."}
		"cold":
			return {"what": "Too cold (%s): %s." % [how, describe("cold", stage)],
				"why": "A freezing night up high, with little food or energy to stay warm.",
				"helps": "A hot drink and dry gloves, food, and rest."}
	return {"what": "%s %s unwell." % [name, "are" if id == "you" else "is"], "why": "", "helps": ""}


## A dose taken before a climb, to keep the symptoms off while you climb.
static func dose_for_climb(session: Dictionary) -> bool:
	var t := ensure(session)
	if int(t.get("medicine", 0)) <= 0:
		return false
	t["medicine"] = int(t["medicine"]) - 1
	return true


static func send_down(session: Dictionary, id: String) -> Dictionary:
	_depart(session, id)
	return {"note": "%s goes down with a porter while it is still a walk, not a rescue. %s" % [NAMES[id], FAREWELL.get(id, "")], "move": "hold", "hours": 2, "teamCondition": -10,
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
	var t := ensure(session)
	var key: String = t["ending"]
	var e: Array = ENDINGS.get(key, ["The expedition is over", ""]).duplicate()
	# Name who is not at the gate with you.
	var names: Array = []
	for id in t["gone"]:
		if id != "you":
			names.append(NAMES[id])
	if not names.is_empty() and key in ["summit-cost", "hard-walk-out"]:
		e[1] = "%s %s went down early and met you at the gate." % [e[1], " and ".join(names)]
	return e


## How the climbs feel the trek: the route's steepness, and being unwell.
static func climb_factor(session: Dictionary) -> Dictionary:
	var you := sickness(session, "you")
	var stage: int = you.get("stage", 0)
	return {"steep": float(route(session)["climb"]), "sick": stage, "stamina": 1.0 - 0.12 * stage}
