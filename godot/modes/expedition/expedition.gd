extends Node
## The running expedition (autoload `Expedition`): the whole Kilimanjaro
## game from the Expo app, ported (engine/), with its three played climbs.
##
## The session is the Coordinator's: the expedition state, the pending
## climb if a card launched one, and the attempts already landed. Scenes
## change through here, so the flow menu → camp (cards) → climb → camp
## stays in one place, and every change is saved.

signal changed

const MENU := "res://modes/expedition/menu.tscn"
const CAMP := "res://modes/expedition/camp/camp.tscn"
const LEVELS := {
	"lava-tower": "res://modes/expedition/levels/kilimanjaro/lava_tower/lava_tower.tscn",
	"barranco-wall": "res://modes/expedition/levels/kilimanjaro/barranco/barranco.tscn",
	"summit-night": "res://modes/expedition/levels/kilimanjaro/summit_night/summit_night.tscn",
}
## The played way down from the summit. Not one of the Coordinator's climbs
## (those are the Expo game's, kept identical): it lives on the trek.
const DESCENT := "res://modes/expedition/levels/kilimanjaro/descent/descent.tscn"

var def: Dictionary = {}
var session: Dictionary = {}
## The climb in progress, for resuming mid-level: {attemptId, challengeId,
## checkpoint, slips, mate, regrouped, spotter, seconds}.
var climb: Dictionary = {}
## What the last action did, for the camp screen to show once:
## {kind: card | climb | beat, label, before (state), outcome}.
var last: Dictionary = {}
## Lost gear found, per climb: {challengeId: [index, ...]}. Kept across
## attempts and new expeditions, like a collection.
var found: Dictionary = {}
## Off in tests, so landing an outcome does not replace the test runner.
var navigate := true


func _init() -> void:
	def = Kili.def()
	session = Coordinator.create_session(ExpeditionEngine.create(7, def))


func state() -> Dictionary:
	return session["state"]


func pending() -> Variant:
	return session["pending"]


func active() -> bool:
	return state()["status"] == "active"


## The decision in front of the party, or {} once the expedition is over.
func card() -> Dictionary:
	if not active():
		return {}
	var t := Trek.ensure(session)
	if t["route"] == "":
		return Trek.route_card()
	if t["emergency"] != null and pending() == null:
		return Trek.emergency_card(session)
	return ExpeditionEngine.current_event(state(), def)


func trek() -> Dictionary:
	return Trek.ensure(session)


## Which choices of the current card are played climbs: id or "".
func playable() -> Array:
	var c := card()
	var out: Array = []
	if c.is_empty():
		return out
	for i in c["choices"].size():
		out.append("" if c.get("trek", false) else Coordinator.challenge_for(state(), c, i))
	return out


func new_expedition(seed: int = 7) -> void:
	# Starting over with one still under way is giving that one up.
	if not session.is_empty() and active() and state()["history"].size() > 0:
		Analytics.event("expedition_abandoned", {"checkpoint": state()["checkpoint"], "day": ExpeditionEngine.day_of(state())})
	Analytics.event("expedition_started", {"seed": seed})
	_reported_end = false
	session = Coordinator.create_session(ExpeditionEngine.create(seed, def))
	session["trek"] = Trek.fresh("")
	climb = {}
	last = {}
	save()
	changed.emit()


## A card choice. A choice that launches a climb opens the level; the card
## is only spent when the climb's outcome lands.
func choose(index: int) -> void:
	var c := card()
	if c.is_empty() or index < 0 or index >= c["choices"].size():
		return
	var before := state()
	if c.get("trek", false):
		var choice: Dictionary = c["choices"][index]
		if choice.has("route"):
			Trek.choose_route(session, choice["route"])
			last = {}
		else:
			var effect := Trek.resolve_emergency(session, choice["act"], def)
			session = Coordinator.play(session, effect, def)
			Trek.advance(session, before, def)
			last = {"kind": "card", "label": choice["label"], "before": before}
		save()
		changed.emit()
		return
	if descent_launches(index):
		_open_descent(index)
		return
	var r := Coordinator.choose(session, index, def)
	session = r["session"]
	if r["launched"] != null:
		_open_climb(r["launched"])
		save()
		go(LEVELS[r["launched"]["challengeId"]])
		return
	Trek.advance(session, before, def)
	last = {"kind": "card", "label": c["choices"][index]["label"], "before": before}
	save()
	changed.emit()


