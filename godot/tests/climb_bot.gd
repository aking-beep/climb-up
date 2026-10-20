class_name ClimbBot
extends TestCase
## A scripted climber for the level tests. It plays through the same input
## actions a player presses (GameInput.scripted) and reads only what a
## player can see: gust warnings, grit trickling over a column, cracked
## slabs. It knows the route; it does not cheat the hazards.

const T := 16.0
## The most moving time, in seconds, between two things to do (an artifact, a
## cairn, a sign count), and between two real challenges (they do not).
const QUIET_MAX := 5.0
const CHALLENGE_MAX := 8.0
const NOT_CHALLENGES := ["artifact", "cairn", "sign", "talk", "water", "mate"]

var level: Node
var c: Climber
var outcome: ChallengeOutcome


func tx() -> float:
	return c.global_position.x / T


func ty() -> float:
	return c.global_position.y / T


func where() -> String:
	return "(%.2f, %.2f) state=%d stamina=%.0f/%.0f slips=%d cp=%d clock=%.1f" % [tx(), ty(), c.state, c.stamina.value, c.stamina.max_value, c.slips, level.checkpoint, c.clock]


var _hopped := false


## While walking: hop boulders and gaps ahead, and a stone rolling this way.
func _hop(held: Dictionary) -> void:
	var dir := 1 if held.get("move_right", false) else (-1 if held.get("move_left", false) else 0)
	var want := false
	if c.state == Climber.State.GROUND and dir != 0:
		want = c.hurdle_ahead(dir) or c.gap_ahead(dir)
		var cr: Creatures = level.get("creatures")
		if cr and cr.danger_ahead(c.global_position.x, c.global_position.y, dir):
			want = true
	if c.state == Climber.State.GROUND or c.state == Climber.State.REST:
		var hz: Hazards = level.get("hazards")
		if hz and hz.roller_near(c.global_position.x, c.global_position.y, 26.0):
			want = true
			# One catching up from behind: stop and hop on the spot so it
			# rolls under, rather than hopping along with it.
			for st in hz.rolling:
				var dx: float = c.global_position.x - st["node"].position.x
				if int(st["dir"]) == dir and signf(dx) == float(dir) and absf(dx) < 40.0:
					held.erase("move_right")
					held.erase("move_left")
	if c.exposed and not c.wind.calm_for(c.clock, 0.7):
		want = false
	if want and not _hopped:
		held["jump"] = true
		if OS.get_environment("HOP_DEBUG") != "":
			var cr2: Creatures = level.get("creatures")
			print("HOPDBG x=", c.global_position, " hurdle=", c.hurdle_ahead(dir), " gap=", c.gap_ahead(dir), " danger=", cr2.danger_ahead(c.global_position.x, c.global_position.y, dir) if cr2 else false)
	_hopped = want and not _hopped


## Holds `keys` until `done` is true, or fails after `seconds` of game time.
## On the way it hops what needs hopping, and goes back for a teammate who
## has run out of breath.
func drive(keys: Array, done: Callable, seconds: float = 40.0, label: String = "") -> bool:
	# A deadline in physics frames, so detours (rests, breathers) count too.
	var deadline := Engine.get_physics_frames() + int(seconds * 60.0)
	while Engine.get_physics_frames() < deadline:
		if done.call():
			GameInput.scripted = {"_": false}
			return true
		if level.get("_ended") and label != "panel":
			break
		if level.get("mate_winded") and label != "breather":
			await breather()
			continue
		# Out of breath on the walk: sit, as a player would.
		var walking: bool = keys.has("move_left") or keys.has("move_right")
		if walking and c.state == Climber.State.GROUND and c.stamina.fraction() < 0.2 and label != "breather" and label != "resting":
			await rest_up(0.9)
			continue
		var held := {"_": false}
		for k in keys:
			held[k] = true
		_hop(held)
		GameInput.scripted = held
		await tree.physics_frame
		if level.panel.open and label != "panel":
			break
	GameInput.scripted = {"_": false}
	var ok: bool = done.call()
	if not ok:
		failures.append("gave up %s at %s" % [label, where()])
	return ok


