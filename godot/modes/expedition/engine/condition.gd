class_name Condition
extends RefCounted
## How the trek reaches into a played climb: the body you climb in is the
## one the camp choices left you.
##
## Everything lands on the one bar, stamina: how big it is and how fast it
## refills. (On the climb, what hits you takes stamina too.)
##
## - Health: a party in poor health starts with a smaller bar.
## - Sleep: a bad night (a night without rest) shrinks the stamina bar and
##   slows getting your breath back; a good one speeds it.
## - Energy: worn out, there is less in your legs.
## - Food: on thin rations (low supplies) you recover slowly.
## - Sickness: altitude sickness brings dizzy spells, a bad stomach (from
##   untreated water or food gone bad) brings cramps, the cold numbs your
##   fingers so holding on to rock costs more.
## - Medicine: a dose before the climb keeps the symptoms off for that climb.
##
## Game fiction. The sickness here is a mechanic, not medical advice.


## What this climb asks of the body, from the session. `dosed`: medicine
## taken for this climb.
static func of(session: Dictionary, dosed: bool = false) -> Dictionary:
	var s: Dictionary = session["state"]
	var t := Trek.ensure(session)
	var you := Trek.sickness(session, "you")
	var kind: String = you.get("kind", "")
	var stage: int = you.get("stage", 0)
	var c := {
		"health": clampf(float(s.get("health", 100)), 0.0, 100.0),
		"stamina": 1.0, "recovery": 1.0, "grip": 1.0, "thinAir": 1.0,
		"dizzy": 0, "cramps": 0, "sick": kind, "stage": stage,
		"medicine": int(t.get("medicine", 0)), "dosed": dosed, "lines": [],
		# What shrank the bar, for the brief: [words, multiplier].
		"factors": [],
		"sleep": String(t.get("sleep", "")), "hungry": int(s.get("supplies", 100)) < 30,
	}
	var lines: Array = c["lines"]
	match String(t.get("sleep", "")):
		"badly":
			c["stamina"] *= 0.88
			c["factors"].append(["a bad night", 0.88])
			c["recovery"] *= 0.8
			lines.append("You slept badly: less stamina, and it comes back slower.")
		"well":
			c["recovery"] *= 1.1
			lines.append("You slept well: stamina comes back a little faster.")
	if int(s.get("energy", 100)) < 35:
		c["stamina"] *= 0.9
		c["factors"].append(["worn out", 0.9])
		lines.append("Tired (energy %d): less stamina." % int(s["energy"]))
	if int(s.get("supplies", 100)) < 30:
		c["recovery"] *= 0.8
		lines.append("Not much food left: you are hungry, so stamina comes back slower.")
	if stage > 0:
		c["stamina"] *= 1.0 - 0.1 * stage
		c["factors"].append([{"ams": "altitude sickness", "stomach": "a bad stomach", "cold": "the cold"}.get(kind, "unwell"), 1.0 - 0.1 * stage])
		match kind:
			"ams":
				c["thinAir"] = 1.0 + 0.25 * stage
				c["dizzy"] = stage
				lines.append("Altitude sickness: breathing is harder, and now and then you feel dizzy and walk unsteadily.")
			"stomach":
				c["cramps"] = stage
				lines.append("Sick stomach: now and then a cramp stops you for a moment.")
			"cold":
				c["grip"] = 1.0 + 0.3 * stage
				lines.append("Cold, numb fingers: holding on to rock tires you faster.")
	# A painkiller at this camp eases altitude sickness's symptoms for the
	# next climb too.
	var eased: bool = kind == "ams" and you.get("eased") == s.get("checkpoint")
	if (dosed or eased) and stage > 0:
		c["dizzy"] = 0
		c["cramps"] = 0
		c["grip"] = 1.0
		lines.append("You took a painkiller: the symptoms stay off for this climb." if kind == "ams" else "You took medicine: the symptoms stay off for this climb.")
	if c["health"] < 80.0:
		# Poor health is a smaller bar: down to 70% of it at none.
		c["stamina"] *= 0.7 + 0.3 * c["health"] / 80.0
		c["factors"].append(["the team's health is low (%d)" % int(c["health"]), 0.7 + 0.3 * c["health"] / 80.0])
		lines.append("The team's health is low (%d): less stamina." % int(c["health"]))
	return c


## Why the bar is the size it is, in one line: what the party's energy
## gives, then each thing that took a share of it.
static func explain(c: Dictionary, energy: float, final: float) -> String:
	var base := int(StaminaModel.max_for_energy(energy))
	if c["factors"].is_empty():
		return "Your stamina today: %d (from the team's energy, %d)." % [int(final), int(energy)]
	var parts: Array = []
	for f in c["factors"]:
		parts.append("%s takes %d%%" % [f[0], int(round((1.0 - f[1]) * 100.0))])
	return "Your stamina today: %d. The team's energy (%d) would give %d, but %s." % [int(final), int(energy), base, ", ".join(parts)]