func _open_climb(p: Dictionary) -> void:
	if climb.get("attemptId") == p["attemptId"]:
		return
	climb = {"attemptId": p["attemptId"], "challengeId": p["challengeId"], "checkpoint": 0, "slips": 0, "mate": "waiting", "regrouped": false, "spotter": false, "seconds": 0.0}


## Back into a climb that was launched but not finished (after a quit).
func resume_climb() -> void:
	var p: Variant = pending()
	if p == null:
		return
	_open_climb(p)
	go(LEVELS[p["challengeId"]])


## A camp beat (pole pole, water, head count) or sitting with someone.
func play_routine(id: String) -> void:
	if Trek.lost_roles(session).has(id):
		return
	_beat(Party.routine_effect(state(), id), id)


func tend(id: String) -> void:
	_beat(Party.tend_effect(state(), id), "tend-" + id)


## Jun looks after someone who is unwell.
func treat(id: String) -> void:
	if Trek.can_treat(session, id) and pending() == null:
		_beat(Trek.treat(session, id), "treat-" + id)


## A dose from the medicine kit for someone unwell.
func medicate(id: String) -> void:
	if Trek.can_medicate(session, id) and pending() == null:
		_beat(Trek.medicate(session, id), "medicine-" + id)


## Sends someone down with a porter before it becomes a rescue.
func send_down(id: String) -> void:
	if id != "you" and not Trek.is_gone(session, id) and pending() == null:
		_beat(Trek.send_down(session, id), "down-" + id)


func _beat(effect: Variant, label: String) -> void:
	if effect == null or pending() != null:
		return
	var before := state()
	session = Coordinator.play(session, effect, def)
	Trek.advance(session, before, def)
	last = {"kind": "beat", "label": label, "before": before}
	save()
	changed.emit()


## The climb ended. Lands once: an outcome for another attempt is ignored.
## Returns the Coordinator's status (applied, duplicate, stale, invalid).
func finish_climb(outcome: Dictionary) -> String:
	var p: Variant = pending()
	if p == null or outcome.get("attemptId") != p["attemptId"]:
		return "stale"
	var before := state()
	var r := Coordinator.resolve(session, outcome, def)
	session = r["session"]
	if r["status"] == "applied":
		Trek.advance(session, before, def)
		# A three-star climb lifts the party.
		if int(outcome.get("stars", 0)) >= 3 and active():
			var s: Dictionary = state().duplicate(true)
			s["teamCondition"] = mini(100, int(s["teamCondition"]) + 3)
			s["energy"] = mini(100, int(s["energy"]) + 2)
			s["lastNote"] = (String(s["lastNote"]) + " A clean climb: the party's spirits lift.").strip_edges()
			session["state"] = s
		# Left on the rock with no Lena to bring them up: they turn back down,
		# and that is the end of their trip.
		var mate: String = Trek.CLIMB_MATE.get(String(p["challengeId"]), "")
		if outcome.get("assisted") == false and mate != "" and Trek.is_gone(session, "lena") and not Trek.is_gone(session, mate) and active():
			Trek._depart(session, mate)
			var sm: Dictionary = state().duplicate(true)
			sm["teamCondition"] = maxi(0, int(sm["teamCondition"]) - 10)
			# The climb's note still says Lena brings them up: she can't.
			sm["lastNote"] = String(sm["lastNote"]).replace(" and Lena brings %s up later" % Trek.NAMES[mate], "")
			sm["lastNote"] = (String(sm["lastNote"]) + " With no Lena to bring %s up, %s turns back down alone." % [Trek.NAMES[mate], Trek.NAMES[mate]]).strip_edges()
			session["state"] = sm
		# What bit, stung and struck you on the climb comes back to camp, as
		# energy: the bar the next climb starts with.
		var hurt := int(outcome.get("hurt", 0))
		if hurt >= 10 and active():
			var s: Dictionary = state().duplicate(true)
			var cost := mini(12, hurt / 5)
			s["energy"] = maxi(0, int(s["energy"]) - cost)
			s["lastNote"] = (String(s["lastNote"]) + " Stings and bites from the climb: energy %d." % -cost).strip_edges()
			session["state"] = s
		# Snacks eaten on the climb come out of the camp's food.
		var food := int(outcome.get("food", 0))
		if food > 0 and active():
			var sf: Dictionary = state().duplicate(true)
			sf["supplies"] = maxi(0, int(sf["supplies"]) - food)
			sf["lastNote"] = (String(sf["lastNote"]) + " Food eaten on the climb: supplies -%d." % food).strip_edges()
			session["state"] = sf
		# Fires at the cairns: hours off the expedition's clock.
		var fire := clampi(int(outcome.get("fireHours", 0)), 0, 24)
		if fire > 0 and active():
			var sh: Dictionary = state().duplicate(true)
			sh["elapsedHours"] = int(sh["elapsedHours"]) + fire
			sh["lastNote"] = (String(sh["lastNote"]) + " Fires on the climb: %d hour%s later." % [fire, "" if fire == 1 else "s"]).strip_edges()
			session["state"] = sh
		last = {"kind": "climb", "label": p["choiceLabel"], "before": before, "outcome": outcome}
	climb = {}
	save()
	go(CAMP)
	changed.emit()
	return r["status"]


