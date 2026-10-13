extends ClimbLevel
## Summit night: the last and hardest climb. Headlamps on at Barafu, frozen
## switchbacks of scree and rock to the crater rim, then Stella Point at
## first light. The cold slows recovery, every move costs more, the rim
## wind comes often, two slips end it, and Jun is heavier to help.
## Geometry is summit_night.txt (tools/levels/kili_maps.py). Game fiction.


func _init() -> void:
	spec = {
		"id": "summit-night",
		"map": "res://modes/expedition/levels/kilimanjaro/summit_night/summit_night.txt",
		"hud": "Summit night",
		"difficulty": {"recovery": 0.65, "drain": 1.15, "wind": 30.0, "maxSlips": 2, "helpCost": 22.0, "rockPeriod": 4.8},
		"meters": 5700,
		"dangers": ["ice on the switchbacks", "a crevasse", "stones on the rock steps", "cracked slabs on the rim"],
		"gear": [
			["a frozen compass", "The glass is frosted over. It still points the way down."],
			["an ice axe", "Left in a pocket of the slope. The pick is sharp."],
			["a photograph of Stella Point", "Taken at dawn. The sky in it is the one coming now."],
		],
		"theme": {
			"night": true,
			"far": "res://assets/scenery/summit-sea.png",
			"farScale": 0.7,
			"farRepeat": true,
			"mid": "",
			"foreground": "res://assets/scenery/summit-foreground.png",
			"cliff": "res://assets/scenery/summit-wall-deep.png",
			"deep": "res://assets/scenery/summit-wall.png",
			"tint": "#c9d2e6",
			"snow": true,
			"grass": false,
			"sunShafts": false,
		},
		"mate": {"person": "jun", "name": "Jun", "they": "he", "They": "He", "them": "him", "passDir": -1,
			"climbLines": ["Jun: My hands are coming back. Thank you.", "Jun: Count the zigzags with me.", "Jun: There's the rim. Keep going.", "Jun: Breathe. Then go."]},
		"people": {
			"l": ["lena", "Lena · Guide", [
				"Pole pole. Nobody overtakes the headlamp in front of them.",
				"Rest at every cairn. The cold takes longer to give your arms back.",
				"If anyone turns around tonight, the whole party turns with them. That's how we do it.",
			]],
			"m": ["marco", "Marco · Climber", [
				"I've got the thermos. Drink when we stop, even if you don't want to.",
				"Jun went ahead to check the switchbacks. Keep an eye out for his lamp.",
			]],
		},
		"signs": [
			["Barafu · 4,670 m", "Midnight. The crater rim is above you, a line of headlamps on the dark."],
			["The switchbacks", "Scree and short rock steps. The cold slows how fast your arms come back: sit at the cairns."],
			["The crater rim", "Open to the wind. When it rises, stop and BRACE. Walk between gusts."],
			["Stella Point · 5,756 m", "First light. Uhuru is along the rim. The way home starts here."],
		],
		"copy": {
			"kicker": "Barafu · midnight",
			"title": "Summit night",
			"brief": "Headlamps on. Frozen switchbacks of scree and rock to the crater rim, then Stella Point at first light. The cold slows how fast your arms come back, so rest at every cairn. The rim is open to the wind. Jun is somewhere on the zigzags.",
			"backOff": "Turn the headlamps around",
			"mateTitle": "Jun has stopped on the switchback",
			"mateBody": "His hands have gone numb and he has dropped a glove on the scree.",
			"decideHelped": "Jun is moving again. Now what?",
			"decideLeft": "Lena is with Jun. Now what?",
			"decideBody": "The crater rim is above, open to the wind. Stella Point is beyond it.",
			"doneComplete": "Stella Point, as the sky goes pale.",
			"doneRetreat": "Back down to Barafu.",
			"doneFail": "The mountain kept the summit tonight.",
			"vista": "The sky goes pale over the cloud sea",
		},
	}