## Walk back to a winded teammate and sit with them until they can go on.
func breather() -> void:
	var m: Node2D = level.mate
	var dir := "move_left" if m.global_position.x < c.global_position.x else "move_right"
	await drive([dir], func() -> bool: return absf(m.global_position.x - c.global_position.x) < 2.0 * T or not level.mate_winded, 40.0, "breather")
	GameInput.scripted = {"_": false, "rest": true}
	await tree.physics_frame
	await drive([], func() -> bool: return not level.mate_winded, 30.0, "breather")


func rest_up(fraction: float = 0.95) -> void:
	# Sit (REST), and sit again after getting up to dodge something: a
	# player rests until full, since standing gives nothing back.
	var full := func() -> bool: return c.stamina.fraction() >= fraction and (level.get("mate_state") != "helped" or level.get("mate_breath") >= 90.0 or level.get("mate_winded"))
	var deadline := Engine.get_physics_frames() + 90 * 60
	var tap := true
	while Engine.get_physics_frames() < deadline and not full.call() and not level.get("_ended"):
		var held := {"_": false}
		if c.state == Climber.State.GROUND and tap:
			held["rest"] = true
		tap = not tap
		_hop(held)
		GameInput.scripted = held
		await tree.physics_frame
	GameInput.scripted = {"_": false}
	if not full.call() and not level.get("_ended"):
		failures.append("gave up resting at %s state=%d stamina=%d/%d" % [where(), c.state, int(c.stamina.value), int(c.stamina.max_value)])


func _slab_near(dir: int, tiles: int) -> bool:
	var hz: Hazards = level.hazards
	var row := Terrain.cell_of(c.global_position + Vector2(0, 2)).y
	for k in range(0, tiles + 1):
		var col := Terrain.cell_of(c.global_position + Vector2(dir * k * T, 0)).x
		for dx in [-1, 0, 1]:
			if hz.is_slab(Vector2i(col + dx, row)) and k + dx >= 0:
				return true
	return false


func _on_slab() -> bool:
	return _slab_near(1, 0)


## Walk toward `until_x` (either way). On open ground, sit (REST) whenever a gust
## is near; never stop on a cracked slab, and only step onto slabs when the
## wind will stay down long enough to cross them.
func cross(until_x: float) -> bool:
	var dir := "move_right" if until_x > tx() else "move_left"
	var sign := 1 if dir == "move_right" else -1
	var arrived := func() -> bool: return tx() >= until_x if dir == "move_right" else tx() <= until_x
	var sat := 0
	var last_x := tx()
	var stuck := 0
	for i in 60 * 150:
		if arrived.call() or level.panel.open:
			break
		# Walking into a wall (it is to be climbed, not walked): stop.
		if c.state == Climber.State.GROUND and absf(tx() - last_x) < 0.01 and GameInput.scripted.get(dir, false):
			stuck += 1
			if stuck > 90:
				break
		else:
			stuck = 0
		last_x = tx()
		var held := {"_": false}
		var ahead := c.terrain.kinds_in(c.body_rect(c.global_position + Vector2(sign * T, 0)))
		var windy: bool = c.exposed or ahead.has(Terrain.Kind.EXPOSED)
		# Out of breath: sit (twice at most here: where sitting gives
		# nothing back, in the wind, walk on).
		if c.state == Climber.State.GROUND and c.stamina.fraction() < 0.2 and not _on_slab() and sat < 2:
			sat += 1
			await rest_up(0.9)
			continue
		if _on_slab():
			held[dir] = true
		elif _slab_near(sign, 2) and windy and not c.wind.calm_for(c.clock, 3.0):
			held["rest"] = true
		elif windy and not c.wind.calm_for(c.clock, 0.8):
			held["rest"] = true
		else:
			held[dir] = true
		_hop(held)
		GameInput.scripted = held
		await tree.physics_frame
	GameInput.scripted = {"_": false}
	var ok: bool = arrived.call() or level.panel.open
	if not ok:
		failures.append("gave up crossing to %.1f at %s" % [until_x, where()])
	return ok