# --- The way down ----------------------------------------------------------------

## True when this choice turns the party around on the summit and the way
## down has not been played yet: it opens the descent level.
func descent_launches(index: int) -> bool:
	var c := card()
	if c.is_empty() or c.get("trek", false) or state()["checkpoint"] != "summit" or pending() != null:
		return false
	if trek().get("descent", {}).get("played", false):
		return false
	var move := String(c["choices"][index]["effect"].get("move", ""))
	return move == "retreat" or move == "down"


func _open_descent(index: int) -> void:
	var id := "descent:%s:%d" % [ExpeditionEngine.to_base36(int(state()["seed"])), state()["history"].size()]
	trek()["descent"] = {"attemptId": id, "choiceIndex": index, "played": false, "result": ""}
	climb = {"attemptId": id, "challengeId": "descent", "checkpoint": 0, "slips": 0, "mate": "waiting", "regrouped": false, "spotter": false, "seconds": 0.0}
	save()
	go(DESCENT)


## What the way down did to the expedition, as an engine effect. A clean,
## together descent is worth more than the summit was; leaving a spent
## teammate on the rim costs the team; a descent that took more than you
## had hurts, and can end the expedition up there.
static func descent_effect(o: Dictionary) -> Dictionary:
	# No hours of its own: it lands while the party is still on top, and the
	# card's own move down is the time the descent takes.
	var e := {"note": "You bring the team down off the summit cone to Barafu.", "hours": 0, "move": "wait"}
	var scores := {}
	if o.get("result") == "fail":
		e["note"] = "The descent takes more than you have. Lena and the porters bring you down to Barafu."
		e["health"] = -10
		e["energy"] = -6
		e["teamCondition"] = -6
		e["hours"] = 2
		scores["riskManagement"] = {"label": "The descent took more than the team had left", "delta": -6, "mark": "descent-fail"}
	else:
		var slips := int(o.get("slips", 0))
		if slips > 0:
			e["health"] = -mini(8, slips * 2)
		else:
			scores["riskManagement"] = {"label": "A clean descent: no slips on the scree", "delta": 4, "mark": "descent-clean"}
		if int(o.get("staminaLeft", 100)) < 25:
			e["energy"] = -4
		if o.get("regrouped", false):
			e["energy"] = int(e.get("energy", 0)) + 2
	var a: Variant = o.get("assisted")
	if a == true:
		e["teamCondition"] = int(e.get("teamCondition", 0)) + 6
		scores["teamwork"] = {"label": "You brought Jun down on the rope beside you", "delta": 8, "mark": "descent-assist"}
		scores["judgment"] = {"label": "You kept the team together on the way down", "delta": 4, "mark": "descent-together"}
	elif a == false:
		e["teamCondition"] = int(e.get("teamCondition", 0)) - 6
		scores["teamwork"] = {"label": "You went down ahead of Jun and left him to Lena", "delta": -6, "mark": "descent-left"}
	# Fires on the way down: hours on the clock.
	if int(o.get("fireHours", 0)) > 0:
		e["hours"] = int(e["hours"]) + clampi(int(o["fireHours"]), 0, 24)
	# Snacks eaten on the way down come out of the camp's food.
	if int(o.get("food", 0)) > 0:
		e["supplies"] = -int(o["food"])
	if not scores.is_empty():
		e["scores"] = scores
	return e


