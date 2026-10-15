class_name Plain
extends RefCounted
## Plain words for people who have never been near a mountain. Text from
## the expedition's content and the game's own copy goes through say()
## before it is shown, so a climbing word is either swapped for an everyday
## one or explained the first time it appears in a text. The content files
## keep their own words (they are shared with the Expo game and its tests).

## Whole phrases first, then single words. Matched without case; the first
## letter keeps the case of the original.
const SWAPS := [
	["acclimatization walk", "walk up high to get used to the height"],
	["acclimatization", "getting used to the height"],
	["acclimatisation", "getting used to the height"],
	["acclimatize", "get used to the height"],
	["acclimatise", "get used to the height"],
	["acclimatized", "used to the height"],
	["summit bid", "push for the top"],
	["turn the bid around", "turn back before the top"],
	["the bid", "the push for the top"],
	["summit push", "push for the top"],
	["the high camps", "the camps up high"],
	["high camps", "camps up high"],
	["high camp", "the last camp below the top"],
	["the margin", "the safety buffer"],
	["margin", "safety buffer"],
	["short-rope", "tie onto your rope"],
	["scree", "loose gravel"],
	["AMS", "altitude sickness"],
	["switchbacks", "zigzag paths"],
	["turnaround time", "time to turn back"],
]
## Explained in brackets, once per text, the first time they appear.
const EXPLAIN := {
	"pole pole": "slowly, slowly",
	"porters": "the crew who carry the loads",
	"crater rim": "the edge of the old volcano's top",
	"cairn": "a pile of stones marking the way",
}
## The score's names, in everyday words.
const SCORE := {"Judgment": "Good calls", "Risk management": "Staying safe", "Teamwork": "Teamwork", "Preparation": "Being ready"}

static var _rx: Dictionary = {}


static func _re(pattern: String) -> RegEx:
	if not _rx.has(pattern):
		var r := RegEx.new()
		r.compile(pattern)
		_rx[pattern] = r
	return _rx[pattern]


static func say(text: String) -> String:
	if text == "":
		return text
	var out := text
	for pair in SWAPS:
		out = _swap(out, pair[0], pair[1])
	for word in EXPLAIN:
		var r := _re("(?i)\\b" + word + "\\b")
		var m := r.search(out)
		if m and not out.substr(m.get_end(), 2) == " (":
			out = out.substr(0, m.get_end()) + " (" + EXPLAIN[word] + ")" + out.substr(m.get_end())
	return out


static func _swap(text: String, from: String, to: String) -> String:
	var r := _re(("\\b" if from == "AMS" else "(?i)\\b") + from + "\\b")
	var out := ""
	var at := 0
	for m in r.search_all(text):
		var orig := m.get_string()
		var rep := to
		if orig.substr(0, 1) == orig.substr(0, 1).to_upper() and orig.substr(0, 1) != orig.substr(0, 1).to_lower():
			rep = to.substr(0, 1).to_upper() + to.substr(1)
		out += text.substr(at, m.get_start() - at) + rep
		at = m.get_end()
	return out + text.substr(at)


static func score(name: String) -> String:
	return SCORE.get(name, name)


## A short glossary, for the camp's log tab.
const WORDS := [
	["Getting used to the height", "Up high the air has less oxygen. Bodies adapt slowly, a little each day spent high and slept lower. Going up faster than that makes people ill."],
	["Altitude sickness", "Headache, sickness, dizziness from going up too fast. In this game, resting and going down are what fix it."],
	["The permit", "The park gives you a set number of days. Run out and the rangers walk you down."],
	["Camp", "Where the team sleeps each night. Each decision here is one part of a day."],
	["The summit", "The very top. Reaching it is not the win: bringing everyone home is."],
	["Lena, Marco, Jun", "Your guide, your climbing partner and the team's doctor. How they are doing is the Team bar and their portraits."],
]
