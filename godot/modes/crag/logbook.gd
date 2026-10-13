class_name Logbook
extends RefCounted
## The crag's logbook rules: each route's skill challenge, its mastery
## stars, and the achievements. All of them ask for skill shown on a go
## (how you climbed), never for a count of goes: nothing here can be ground
## out by repeating an easy route.
##
## A go's stats (CragLevel.go_stats()):
##   sent, falls, seconds, style, grip_taps (squeezes on tiny holds), rests
##   (sits on the rope), perfect (perfect dyno catches), dynos, bolts,
##   clipped (bolts clipped), good_clips (clipped from a jug, pocket or
##   ordinary rock: not tiny holds or slopers), min_sloper_grip (lowest
##   grip on slopers, 1 when none), causes ({cause: falls}).
##
## Mastery, per route: one star for the send, two for a clean send
## (redpoint, flash or onsight), three when the route's challenge is done
## as well.

## Each route's challenge, for its skill: [title, how].
const CHALLENGES := {
	"first-climb": ["No falls", "Climb the lesson without falling."],
	"warm-up": ["Good clips", "Send it, clipping every bolt from a good hold (not tiny holds)."],
	"sundown": ["Feather touch", "Send it without your grip on the slopers ever dropping below a third."],
	"the-pinch": ["Economy", "Send it clean without a wasted squeeze: none while the grip is above 70%, none in a flurry."],
	"leap-of-faith": ["Stick it", "Send it clean with a perfect catch on the leap."],
	"lions-roof": ["No sitting", "Send it without resting on the rope once."],
	"thunderhead": ["Lightning", "Send it clean with both catches perfect."],
}

## Achievements: [title, what for]. Checked after every go (and daily go).
const ACHIEVEMENTS := {
	"first-send": ["First send", "Finish First Climb."],
	"onsight": ["Onsight", "Onsight a graded route: first go, no falls, no beta."],
	"redpoint": ["Redpoint", "Send a route clean after trying it before."],
	"perfect-catch": ["Perfect catch", "Catch a dyno right on the contact."],
	"feather": ["Feather touch", "Do Sundown's challenge: slopers with a light, steady touch."],
	"economy": ["Economy", "Do The Pinch's challenge: few, well-timed squeezes."],
	"no-sitting": ["Iron arms", "Do Lion's Roof's challenge: no rests on the rope."],
	"runout": ["Run-out", "Send Thunderhead without a fall."],
	"clean-sweep": ["Clean sweep", "A clean send (redpoint or better) of every graded route."],
	"master": ["Master of Lion Rock", "Three stars on all seven routes."],
	"daily": ["Daily climber", "Send a daily route."],
	"daily-clean": ["Daily onsight", "Send a daily route on your first go without falling."],
}

const CLEAN := ["redpoint", "flash", "onsight"]


## How this go did on the route's challenge, in a few words.
static func challenge_progress(id: String, s: Dictionary) -> String:
	if challenge_done(id, s):
		return "done!"
	var clean: bool = String(s.get("style", "")) in CLEAN
	if not s.get("sent", false):
		return "send it first"
	match id:
		"first-climb":
			return "%d fall%s" % [int(s.get("falls", 0)), "" if int(s.get("falls", 0)) == 1 else "s"]
		"warm-up":
			return "%d of %d bolts clipped from good holds" % [int(s.get("good_clips", 0)), int(s.get("bolts", 0))]
		"sundown":
			return "grip on the slopers dropped to %d%% (keep it above 33%%)" % int(float(s.get("min_sloper_grip", 0.0)) * 100.0)
		"the-pinch":
			return "%d wasted squeeze%s%s" % [int(s.get("wasted", 0)), "" if int(s.get("wasted", 0)) == 1 else "s", "" if clean else ", with falls"]
		"leap-of-faith", "thunderhead":
			return "%d perfect catch%s%s" % [int(s.get("perfect", 0)), "" if int(s.get("perfect", 0)) == 1 else "es", "" if clean else ", with falls"]
		"lions-roof":
			return "%d rest%s on the rope" % [int(s.get("rests", 0)), "" if int(s.get("rests", 0)) == 1 else "s"]
	return ""


## True when this go did the route's challenge.
static func challenge_done(id: String, s: Dictionary) -> bool:
	if not s.get("sent", false):
		return false
	var clean: bool = String(s.get("style", "")) in CLEAN
	match id:
		"first-climb":
			return int(s.get("falls", 1)) == 0
		"warm-up":
			return int(s.get("good_clips", 0)) >= int(s.get("bolts", 99))
		"sundown":
			return float(s.get("min_sloper_grip", 0.0)) >= 1.0 / 3.0
		"the-pinch":
			return clean and int(s.get("wasted", 99)) == 0 and s.has("wasted")
		"leap-of-faith":
			return clean and int(s.get("perfect", 0)) >= 1
		"lions-roof":
			return int(s.get("rests", 1)) == 0
		"thunderhead":
			return clean and int(s.get("perfect", 0)) >= 2
	return false


## Stars for a route's record: 0 to 3.
static func stars(rec: Dictionary) -> int:
	if int(rec.get("sends", 0)) <= 0:
		return 0
	var n := 1
	if String(rec.get("best", "")) in CLEAN:
		n += 1
	if bool(rec.get("challenge", false)):
		n += 1
	return n


## The achievements a go earns, given every route's record after it (and
## those already held). Returns the ids that are new.
static func earned(id: String, s: Dictionary, progress: Dictionary, held: Dictionary, routes: Array) -> Array:
	var out: Array = []
	var give := func(a: String) -> void:
		if not held.has(a) and not out.has(a):
			out.append(a)
	var sent: bool = s.get("sent", false)
	var style := String(s.get("style", ""))
	var daily: bool = s.get("daily", false)
	if int(s.get("perfect", 0)) > 0:
		give.call("perfect-catch")
	if daily:
		if sent:
			give.call("daily")
		if style in ["onsight", "flash"]:
			give.call("daily-clean")
		return out
	if sent and id == "first-climb":
		give.call("first-send")
	if style == "onsight" and id != "first-climb":
		give.call("onsight")
	if style == "redpoint":
		give.call("redpoint")
	if challenge_done(id, s):
		match id:
			"sundown":
				give.call("feather")
			"the-pinch":
				give.call("economy")
			"lions-roof":
				give.call("no-sitting")
	if sent and id == "thunderhead" and int(s.get("falls", 1)) == 0:
		give.call("runout")
	var all_clean := true
	var all_three := true
	for r in routes:
		var rec: Dictionary = progress.get(r["id"], {})
		if not r.get("tutorial", false) and not String(rec.get("best", "")) in CLEAN:
			all_clean = false
		if stars(rec) < 3:
			all_three = false
	if all_clean:
		give.call("clean-sweep")
	if all_three:
		give.call("master")
	return out