## The way down is over. The card's own move takes the party down, exactly
## as the card would have without the level; then how the descent went
## lands on the stats and the score straight away, like the trek's own
## consequences (no extra engine step, so no extra roll of the mountain's
## dice). A descent that went badly can still end the expedition. Lands
## once.
func finish_descent(outcome: Dictionary) -> String:
	var d: Dictionary = trek().get("descent", {})
	if d.is_empty() or d.get("played", false) or d.get("attemptId", "") != outcome.get("attemptId"):
		return "stale"
	var before := state()
	var r := Coordinator.choose(session, int(d["choiceIndex"]), def)
	session = r["session"]
	Trek.advance(session, before, def)
	_land_descent(descent_effect(outcome))
	d["played"] = true
	d["result"] = String(outcome.get("result", ""))
	trek()["descent"] = d
	Analytics.event("descent_completed", {"result": d["result"], "slips": int(outcome.get("slips", 0)), "assisted": outcome.get("assisted") == true})
	last = {"kind": "climb", "label": "The way down", "before": before, "outcome": outcome}
	climb = {}
	save()
	go(CAMP)
	changed.emit()
	return "applied"


## Adds a descent effect's stats, scores and note to the state; the end of
## the expedition is judged again after.
func _land_descent(e: Dictionary) -> void:
	var s: Dictionary = state().duplicate(true)
	var was_active: bool = s["status"] == "active"
	for key in ExpeditionEngine.STAT_KEYS:
		s[key] += int(e.get(key, 0))
	ExpeditionEngine._add_scores(s, e)
	ExpeditionEngine._clamp_stats(s)
	if was_active:
		ExpeditionEngine._evaluate(s, def)
	elif s["status"] == "complete" and (int(s["health"]) <= 0 or int(s["teamCondition"]) <= 0):
		# Home, but the descent broke someone: not a safe return.
		s["status"] = "failed"
		s["returnedSafely"] = false
	s["lastNote"] = (String(e.get("note", "")) + " " + String(s["lastNote"])).strip_edges()
	session["state"] = s
	if s["status"] != "active":
		Trek._settle_ending(session)


## Leaving the climb from its brief without starting: lands as a retreat.
func abandon_climb() -> void:
	var p: Variant = pending()
	if p == null:
		return
	var before := state()
	var r := Coordinator.abandon(session, def)
	session = r["session"]
	if r["status"] == "applied":
		Trek.advance(session, before, def)
		last = {"kind": "climb", "label": p["choiceLabel"], "before": before,
			"outcome": {"challengeId": p["challengeId"], "result": "retreat", "slips": 0, "staminaLeft": 100, "assisted": null, "regrouped": false, "seconds": 0}}
	climb = {}
	save()
	go(CAMP)
	changed.emit()


## Progress inside the climb, so quitting mid-wall resumes at the last cairn.
func remember(progress: Dictionary) -> void:
	if climb.is_empty():
		return
	for key in progress:
		climb[key] = progress[key]
	save()