## A column a stone will not come down within `horizon`, reachable from here
## (rock to hold if climbing, floor if walking): its x, or NAN.
func _safe_x(horizon: float) -> float:
	var hz: Hazards = level.hazards
	var x := c.global_position.x
	for off in [T, -T, 2 * T, -2 * T]:
		# Column centres: an edge of a face can snag on the lip above.
		var x2: float = floorf((x + off) / T) * T + T / 2.0
		if hz.threat_at(x2, horizon):
			continue
		var chest := Vector2(x2, c.global_position.y - Climber.SIZE.y * 0.5)
		if c.is_climbing() and not c.terrain.is_climbable(Terrain.cell_of(chest)):
			continue
		if not c.is_climbing() and c.terrain.is_solid(Terrain.cell_of(chest)):
			continue
		return x2
	return NAN


## Climb up until `done`, watching the grit: when a stone is coming down this
## column, move across to one it is not.
## `lean` (move_left / move_right) is held with UP at the top of a face, to
## pull over onto that side.
func climb_dodging(done: Callable, label: String, seconds: float = 60.0, lean: String = "") -> bool:
	var hz: Hazards = level.hazards
	var slips := c.slips
	var caught := c.caught
	var target := NAN
	for i in int(seconds * 60.0):
		if done.call():
			break
		# Knocked off (a slip, or one the rope held): back at a cairn, the
		# face is not under the hands any more.
		if (c.slips > slips or c.caught > caught) and c.state != Climber.State.SLIP:
			break
		var held := {"_": false}
		var x := c.global_position.x
		if c.state == Climber.State.SLIP:
			pass
		elif not is_nan(target):
			if absf(target - x) < 1.5:
				target = NAN
			else:
				held["move_left" if target < x else "move_right"] = true
		elif hz.threat_at(x, 1.6):
			target = _safe_x(2.4)
			if is_nan(target):
				target = _safe_x(1.4)
			if is_nan(target):
				# Nowhere to step aside: climb on and hope to be out of it.
				held["climb_up"] = true
		else:
			held["climb_up"] = true
			var top := c.is_climbing() and c.terrain.hold_at(c.body_rect(c.global_position + Vector2(0, -6))) == Terrain.Kind.AIR
			if lean != "" and top:
				held[lean] = true
		GameInput.scripted = held
		if OS.get_environment("DODGE_DEBUG") != "" and i % 15 == 0 and "step 5" in label:
			print("DODGE ", where(), " threat=", hz.threat_at(x, 1.6), " target=", target, " held=", held.keys(), " rocks=", hz.rocks.size())
		await tree.physics_frame
		if level.panel.open:
			break
	GameInput.scripted = {"_": false}
	if c.slips > slips:
		failures.append("slipped on %s (%d) at %s" % [label, c.slips - slips, where()])
	elif c.caught > caught and not done.call():
		failures.append("knocked off %s (the rope held) at %s" % [label, where()])
	var ok: bool = done.call()
	if not ok:
		failures.append("gave up %s at %s" % [label, where()])
	return ok


func up_to(floor_row: float, label: String, lean: String = "") -> bool:
	return await climb_dodging(func() -> bool: return c.state == Climber.State.GROUND and ty() <= floor_row + 0.05, label, 60.0, lean)


