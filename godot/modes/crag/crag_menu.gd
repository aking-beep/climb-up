extends Screen
## The crag: its routes, easiest first, each with its grade and how you have
## done on it. A locked route opens when the one before it is sent.


func _ready() -> void:
	super._ready()
	kicker("The crag · sport routes")
	title("Lion Rock", 16)
	text("Lead each route from the ground. Clip the bolts as you pass them; a fall drops you onto the last one you clipped. Reach the anchor to send it.", 8, MUTED)
	var first: Button = null
	for r in Crag.ROUTES:
		var rec := Crag.record(r["id"])
		var open: bool = Crag.unlocked(r["id"])
		var status := "locked: send the route before it"
		if open:
			status = "not tried yet"
			if int(rec["sends"]) > 0:
				status = "sent · best: %s" % Crag.STYLES[rec["best"]][0]
			elif int(rec["attempts"]) > 0:
				status = "%d go%s, not sent yet" % [int(rec["attempts"]), "" if int(rec["attempts"]) == 1 else "es"]
		var b := button("%s  %s  · %s" % [r["grade"], r["name"], status], Crag.climb.bind(r["id"]), open and int(rec["sends"]) == 0)
		b.disabled = not open
		if open and first == null and int(rec["sends"]) == 0:
			first = b
	var back := button("Back", func() -> void: Crag.go(Crag.TITLE))
	(first if first else back).grab_focus()