## Best result per climb: {challengeId: {stars, artifacts}}. Kept like gear.
var best: Dictionary = {}


## Records a result; true when it beats the best so far.
func record_best(id: String, stars: int, artifacts: int) -> bool:
	var was: Dictionary = best.get(id, {"stars": 0, "artifacts": 0})
	var better: bool = stars > int(was.get("stars", 0)) or (stars == int(was.get("stars", 0)) and artifacts > int(was.get("artifacts", 0)))
	if better:
		best[id] = {"stars": stars, "artifacts": artifacts}
		save()
	return better and stars > 0


func gear_found(id: String) -> Array:
	return found.get(id, [])


func find_gear(id: String, index: int) -> void:
	var list: Array = found.get(id, [])
	if not list.has(index):
		list.append(index)
	found[id] = list
	save()


var _reported_end := false


## Once an expedition is over (home, or lost on the mountain): one event.
func _report_end() -> void:
	if active() or _reported_end:
		return
	_reported_end = true
	Records.expedition_finished(session)
	var sc := ExpeditionEngine.score(state())
	Analytics.event("expedition_completed", {"returned": sc["returnedSafely"], "summit": sc["summitReached"], "overall": sc["overall"],
		"day": ExpeditionEngine.day_of(state()), "descent_played": bool(trek().get("descent", {}).get("played", false))})


func save() -> bool:
	_report_end()
	return SaveGame.write({"session": session, "climb": climb, "found": found, "best": best, "settings": Settings.to_dict()})


## True when a saved expedition was restored. A save that does not have the
## shape of a session (or names a climb this build lacks) is not loaded.
func load_saved() -> bool:
	var data: Variant = SaveGame.read()
	if data == null:
		return false
	var s: Variant = _whole(data.get("session"))
	if typeof(s) != TYPE_DICTIONARY or typeof(s.get("state")) != TYPE_DICTIONARY:
		return false
	var st: Dictionary = s["state"]
	for key in ["seed", "checkpoint", "status", "history", "marks", "ledger", "seen"]:
		if not st.has(key):
			return false
	var p: Variant = s.get("pending")
	if p != null and (typeof(p) != TYPE_DICTIONARY or not LEVELS.has(p.get("challengeId"))):
		p = null
	session = {"state": st, "prior": null, "pending": p, "resolvedAttempts": s.get("resolvedAttempts", [])}
	var tk: Variant = s.get("trek")
	if typeof(tk) == TYPE_DICTIONARY and Trek.ROUTES.has(tk.get("route")) or (typeof(tk) == TYPE_DICTIONARY and tk.get("route") == ""):
		var t := Trek.fresh(String(tk["route"]))
		for key in t:
			if tk.has(key) and typeof(tk[key]) == typeof(t[key]):
				t[key] = tk[key]
		if typeof(tk.get("emergency")) == TYPE_DICTIONARY and Party.ORDER.has(tk["emergency"].get("who")):
			t["emergency"] = tk["emergency"]
		session["trek"] = t
	var f: Variant = _whole(data.get("found", {}))
	found = f if typeof(f) == TYPE_DICTIONARY else {}
	var b: Variant = _whole(data.get("best", {}))
	best = b if typeof(b) == TYPE_DICTIONARY else {}
	var c: Variant = data.get("climb", {})
	climb = c if typeof(c) == TYPE_DICTIONARY and p != null and c.get("attemptId") == p["attemptId"] else {}
	last = {}
	return true


## JSON brings every number back as a float; the engine's numbers are
## whole, so whole floats become ints again.
static func _whole(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if v == floorf(v) and absf(v) < 9.0e15 else v
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = _whole(v[k])
			return d
		TYPE_ARRAY:
			return v.map(_whole)
	return v


func has_save() -> bool:
	return SaveGame.read() != null


func go(path: String) -> void:
	if navigate and is_inside_tree():
		Transition.go(get_tree(), path)
