extends ClimbLevel
## The way down, played: Stella Point at sunrise to Barafu. Opened when the
## party turns around at the summit (Expedition.choose), and it is the point
## of the whole game: the summit is behind you and nothing is won until the
## team is down. The rim is open to the wind, the scree is long and loose,
## one rock step is climbed down, an icy bench, a rest halfway. Jun sits on
## the rim with nothing left: short-rope him down beside you (he slows you,
## and his breath runs out if you push) or leave him with Lena. How it goes
## lands on the expedition (Expedition.finish_descent): health, the team,
## and the score for bringing everyone down together.
## Geometry is descent_<route>.txt, one layout per route
## (tools/levels/route_levels.py). Game fiction, not
## mountaineering advice.

const ID := "descent"


func _init() -> void:
	spec = {
		"id": ID,
		"maps": "res://modes/expedition/levels/kilimanjaro/descent/descent",
		"music": "descent",
		"hud": "The descent",
		"difficulty": {"recovery": 0.75, "drain": 1.1, "wind": 34.0, "maxSlips": 3, "helpCost": 18.0, "rockPeriod": 6.0},
		# Frost at the top, then down into the heat of the lower slopes.
		"climate": {"temps": [[0.0, -6.0], [0.5, 8.0], [1.0, 26.0]], "drift": 1.0,
			"light": [[0.0, "#ffe2d0"], [0.4, "#fff6ea"], [1.0, "#fff0d6"]]},
		"meters": 5300,
		"dangers": ["the wind on the rim", "loose scree", "ice above the rock step"],
		"gear": [
			["goggles and a buff", "Left on the rim by someone who no longer needed them. Gusts push you less, and sitting on windy ground gives some breath back.", "shell"],
			["trekking poles", "Stuck in the scree at the top of the first slope. The long slopes down cost less with them.", "poles"],
			["crampons", "On the bench above the ice. On ice they bite: no sliding, and it costs less.", "crampons"],
		],
		"drink": "a bottle of water",
		"theme": {
			"night": false,
			"far": "res://assets/scenery/summit-sea.png",
			"farScale": 0.7,
			"farRepeat": true,
			"mid": "",
			"foreground": "res://assets/scenery/summit-foreground.png",
			"cliff": "res://assets/scenery/summit-wall-deep.png",
			"deep": "res://assets/scenery/summit-wall.png",
			"tint": "#e8e2dc",
			"snow": true,
			"grass": false,
			"sunShafts": true,
		},
		"mate": {"person": "jun", "name": "Jun", "they": "he", "They": "He", "them": "him", "passDir": 1,
			"climbLines": ["Jun: Slower. My legs are shaking.", "Jun: I can see the tents.", "Jun: Thank you for not leaving me up there.", "Jun: Talk to me. It helps."]},
		"people": {
			"l": ["lena", "Lena · Guide", [
				"The summit is only halfway. In this game, like on any mountain, the way down is where tired people get hurt.",
				"Jun gave everything on the way up. Bring him with you, or leave him with me and I'll bring him slowly.",
				"Keep the whole team in sight. Nobody runs the scree alone.",
			]],
			"m": ["marco", "Marco · Climber", [
				"You're down. All of you? Then that's the summit that counts.",
				"Tea's on. Sit. Your legs will tell you about it tomorrow.",
			]],
		},
		"signs": [
			["Stella Point · 5,756 m", "Sunrise. You stood on the top. Now get everyone home: that is the game."],
			["Halfway down", "The air is thicker already. Rest before the ice above the step."],
			["Below the rock step", "Breathe. The last of the scree is ahead, and Barafu below it."],
			["Barafu · 4,670 m", "The tents. The team. The way home starts tomorrow."],
		],
		"copy": {
			"kicker": "Stella Point · sunrise",
			"title": "The way down",
			"brief": "You stood on the summit. Now the expedition is getting down. The rim is open to the wind (don't move in a gust: stop and REST until it passes), the scree slopes are long, there is one rock step to climb down (stand at the edge and push DOWN), and ice above it. Jun is on the rim with nothing left in his legs.",
			"backOff": "",
			"mateTitle": "Jun can't get up",
			"mateBody": "He sits on the rim, shaking. He gave everything on the way up.",
			"decideHelped": "Jun is on the rope beside you.",
			"decideLeft": "Lena stays with Jun.",
			"decideBody": "Barafu is below, past the scree, the ice and the rock step.",
			"doneComplete": "Barafu. Everyone you brought is down.",
			"doneRetreat": "Down, slowly.",
			"doneFail": "The descent took more than you had.",
			"vista": "The sun comes up over the cloud sea. Take it in: then go down.",
		},
	}
	# Each route comes down in its own weather (Places): the long way in
	# sunshine (the spec above), the faster way through cloud, the fastest
	# way in a storm.
	spec["routes"] = {
		"lemosho": {"hud": "The Mweka path"},
		"machame": {
			"hud": "Down through the cloud",
			"difficulty": {"recovery": 0.75, "drain": 1.1, "wind": 36.0, "maxSlips": 3, "helpCost": 18.0, "rockPeriod": 5.5},
			"climate": {"temps": [[0.0, -6.0], [0.5, 2.0], [1.0, 10.0]], "drift": 1.0,
				"light": [[0.0, "#e8e8ec"], [0.5, "#dcdee2"], [1.0, "#e4e2dc"]]},
			"gear": [
				["goggles and a buff", "Out on the rim, past the path. Gusts push you less, and sitting on windy ground gives some breath back.", "shell"],
				["trekking poles", "Up a rock off the first slope. The long slopes down cost less with them.", "poles"],
				["crampons", "On a ledge above the ice, off the line. On ice they bite: no sliding, and it costs less.", "crampons"],
			],
			"drink": "a bottle of water",
			"theme": {
				"far": "",
				"mid": "",
				"foreground": "res://assets/scenery/summit-foreground.png",
				"cliff": "res://assets/scenery/summit-wall-deep.png",
				"deep": "res://assets/scenery/summit-wall.png",
				"ramp": ["#1e1e22", "#3a3a40", "#5e5e64", "#9a9a9e", "#dedcd8"],
				"sky": ["#7a8490", "#b4bac0", "#dadcde"],
				"skylines": [
					{"kind": "clouds", "color": "#c8ccd2", "light": "#eef0f2", "factor": [0.08, 0.12], "y": 250.0, "tall": 80.0, "seed": 2},
					{"kind": "clouds", "color": "#d8dce0", "light": "#f6f8fa", "factor": [0.3, 0.35], "y": 300.0, "tall": 70.0, "near": true, "seed": 8},
				],
				"mist": 2.8,
				"snow": false,
				"grass": false,
				"sunShafts": false,
			},
			"signs": [
				["Stella Point · 5,756 m", "Cloud has come up over the rim. Get everyone down to Barafu: that is the game."],
				["Halfway down", "You can see three cairns at most. Rest before the ice above the step."],
				["Below the rock step", "The cloud is thinning. The last of the scree is ahead."],
				["Barafu · 4,670 m", "Out of the cloud, the tents. The way home starts tomorrow."],
			],
			"copy": {
				"kicker": "Stella Point · cloud",
				"title": "Down through the cloud",
				"brief": "You stood on the summit. Now get down, inside a cloud: the rim is open to the wind (don't move in a gust: REST until it passes), the scree is long, there is a rock step to climb down and ice above it. Jun is on the rim with nothing left in his legs.",
			},
		},
		"umbwe": {
			"hud": "Down in the storm",
			"difficulty": {"recovery": 0.7, "drain": 1.15, "wind": 42.0, "maxSlips": 3, "helpCost": 20.0, "rockPeriod": 4.5},
			"climate": {"temps": [[0.0, -12.0], [0.5, -6.0], [1.0, 2.0]], "drift": 1.0,
				"light": [[0.0, "#c4c8d4"], [0.5, "#b8bcc8"], [1.0, "#ccd0d4"]]},
			"gear": [
				["a storm shell", "Out on the rim in the wind, off the path. Gusts push you less, and sitting on windy ground gives some breath back.", "shell"],
				["trekking poles", "Up a rock off the first slope. The long slopes down cost less with them.", "poles"],
				["crampons", "On a ledge above the ice, off the line. On ice they bite: no sliding, and it costs less.", "crampons"],
			],
			"drink": "snowmelt in a bottle",
			"theme": {
				"far": "",
				"mid": "",
				"foreground": "res://assets/scenery/summit-foreground.png",
				"foregroundTint": "#8890a0",
				"cliff": "res://assets/scenery/summit-wall-deep.png",
				"deep": "res://assets/scenery/summit-wall.png",
				"ramp": ["#14161c", "#282c36", "#444a56", "#747a86", "#c4c8d0"],
				"sky": ["#3e4654", "#6e7684", "#9a9ea6"],
				"skylines": [
					{"kind": "ridge", "color": "#4a5260", "light": "#c8d2de", "factor": [0.05, 0.08], "y": 230.0, "tall": 120.0, "seed": 12},
				],
				"weather": "sleet",
				"mist": 2.0,
				"snow": false,
				"grass": false,
				"sunShafts": false,
			},
			"signs": [
				["Stella Point · 5,756 m", "A storm is coming over the rim. Get everyone down to Barafu, fast and together."],
				["Halfway down", "Sleet on the scree. Rest before the ice above the step."],
				["Below the rock step", "The worst of the wind is above you now."],
				["Barafu · 4,670 m", "The tents, still standing. Everyone in."],
			],
			"copy": {
				"kicker": "Stella Point · storm",
				"title": "Down in the storm",
				"brief": "You stood on the summit, and the weather has turned. Sleet, wind on the rim (don't move in a gust: REST until it passes), long scree, a rock step to climb down and ice above it. Your bar is small on this route: rest at every cairn. Jun is on the rim with nothing left in his legs.",
			},
		},
	}


