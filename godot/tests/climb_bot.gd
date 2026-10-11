class_name ClimbBot
extends TestCase
## A scripted climber for the level tests. It plays through the same input
## actions a player presses (GameInput.scripted) and reads only what a
## player can see: gust warnings, grit trickling over a column, cracked
## slabs. It knows the route; it does not cheat the hazards.

const T := 16.0

var level: Node
var c: Climber
var outcome: ChallengeOutcome


func tx() -> float:
	return c.global_position.x / T


func ty() -> float:
	return c.global_position.y / T


func where() -> String:
	return "(%.2f, %.2f) state=%d stamina=%.0f/%.0f slips=%d cp=%d clock=%.1f" % [tx(), ty(), c.state, c.stamina.value, c.stamina.max_value, c.slips, level.checkpoint, c.clock]


## Holds `keys` until `done` is true, or fails after `seconds` of game time.
func drive(keys: Array, done: Callable, seconds: float = 40.0, label: String = "") -> bool:
	for i in int(seconds * 60.0):
		if done.call():
			GameInput.scripted = {"_": false}
			return true
		var held := {"_": false}
		for k in keys:
			held[k] = true
		GameInput.scripted = held
		await tree.physics_frame
		if level.panel.open and label != "panel":
			break
	GameInput.scripted = {"_": false}
	var ok: bool = done.call()
	if not ok:
		failures.append("gave up %s at %s" % [label, where()])
	return ok


func rest_up(fraction: float = 0.95) -> void:
	GameInput.scripted = {"_": false, "rest": true}
	await tree.physics_frame
	GameInput.scripted = {"_": false}
	await drive([], func() -> bool: return c.stamina.fraction() >= fraction, 90.0, "resting")


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
		if _on_slab():
			held[dir] = true
		elif _slab_near(sign, 2) and windy and not c.wind.calm_for(c.clock, 3.0):
			held["brace"] = true
		elif windy and not c.wind.calm_for(c.clock, 0.8):
			held["brace"] = true
		else:
			held[dir] = true
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
		var x2: float = x + off
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
		else:
			held["climb_up"] = true
			var top := c.is_climbing() and c.terrain.hold_at(c.body_rect(c.global_position + Vector2(0, -6))) == Terrain.Kind.AIR
			if lean != "" and top:
				held[lean] = true
		GameInput.scripted = held
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
