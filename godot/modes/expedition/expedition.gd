extends Node
## The running expedition (autoload `Expedition`): its state, the climb in
## progress, the last outcome, and saving. Scenes change through here so the
## flow menu → briefing → climb → outcome stays in one place.

const MENU := "res://modes/expedition/menu.tscn"
const BRIEFING := "res://modes/expedition/briefing.tscn"
const BARRANCO := "res://modes/expedition/levels/kilimanjaro/barranco/barranco.tscn"
const OUTCOME := "res://modes/expedition/outcome.tscn"

var state: ExpeditionState = ExpeditionState.new()
## The climb in progress: {attemptId, checkpoint, slips, mate, regrouped, seconds}.
var climb: Dictionary = {}
var last_outcome: ChallengeOutcome = null
var last_choice := ""
## The expedition just before the last decision landed, to show what changed.
var before: Dictionary = {}
## Off in tests, so landing an outcome does not replace the test runner.
var navigate := true


func new_expedition(seed: int = 7) -> void:
	state = ExpeditionState.new()
	state.seed = seed
	climb = {}
	last_outcome = null
	save()


func attempt_id() -> String:
	return "kilimanjaro:%d:kili-wall:%d" % [state.seed, int(state.hours)]


func start_climb() -> void:
	if climb.is_empty():
		climb = {"attemptId": attempt_id(), "checkpoint": 0, "slips": 0, "mate": "waiting", "regrouped": false, "seconds": 0.0}
	save()
	go(BARRANCO)


## Leaving from the briefing without climbing: lands as a retreat, once.
func back_off() -> void:
	if climb.is_empty():
		climb = {"attemptId": attempt_id(), "checkpoint": 0}
	var o := ChallengeOutcome.new()
	o.attempt_id = climb["attemptId"]
	o.result = "retreat"
	o.stamina_left = 100
	finish_climb(o)


## The climb ended. Lands once: an outcome for another attempt is ignored.
func finish_climb(outcome: ChallengeOutcome) -> void:
	if climb.is_empty() or outcome.attempt_id != climb.get("attemptId"):
		return
	climb = {}
	last_outcome = outcome
	last_choice = "climb"
	before = state.to_dict()
	state.apply_wall(outcome)
	save()
	go(OUTCOME)


func rest_instead() -> void:
	last_outcome = null
	last_choice = "rest"
	before = state.to_dict()
	state.rest_day()
	save()
	go(OUTCOME)


## Progress inside the climb, so quitting mid-wall resumes at the last cairn.
func remember(progress: Dictionary) -> void:
	if climb.is_empty():
		return
	for key in progress:
		climb[key] = progress[key]
	save()


func save() -> bool:
	return SaveGame.write({"expedition": state.to_dict(), "climb": climb, "settings": Settings.to_dict()})


## True when a saved expedition was restored.
func load_saved() -> bool:
	var data: Variant = SaveGame.read()
	if data == null:
		return false
	var restored := ExpeditionState.from_dict(data.get("expedition"))
	if restored == null:
		return false
	state = restored
	var c: Variant = data.get("climb", {})
	climb = c if typeof(c) == TYPE_DICTIONARY and c.has("attemptId") else {}
	return true


func has_save() -> bool:
	return SaveGame.read() != null


func go(path: String) -> void:
	if navigate and is_inside_tree():
		get_tree().call_deferred("change_scene_to_file", path)
