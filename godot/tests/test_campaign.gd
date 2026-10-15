extends TestCase
## The whole Kilimanjaro campaign in one go, through the Expedition autoload
## the game uses: every camp card from the gate to the walk out, each
## played climb (Lava Tower, Barranco Wall, summit night, the way down)
## opened at its gate with its brief, its outcome landed, the game saved
## and loaded back at every step, and the finished expedition on the
## records as a completion. (Each climb is played for real by the bots in
## test_climbs, test_barranco and test_descent.)


func _brief(path: String) -> bool:
	var level: Node = load(path).instantiate()
	root.add_child(level)
	await physics_frames(3)
	var ok: bool = level.panel != null and level.panel.open
	level.queue_free()
	await physics_frames(1)
	return ok


func test_the_whole_campaign_from_the_gate_to_the_walk_out() -> void:
	for seed in [7, 8, 9]:
		await _campaign(seed)


func _campaign(seed: int) -> void:
	Expedition.navigate = false
	SaveGame.erase()
	Records.delete_all()
	Expedition.new_expedition(seed)
	print("      seed %d" % seed)
	var played: Array = []
	for n in 80:
		if not Expedition.active():
			break
		var card := Expedition.card()
		var pick := 0
		for i in card["choices"].size():
			var ch: Dictionary = card["choices"][i]
			# An emergency on the trek: the sick one goes down with the
			# porters and the rest carry on (so the summit and the way down
			# are still played).
			if TestSessions.CAREFUL.has(ch["label"]) or ch["label"] == "Turn down while you still can" or ch.get("act", "") == "evacuate":
				pick = i
				break
		if Expedition.descent_launches(pick):
			Expedition.choose(pick)
			eq(Expedition.climb.get("challengeId"), "descent", "turning down on the summit opens the way down")
			check(await _brief(Expedition.DESCENT), "the descent level opens with its brief")
			var o := {"attemptId": Expedition.climb["attemptId"], "result": "complete", "slips": 0, "staminaLeft": 60, "assisted": true, "regrouped": false}
			eq(Expedition.finish_descent(o), "applied", "the way down lands")
			played.append("descent")
		else:
			Expedition.choose(pick)
			var p: Variant = Expedition.pending()
			if p != null:
				var id: String = p["challengeId"]
				check(await _brief(Expedition.LEVELS[id]), "%s opens with its brief" % id)
				eq(Expedition.finish_climb(TestSessions.complete(p)), "applied", "%s lands" % id)
				played.append(id)
		# Saved at every step: what loads back is the same expedition.
		var was: Dictionary = Expedition.state().duplicate(true)
		check(Expedition.load_saved(), "the save loads (card %d)" % n)
		eq(Expedition.state()["history"].size(), was["history"].size(), "with the same history")
		eq(Expedition.state()["elapsedHours"], was["elapsedHours"], "and the same clock")
	eq(played, ["lava-tower", "barranco-wall", "summit-night", "descent"], "every played climb, in order")
	var s := Expedition.state()
	eq(s["status"], "complete", "home at the gate")
	check(s["summitReached"] and s["returnedSafely"], "summit and back down")
	var runs: Array = Records.data["expedition"]["runs"]
	check(runs.size() == 1 and runs[0]["complete"], "on the records once, as a completion")
	check(int(runs[0]["teamHome"]) >= 3, "with the team home")
	eq(Records.pending().filter(func(e: Dictionary) -> bool: return e["kind"] == "expedition").size(), 1, "and waiting to be sent for checking")
	print("      %d days, score %d, %d leader points, %d of 4 home" % [runs[0]["days"], runs[0]["score"], runs[0]["points"], runs[0]["teamHome"]])
	SaveGame.erase()
	Records.delete_all()
	Expedition.navigate = true
