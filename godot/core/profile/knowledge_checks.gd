class_name KnowledgeChecks
extends RefCounted
## Knowledge checks (CLIMB UP 2.0): short questions about knots, belaying,
## anchors and reading a route or the mountain, shown at the crag's school
## and at camp. A right answer counts toward gear (Unlocks "knowledge").
## Nothing in a climb depends on them.
##
## The answers follow standard climbing practice, kept short. Where a real
## answer depends on the situation, the card says it is simplified. Every
## card shows DISCLAIMER: this is a game, not instruction.

const DISCLAIMER := "A game, not a lesson. Learn knots, belaying and anchors from a qualified instructor, in person, before you rely on them."

const TOPICS := {"knots": "Knots", "belay": "Belaying", "anchors": "Anchors and clipping", "route": "Reading the route"}

## {id, topic, q, options (3), answer (index), why, simplified (bool)}
const CARDS := [
	{"id": "knot-tie-in", "topic": "knots", "q": "Which knot ties the rope into your harness for a roped climb?",
		"options": ["A slip knot", "A figure-eight follow-through", "A granny knot"], "answer": 1,
		"why": "The figure-eight follow-through (a figure eight retraced through the harness's tie-in points) is the standard tie-in. It is easy to check by eye and leaves a tail.", "simplified": false},
	{"id": "knot-check", "topic": "knots", "q": "Before you leave the ground, who checks your knot and your partner's belay?",
		"options": ["Both of you check each other", "Only the belayer", "Nobody, once you are experienced"], "answer": 0,
		"why": "A partner check before every climb: knot finished and threaded through both tie-in points, harness buckles done, belay device and locking carabiner set up and locked.", "simplified": false},
	{"id": "knot-tail", "topic": "knots", "q": "Your figure eight is tied. What about the end of the rope that sticks out?",
		"options": ["Cut it off flush with the knot", "Leave a tail of a fist's width or more", "Tuck it into your chalk bag"], "answer": 1,
		"why": "A tail of several centimetres (about a fist's width) means the knot cannot work loose. Never cut the rope.", "simplified": true},
	{"id": "belay-brake", "topic": "belay", "q": "While you belay, what must your brake hand never do?",
		"options": ["Move along the rope", "Pull in slack", "Let go of the brake strand"], "answer": 2,
		"why": "The brake hand stays on the brake strand the whole time. Slide it along and take in slack, but never let go.", "simplified": false},
	{"id": "belay-assisted", "topic": "belay", "q": "What does an assisted-braking belay device do?",
		"options": ["Helps lock the rope in a fall, with the belayer still holding the brake strand", "Holds the climber with nobody belaying", "Lets the belayer take both hands off"], "answer": 0,
		"why": "Assisted braking helps, it does not replace the belayer. The brake hand stays on the rope.", "simplified": false},
	{"id": "belay-attention", "topic": "belay", "q": "When may the belayer stop belaying?",
		"options": ["When the climber looks steady", "When the climber is safe and both have agreed with clear calls", "As soon as the climber reaches the top"], "answer": 1,
		"why": "Stop only after a clear exchange of calls you have both agreed on, with the climber secured or back on the ground.", "simplified": true},
	{"id": "anchor-redundant", "topic": "anchors", "q": "What makes a top anchor good?",
		"options": ["One big bolt is enough", "Strong, with more than one piece, so no single failure drops you", "It looks solid from the ground"], "answer": 1,
		"why": "A good anchor is strong and redundant: more than one solid piece, connected so one failing does not mean a fall to the ground.", "simplified": true},
	{"id": "anchor-lower", "topic": "anchors", "q": "At the top of a sport route, before you unclip anything at the anchor, what must be true?",
		"options": ["You are secured to the anchor and your belayer knows what you are doing", "You are tired", "The next climber is ready"], "answer": 0,
		"why": "Never be off the rope without being secured, and agree with your belayer what happens before you start. How to clean an anchor is taught in person: methods vary.", "simplified": true},
	{"id": "clip-back", "topic": "anchors", "q": "A quickdraw is back-clipped: the rope runs the wrong way through it. What can happen?",
		"options": ["Nothing: it holds the same", "In a fall the rope can unclip itself", "It makes the rope run more smoothly"], "answer": 1,
		"why": "The rope should run from the rock side out toward you. Back-clipped, a fall can twist the rope across the gate and open it.", "simplified": false},
	{"id": "clip-leg", "topic": "anchors", "q": "You are above a clipped bolt. Where should your leg be?",
		"options": ["Never behind the rope", "Behind the rope, for balance", "It does not matter"], "answer": 0,
		"why": "With a leg behind the rope, a fall can flip you upside down. Keep the rope in front of your leg.", "simplified": false},
	{"id": "route-hollow", "topic": "route", "q": "A block sounds hollow when you knock it. What do you do?",
		"options": ["Pull on it hard to test it", "Use it, but quickly", "Avoid weighting it, and warn anyone below"], "answer": 2,
		"why": "Hollow-sounding rock can come off. Climb around it and tell your belayer and anyone underneath.", "simplified": true},
	{"id": "route-storm", "topic": "route", "q": "Clouds build fast and you hear thunder far off. You are halfway up a long route. What is the sensible call?",
		"options": ["Keep going: it is far away", "Turn around early", "Wait on the ridge to see"], "answer": 1,
		"why": "Lightning and wet rock are serious. Deciding early, while going down is still easy, is part of climbing.", "simplified": true},
	{"id": "route-altitude", "topic": "route", "q": "High on a mountain, a teammate's headache and nausea get worse even at rest. What is the standard first step?",
		"options": ["Go higher to get it over with", "Stop going up, and go down if it does not get better", "Give them coffee and carry on"], "answer": 1,
		"why": "Do not go higher with symptoms that are getting worse, and going down is the most reliable treatment. Real care follows a medic or doctor.", "simplified": true},
	{"id": "route-helmet", "topic": "route", "q": "Why wear a helmet at the crag even while you belay?",
		"options": ["Stones and dropped gear can fall from above", "It keeps you warm", "Only climbers need one"], "answer": 0,
		"why": "Rock and gear fall from above, at the climber and at the belayer. Wear the helmet at the foot of the cliff too.", "simplified": false},
]


static func card(id: String) -> Dictionary:
	for c in CARDS:
		if c["id"] == id:
			return c
	return {}


static func topic_cards(topic: String) -> Array:
	return CARDS.filter(func(c: Dictionary) -> bool: return c["topic"] == topic)


## The first card not yet answered right in `topic` ("" for any topic).
static func next_card(topic: String = "") -> Dictionary:
	for c in CARDS:
		if (topic == "" or c["topic"] == topic) and not Profile.knowledge.get(c["id"], {}).get("right", false):
			return c
	return {}


static func right_in(topic: String) -> int:
	var n := 0
	for c in topic_cards(topic):
		if Profile.knowledge.get(c["id"], {}).get("right", false):
			n += 1
	return n
