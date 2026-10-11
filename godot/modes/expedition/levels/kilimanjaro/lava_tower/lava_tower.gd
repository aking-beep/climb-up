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
		"meters": 4600,
		"dangers": ["a scree bridge that gives way if you stop", "stones down the chimney"],
		"gear": [
			["a brass compass", "Dropped at the lip, where the wind takes things."],
			["a wooden ice axe", "Wedged in the chimney's niche, out of the stonefall."],
			["a faded photograph", "The tower from this ledge, years ago. It has not changed."],
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
				"On the ledge under the overhang the plateau wind comes through. Stand still when it does.",
			]],
			"m": ["marco", "Marco · Climber", [
				"I'll carry the water today. Tomorrow is the wall, and I want my arms for it.",
				"Touch the top for me. I'll see it from Barranco.",
			]],
		},
		"signs": [
			["Shira 2 · 3,850 m", "The Lava Tower stands over the plateau. Climb it, then walk down to Barranco to sleep."],
			["The tower foot", "The boulders are a scramble: push UP on them. The scree face above is loose and eats your arms."],
			["The wind ledge", "The plateau wind comes under the overhang here. When it rises, stop and BRACE."],
			["Top of the Lava Tower · 4,600 m", "Higher than you will sleep tonight. The path drops east toward Barranco."],
		],
		"copy": {
			"kicker": "Shira 2 · climb high",
			"title": "The Lava Tower",
			"brief": "Climb high, sleep low. The tower is loose red scree and a chimney of old lava. Scree eats your arms, so breathe on the benches. The plateau wind crosses the ledge under the overhang: stand still when it comes. Touch the top, then walk down toward Barranco.",
			"backOff": "Back off and stay at Shira 2",
			"mateTitle": "", "mateBody": "", "decideHelped": "", "decideLeft": "", "decideBody": "",
			"doneComplete": "You touched the top of the tower.",
			"doneRetreat": "Back down to Shira 2.",
			"doneFail": "The scree said no today.",
			"vista": "The plateau, and Shira far below",
		},
	}
