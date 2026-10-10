extends Screen
## Title screen: continue, start over, settings.


func _ready() -> void:
	super._ready()
	var has_save := Expedition.load_saved()
	kicker("Kilimanjaro · Godot prototype")
	title("Climb Up", 22)
	text("How high you climb isn't how you win.", 9, MUTED)
	text("Barranco Camp, day five. The wall above the tents is the way to Karanga. Climb it, help who needs helping, and know when to turn around.")
	if has_save:
		var label := "Return to the wall (cairn %d)" % int(Expedition.climb.get("checkpoint", 0)) if not Expedition.climb.is_empty() else "Continue the expedition"
		button(label, _continue, true).grab_focus()
	var fresh := button("New expedition", _new, not has_save)
	if not has_save:
		fresh.grab_focus()
	button("Graphics: %s" % ["Full", "Reduced", "Low power"][Settings.quality], _quality)
	button("Reduced motion: %s" % ("On" if Settings.reduced_motion else "Off"), _motion)
	text("Keys: arrows or WASD · UP on rock climbs · E talk / choose · Shift brace · R rest · Esc pause", 7, MUTED)


func _continue() -> void:
	if not Expedition.climb.is_empty():
		Expedition.start_climb()
	else:
		Expedition.go(Expedition.BRIEFING)


func _new() -> void:
	Expedition.new_expedition(7)
	Expedition.go(Expedition.BRIEFING)


func _quality() -> void:
	Settings.set_quality((Settings.quality + 1) % 3)
	get_tree().reload_current_scene()


func _motion() -> void:
	Settings.set_reduced_motion(not Settings.reduced_motion)
	get_tree().reload_current_scene()
