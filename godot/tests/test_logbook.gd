extends TestCase
## The crag's logbook: ascent styles awarded honestly, mastery stars, each
## route's skill challenge, achievements for skill rather than repetition,
## and a save that survives bad data and older versions.


func _fresh() -> void:
	Crag.navigate = false
	Crag.reset()


## A go: tie in, then finish with these stats.
func _go(id: String, sent: bool, falls: int, seconds: int, stats: Dictionary = {}) -> Dictionary:
	Crag.tie_in(id)
	return Crag.finish(id, sent, falls, seconds, 0, stats)


func test_styles_are_named_honestly() -> void:
	_fresh()
	eq(_go("warm-up", true, 0, 60)["style"], "onsight", "first go, no falls, no beta: onsight")
	eq(_go("sundown", true, 1, 80)["style"], "falls", "a fall on the way: a send with falls, not clean")
	eq(_go("sundown", true, 0, 70)["style"], "redpoint", "clean, after an earlier go: redpoint")
	Crag.take_beta("the-pinch")
	eq(_go("the-pinch", true, 0, 90)["style"], "flash", "first go clean with beta: flash")
	# A go that lowered off still counts as a go: a clean send after it is
	# a redpoint, never an onsight.
	_go("leap-of-faith", false, 2, 40)
	eq(_go("leap-of-faith", true, 0, 95)["style"], "redpoint", "lowered off first, sent clean next: redpoint")
	eq(Crag.record("leap-of-faith")["falls"], 2, "falls are logged across goes")
	# Reading the brief or looking at the route is not a go.
	eq(Crag.record("lions-roof")["attempts"], 0, "untried")
	_fresh()


func test_mastery_stars() -> void:
	_fresh()
	eq(Crag.stars("warm-up"), 0, "no stars before a send")
	var o := _go("warm-up", true, 1, 70, {"bolts": 6, "good_clips": 2})
	eq(o["stars"], 1, "a send with falls: one star")
	o = _go("warm-up", true, 0, 65, {"bolts": 6, "good_clips": 4})
	eq(o["stars"], 2, "a clean send: two")
	check(not o["challenge"], "the challenge wants every clip from a good hold")
	eq(Logbook.challenge_progress("warm-up", {"sent": true, "bolts": 6, "good_clips": 4}), "4 of 6 bolts clipped from good holds", "and says how far off it was")
	o = _go("warm-up", true, 0, 60, {"bolts": 6, "good_clips": 6})
	check(o["challenge"] and o["firstChallenge"], "every clip from a good hold: challenge done")
	eq(o["stars"], 3, "three stars")
	eq(o["fasterBy"], 5, "and five seconds off the best time")
	o = _go("warm-up", true, 2, 90, {"bolts": 6, "good_clips": 0})
	eq(o["stars"], 3, "a worse go later does not take stars away")
	eq(Crag.record("warm-up")["best"], "redpoint", "nor the best style")
	eq(Crag.record("warm-up")["bestSeconds"], 60, "nor the best time")
	_fresh()


func test_each_challenge_asks_for_its_skill() -> void:
	var cases := {
		"first-climb": [{"falls": 0}, {"falls": 1}],
		"warm-up": [{"bolts": 6, "good_clips": 6}, {"bolts": 6, "good_clips": 5}],
		"sundown": [{"min_sloper_grip": 0.5}, {"min_sloper_grip": 0.2}],
		"the-pinch": [{"style": "redpoint", "wasted": 0, "grip_taps": 12}, {"style": "redpoint", "wasted": 2, "grip_taps": 5}],
		"leap-of-faith": [{"style": "onsight", "perfect": 1}, {"style": "falls", "perfect": 1}],
		"lions-roof": [{"rests": 0}, {"rests": 1}],
		"thunderhead": [{"style": "redpoint", "perfect": 2}, {"style": "redpoint", "perfect": 1}],
	}
	for id in cases:
		var yes: Dictionary = cases[id][0].duplicate()
		var no: Dictionary = cases[id][1].duplicate()
		yes["sent"] = true
		no["sent"] = true
		check(Logbook.challenge_done(id, yes), "%s: %s does it" % [id, yes])
		check(not Logbook.challenge_done(id, no), "%s: %s does not" % [id, no])
		yes["sent"] = false
		check(not Logbook.challenge_done(id, yes), "%s: never without the send" % id)
		check(Logbook.CHALLENGES.has(id), "%s has a challenge" % id)


func test_achievements_reward_skill_not_grinding() -> void:
	_fresh()
	# A hundred sends of the easiest route, with falls: no more than the
	# first-send achievement.
	for i in 100:
		_go("first-climb", true, 1, 90)
	eq(Crag.achievements.keys(), ["first-send"], "repeating a route earns nothing more")
	var o := _go("warm-up", true, 0, 60)
	check("onsight" in o["achievements"], "an onsight is one")
	o = _go("leap-of-faith", true, 0, 100, {"perfect": 1})
	check("perfect-catch" in o["achievements"], "a perfect catch is one")
	o = _go("leap-of-faith", true, 0, 100, {"perfect": 1})
	check(not "perfect-catch" in o["achievements"], "and each is earned once")
	for a in Crag.achievements:
		check(Logbook.ACHIEVEMENTS.has(a), "%s is a known achievement" % a)
	_fresh()


func test_the_logbook_saves_and_survives_bad_data() -> void:
	_fresh()
	_go("warm-up", true, 0, 61, {"bolts": 6, "good_clips": 6})
	Crag.load_progress()
	var r := Crag.record("warm-up")
	eq(r["bestSeconds"], 61, "best time kept")
	check(r["challenge"], "challenge kept")
	check(Crag.achievements.has("onsight"), "achievements kept")
	# Bad types and unknown keys: dropped, nothing crashes.
	SaveGame.write({"progress": {"warm-up": {"attempts": "lots", "falls": [], "challenge": "yes", "highRows": 9e9}}, "achievements": {"onsight": 1, "hack": "2026-01-01"}}, Crag.SAVE)
	Crag.load_progress()
	r = Crag.record("warm-up")
	eq(r["attempts"], 0, "a bad count reads as 0")
	eq(r["falls"], 0, "bad falls read as 0")
	eq(r["challenge"], false, "a bad flag reads as not done")
	check(int(r["highRows"]) <= 999, "an absurd high point is clamped")
	check(not Crag.achievements.has("hack"), "unknown achievements are dropped")
	# An older save (no logbook fields) still loads.
	SaveGame.write({"progress": {"warm-up": {"attempts": 3, "sends": 1, "best": "redpoint", "bestFalls": 0, "bestSeconds": 70, "highpoint": 2, "beta": false}}, "shoes": "aggressive"}, Crag.SAVE)
	Crag.load_progress()
	eq(Crag.record("warm-up")["sends"], 1, "an older save loads")
	eq(Crag.stars("warm-up"), 2, "with its stars worked out")
	_fresh()


func test_next_route_is_always_clear() -> void:
	_fresh()
	eq(Crag.next_route(), "first-climb", "a new player is pointed at the lesson")
	_go("first-climb", true, 0, 80)
	eq(Crag.next_route(), "warm-up", "then the next open route")
	check(Crag.unlocked("warm-up") and not Crag.unlocked("sundown"), "one at a time")
	_fresh()
