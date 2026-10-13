extends Screen
## The front door: two games on the same climbing. Crag is short routes at
## one cliff, a few minutes each (and a new route every day); Expedition is
## the long Kilimanjaro trip with a team. A new player is pointed at the
## crag's lesson first: it teaches the moves both games use.


func _ready() -> void:
	super._ready()
	Audio.play_music("camp")
	kicker("Climb Up")
	title("How high you climb isn't how you win.", 13)
	var new_player := int(Crag.record("first-climb")["attempts"]) == 0 and not Expedition.has_save()
	var crag := button("Crag · short climbs%s" % (" · new? start here" if new_player else ""), _crag, true)
	text("A few minutes a route, up one cliff. Learn the moves, send each route clean, and try a new route every day.", 8, MUTED)
	var exp := button("Expedition · Kilimanjaro", _expedition, true)
	text("A long journey with a team of four: plan each day at camp, play three big climbs, and get everyone home safely.", 8, MUTED)
	(crag if new_player or not Expedition.has_save() else exp).grab_focus()


func _crag() -> void:
	Analytics.event("mode_selected", {"mode": "crag"})
	Crag.go(Crag.MENU)


func _expedition() -> void:
	Analytics.event("mode_selected", {"mode": "expedition"})
	Expedition.go(Expedition.MENU)


func on_back() -> void:
	get_tree().quit()
