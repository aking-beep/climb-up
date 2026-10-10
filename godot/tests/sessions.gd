class_name TestSessions
extends RefCounted
## Expedition sessions for tests: a careful party played through the real
## engine up to the gate of a climb, with that climb launched (pending).

const CAREFUL := [
	"Walk the forest and set camp", "Sleep under the trees", "Break camp and keep a patient pace",
	"Stake the tents and sleep", "Cross the plateau and pitch at Shira 2", "Sleep before the tower",
	"Tag the tower, then sleep low", "Sleep and leave the wall for morning", "Climb the wall and camp at Karanga",
	"Lie down in the valley", "Take the extra day", "Break camp for Barafu", "Lie down on the ridge",
	"Rest the day", "Keep the pace through the dark",
]


static func complete(p: Dictionary) -> Dictionary:
	return {"attemptId": p["attemptId"], "challengeId": p["challengeId"], "result": "complete", "staminaLeft": 60, "slips": 0, "assisted": null if p["challengeId"] == "lava-tower" else true, "regrouped": false, "seconds": 200}


## A session with `challenge` pending, or {} if the careful party never got there.
static func at(challenge: String, seed: int = 7) -> Dictionary:
	var def := Kili.def()
	var session := Coordinator.create_session(ExpeditionEngine.create(seed, def))
	for n in 120:
		if session["state"]["status"] != "active":
			return {}
		var card := ExpeditionEngine.current_event(session["state"], def)
		var pick := 0
		for i in card["choices"].size():
			if CAREFUL.has(card["choices"][i]["label"]):
				pick = i
				break
		var r := Coordinator.choose(session, pick, def)
		session = r["session"]
		if r["launched"] != null:
			if r["launched"]["challengeId"] == challenge:
				return session
			session = Coordinator.resolve(session, complete(r["launched"]), def)["session"]
	return {}
