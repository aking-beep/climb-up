class_name Condition
extends RefCounted
## How the trek reaches into a played climb: the body you climb in is the
## one the camp choices left you.
##
## - Health: the expedition's health is where the climb's health bar starts,
##   lower again when you are unwell.
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
		"health": clampf(float(s.get("health", 100)), 25.0, 100.0),
		"stamina": 1.0, "recovery": 1.0, "grip": 1.0, "thinAir": 1.0,
		"dizzy": 0, "cramps": 0, "sick": kind, "stage": stage,
		"medicine": int(t.get("medicine", 0)), "dosed": dosed, "lines": [],
	}
	var lines: Array = c["lines"]
	match String(t.get("sleep", "")):
		"badly":
			c["stamina"] *= 0.88
			c["recovery"] *= 0.8
			lines.append("You slept badly: a smaller stamina bar, and slower to get your breath back.")
		"well":
			c["recovery"] *= 1.1
			lines.append("You slept well: you get your breath back a little faster.")
	if int(s.get("energy", 100)) < 35:
		c["stamina"] *= 0.9
		lines.append("Worn out (energy %d): less in your legs." % int(s["energy"]))
	if int(s.get("supplies", 100)) < 30:
		c["recovery"] *= 0.8
		lines.append("Thin rations: you are hungry, and slow to recover.")
	if stage > 0:
		c["health"] = maxf(25.0, c["health"] - 8.0 * stage)
		c["stamina"] *= 1.0 - 0.1 * stage
		match kind:
			"ams":
				c["thinAir"] = 1.0 + 0.25 * stage
				c["dizzy"] = stage
				lines.append("Altitude sickness: the air is thinner for you, and dizzy spells slow you and make your feet wander.")
			"stomach":
				c["cramps"] = stage
				lines.append("A bad stomach: now and then a cramp doubles you over. You can't walk or hop until it passes.")
			"cold":
				c["grip"] = 1.0 + 0.3 * stage
				lines.append("Numb fingers: holding on to rock costs more.")
	if dosed and stage > 0:
		c["dizzy"] = 0
		c["cramps"] = 0
		c["grip"] = 1.0
		c["health"] = minf(100.0, c["health"] + 10.0)
		lines.append("You took medicine: the symptoms stay off for this climb.")
	if c["health"] < 60.0:
		lines.append("You start this climb hurt: health %d." % int(c["health"]))
	return c


## A dose is worth taking: unwell, symptoms to keep off, and some left.
static func medicine_helps(session: Dictionary) -> bool:
	var c := of(session)
	return c["medicine"] > 0 and (c["dizzy"] > 0 or c["cramps"] > 0 or c["grip"] > 1.0)


## Seconds between dizzy spells or cramps at `stage`, after the first.
static func spell_period(stage: int, cramps: bool) -> float:
	return (20.0 - 4.0 * stage) if cramps else (16.0 - 3.0 * stage)