## The longest stretch of moving with nothing to deal with: [seconds, where
## it ended (tiles), what ended it]. Resting and reading do not count.
func longest_quiet(challenges_only: bool = false) -> Array:
	var worst := [0.0, Vector2.ZERO, ""]
	var last := 0.0
	var log: Array = level.pace_log.duplicate()
	log.append([0, "end", level.travel, c.global_position / T])
	for e in log:
		if challenges_only and e[1] in NOT_CHALLENGES:
			continue
		var gap: float = e[2] - last
		if gap > worst[0]:
			worst = [gap, e[3], e[1]]
		last = e[2]
	return worst


## Checks a finished climb's pacing and prints it.
func check_pacing(label: String) -> void:
	var quiet := longest_quiet()
	var hard := longest_quiet(true)
	print("      %s: %d engaged moments; longest quiet %.1f s (to %s), longest without a challenge %.1f s (to %s)" % [label, level.pace_log.size(), quiet[0], quiet[1], hard[0], hard[1]])
	if OS.get_environment("PACE_DEBUG") == "2":
		for e in level.pace_log:
			print("        ev %.1f %s travel=%.1f at %s" % [e[0], e[1], e[2], e[3]])
	if OS.get_environment("PACE_DEBUG") != "":
		var last := [0.0, Vector2.ZERO]
		for e in level.pace_log:
			if e[1] in NOT_CHALLENGES:
				continue
			if e[2] - last[0] > 4.0:
				print("        gap %.1f s from %s to %s (%s)" % [e[2] - last[0], last[1], e[3], e[1]])
			last = [e[2], e[3]]
	check(quiet[0] <= QUIET_MAX, "%s: something to do every %.0f s of moving, but %.1f s ending at %s" % [label, QUIET_MAX, quiet[0], quiet[1]])
	check(hard[0] <= CHALLENGE_MAX, "%s: a challenge every %.0f s of moving, but %.1f s ending at %s" % [label, CHALLENGE_MAX, hard[0], hard[1]])


## Before climbing into a stone chute at x: wait out of the line until a stone
## has just come down, then go, as a careful player would.
func wait_for_stone_window(x: float) -> void:
	var hz: Hazards = level.hazards
	var near := false
	for chute in hz.chutes:
		if absf(chute["cell"].x * T + T / 2.0 - x) < 3.0 * T:
			near = true
	if not near:
		return
	var seen := false
	for i in 60 * 15:
		var falling := false
		for r in hz.rocks:
			if absf(r["node"].position.x - x) < 3.0 * T:
				falling = true
		if falling:
			seen = true
		elif seen:
			return
		GameInput.scripted = {"_": false}
		await tree.physics_frame


## A teammate's panel locks the climber; if helping costs more than is left,
## step back, rest, and walk back to them (`dir`: the way to them).
func rest_up_locked(dir: String = "move_left") -> void:
	if c.stamina.value >= c.helper_cost + 5:
		return
	level.panel.choose("back")
	await rest_up(0.9)
	# Away more than three tiles and back: meeting them again asks again.
	var away := "move_left" if dir == "move_right" else "move_right"
	var from := tx()
	await drive([away], func() -> bool: return absf(tx() - from) > 3.6, 6.0, "a few steps back")
	await drive([dir], func() -> bool: return level.panel.open, 10.0, "back to " + String(level.mate_name()))


## Climbs a level along its layout's line (tools/levels/route_levels.py
## writes it beside the map): walk, rest, climb a face (out of the stones'
## line, into a niche halfway), cross a band of rock, meet the teammate,
## climb down a step, fetch what lies off the line (and put it on), and on
## to the exit. False when something gave up.
func follow(script: Array) -> bool:
	var before := failures.size()
	var i := 0
	var tries := 0
	var section := 0
	var furthest := 0
	var total := 0
	while i < script.size():
		var step: Array = script[i]
		if outcome != null and step[0] != "finish":
			break
		if step[0] == "walk" and i != section:
			section = i
			# New ground: fresh tries (going back over old ground is not).
			if i > furthest:
				tries = 0
		furthest = maxi(furthest, i)
		var had := failures.size()
		if OS.get_environment("BOT_TRACE") != "":
			print("      step %d %s at %s" % [i, step, where()])
		await _act(step)
		i += 1
		# Knocked back to a cairn (a stone, a gust, a slip the rope held):
		# go back to the start of this stretch and try it again, as a
		# player would. Three times a stretch, eight a climb at most.
		if failures.size() > had and step[0] in ["climb", "traverse", "down", "walk", "fetch", "finish"] and tries < 3 and total < 8 and not level.get("_ended"):
			total += 1
			tries += 1
			retries += 1
			failures.resize(had)
			i = _resume_at(script, section)
	return failures.size() == before