func mate_panel() -> void:
	var can := stamina.value >= climber.helper_cost
	panel.show_panel("Teammate", spec["copy"]["mateTitle"],
		"%s%s Short-rope him down beside you: it costs you %d stamina now, he walks behind you, his breath runs low if you rush, and he will catch your next slip. Or leave him with Lena, who will bring him down hours behind you." % [
			spec["copy"]["mateBody"], _mate_sick_words(), int(climber.helper_cost)],
		[
			["help", "Short-rope Jun down with you" if can else "Short-rope Jun (need %d stamina: rest first)" % int(climber.helper_cost), not can],
			["leave", "Leave Jun with Lena" if not _no_lena() else "Go down without Jun"],
			["back", "Step back"],
		])


func decide_panel() -> void:
	var line := "Jun walks behind you on the rope." if mate_state == "helped" else "Lena stays with Jun. You go down on your own."
	panel.show_panel("On the rim", spec["copy"]["decideHelped"] if mate_state == "helped" else spec["copy"]["decideLeft"],
		"%s %s Stamina %d%%." % [line, spec["copy"]["decideBody"], int(stamina.fraction() * 100)],
		[["continue", "Start down"], ["regroup", "Sit together for a while first (full stamina)"]])


func pause_menu() -> void:
	climber.lock(true)
	panel.show_panel("Paused", spec["hud"], "There is no turning back on the way down. Rest at the cairns.", [
		["resume", "Resume"],
		["settings", "Settings"],
		["quit", "Save and go to the menu"],
	])


## Lands on the expedition through its own door (not a Coordinator climb).
func land() -> void:
	if _outcome != null and Expedition.trek().get("descent", {}).get("attemptId", "") == attempt_id:
		panel.hide_panel()
		Expedition.finish_descent(_outcome.to_dict())
