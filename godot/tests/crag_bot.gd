class_name CragBot
extends ClimbBot
## The scripted crag climber, shared by the crag suites: loads a route and
## leads it through the real input actions, as a player would (walk to the
## line, climb, traverse where the line goes, shake out on jugs, keep moving
## on crimps and squeeze when the meter drops, pause on slopers, dyno the
## blank and tap once on the catch, clip, rest on the rope, top out).

func _load(id: String, start: String = "start") -> void:
	Crag.navigate = false
	Settings.touch_controls = false
	Crag.current = id
	level = load(Crag.LEVEL).instantiate()
	root.add_child(level)
	await physics_frames(2)
	c = level.climber
	check(level.panel.open, "the brief is shown first")
	if start != "":
		level.panel.choose(start)
	await physics_frames(1)


func _done() -> void:
	GameInput.scripted = {}
	level.queue_free()
	await physics_frames(2)


func _above(dy: int, x: float) -> Vector2i:
	var top := Terrain.cell_of(c.body_rect().position)
	return Vector2i(Terrain.cell_of(Vector2(x, 0)).x, top.y - dy)


## A column within reach sideways along the hands' row from which the line
## goes on up: its x, or NAN.
func _line_goes_up(dir: int) -> float:
	var t: Terrain = level.terrain
	var row := Terrain.cell_of(c.body_rect().position + Vector2(0, 4)).y
	var col := Terrain.cell_of(c.global_position).x
	for k in range(1, 16):
		var x := col + dir * k
		if not t.is_climbable(Vector2i(x, row)) and not t.is_climbable(Vector2i(x, row + 1)):
			return NAN
		if t.is_climbable(Vector2i(x, row - 1)):
			return x * T + T / 2.0
	return NAN


## Leads the current route to the anchor, as a player would. Returns true
## on the send.
func lead(seconds: float = 300.0) -> bool:
	var t: Terrain = level.terrain
	var resting := false
	var settling := false
	var target := NAN
	for i in int(seconds * 60.0):
		if level._ended:
			break
		if level.panel.open and level.lesson != "":
			# A lesson: read it, then on.
			level.panel.choose("lesson")
			await tree.physics_frame
			continue
		var held := {"_": false}
		if c.state == Climber.State.SLIP:
			target = NAN
			resting = false
		if c.state == Climber.State.GROUND and not c.can_grab():
			held["move_right"] = true
		elif c.state == Climber.State.GROUND:
			held["climb_up"] = true
		elif c.state == Climber.State.CLIMB:
			var hold := t.hold_at(c.body_rect())
			if hold == Terrain.Kind.JUG and (resting or c.stamina.fraction() < 0.9):
				# Shake out on the jug until the arms are full.
				resting = c.stamina.fraction() < 0.97
			elif not is_nan(target):
				if absf(target - c.global_position.x) < 1.5:
					target = NAN
				else:
					held["move_left" if target < c.global_position.x else "move_right"] = true
			else:
				var top := t.hold_at(c.body_rect(c.global_position + Vector2(0, -6))) == Terrain.Kind.AIR
				if top and level.dyno_above():
					held["climb_up"] = true
					held["jump"] = true
				elif top:
					var right := _line_goes_up(1)
					var left := _line_goes_up(-1)
					target = right if not is_nan(right) else left
					if is_nan(target):
						# The top of the line: pull over onto the ledge.
						held["climb_up"] = true
						held["move_right"] = true
				else:
					held["climb_up"] = true
		if held.has("jump") and _hopped:
			held.erase("jump")
		_hopped = held.has("jump")
		# Tap to clip each bolt and to stick a dyno; on tiny holds, squeeze
		# GRIP only when the meter drops below half, as a player would.
		if (level.action_word == "CLIP" or level.catching > 0.0) and i % 4 < 2:
			held["interact"] = true
		elif level.action_word == "GRIP" and level.on_crimps and level.grip < 0.5 and i % 4 < 2:
			held["interact"] = true
		# On slopers: move, and stop to let the grip settle when it drops.
		if level.on_slopers and (settling or level.grip < 0.45):
			settling = level.grip < 0.95
			for k in ["climb_up", "move_left", "move_right", "jump"]:
				held.erase(k)
		else:
			settling = false
		# Just clipped and getting tired: rest on the rope, and keep still
		# while the stamina comes back.
		if level.resting_rope:
			held = {"_": false}
		elif level.can_rest() and level.action_word == "REST" and c.stamina.fraction() < 0.85:
			held = {"interact": i % 4 < 2}
		GameInput.scripted = held
		if OS.get_environment("CRAG_DEBUG") != "" and i % 30 == 0:
			print("CRAGDBG ", where(), " held=", held.keys(), " target=", target, " resting=", resting)
		await tree.physics_frame
	GameInput.scripted = {"_": false}
	return level.result == "sent"