## Times follow() went back to the start of a stretch.
var retries := 0


## Where to pick the line up again after being sent back to a cairn: the
## lines run left to right, so the first walk that is still ahead of the
## climber (a wall behind the cairn is climbed again; one before it is not).
func _resume_at(script: Array, fallback: int) -> int:
	var x := tx()
	for j in script.size():
		var a: Array = script[j]
		var at := NAN
		if a[0] == "walk":
			at = float(a[1])
		elif a[0] in ["climb", "fetch", "pitch"]:
			at = float(a[1]["x"])
		# A wall whose foot you stand at is still ahead if its top is above;
		# a step down is, if its foot is below and its lip is here.
		var wall_above: bool = a[0] in ["climb", "pitch"] and absf(at - x) < 3.0 and float(a[1]["row"]) < ty() - 0.5
		if a[0] == "walk" and j + 1 < script.size():
			var next: Array = script[j + 1] if script[j + 1][0] != "rest" or j + 2 >= script.size() else script[j + 2]
			if next[0] == "down" and float(next[1]["row"]) > ty() + 0.5 and absf(float(a[1]) - x) < 3.0:
				wall_above = true
		if is_nan(at) or (at <= x + 0.3 and not wall_above):
			continue
		# Back to the walk that leads to it (and its rest).
		var k := j
		while k > 0 and script[k][0] != "walk":
			k -= 1
		return k
	return fallback


## An alpine pitch (Alpine): up the cleft, clipping each piton as it comes
## into reach and sitting back on the rope when the next stretch needs more
## than is left; at the anchor, pull the partner up.
func lead_pitch(s: Dictionary) -> void:
	var al: Alpine = level.alpine
	var x := float(s["x"])
	var which: int = al.lead
	var stretch := float(s.get("stretch", 15.0))
	await wait_for_dry(6.0)
	if s.get("chute", false):
		await wait_for_stone_window((x - 1.0) * T)
	await drive(["move_right"], func() -> bool: return c.is_climbing() or tx() >= x - 0.3, 20.0, "to the pitch at %.1f" % x)
	var slips := c.slips
	var hz: Hazards = level.hazards
	for i in 150 * 60:
		if al.lead != which or level.get("_ended"):
			break
		if c.slips > slips:
			# Off the rope altogether: back at a cairn.
			GameInput.scripted = {"_": false}
			failures.append("slipped on the pitch at %.1f at %s" % [x, where()])
			return
		if al.belaying:
			await press("interact")
			continue
		if c.state == Climber.State.SLIP or c.state == Climber.State.LOCKED:
			GameInput.scripted = {"_": false}
			await tree.physics_frame
			continue
		if al.clip_target >= 0:
			await press("interact")
			continue
		if al.resting:
			GameInput.scripted = {"_": false}
			await tree.physics_frame
			continue
		if c.state == Climber.State.CLIMB and al.clipped() > 0 and al.rope_left > 0.5 and c.stamina.value < minf(stretch, c.stamina.max_value * 0.95):
			await press("rest")
			continue
		var held := {"_": false}
		if c.state == Climber.State.GROUND and c.global_position.distance_to(al.current()["base"]) < 3.0 * T and hz.threat_at(c.global_position.x, 1.6):
			# A stone coming down the cleft: step back under the prow and
			# let it pass.
			if tx() > x - 3.0:
				held["move_left"] = true
		else:
			held["climb_up"] = true
			if c.is_climbing() and c.terrain.hold_at(c.body_rect(c.global_position + Vector2(0, -6))) == Terrain.Kind.AIR:
				held["move_right"] = true
			elif c.state == Climber.State.GROUND and ty() <= float(s["row"]) + 0.05:
				held = {"_": false, "move_right": true}
		GameInput.scripted = held
		await tree.physics_frame
	GameInput.scripted = {"_": false}
	if al.lead == which:
		failures.append("never brought the partner up the pitch at %.1f: %s" % [x, where()])


