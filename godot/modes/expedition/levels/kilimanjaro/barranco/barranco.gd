extends ClimbLevel
## The Barranco Wall: Barranco Camp, the approach, the wall, Marco, the
## plateau, and the way on to Karanga. The middle climb: thinner air than
## Shira, a real wall, Marco to help. Geometry is barranco.txt (stamped by
## tools/levels/barranco_map.py).


func _init() -> void:
	spec = {
		"id": "barranco-wall",
		"map": "res://modes/expedition/levels/kilimanjaro/barranco/barranco.txt",
		"hud": "Barranco Wall",
		"difficulty": {"recovery": 0.85, "drain": 1.0, "wind": 5.0, "maxSlips": 3, "helpCost": 15.0, "rockPeriod": 5.0},
		# A sunny morning in the valley; cloud comes up the wall as you climb.
		"climate": {"temps": [[0.0, 14.0], [0.5, 7.0], [1.0, 1.0]], "drift": -1.0,
			"light": [[0.0, "#fff6e6"], [0.6, "#f2f0ea"], [1.0, "#d4d8e0"]]},
		"meters": 4200,
		"dangers": ["stones down the loose gully", "cracked slabs on the exposed ledge"],
		"gear": [
			["an old brass compass", "The needle still swings north. Someone took a bearing here once."],
			["a wooden ice axe", "Hickory and rust. It has been on this wall longer than the cairns."],
			["a faded photograph", "A party on the plateau, squinting into the sun. Nobody you know."],
		],
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
				"On the exposed ledge, when the wind starts talking, stop and brace. Walk between gusts, not through them.",
				"I'll come up last. If anyone stops, they stop for a reason.",
			]],
			"j": ["jun", "Jun · Doctor", [
				"Marco didn't sleep. If he stalls up there, he'll be too proud to ask.",
				"Sit at the cairns. Your arms come back faster sitting than standing.",
				"Breathe out on the hard moves. It's free.",
			]],
		},
		"signs": [
			["Barranco Camp · 3,960 m", "The wall above the tents is the way to Karanga. A morning's work, if nobody hurries."],
			["The wall", "Scramble the boulders, then follow the ledges. UP on rock to climb. Keep pushing UP at the top of a face to pull over onto the ledge."],
			["Exposed", "Wind comes across this ledge from the west. When it rises, stop and BRACE. Walk between gusts."],
			["The shoulder", "Barranco Camp is straight below. The crouch ledge ahead is under an overhang and open to the wind: brace in the gusts."],
			["Top of the Barranco Wall", "Karanga is over the rise. Look back: the tents at Barranco are the size of seeds."],
		],
		"copy": {
			"kicker": "Barranco Camp · morning",
			"title": "The Barranco Wall",
			"brief": "A steep morning scramble. Push up on the rock to climb. Ledges and cairns are where you breathe. On the exposed step, stop when the wind comes. Marco is somewhere above you.",
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
