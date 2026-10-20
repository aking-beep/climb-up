extends ClimbLevel
## Summit night: the last and hardest climb. The cold slows recovery, every
## move costs more, the rim wind comes often, and Jun is heavier to help.
## Each route goes to the top its own way (Places):
##
## - the long way: Stella Point, the spec below (before "routes"): frozen
##   zigzags of scree from Barafu under the stars, the rim at first light;
## - the faster way: the Southern Icefields, up beside the Rebmann Glacier
##   before dawn, ice cliffs and seracs, a crevasse, the rim walk to Uhuru
##   in pink light;
## - the fastest way: the Western Breach, a black rock band in the dark with
##   stones coming down its gullies, ice in the chimneys, then the crater
##   floor, the Furtwangler Glacier and Uhuru.
##
## Geometry is summit_night_<route>.txt (tools/levels/route_levels.py).
## Game fiction.


func _init() -> void:
	spec = {
		"id": "summit-night",
		# The top: the Uhuru sign, flags and a sunrise (SummitTop, SummitDawn).
		"summit": true,
		"maps": "res://modes/expedition/levels/kilimanjaro/summit_night/summit_night",
		"music": "summit",
		"hud": "Summit night",
		"difficulty": {"recovery": 0.8, "drain": 1.1, "wind": 30.0, "maxSlips": 2, "helpCost": 22.0, "rockPeriod": 4.8},
		# Midnight cold, colder before dawn, then the sun at Stella Point.
		"climate": {"temps": [[0.0, -7.0], [0.7, -16.0], [1.0, -10.0]], "drift": -1.0,
			"light": [[0.0, "#9aa4d8"], [0.7, "#8e98cc"], [0.9, "#d8a8b8"], [1.0, "#ffd4b8"]]},
		"meters": 5700,
		"dangers": ["ice on the switchbacks", "a crevasse", "stones on the rock steps", "cracked slabs on the rim"],
		"gear": [
			["a headlamp", "On a ledge off the path just out of Barafu: climb for it. You see your footing: the cold and the dark no longer slow your walk.", "headlamp"],
			["crampons", "Left on a ledge above the first ice by a party coming down. On ice they bite: no sliding, and it costs less.", "crampons"],
			["a short rope", "Up a side wall above the zigzags. Lena can hold your next slip on it.", "rope"],
			["goggles and a buff", "Out on the windy rim, off the path. Gusts push you less, and sitting on windy ground gives some breath back.", "shell"],
			["trekking poles", "On a ledge before the last step. The walk along the rim costs less with them.", "poles"],
		],
		"drink": "a thermos of hot tea",
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
			["The crater rim", "Two open saddles take the wind; the rock between them is a lee, with a cairn and a rest stone. In a saddle, when the wind rises, don't move: stop and REST until it passes."],
			["Stella Point · 5,756 m", "First light. Uhuru is along the rim. The way home starts here."],
		],
		"copy": {
			"kicker": "Barafu · midnight",
			"title": "Summit night",
			"brief": "Midnight start, and your headlamp is dim. Frozen switchbacks of scree, ice and rock to the crater rim, then Stella Point at first light. The cold slows how fast your arms come back, so REST at every cairn. The rim is open to the wind: don't move in a gust, REST until it passes. Jun is somewhere on the zigzags.",
			"backOff": "Turn the headlamps around",
			"mateTitle": "Jun has stopped on the switchback",
			"mateBody": "His hands have gone numb and he has dropped a glove on the scree.",
			"decideHelped": "Jun is moving again. Now what?",
			"decideLeft": "Lena is with Jun. Now what?",
			"decideBody": "The crater rim is above, open to the wind. Stella Point is beyond it.",
			"doneComplete": "Uhuru Peak at sunrise: the roof of Africa.",
			"doneRetreat": "Back down to Barafu.",
			"doneFail": "The mountain kept the summit tonight.",
			"vista": "The sun is coming up over the cloud sea",
		},
	}
	spec["routes"] = {
		"lemosho": {"hud": "Stella Point"},
		"machame": {
			"hud": "Southern Icefields",
			"difficulty": {"recovery": 0.8, "drain": 1.1, "wind": 34.0, "maxSlips": 2, "helpCost": 22.0, "rockPeriod": 5.0},
			# Bitter cold before dawn, then a pink sunrise on the ice.
			"climate": {"temps": [[0.0, -10.0], [0.6, -18.0], [1.0, -9.0]], "drift": -1.0,
				"light": [[0.0, "#a8a0d0"], [0.5, "#c0a0c8"], [0.8, "#f0b0b8"], [1.0, "#ffd8c0"]]},
			"meters": 5895,
			"dangers": ["ice runs", "a crevasse", "seracs that drop ice", "the rim wind"],
			"gear": [
				["crampons", "Up an ice step off the path, before the first ice run. On ice they bite: no sliding, and it costs less.", "crampons"],
				["a headlamp", "On a ledge above the zigzags: climb for it. You see your footing: the cold and the dark no longer slow your walk.", "headlamp"],
				["goggles and a buff", "Out on the windy rim, past the path. Gusts push you less, and sitting on windy ground gives some breath back.", "shell"],
				["a short rope", "Across the crevasse and up a side wall. Lena can hold your next slip on it.", "rope"],
				["a helmet", "Under the seracs, off the line. Falling ice costs breath instead of knocking you over.", "helmet"],
			],
			"drink": "a thermos of hot tea",
			"theme": {
				"night": true,
				"far": "res://assets/scenery/summit-sea.png",
				"farScale": 0.7,
				"farRepeat": true,
				"farTint": "#ffc8d0",
				"mid": "",
				"foreground": "res://assets/scenery/summit-foreground.png",
				"foregroundTint": "#b8c8e8",
				"cliff": "res://assets/scenery/summit-wall-deep.png",
				"deep": "res://assets/scenery/summit-wall.png",
				"ramp": ["#222a3e", "#3c4c6c", "#6a86ac", "#a8c4e2", "#eef6ff"],
				"rampAmount": 0.8,
				"sky": ["#14183a", "#5a4878", "#e8a0a0"],
				"skylines": [
					{"kind": "glacier", "color": "#8ca4c8", "light": "#e4eeff", "factor": [0.04, 0.07], "y": 210.0, "tall": 110.0, "seed": 11},
					{"kind": "glacier", "color": "#a8bede", "light": "#f4f8ff", "factor": [0.16, 0.22], "y": 265.0, "tall": 90.0, "near": true, "seed": 5},
				],
				"flora": {"serac": 9},
				"tint": "#d8e0f4",
				"snow": true,
				"grass": false,
				"sunShafts": false,
			},
			"mate": {"person": "jun", "name": "Jun", "they": "he", "They": "He", "them": "him", "passDir": -1,
				"climbLines": ["Jun: The ice is so blue.", "Jun: My hands are back. Go on.", "Jun: Pink light. We're nearly there.", "Jun: Wait for the gust."]},
			"people": {
				"l": ["lena", "Lena · Guide", [
					"The glaciers here are going. Most of the ice my grandfather saw is gone.",
					"Crampons bite on the ice runs. Without them, don't stop and don't hurry.",
					"Seracs drop ice when the sun touches them. Be past them by dawn.",
				]],
				"m": ["marco", "Marco · Climber", [
					"Thermos is full. Drink at every stop.",
					"Jun went ahead with the lamp. Find his light.",
				]],
			},
			"signs": [
				["Barafu · 4,670 m", "Before dawn. Up beside the Rebmann Glacier to the rim, then along the icefields to Uhuru."],
				["The ice runs", "Blue ice on the zigzags. Crampons bite; without them you slide. Things worth having are off the line."],
				["The southern rim", "The icefields on one side, the drop on the other, and the wind across both. In a gust, don't move: REST."],
				["Uhuru Peak · 5,895 m", "Sunrise on the ice. The highest point in Africa."],
			],
			"copy": {
				"kicker": "Barafu · before dawn",
				"title": "The Southern Icefields",
				"brief": "The faster way to the top: up beside the Rebmann Glacier in the dark, blue ice runs and seracs, a crevasse, then the rim walk along the Southern Icefields to Uhuru at sunrise. Your bar is half the long way's: REST at every cairn. Gear and artifacts are off the line. Jun is somewhere on the ice.",
				"backOff": "Turn the headlamps around",
				"mateTitle": "Jun has stopped on the ice",
				"mateBody": "He slid on the ice run and his hands have gone numb holding on.",
				"decideHelped": "Jun is moving again. Now what?",
				"decideLeft": "Lena is with Jun. Now what?",
				"decideBody": "The rim and the icefields are above, open to the wind.",
				"doneComplete": "Uhuru at sunrise, the ice gone pink.",
				"doneRetreat": "Back down to Barafu.",
				"doneFail": "The ice kept the summit tonight.",
				"vista": "The Southern Icefields in the first light",
			},
		},
		"umbwe": {
			"hud": "Western Breach",
			"difficulty": {"recovery": 0.75, "drain": 1.15, "wind": 30.0, "maxSlips": 2, "helpCost": 24.0, "rockPeriod": 4.8},
			"climate": {"temps": [[0.0, -9.0], [0.6, -19.0], [1.0, -12.0]], "drift": -1.0,
				"light": [[0.0, "#8a90c0"], [0.7, "#8088b8"], [0.9, "#c8a0b8"], [1.0, "#ffd0b0"]]},
			"meters": 5895,
			"dangers": ["stones down the Breach's gullies", "ice in the chimneys", "cracked slabs", "the crater wind", "the Furtwangler Glacier's ice walls"],
			"gear": [
				["a helmet", "Up a rock step off the path, below the first gully. A falling stone costs breath instead of knocking you over.", "helmet"],
				["a headlamp", "On a ledge to one side of the rock band: climb for it. You see your footing: the cold and the dark no longer slow your walk.", "headlamp"],
				["crampons", "Wedged in a chimney off the line. On ice they bite: no sliding, and it costs less.", "crampons"],
				["a short rope", "High on a side wall of the Breach. Lena can hold your next slip on it.", "rope"],
				["a pair of gloves", "On the crater floor, out by the ice. Rock and ice cost less with them on.", "gloves"],
			],
			"drink": "a thermos of hot tea",
			"theme": {
				"night": true,
				"far": "res://assets/scenery/summit-sea.png",
				"farScale": 0.7,
				"farRepeat": true,
				"farTint": "#9090b8",
				"mid": "",
				"foreground": "res://assets/scenery/lava-foreground.png",
				"foregroundTint": "#606080",
				"cliff": "res://assets/scenery/lava-wall-deep.png",
				"deep": "res://assets/scenery/lava-wall.png",
				"ramp": ["#1e1a26", "#363040", "#544c60", "#807892", "#cac4d8"],
				"sky": ["#04050e", "#121834", "#3a2848"],
				"skylines": [
					{"kind": "crater", "color": "#262632", "light": "#e8e0c0", "factor": [0.04, 0.06], "y": 200.0, "tall": 90.0, "seed": 6},
					{"kind": "breach", "color": "#12131c", "light": "#b8c8e4", "factor": [0.14, 0.2], "y": 270.0, "tall": 230.0, "near": true, "seed": 8},
				],
				"flora": {"serac": 5, "vent": 4},
				"tint": "#c4c8e0",
				"snow": true,
				"grass": false,
				"sunShafts": false,
			},
			"mate": {"person": "jun", "name": "Jun", "they": "he", "They": "He", "them": "him", "passDir": -1,
				"climbLines": ["Jun: I can't feel my feet.", "Jun: The crater. We're in.", "Jun: Not under the gully. Here.", "Jun: Breathe. Then go."]},
			"people": {
				"l": ["lena", "Lena · Guide", [
					"The Breach is the hardest way to the top. It is quiet only when it is frozen: we go in the dark for that.",
					"Stones come down the gullies. Stand under rock, wait, and move.",
					"In the crater the air is thinnest. Slow is fast up here.",
				]],
				"m": ["marco", "Marco · Climber", [
					"Thermos. Drink. Don't argue.",
					"Jun went up first to look at the band. Find his lamp.",
				]],
			},
			"signs": [
				["Arrow Glacier · 4,870 m", "Midnight under the Western Breach. Up the rock band, into the crater, across to Uhuru."],
				["The rock band", "Steep rock, ice in the chimneys, stones down the gullies. Off the line are the things you need."],
				["The crater rim · 5,700 m", "Inside: the Furtwangler Glacier, the ash pit, and the wind. In a gust, don't move: REST."],
				["Uhuru Peak · 5,895 m", "The top of Africa, from the hardest side."],
			],
			"copy": {
				"kicker": "Arrow Glacier · midnight",
				"title": "The Western Breach",
				"brief": "The fastest way to the top is the hardest: the Western Breach in the dark, a rock band with stones down its gullies and ice in its chimneys, then the crater floor, the Furtwangler Glacier and the final wall to Uhuru. Your bar is a quarter of the long way's and knocks hurt in full: REST at every cairn and move between the stones. The three tall clefts are alpine pitches, climbed on a rope with your partner belaying from below: tap CLIP at each piton, and a fall stops on the rope instead of sending you back (it still hurts). Stones never fall while you are on a wall: read the grit at the foot, then climb. Tap REST on the rock to hang on the rope. At the anchor on top, tap PULL to bring your partner up. Your bar starts at a quarter and a rest gives back only that much, but every piece of gear and every artifact you find grows it for good. Gear and artifacts are off the line. Jun is somewhere on the band.",
				"backOff": "Turn the headlamps around",
				"mateTitle": "Jun has stopped on the band",
				"mateBody": "A stone hit his pack and he is clinging to the rock, shaking.",
				"decideHelped": "Jun is moving again. Now what?",
				"decideLeft": "Lena is with Jun. Now what?",
				"decideBody": "The top of the band is above, and the crater beyond it.",
				"doneComplete": "Uhuru Peak, out of the Breach at sunrise.",
				"doneRetreat": "Back down to the Arrow Glacier.",
				"doneFail": "The Breach kept the summit tonight.",
				"vista": "The crater and the glacier walls at dawn",
			},
		},
	}