## A dose is worth taking: unwell, symptoms to keep off, and some left.
static func medicine_helps(session: Dictionary) -> bool:
	var c := of(session)
	return c["medicine"] > 0 and (c["dizzy"] > 0 or c["cramps"] > 0 or c["grip"] > 1.0)


## Seconds between dizzy spells or cramps at `stage`, after the first.
static func spell_period(stage: int, cramps: bool) -> float:
	return (20.0 - 4.0 * stage) if cramps else (16.0 - 3.0 * stage)


## What the camp's choices did to the body for this climb, row by row, for
## the brief: each row is {tone: good/bad/info, icon, title, text}. Built
## from the stamina model the climb actually uses, so the numbers shown are
## the numbers played. `level_recovery`: the climb's own recovery (the
## cold), already inside `st.recovery`.
static func report(c: Dictionary, st: StaminaModel, energy: float, meters: float, acclimatization: float, level_recovery: float) -> Array:
	var rows: Array = []
	# The bar.
	var base := int(StaminaModel.max_for_energy(energy))
	var took: Array = []
	for f in c["factors"]:
		took.append("%s -%d%%" % [f[0], int(round((1.0 - f[1]) * 100.0))])
	var bar := "Team energy %d gives a bar of %d." % [int(energy), base]
	if not took.is_empty():
		bar += " Lost to " + ", ".join(took) + "."
	rows.append({"tone": "good" if took.is_empty() and base >= 85 else ("bad" if not took.is_empty() or base < 70 else "info"),
		"icon": "bolt", "title": "Stamina %d" % int(st.max_value), "text": bar})
	# Breath: the height, and how used to it the party is.
	var need := ExpeditionEngine.acclimatization_need(meters)
	var gap := StaminaModel.gap_factor(meters, acclimatization)
	var walk := int(round((StaminaModel.height_factor(meters) - 1.0) * 100.0))
	var breath := "Walking costs %d%% more breath at %s m" % [maxi(0, walk), ExpeditionEngine.format_meters(meters)] if walk > 0 else "Walking costs normal breath at %s m" % ExpeditionEngine.format_meters(meters)
	if gap > 1.0:
		breath += ". Not used to this height yet (%d of %d): that adds %d%%." % [int(acclimatization), need, int(round((gap - 1.0) * 100.0))]
	else:
		breath += ". You are used to the height (%d, %d needed): no extra cost." % [int(acclimatization), need]
	if c["thinAir"] > 1.0:
		breath += " Altitude sickness adds %d%%." % int(round((c["thinAir"] - 1.0) * 100.0))
	rows.append({"tone": "bad" if gap > 1.0 or c["thinAir"] > 1.0 else "good", "icon": "peak", "title": "Breath", "text": breath})
	# How fast it comes back when you sit.
	var parts: Array = []
	if level_recovery < 1.0:
		parts.append("the cold -%d%%" % int(round((1.0 - level_recovery) * 100.0)))
	var sleep := String(c.get("sleep", ""))
	if sleep == "badly":
		parts.append("slept badly -20%")
	elif sleep == "well":
		parts.append("slept well +10%")
	if c.get("hungry", false):
		parts.append("hungry -20%")
	var rec := int(round(st.recovery * 100.0))
	var back := "Sitting down refills stamina at %d%% speed" % rec
	if not parts.is_empty():
		back += " (" + ", ".join(parts) + ")"
	rows.append({"tone": "good" if rec >= 100 else ("bad" if rec < 75 else "info"), "icon": "heart", "title": "Rest", "text": back + "."})
	# Being ill, and the medicine.
	if int(c["stage"]) > 0:
		var what: String = {"ams": "Altitude sickness: now and then you feel dizzy and walk unsteadily.", "stomach": "A bad stomach: cramps now and then stop you for a moment.", "cold": "Cold: numb fingers: holding on to rock costs %d%% more." % int(round((1.0 + 0.3 * int(c["stage"]) - 1.0) * 100.0))}.get(String(c["sick"]), "Unwell.")
		var off: bool = c["dizzy"] == 0 and c["cramps"] == 0 and c["grip"] <= 1.0
		if off:
			rows.append({"tone": "good", "icon": "crate", "title": "Medicine", "text": "You took something for it: the symptoms stay off for this climb."})
		else:
			if int(c["medicine"]) > 0:
				what += " A dose first keeps that off (%d in the kit)." % int(c["medicine"])
			rows.append({"tone": "bad", "icon": "cloud", "title": "Unwell", "text": what})
	return rows
