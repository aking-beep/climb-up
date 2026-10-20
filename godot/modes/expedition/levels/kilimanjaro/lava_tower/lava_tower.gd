extends ClimbLevel
## The first played climb: climb high, sleep low. The warm-up: daylight,
## nobody to carry. Each route climbs its own place here (Places):
##
## - the long way: the Shira Cathedral, a buttress of old basalt over the
##   Shira plateau's moorland, giant heather and protea, an afternoon mist;
## - the faster way: the Lava Tower, loose red scree and a chimney of old
##   lava in the plateau wind (the spec below, before "routes");
## - the fastest way: the Umbwe Ridge, a knife of cloud forest between two
##   gorges, roots for holds, mud for ground, rain and falling branches.
##
## Geometry is lava_tower_<route>.txt (tools/levels/route_levels.py).
## Game fiction.


func _init() -> void:
	spec = {
		"id": "lava-tower",
		"maps": "res://modes/expedition/levels/kilimanjaro/lava_tower/lava_tower",
		"music": "lava",
		"hud": "Lava Tower",
		"difficulty": {"recovery": 1.0, "drain": 0.85, "wind": -15.0, "maxSlips": 4, "helpCost": 15.0, "rockPeriod": 6.0},
		# Afternoon sun on black lava rock, then a cold sunset on the tower.
		"climate": {"temps": [[0.0, 27.0], [0.4, 18.0], [0.8, 6.0], [1.0, 2.0]], "drift": -1.5,
			"light": [[0.0, "#fff2dc"], [0.5, "#ffe2c0"], [0.85, "#f0b48c"], [1.0, "#c89aa8"]]},
		"meters": 4600,
		"dangers": ["a scree bridge that gives way if you stop", "stones down the chimney"],
		"gear": [
			["a short rope", "On a ledge above the path out of camp: climb for it. Lena can hold your next slip on it.", "rope"],
			["goggles and a buff", "Out on the wind ledge, off the line. Gusts push you less, and sitting on windy ground gives some breath back.", "shell"],
			["a helmet", "Up a side wall below the chimney. A falling stone costs breath instead of knocking you over.", "helmet"],
			["a pair of gloves", "On a ledge above the first scree. Rock costs less with them on.", "gloves"],
			["trekking poles", "On a rock off the path on top of the tower. Walking costs less with them.", "poles"],
		],
		"drink": "a bottle of water",
		"theme": {
			"far": "res://assets/scenery/barranco-kibo.png",
			"farScale": 0.75,
			"mid": "res://assets/scenery/plateau.png",
			"foreground": "res://assets/scenery/lava-foreground.png",
			"cliff": "res://assets/scenery/lava-wall-deep.png",
			"deep": "res://assets/scenery/lava-wall.png",
			"tint": "#f6ddd0",
			"grass": false,
		},
		"mate": {},
		"people": {
			"l": ["lena", "Lena · Guide", [
				"Climb high, sleep low. We touch the top and sleep at Barranco, lower down.",
				"The red scree moves under you. Short moves, and breathe on the benches.",
				"On the ledge under the overhang the plateau wind comes through. Don't move when it does: sit down and REST until it passes.",
			]],
			"m": ["marco", "Marco · Climber", [
				"I'll carry the water today. Tomorrow is the wall, and I want my arms for it.",
				"Touch the top for me. I'll see it from Barranco.",
			]],
		},
		"signs": [
			["Shira 2 · 3,850 m", "The Lava Tower stands over the plateau. Climb it, then walk down to Barranco to sleep."],
			["The tower foot", "The boulders are a scramble: push UP on them. The scree face above is loose and eats your arms."],
			["The wind ledge", "The plateau wind comes under the overhang here. When it rises, don't move: stop and REST until it passes."],
			["Top of the Lava Tower · 4,600 m", "Higher than you will sleep tonight. The path drops east toward Barranco."],
		],
		"copy": {
			"kicker": "Shira 2 · climb high",
			"title": "The Lava Tower",
			"brief": "Climb high, sleep low. The tower is loose red scree and a chimney of old lava. Scree eats your arms, so press REST on the benches: only resting gives your breath back. The plateau wind crosses the ledge under the overhang: don't move when it comes, REST until it passes. Touch the top, then walk down toward Barranco.",
			"backOff": "Back off and stay at Shira 2",
			"mateTitle": "", "mateBody": "", "decideHelped": "", "decideLeft": "", "decideBody": "",
			"doneComplete": "You touched the top of the tower.",
			"doneRetreat": "Back down to Shira 2.",
			"doneFail": "The scree said no today.",
			"vista": "The plateau, and Shira far below",
		},
	}
	spec["routes"] = {
		"lemosho": {
			"hud": "Shira Cathedral",
			"difficulty": {"recovery": 1.05, "drain": 0.8, "wind": -20.0, "maxSlips": 4, "helpCost": 15.0, "rockPeriod": 7.5},
			# A warm afternoon on the moorland, mist coming up from the forest.
			"climate": {"temps": [[0.0, 20.0], [0.5, 14.0], [1.0, 8.0]], "drift": -1.0,
				"light": [[0.0, "#fff4dc"], [0.6, "#ffe8c4"], [1.0, "#f4d0a8"]]},
			"meters": 3870,
			"dangers": ["loose basalt blocks on the buttress", "the plateau wind on the rim"],
			"gear": [
				["trekking poles", "Up on a heather ledge off the path out of camp. Walking costs less with them.", "poles"],
				["a pair of gloves", "On a shelf above the first boulders: climb up for them. Rock costs less with them on.", "gloves"],
				["goggles and a buff", "On the rim, out past the path in the wind. Gusts push you less, and sitting on windy ground gives some breath back.", "shell"],
				["a short rope", "Up a side face of the buttress. Lena can hold your next slip on it.", "rope"],
				["a helmet", "Under the loose gully, off to one side. A falling stone costs breath instead of knocking you over.", "helmet"],
			],
			"drink": "a flask of sweet tea",
			"theme": {
				"far": "res://assets/scenery/barranco-kibo.png",
				"farScale": 0.75,
				"mid": "res://assets/scenery/plateau.png",
				"foreground": "res://assets/scenery/barranco-foreground.png",
				"cliff": "res://assets/scenery/barranco-wall-deep.png",
				"deep": "res://assets/scenery/barranco-wall.png",
				"ramp": ["#3c3628", "#5c543a", "#827a52", "#aca274", "#e0d8b0"],
				"sky": ["#6f9cc4", "#cfe0e6", "#f6e8c8"],
				"skylines": [
					{"kind": "hills", "color": "#8a9a7c", "light": "#b8c49a", "factor": [0.12, 0.2], "y": 250.0, "tall": 70.0, "near": true, "seed": 3},
				],
				"flora": {"heather": 12, "protea": 6},
				"mist": 1.5,
				"grass": true,
			},
			"people": {
				"l": ["lena", "Lena · Guide", [
					"The Cathedral is the old wall of the Shira volcano. It fell in long before Kibo was finished.",
					"The basalt here is blocky. Test a hold before you trust it.",
					"On the rim the plateau wind comes through. Don't move when it does: sit down and REST until it passes.",
				]],
				"m": ["marco", "Marco · Climber", [
					"Heather higher than me. I didn't know heather did that.",
					"Touch the top for me. I'll watch from camp.",
				]],
			},
			"signs": [
				["Shira 2 · 3,850 m", "The Shira Cathedral stands over the moorland. Climb it for the air, then come down to sleep."],
				["The buttress foot", "Boulders, then blocky basalt. Push UP to climb. Things worth having lie off the path: look up."],
				["The rim", "The plateau wind comes over the rim here. When it rises, don't move: stop and REST until it passes."],
				["Top of the Cathedral · 3,870 m", "The whole Shira plateau below, and Kibo across it. The path drops back to camp."],
			],
			"copy": {
				"kicker": "Shira 2 · afternoon",
				"title": "The Shira Cathedral",
				"brief": "Climb high, sleep low. The Cathedral is a buttress of old basalt above the Shira moorland: boulders, blocky faces, a windy rim. Press REST on the ledges: only resting gives your breath back. Your gear and the artifacts are off the path, up side walls and out on ledges: you have to climb for them.",
				"backOff": "Back off and stay at Shira 2",
				"doneComplete": "You stood on the Cathedral.",
				"doneRetreat": "Back down to Shira 2.",
				"doneFail": "The Cathedral said no today.",
				"vista": "The Shira plateau, gold in the afternoon",
			},
		},
		"machame": {},
		"umbwe": {
			"hud": "Umbwe Ridge",
			"music": "lava",
			"difficulty": {"recovery": 0.95, "drain": 0.95, "wind": -25.0, "maxSlips": 4, "helpCost": 15.0, "rockPeriod": 6.0},
			# Wet forest: warm and dripping low, cold cloud on the ridge.
			"climate": {"temps": [[0.0, 16.0], [0.5, 11.0], [1.0, 5.0]], "drift": -1.0,
				"light": [[0.0, "#e0ecd8"], [0.5, "#d4dccc"], [1.0, "#c4c8c0"]]},
			"meters": 3850,
			"dangers": ["mud that slides you off", "dead branches coming down", "siafu ants on the roots", "nettles"],
			"gear": [
				["a pair of gloves", "Up a root wall off the path. Roots and rock cost less with them on.", "gloves"],
				["a helmet", "In the fork of a tree, above the path: climb for it. A falling branch costs breath instead of knocking you over.", "helmet"],
				["trekking poles", "Out past the mud, off the line. Walking costs less with them.", "poles"],
				["a short rope", "On a ledge above the knife edge. Lena can hold your next slip on it.", "rope"],
				["a rain shell", "High on the ridge, off to the side. The wind and rain push you less, and sitting on windy ground gives some breath back.", "shell"],
			],
			"drink": "rain water in a bottle",
			"theme": {
				"far": "",
				"mid": "",
				"foreground": "res://assets/scenery/barranco-foreground.png",
				"foregroundTint": "#5a7a50",
				"cliff": "res://assets/scenery/barranco-wall-deep.png",
				"deep": "res://assets/scenery/barranco-wall.png",
				"ramp": ["#1c2416", "#2e3a22", "#465432", "#68744a", "#9a9c6c"],
				"sky": ["#5e706a", "#9eaca4", "#c4cabe"],
				"skylines": [
					{"kind": "ridge", "color": "#4e5e58", "light": "#6e7e76", "factor": [0.04, 0.08], "y": 190.0, "tall": 110.0, "seed": 5},
					{"kind": "forest", "color": "#1f3a2a", "light": "#2f5a3c", "factor": [0.1, 0.16], "y": 220.0, "tall": 150.0, "seed": 2},
					{"kind": "forest", "color": "#16281c", "light": "#264a32", "factor": [0.24, 0.3], "y": 270.0, "tall": 190.0, "near": true, "seed": 9},
				],
				"flora": {"tree_0": 7, "tree_1": 7, "roots": 9},
				"weather": "rain",
				"mist": 2.4,
				"grass": true,
				"sunShafts": false,
				"stone": "branch",
			},
			"people": {
				"l": ["lena", "Lena · Guide", [
					"Umbwe is the steepest way onto the mountain. The roots are the holds: they are older than any of us.",
					"Mud is worse than ice. Don't stop on it, and don't run.",
					"When a branch cracks above you, move. Don't look up first.",
				]],
				"m": ["marco", "Marco · Climber", [
					"Everything is wet. Even the inside of my boots is wet.",
					"I'll carry the water. You find us a way up through this.",
				]],
			},
			"signs": [
				["Upper Umbwe · 3,850 m", "Cloud forest on a knife of a ridge. Climb the roots to the heather, then down to sleep."],
				["The root wall", "Roots for holds: push UP on them. Mud on the ledges slides you off. What you need is off the path: climb for it."],
				["The knife edge", "Gorges on both sides and the wind between them. When it gusts, don't move: stop and REST."],
				["The heather line · 3,900 m", "The trees give up here. Above is moor and rock, and the Breach far above that."],
			],
			"copy": {
				"kicker": "Upper Umbwe · rain",
				"title": "The Umbwe Ridge",
				"brief": "The fastest way starts steep. A knife of a ridge through the cloud forest: roots for holds, mud for ground, dead branches coming down and siafu ants on the roots. Your bar is small on this route: REST before every wall. This is a climbing route: most of it is alpine pitches, tall clefts climbed on a rope with your partner belaying from below, with short ledges between them: tap CLIP at each piton, and a fall stops on the rope instead of sending you back (it still hurts). Stones never fall while you are on a wall: read the grit at the foot, then climb. Once clipped, hold still (or tap REST) to hang on the rope and get your breath back. At the anchor on top, tap PULL to bring your partner up. Your bar starts at a quarter and a rest gives back only that much, but every piece of gear and every artifact you find grows it for good. When the rain comes down hard, wet rock costs more and a rest in the open gives less: wait it out under rock. Gear and artifacts are off the line: climb for them.",
				"backOff": "Back off and stay below the ridge",
				"doneComplete": "Out of the trees, onto the heather.",
				"doneRetreat": "Back down to camp.",
				"doneFail": "The forest kept you today.",
				"vista": "The forest canopy, and cloud in the gorges",
			},
		},
	}
