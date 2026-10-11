extends Screen
## The front door: two separate games on the same climbing. Expedition is
## the Kilimanjaro trip (camp decisions and three climbs); Crag is single
## sport routes at one cliff, graded, to send clean.


func _ready() -> void:
	super._ready()
	kicker("Climb Up")
	title("How high you climb isn't how you win.", 13)
	var go := button("Expedition · Kilimanjaro", func() -> void: Expedition.go(Expedition.MENU), true)
	go.grab_focus()
	text("Days on the mountain with Lena, Marco and Jun: a route, a permit, camp calls, and three climbs you play.", 8, MUTED)
	button("Crag · sport routes", func() -> void: Crag.go(Crag.MENU), true)
	text("One cliff, five routes from grade 4 to 6c. Lead them: clip the bolts, read the crimps, rest on jugs, dyno the blank. Send one to open the next.", 8, MUTED)
