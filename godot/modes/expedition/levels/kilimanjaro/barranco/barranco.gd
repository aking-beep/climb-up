extends ClimbLevel
## The middle climb: thinner air, a real day's work, and Marco to help.
## Each route climbs its own place here (Places):
##
## - the long way: the Karanga Valley, from the top of the Barranco Wall
##   down into the valley of giant groundsels and the last stream, and up
##   its loose side to Karanga Camp in the morning sun;
## - the faster way: the Barranco Wall itself, the spec below (before
##   "routes"): the scramble, the Kissing Rock traverse, the shoulder;
## - the fastest way: the Arrow Glacier, grey scree and old ice under the
##   Western Breach in a sleet storm, stones coming off the Breach.
##
## Geometry is barranco_<route>.txt (tools/levels/route_levels.py).


func _init() -> void:
	spec = {
		"id": "barranco-wall",
		"maps": "res://modes/expedition/levels/kilimanjaro/barranco/barranco",
		"music": "barranco",
		"hud": "Barranco Wall",
		"difficulty": {"recovery": 0.95, "drain": 0.9, "wind": -5.0, "maxSlips": 3, "helpCost": 15.0, "rockPeriod": 5.0},
		# A sunny morning in the valley; cloud comes up the wall as you climb.
		"climate": {"temps": [[0.0, 14.0], [0.5, 7.0], [1.0, 1.0]], "drift": -1.0,
			"light": [[0.0, "#fff6e6"], [0.6, "#f2f0ea"], [1.0, "#d4d8e0"]]},
		"meters": 4200,
		"dangers": ["stones down the loose gully", "cracked slabs on the exposed ledge"],
		"gear": [
			["a short rope", "On a ledge above the path out of camp: climb for it. Lena can hold your next slip on it.", "rope"],
			["a pair of gloves", "Up a side wall after the first scramble. Rock costs less with them on.", "gloves"],
			["a helmet", "On a ledge below the loose gully. A falling stone costs breath instead of knocking you over.", "helmet"],
			["goggles and a buff", "Out on the exposed ledge before Marco, off the line. Gusts push you less, and sitting on windy ground gives some breath back.", "shell"],
			["trekking poles", "On a rock off the path on the plateau above the wall. The long walk to Karanga costs less with them.", "poles"],
		],
		"drink": "a bottle of water",
		"theme": {
			"far": "res://assets/scenery/barranco-kibo.png",
			"mid": "res://assets/scenery/barranco-valley.png",
			"foreground": "res://assets/scenery/barranco-foreground.png",
		},
		"mate": {"person": "marco", "name": "Marco", "they": "he", "They": "He", "them": "him", "passDir": 1,
			"climbLines": ["Marco: Thanks for coming back for me.", "Marco: Right behind you. Slow is fine.", "Marco: I can see the top from here.", "Marco: Wind's picking up. Wait for it."]},
		"people": {
			"l": ["lena", "Lena · Guide", [
				"The wall looks worse than it is. Hands on rock, feet on rock, and nothing in a hurry.",
				"On the exposed ledge, when the wind starts talking, don't move: stop and REST until it passes. Walk between gusts, not through them.",
				"I'll come up last. If anyone stops, they stop for a reason.",
			]],
			"j": ["jun", "Jun · Doctor", [
				"Marco didn't sleep. If he stalls up there, he'll be too proud to ask.",
				"Sit at the cairns. Standing about gives you nothing back: only sitting down (REST) does.",
				"Breathe out on the hard moves. It's free.",
			]],
		},
		"signs": [
			["Barranco Camp · 3,960 m", "The wall above the tents is the way to Karanga. A morning's work, if nobody hurries."],
			["The wall", "Scramble the boulders, then follow the ledges. UP on rock to climb. Keep pushing UP at the top of a face to pull over onto the ledge."],
			["Exposed", "Wind comes across this ledge from the west. When it rises, don't move: stop and REST until it passes. Walk between gusts."],
			["The shoulder", "Barranco Camp is straight below. The crouch ledge ahead is under an overhang and open to the wind: stop and REST in the gusts, then walk on."],
			["Top of the Barranco Wall", "Karanga is over the rise. Look back: the tents at Barranco are the size of seeds."],
		],
		"copy": {
			"kicker": "Barranco Camp · morning",
			"title": "The Barranco Wall",
			"brief": "A steep morning scramble. Push up on the rock to climb. Press REST on ledges and at cairns: only resting gives your breath back. On the exposed step and the shoulder, don't move when the wind comes: REST until it passes. Marco is somewhere above you.",
			"backOff": "Back off and stay at Barranco",
			"mateTitle": "Marco has stopped on the ledge",
			"mateBody": "His pack is wedged against the rock and he has frozen above the drop.",
			"decideHelped": "Marco is moving again. Now what?",
			"decideLeft": "Lena will bring Marco. Now what?",
			"decideBody": "The loose gully above is the last of the wall.",
			"doneComplete": "Over the top. Karanga is ahead.",
			"doneRetreat": "You turn back for Barranco.",
			"doneFail": "The wall said no today.",
			"vista": "Barranco Camp, far below",
		},
	}
	spec["routes"] = {
		"lemosho": {
			"hud": "Karanga Valley",
			"difficulty": {"recovery": 1.0, "drain": 0.85, "wind": -15.0, "maxSlips": 3, "helpCost": 14.0, "rockPeriod": 7.0},
			"climate": {"temps": [[0.0, 12.0], [0.5, 16.0], [1.0, 10.0]], "drift": 0.0,
				"light": [[0.0, "#fff8ea"], [0.6, "#fffbf2"], [1.0, "#f2ecdc"]]},
			"meters": 4035,
			"dangers": ["the stream at the valley floor", "loose scree on the valley sides"],
			"gear": [
				["a short rope", "On a boulder off the path above the wall's top. Lena can hold your next slip on it.", "rope"],
				["trekking poles", "Up a side ledge on the way down into the valley. The steep slopes cost less with them.", "poles"],
				["a pair of gloves", "Across the stream and up a rock. Rock costs less with them on.", "gloves"],
				["a helmet", "Under the loose slope, off the path. A falling stone costs breath instead of knocking you over.", "helmet"],
				["goggles and a buff", "Out on the windy shoulder, past the path. Gusts push you less, and sitting on windy ground gives some breath back.", "shell"],
			],
			"drink": "water from the Karanga stream",
			"theme": {
				"far": "res://assets/scenery/barranco-kibo.png",
				"mid": "res://assets/scenery/barranco-valley.png",
				"foreground": "res://assets/scenery/barranco-foreground.png",
				"ramp": ["#2a342c", "#425244", "#62745c", "#94a482", "#d2dcbe"],
				"sky": ["#4f88c0", "#b4d4ea", "#eef2e4"],
				"skylines": [
					{"kind": "clouds", "color": "#e8eef2", "light": "#ffffff", "factor": [0.05, 0.1], "y": 290.0, "tall": 60.0, "seed": 4},
				],
				"flora": {"groundsel": 10, "lobelia": 8},
				"mist": 0.8,
				"grass": true,
			},
			"mate": {"person": "marco", "name": "Marco", "they": "he", "They": "He", "them": "him", "passDir": 1,
				"climbLines": ["Marco: Thanks. My legs just stopped.", "Marco: Last water. Fill everything.", "Marco: Groundsels like giants. Look at them.", "Marco: Karanga's just over that."]},
			"people": {
				"l": ["lena", "Lena · Guide", [
					"Karanga means peanut. The valley is the last place with running water until the top.",
					"Down and up again. The way down is where knees go: small steps.",
					"The giant groundsels grow a few centimetres a year. Some here are older than my grandmother.",
				]],
				"j": ["jun", "Jun · Doctor", [
					"Drink at the stream. Up there it will be ice.",
					"Marco is slow this morning. Keep an eye on him.",
					"Sit at the cairns. Standing about gives you nothing back.",
				]],
			},
			"signs": [
				["Top of the Barranco Wall · 4,200 m", "The wall is behind you. The Karanga Valley is ahead: down to the stream, then up the far side."],
				["Into the valley", "Steep and loose going down. Climb down a face: stand at the edge and push DOWN."],
				["The stream", "The last running water. Hop the stream; the far side is loose."],
				["The far side", "Scree and short walls up out of the valley. Things worth having are off the path."],
				["Karanga Camp · 4,035 m", "Tents on the ridge. Barafu and the summit are tomorrow."],
			],
			"copy": {
				"kicker": "Above Barranco · morning",
				"title": "The Karanga Valley",
				"brief": "A sunny morning's walk with a climb at each end: down into the valley of giant groundsels and the last stream, up its loose far side to Karanga Camp. Things hurt less on the long way and your bar is the biggest, but REST before each wall. Gear and artifacts are off the path: climb for them. Marco is somewhere ahead.",
				"backOff": "Back off and stay at Barranco",
				"mateTitle": "Marco has sat down by the stream",
				"mateBody": "His legs have gone and he says he just needs a minute. It has been ten.",
				"decideHelped": "Marco is moving again. Now what?",
				"decideLeft": "Lena will bring Marco. Now what?",
				"decideBody": "The far side of the valley is above, loose and steep.",
				"doneComplete": "Karanga Camp, and tea.",
				"doneRetreat": "You turn back for Barranco.",
				"doneFail": "The valley wore you out.",
				"vista": "The Karanga Valley, and the stream far below",
			},
		},
		"machame": {},
		"umbwe": {
			"hud": "Arrow Glacier",
			"difficulty": {"recovery": 0.85, "drain": 1.0, "wind": 10.0, "maxSlips": 3, "helpCost": 18.0, "rockPeriod": 5.0},
			"climate": {"temps": [[0.0, 4.0], [0.5, -2.0], [1.0, -6.0]], "drift": -1.0,
				"light": [[0.0, "#dfe4ec"], [0.6, "#c8ccd6"], [1.0, "#b4b8c4"]]},
			"meters": 4870,
			"dangers": ["stones off the Breach", "old ice on the scree", "sleet and wind", "cracked slabs"],
			"gear": [
				["a helmet", "Up a rock step off the path at the start. A falling stone costs breath instead of knocking you over.", "helmet"],
				["crampons", "Left on a ledge above the first ice: climb for them. On ice they bite: no sliding, and it costs less.", "crampons"],
				["a pair of gloves", "Out under the stonefall, off the line. Rock and ice cost less with them on.", "gloves"],
				["a storm shell", "On the windy shoulder, past the path. Gusts push you less, and sitting on windy ground gives some breath back.", "shell"],
				["a short rope", "High on a side wall near the glacier. Lena can hold your next slip on it.", "rope"],
			],
			"drink": "snowmelt in a bottle",
			"theme": {
				"far": "",
				"mid": "",
				"foreground": "res://assets/scenery/summit-foreground.png",
				"foregroundTint": "#9098a8",
				"cliff": "res://assets/scenery/summit-wall-deep.png",
				"deep": "res://assets/scenery/summit-wall.png",
				"ramp": ["#16181e", "#2a2e38", "#464c58", "#767c88", "#c2c6ce"],
				"sky": ["#465060", "#7a828e", "#a6aab0"],
				"skylines": [
					{"kind": "breach", "color": "#2a2e38", "light": "#dce6f0", "factor": [0.05, 0.08], "y": 220.0, "tall": 210.0, "seed": 7},
					{"kind": "glacier", "color": "#a8bcd0", "light": "#eef6ff", "factor": [0.18, 0.26], "y": 275.0, "tall": 60.0, "near": true, "seed": 3},
				],
				"flora": {"serac": 5},
				"weather": "sleet",
				"mist": 1.8,
				"grass": false,
				"sunShafts": false,
			},
			"mate": {"person": "marco", "name": "Marco", "they": "he", "They": "He", "them": "him", "passDir": 1,
				"climbLines": ["Marco: I heard it coming. I froze.", "Marco: Stay out from under the Breach.", "Marco: I can't feel my fingers.", "Marco: The glacier's right there."]},
			"people": {
				"l": ["lena", "Lena · Guide", [
					"In 2006 a rockfall came down the Breach onto this path. The route was closed for a year after it.",
					"Listen. When you hear the rattle, look for rock over your head, not at the stones.",
					"Sleet makes the old ice worse. Don't stop on it.",
				]],
				"j": ["jun", "Jun · Doctor", [
					"We came up fast. Headache? Say so.",
					"Marco has been quiet all morning. Watch him on the scree.",
					"Sit at the cairns, out from under the Breach.",
				]],
			},
			"signs": [
				["Barranco Camp · 3,960 m", "Up the scree past the Lava Tower to the Arrow Glacier, under the Western Breach."],
				["The scree", "Loose and steep, with old ice in it. The Breach above sends stones down: move when you hear them."],
				["The shoulder", "Wind and sleet come over here. When it gusts, don't move: stop and REST."],
				["Under the Breach", "Stonefall country. Pick your moment, and don't stop under the gullies."],
				["Arrow Glacier · 4,870 m", "What is left of the glacier. Tonight the Breach; for now, tents behind the boulders."],
			],
			"copy": {
				"kicker": "Barranco Camp · sleet",
				"title": "The Arrow Glacier",
				"brief": "Grey scree and old ice up to the Arrow Glacier, under the Western Breach. Stones come off the Breach often, sleet blows across the shoulder, and your bar is a quarter of the long way's: REST before every face and move between the stones. This is a climbing route: most of it is alpine pitches, tall clefts climbed on a rope with your partner belaying from below, with short ledges between them: tap CLIP at each piton, and a fall stops on the rope instead of sending you back (it still hurts). Stones never fall while you are on a wall: read the grit at the foot, then climb. Tap REST on the rock to hang on the rope. At the anchor on top, tap PULL to bring your partner up. Your bar starts at a quarter and a rest gives back only that much, but every piece of gear and every artifact you find grows it for good. Gear and artifacts are off the line, under the stonefall and up side walls. Marco is somewhere above you.",
				"backOff": "Back off to Barranco",
				"mateTitle": "Marco has frozen on the scree",
				"mateBody": "A stone came past him and he has not moved since. He is under the gully.",
				"decideHelped": "Marco is moving again. Now what?",
				"decideLeft": "Lena will bring Marco. Now what?",
				"decideBody": "The last of the scree is above, right under the Breach.",
				"doneComplete": "The Arrow Glacier. Tents behind the boulders.",
				"doneRetreat": "You turn back for Barranco.",
				"doneFail": "The Breach kept you off today.",
				"vista": "The Western Breach, black above the ice",
			},
		},
	}
