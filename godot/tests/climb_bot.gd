class_name ClimbBot
extends TestCase
## A scripted climber for the level tests. It plays through the same input
## actions a player presses (GameInput.scripted) and reads only what a
## player can see: gust warnings, grit trickling over a column, cracked
## slabs. It knows the route; it does not cheat the hazards.

const T := 16.0
## The most moving time, in seconds, between two things to do (a flower, a
## cairn, a sign count), and between two real challenges (they do not).
const QUIET_MAX := 6.0
const CHALLENGE_MAX := 12.0
const NOT_CHALLENGES := ["flower", "cairn", "sign", "talk", "water"]

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
	if c.state == Climber.State.GROUND:
		var hz: Hazards = level.get("hazards")
		if hz and hz.roller_near(c.global_position.x, c.global_position.y, 26.0):
			want = true
	if c.exposed and not c.wind.calm_for(c.clock, 0.7):
		want = false
	if want and not _hopped:
		held["jump"] = true
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
	GameInput.scripted = {"_": false, "rest": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await drive([], func() -> bool: return c.stamina.fraction() >= fraction and (level.get("mate_state") != "helped" or level.get("mate_breath") >= 90.0 or level.get("mate_winded")), 90.0, "resting")


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


## Walk toward `until_x` (either way). On open ground, brace whenever a gust
## is near; never stop on a cracked slab, and only step onto slabs when the
## wind will stay down long enough to cross them.
func cross(until_x: float) -> bool:
	var dir := "move_right" if until_x > tx() else "move_left"
	var sign := 1 if dir == "move_right" else -1
	var arrived := func() -> bool: return tx() >= until_x if dir == "move_right" else tx() <= until_x
	for i in 60 * 150:
		if arrived.call() or level.panel.open:
			break
		var held := {"_": false}
		var ahead := c.terrain.kinds_in(c.body_rect(c.global_position + Vector2(sign * T, 0)))
		var windy: bool = c.exposed or ahead.has(Terrain.Kind.EXPOSED)
		if c.state == Climber.State.GROUND and c.stamina.fraction() < 0.2 and not _on_slab():
			await rest_up(0.9)
			continue
		if _on_slab():
			held[dir] = true
		elif _slab_near(sign, 2) and windy and not c.wind.calm_for(c.clock, 3.0):
			held["brace"] = true
		elif windy and not c.wind.calm_for(c.clock, 0.8):
			held["brace"] = true
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
	var target := NAN
	for i in int(seconds * 60.0):
		if done.call():
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
	if OS.get_environment("PACE_DEBUG") != "":
		var last := [0.0, Vector2.ZERO]
		for e in level.pace_log:
			if e[1] in NOT_CHALLENGES:
				continue
			if e[2] - last[0] > 7.0:
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
