extends Screen
## The crag: its routes, easiest first, each with its grade and how you have
## done on it. A locked route opens when the one before it is sent.


func _ready() -> void:
	super._ready()
	kicker("The crag · rock climbing")
	title("Lion Rock", 16)
	text("Climb each wall from the ground to the top. Tap CLIP at each bolt as you pass it: if you fall, the last bolt you clipped catches you. The grade is how hard the moves are; the bolting and the exposure say how far apart the bolts are and how far you can fall. Finish a climb to open the next.", 8, MUTED)
	var first: Button = null
	for r in Crag.ROUTES:
		var rec := Crag.record(r["id"])
		var open: bool = Crag.unlocked(r["id"])
		var status := "locked: finish the one before"
		if open:
			status = "not tried yet"
			if int(rec["sends"]) > 0:
				status = "done · best: %s" % Crag.STYLES[rec["best"]][0]
			elif int(rec["attempts"]) > 0:
				status = "%d tr%s, high point bolt %d" % [int(rec["attempts"]), "y" if int(rec["attempts"]) == 1 else "ies", int(rec.get("highpoint", 0))]
		var f := Crag.facts(r["id"])
		var bolting: String = {"well": "well bolted", "sporty": "sporty", "runout": "run-out"}[f["protection"]]
		var moves: String = r["level"] if r.get("tutorial", false) else "%s moves" % r["level"]
		var b := button("%s  %s (%s · %s · %s exposure) · %s" % [r["grade"], r["name"], moves, bolting, f["exposure"], status], Crag.climb.bind(r["id"]), open and int(rec["sends"]) == 0)
		b.disabled = not open
		if open and first == null and int(rec["sends"]) == 0:
			first = b
	var back := button("Back", func() -> void: Crag.go(Crag.TITLE))
	(first if first else back).grab_focus()


func on_back() -> void:
	Crag.go(Crag.TITLE)
