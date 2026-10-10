extends Screen
## The decision before the wall, with what it costs: the card from the
## Expo game, "Climb the wall and camp at Karanga" or "Rest beneath the wall".


func _ready() -> void:
	super._ready()
	var s: ExpeditionState = Expedition.state
	kicker("%s · day %d · %s" % [s.camp, s.day, s.time_of_day()])
	title("The wall is a morning")
	text(s.last_note)
	text("Energy %d → stamina %d · Acclimatization %d · Team %d · Health %d · Weather risk %d" % [s.energy, int(StaminaModel.max_for_energy(s.energy)), s.acclimatization, s.team_condition, s.health, s.weather_risk], 8, MUTED)
	if s.camp != "Barranco Camp":
		text("You are past the wall. The rest of the mountain is not built in this prototype.", 8)
		button("Start a new expedition", func() -> void:
			Expedition.new_expedition(s.seed + 1)
			get_tree().reload_current_scene(), true)
		button("Menu", func() -> void: Expedition.go(Expedition.MENU))
		return
	button("Climb the wall and camp at Karanga  ·  Playable", Expedition.start_climb, true).grab_focus()
	button("Rest beneath the wall  ·  a day, +energy, +team", Expedition.rest_instead)
	button("Menu", func() -> void: Expedition.go(Expedition.MENU))
	text("Game fiction inspired by the place. Not a description of the real route.", 7, MUTED)