## In the rain (RainSchedule): before a wall, wait at its foot until the
## next `seconds` stay out of a downpour, as a careful player would.
func wait_for_dry(seconds: float) -> void:
	var rain: RainSchedule = level.get("rain")
	if rain == null or rain.dry_for(c.clock, seconds):
		return
	await drive([], func() -> bool: return rain.dry_for(c.clock, seconds), 60.0, "waiting out the downpour")


## One press of a button (an action held for a frame, then let go).
func press(action: String) -> void:
	GameInput.scripted = {"_": false, action: true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await tree.physics_frame


func _act(step: Array) -> void:
	match String(step[0]):
		"walk":
			await cross(float(step[1]))
		"rest":
			# [rest, fraction, need]: sit (to `fraction`) only if what is left
			# is less than the next wall needs, as a player saving rests would.
			if step.size() > 2 and c.stamina.value >= float(step[2]):
				return
			await rest_up(float(step[1]))
		"climb":
			var s: Dictionary = step[1]
			var right: bool = int(s["dir"]) > 0
			var dir := "move_right" if right else "move_left"
			var x := float(s["x"])
			await wait_for_dry(absf(ty() - float(s["row"])) * 0.6 + 2.0)
			if s.get("chute", false):
				await wait_for_stone_window(x * T)
			await drive([dir], func() -> bool: return c.is_climbing() or (tx() >= x - 0.5 if right else tx() <= x), 20.0, "to the face at %.1f" % x)
			var lean := "" if int(s.get("lean", 0)) == 0 else ("move_right" if int(s["lean"]) > 0 else "move_left")
			var n: Variant = s.get("niche")
			if n is Dictionary:
				var nrow := float(n["row"])
				await climb_dodging(func() -> bool: return ty() <= nrow - 0.1, "up to the niche")
				await drive(["move_right"], func() -> bool: return c.state == Climber.State.GROUND and tx() >= float(n["x"]), 10.0, "into the niche")
				await rest_up(0.98)
				await drive(["move_left"], func() -> bool: return tx() <= float(n["back"]), 5.0, "back to the face")
				await drive(["climb_up"], func() -> bool: return c.is_climbing(), 5.0, "regrab")
			await up_to(float(s["row"]), "the face at %.1f to row %d" % [x, int(s["row"])], lean)
		"pitch":
			await lead_pitch(step[1])
		"traverse":
			var s: Dictionary = step[1]
			var dir := "move_right" if int(s["dir"]) > 0 else "move_left"
			var to := float(s["to"])
			await drive(["climb_up"], func() -> bool: return c.is_climbing() and ty() <= float(s["row"]) + 1.7, 10.0, "grab the band")
			await drive([dir, "climb_up"], func() -> bool: return c.state == Climber.State.GROUND and (tx() >= to if int(s["dir"]) > 0 else tx() <= to), 40.0, "along the band")
		"mate":
			var s: Dictionary = step[1]
			if level.get("mate_state") in ["helped", "left"]:
				return  # met already, before being sent back
			var dir := "move_right" if int(s["dir"]) > 0 else "move_left"
			await drive([dir], func() -> bool: return level.panel.open, 60.0, "to " + String(level.mate_name()))
			if not level.panel.open:
				return
			await rest_up_locked(dir)
			level.panel.choose(String(s.get("choice", "help")))
			await drive([], func() -> bool: return level.panel.open, 5.0, "panel")
			level.panel.choose("continue")
			await physics_frames(2)
		"down":
			var s: Dictionary = step[1]
			var dir := "move_right" if int(s["dir"]) > 0 else "move_left"
			await drive(["climb_down", dir], func() -> bool: return c.is_climbing(), 3.0, "onto the step")
			await drive(["climb_down"], func() -> bool: return c.state == Climber.State.GROUND, 25.0, "down the step")
		"fetch":
			# Something off the line: up the side wall to its ledge, along
			# to it, back to the edge and down the wall again.
			var s: Dictionary = step[1]
			var x := float(s["x"])
			await wait_for_dry(absf(float(s["floor"]) - float(s["row"])) * 1.2 + 4.0)
			if s.get("chute", false):
				await wait_for_stone_window(x * T)
			await drive(["move_right"], func() -> bool: return c.is_climbing() or tx() >= x - 0.3, 20.0, "to the side wall at %.1f" % x)
			if not c.is_climbing():
				await drive(["climb_up"], func() -> bool: return c.is_climbing(), 3.0, "onto the side wall")
			if not await up_to(float(s["row"]), "the side wall at %.1f" % x, "move_right"):
				return
			# Breath first, on the ledge's sheltered first step: out on a
			# windy ledge, sitting gives nothing back.
			if c.stamina.value < float(s.get("down", 0.0)) * 1.5:
				await rest_up(0.98)
			await cross(float(s["item"]))
			await cross(float(s["back"]))
			# On the ledge: breath for the way down if it is short.
			if c.stamina.value < float(s.get("down", 0.0)):
				await rest_up(0.98)
			await drive(["climb_down", "move_left"], func() -> bool: return c.is_climbing(), 3.0, "back onto the side wall")
			await drive(["climb_down"], func() -> bool: return c.state == Climber.State.GROUND, 25.0, "down the side wall")
		"use":
			# Put the find on: its button in the pack.
			var slots: Array = level.pack_slots()
			for k in slots.size():
				if String(slots[k]["id"]) == String(step[1]) and not slots[k]["on"]:
					await press("use_%d" % (k + 1))
		"finish":
			# On to the exit the way every walk goes: sitting out the gusts on
			# open ground, keeping moving on slabs.
			var dir := "move_right" if int(step[1]) > 0 else "move_left"
			var had := failures.size()
			await cross(9999.0 if int(step[1]) > 0 else -9999.0)
			if outcome == null:
				# The walk stopped short of the exit (a wall, a knock-back):
				# say so in the step's own words.
				failures.resize(had)
				await drive([dir], func() -> bool: return outcome != null, 20.0, "to the exit")


# --- Finding things on the loaded layout ------------------------------------
# The climbs are laid out per route (tools/levels/route_levels.py), so tests
# find what they need on the map rather than naming cells.

## Somewhere to stand: open, not rock to climb, ground under it.
func standable(cell: Vector2i) -> bool:
	var t: Terrain = level.terrain
	return not t.is_solid(cell) and not t.is_climbable(cell) and not t.is_solid(cell + Vector2i.UP) and t.is_solid(cell + Vector2i.DOWN)


## The first cell (bottom to top, left to right) where `test` holds.
func find_cell(test: Callable) -> Vector2i:
	var t: Terrain = level.terrain
	for y in range(t.height - 2, 0, -1):
		for x in range(1, t.width - 1):
			if test.call(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## A stretch of `n` cells to walk on, nothing in the way, over floor of
## `floor_kind` (Terrain.Kind) : its first standing cell.
func clear_walk(floor_kind: int, n: int) -> Vector2i:
	var t: Terrain = level.terrain
	return find_cell(func(cell: Vector2i) -> bool:
		for k in n:
			var at := cell + Vector2i(k, 0)
			if not standable(at) or t.kind(at + Vector2i.DOWN) != floor_kind or t.kind(at) != Terrain.Kind.AIR:
				return false
			for ch in ["n", "a", "b", "d", "w", "*"]:
				if t.markers.get(ch, []).has(at):
					return false
		return true)


## A two-wide gap in the ground with ground on both sides: the cell to stand
## on before it.
func gap_before() -> Vector2i:
	var t: Terrain = level.terrain
	return find_cell(func(cell: Vector2i) -> bool:
		return standable(cell) and standable(cell + Vector2i(-1, 0)) and standable(cell + Vector2i(-2, 0)) \
			and not t.is_solid(cell + Vector2i(1, 1)) and not t.is_solid(cell + Vector2i(2, 1)) and t.kind(cell + Vector2i(1, 1)) != Terrain.Kind.CRUMBLE \
			and _closed_below(cell + Vector2i(1, 1)) and standable(cell + Vector2i(3, 0)) and standable(cell + Vector2i(4, 0)))


## Rock somewhere under `cell` within eight rows: a pit, not a hole.
func _closed_below(cell: Vector2i) -> bool:
	for k in 8:
		if level.terrain.is_solid(cell + Vector2i(0, k)):
			return true
	return false


## A hole: open from the ground to the bottom of the map. Its first column.
func hole() -> Vector2i:
	var t: Terrain = level.terrain
	return find_cell(func(cell: Vector2i) -> bool:
		if not standable(cell + Vector2i(-1, 0)) or t.is_solid(cell + Vector2i.DOWN):
			return false
		for y in range(cell.y, t.height):
			if t.is_solid(Vector2i(cell.x, y)):
				return false
		return true)


## The cracked slabs of a bridge: the first slab cell (the slab is the floor).
func slab() -> Vector2i:
	return find_cell(func(cell: Vector2i) -> bool:
		return level.terrain.kind(cell) == Terrain.Kind.CRUMBLE and level.terrain.kind(cell + Vector2i(1, 0)) == Terrain.Kind.CRUMBLE \
			and standable(cell + Vector2i(-2, -1)))


## The foot of a face under stonefall: where you stand under the chute.
func chute_foot() -> Vector2i:
	var t: Terrain = level.terrain
	for r in t.markers.get("r", []):
		for y in range(r.y + 1, t.height - 1):
			var cell := Vector2i(r.x, y)
			if t.is_solid(cell + Vector2i.DOWN) and t.is_climbable(cell):
				return cell
			if t.is_solid(cell):
				break
	return Vector2i(-1, -1)


## The last face of the climb (from the layout's line): its foot, x as a
## tile column, and the floor row it tops out on.
func last_face() -> Dictionary:
	var faces: Array = level.layout.get("script", []).filter(func(s: Array) -> bool: return s[0] == "climb")
	var f: Dictionary = faces[-1][1]
	var col := int(floor(float(f["x"])))
	var t: Terrain = level.terrain
	var y := int(f["row"])
	while y < t.height - 1 and not t.is_solid(Vector2i(col, y + 1)):
		y += 1
	return {"col": col, "foot": Vector2i(col, y), "top": int(f["row"]), "left": col - 1}


## Somewhere on an exposed ledge to stand, wind on both sides.
func exposed_cell() -> Vector2i:
	return find_cell(func(cell: Vector2i) -> bool: return level.terrain.kind(cell) == Terrain.Kind.EXPOSED and standable(cell) \
		and level.terrain.kind(cell + Vector2i(1, 0)) == Terrain.Kind.EXPOSED and level.terrain.kind(cell + Vector2i(-1, 0)) == Terrain.Kind.EXPOSED)


## Where this route's layout put each kind of gear: {kind: cell}.
func gear_cells() -> Dictionary:
	var out := {}
	for g in level.gear_words():
		if g.size() > 3:
			out[String(g[2])] = Vector2i(int(g[3][0]), int(g[3][1]))
	return out
