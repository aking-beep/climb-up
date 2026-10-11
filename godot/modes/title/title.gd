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
	text("Lead a team of four up Africa's highest mountain. Make the decisions at camp, keep everyone healthy, and play the three hardest climbs yourself.", 8, MUTED)
	button("Crag · rock climbing", func() -> void: Crag.go(Crag.MENU), true)
	text("Six climbs up one cliff, easy to hardest. Tap to clip your rope in, tap to hang on to tiny holds, jump for holds out of reach. Finish one to open the next.", 8, MUTED)


func on_back() -> void:
	get_tree().quit()
