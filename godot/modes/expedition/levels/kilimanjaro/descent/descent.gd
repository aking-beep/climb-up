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
## Geometry is descent.txt (tools/levels/kili_maps.py). Game fiction, not
## mountaineering advice.

const ID := "descent"


func _init() -> void:
	spec = {
		"id": ID,
		"map": "res://modes/expedition/levels/kilimanjaro/descent/descent.txt",
		"hud": "The descent",
		"difficulty": {"recovery": 0.75, "drain": 1.1, "wind": 34.0, "maxSlips": 3, "helpCost": 18.0, "rockPeriod": 6.0},
		"meters": 5300,
		"dangers": ["the wind on the rim", "loose scree", "ice above the rock step"],
		"gear": [],
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
			"brief": "You stood on the summit. Now the expedition is getting down. The rim is open to the wind (stop and BRACE in a gust), the scree slopes are long, there is one rock step to climb down (stand at the edge and push DOWN), and ice above it. Jun is on the rim with nothing left in his legs.",
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
