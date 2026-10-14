extends ClimbLevel
## The Lava Tower: climb high, sleep low. The warm-up: daylight, room for a
## mistake, nobody to carry. Loose red scree, a ledge in the plateau wind,
## a chimney to the top, then the walk down toward Barranco. Geometry is
## lava_tower.txt (tools/levels/kili_maps.py). Game fiction.


func _init() -> void:
	spec = {
		"id": "lava-tower",
		"map": "res://modes/expedition/levels/kilimanjaro/lava_tower/lava_tower.txt",
		"hud": "Lava Tower",
		"difficulty": {"recovery": 1.0, "drain": 0.85, "wind": -15.0, "maxSlips": 4, "helpCost": 15.0, "rockPeriod": 6.0},
		# Afternoon sun on black lava rock, then a cold sunset on the tower.
		"climate": {"temps": [[0.0, 27.0], [0.4, 18.0], [0.8, 6.0], [1.0, 2.0]], "drift": -1.5,
			"light": [[0.0, "#fff2dc"], [0.5, "#ffe2c0"], [0.85, "#f0b48c"], [1.0, "#c89aa8"]]},
		"meters": 4600,
		"dangers": ["a scree bridge that gives way if you stop", "stones down the chimney"],
		"gear": [
			["goggles and a buff", "Dropped at the lip, where the wind takes things. Gusts push you less, and sitting on windy ground gives some breath back.", "shell"],
			["a pair of gloves", "Wedged in the chimney's niche, out of the stonefall. Rock costs less with them on.", "gloves"],
			["trekking poles", "Leaning on the top of the last face. Walking costs less with them.", "poles"],
		],
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
