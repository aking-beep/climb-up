extends Screen
## What the last decision did to the expedition, once. Shows the change in
## each stat, the score notes earned, and the outcome in the Expo engine's
## ChallengeOutcome shape.

const STATS := [["health", "Health"], ["energy", "Energy"], ["acclimatization", "Acclimatization"], ["teamCondition", "Team"]]


func _ready() -> void:
	super._ready()
	var s: ExpeditionState = Expedition.state
	var o: ChallengeOutcome = Expedition.last_outcome
	var heading := "A day under the wall"
	if o:
		heading = {"complete": "Over the wall", "retreat": "Back down to Barranco", "fail": "The wall said no today"}[o.result]
	kicker("%s · day %d" % [s.camp, s.day])
	title(heading)
	text(s.last_note)
	if o:
		var bits := ["%d slip%s" % [o.slips, "" if o.slips == 1 else "s"], "stamina %d%%" % o.stamina_left, "%d min on the wall" % int(o.seconds / 60)]
		if o.assisted == true:
			bits.append("you helped Marco")
		elif o.assisted == false:
			bits.append("Lena brought Marco")
		if o.caught > 0:
			bits.append("Marco caught %d slip%s" % [o.caught, "" if o.caught == 1 else "s"])
		if o.regrouped:
			bits.append("the party regrouped")
		text(" · ".join(bits), 8, MUTED)
	var changes: Array[String] = []
	var b: Dictionary = Expedition.before
	for pair in STATS:
		var now: int = int(s.to_dict()[pair[0]])
		var was: int = int(b.get(pair[0], now))
		if now != was:
			changes.append("%s %d → %d" % [pair[1], was, now])
	if not changes.is_empty():
		kicker("At camp")
		text(" · ".join(changes), 8)
	var before_marks: Array = []
	for entry in b.get("ledger", []):
		before_marks.append(entry.get("mark"))
	for entry in s.ledger:
		if not before_marks.has(entry["mark"]):
			text("%s %+d: %s" % [String(entry["bucket"]).capitalize(), int(entry["delta"]), entry["label"]], 8)
	if o:
		text("Expo ChallengeOutcome: " + JSON.stringify(o.to_expo()), 6, MUTED)
	button("Back to the expedition", func() -> void: Expedition.go(Expedition.BRIEFING), true).grab_focus()
	button("Menu", func() -> void: Expedition.go(Expedition.MENU))
