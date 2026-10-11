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
	return ExpeditionEngine.current_event(state(), def)


## Which choices of the current card are played climbs: id or "".
func playable() -> Array:
	var c := card()
	var out: Array = []
	if c.is_empty():
		return out
	for i in c["choices"].size():
		out.append(Coordinator.challenge_for(state(), c, i))
	return out


func new_expedition(seed: int = 7) -> void:
	session = Coordinator.create_session(ExpeditionEngine.create(seed, def))
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
	var r := Coordinator.choose(session, index, def)
	session = r["session"]
	if r["launched"] != null:
		_open_climb(r["launched"])
		save()
		go(LEVELS[r["launched"]["challengeId"]])
		return
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
	_beat(Party.routine_effect(state(), id), id)


func tend(id: String) -> void:
	_beat(Party.tend_effect(state(), id), "tend-" + id)


func _beat(effect: Variant, label: String) -> void:
	if effect == null or pending() != null:
		return
	var before := state()
	session = Coordinator.play(session, effect, def)
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
		last = {"kind": "climb", "label": p["choiceLabel"], "before": before, "outcome": outcome}
	climb = {}
	save()
	go(CAMP)
	changed.emit()
	return r["status"]


## Leaving the climb from its brief without starting: lands as a retreat.
func abandon_climb() -> void:
	var p: Variant = pending()
	if p == null:
		return
	var before := state()
	var r := Coordinator.abandon(session, def)
	session = r["session"]
	if r["status"] == "applied":
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


func gear_found(id: String) -> Array:
	return found.get(id, [])


func find_gear(id: String, index: int) -> void:
	var list: Array = found.get(id, [])
	if not list.has(index):
		list.append(index)
	found[id] = list
	save()


func save() -> bool:
	return SaveGame.write({"session": session, "climb": climb, "found": found, "settings": Settings.to_dict()})


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
	var f: Variant = _whole(data.get("found", {}))
	found = f if typeof(f) == TYPE_DICTIONARY else {}
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
		get_tree().call_deferred("change_scene_to_file", path)
