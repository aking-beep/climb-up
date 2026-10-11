extends Screen
## Title screen: continue, start over, settings.


func _ready() -> void:
	super._ready()
	var has_save := Expedition.load_saved()
	kicker("Kilimanjaro · Lemosho route, as a game")
	title("Climb Up", 22)
	text("How high you climb isn't how you win.", 9, MUTED)
	text("Ten days on the mountain with Lena, Marco and Jun. Make the calls at camp. Three of them you climb yourself: the Lava Tower, the Barranco Wall, and the summit night.")
	if has_save:
		var s: Dictionary = Expedition.state()
		var label := "Continue · %s, day %d" % [Kili.checkpoint_name(s["checkpoint"]), ExpeditionEngine.day_of(s)]
		if Expedition.pending() != null and int(Expedition.climb.get("checkpoint", 0)) > 0:
			label = "Continue the climb (cairn %d)" % int(Expedition.climb["checkpoint"])
		button(label, _continue, true).grab_focus()
	var fresh := button("New expedition", _new, not has_save)
	if not has_save:
		fresh.grab_focus()
	button("Graphics: %s" % ["Full", "Reduced", "Low power"][Settings.quality], _quality)
	button("Reduced motion: %s" % ("On" if Settings.reduced_motion else "Off"), _motion)
	button("Back", func() -> void: Expedition.go("res://modes/title/title.tscn"))
	text("Keys: arrows or WASD · UP on rock climbs · SPACE jump · E talk / climb · Shift brace · R rest · Esc pause. Phones: left thumb moves, right thumb jumps and acts.", 7, MUTED)


func _continue() -> void:
	if Expedition.pending() != null:
		Expedition.resume_climb()
	else:
		Expedition.go(Expedition.CAMP)


func _new() -> void:
	Expedition.new_expedition(int(Time.get_unix_time_from_system()) % 100000 + 1)
	Expedition.go(Expedition.CAMP)


func _quality() -> void:
	Settings.set_quality((Settings.quality + 1) % 3)
	get_tree().reload_current_scene()


func _motion() -> void:
	Settings.set_reduced_motion(not Settings.reduced_motion)
	get_tree().reload_current_scene()


func on_back() -> void:
	Expedition.go("res://modes/title/title.tscn")
