class_name Hazards
extends Node2D
## The mountain fighting back, and what it hides. Everything here runs on the
## climber's own clock, so a climb replays exactly and pauses with the game.
##
## Rockfall (r markers): stones come down a chute of three columns on a
## schedule. Each is announced by trickling grit and a rattle over the
## column it will fall in; step to another column or under rock, and it
## misses. A hit is a slip (a helped teammate can still catch it).
##
## Cracked slabs (c tiles): solid until you stand on one; then it creaks and
## goes. Keep walking and you are across. Stop (even to sit out a gust) and you
## fall. They settle back after a while.
##
## Ice (i tiles) is in Climber: little grip, so you slide, and the edge
## guard does not hold you there.
##
## Water caches (w): a drink, most of the bar back, once per attempt.
## Gear (*): three pieces per climb, each placed before what it helps with
## (the level says what each does). It lasts this attempt: fail the climb
## or fall in a hole and it goes back where it was (drop_gear).

signal found_gear(index: int)
## Something the player had to deal with: for the level's pacing log.
signal engaged(kind: String)

const SLAB_HOLD := 1.0
const SLAB_BACK := 6.0
const WARN := 1.2
const FIRST_DROP := 4.0
const ROCK_GRAVITY := 520.0
const ROCK_MAX := 300.0
const ROCK_HALF := 4.0
const WATER := 0.45
## Rolling stones: one every ROLL_PERIOD seconds from each b / d marker,
## announced by a rumble, rolling along the ground at ROLL_SPEED.
const ROLL_PERIOD := 6.5
const ROLL_SPEED := 70.0
const ROLL_HALF := 6.0
const ROLL_RANGE := 34.0 * 16.0

var level: Node
var terrain: Terrain
var ground: TileMapLayer
var climber: Climber
var rock_period := 5.0
## gear: [[name, text, kind], ...] for this climb's * markers, bottom to top.
var gear_words: Array = []

var slabs := {}      # cell -> {t, state, gone_at}
var chutes: Array = []
var rocks: Array = []
var pickups: Array = []
var rollers: Array = []      # spawners: {cell, dir, offset, next}
var rolling: Array = []      # stones on the move: {node, dir, vy, start}
var gear_count := 0
## Everlastings: little flowers along the ground, a breath back each.
var flowers := 0
var flowers_total := 0
const FLOWER_BREATH := 3.0
var _flower_tex: Texture2D
var _was_warned := false
var _was_breaking := false
var _clock := -1.0
var _rock_tex: Texture2D


func setup(lvl: Node, t: Terrain, g: TileMapLayer, c: Climber, period: float, words: Array, taken: Array, found: Array) -> void:
	level = lvl
	terrain = t
	ground = g
	climber = c
	rock_period = period
	gear_words = words
	_rock_tex = Art.tex("res://assets/terrain/props/rock.png")
	for y in terrain.height:
		for x in terrain.width:
			if terrain.kind(Vector2i(x, y)) == Terrain.Kind.CRUMBLE:
				slabs[Vector2i(x, y)] = {"t": 0.0, "state": "whole", "gone_at": 0.0}
	var i := 0
	for cell in terrain.markers.get("r", []):
		var grit := CPUParticles2D.new()
		grit.emitting = false
		grit.amount = 14
		grit.lifetime = 0.9
		grit.direction = Vector2.DOWN
		grit.spread = 8.0
		grit.initial_velocity_min = 20.0
		grit.initial_velocity_max = 60.0
		grit.gravity = Vector2(0, 300)
		grit.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		grit.emission_rect_extents = Vector2(5, 1)
		grit.color = Color(0.82, 0.74, 0.62)
		grit.scale_amount_min = 1.0
		grit.scale_amount_max = 2.0
		add_child(grit)
		chutes.append({"cell": cell, "offset": float(posmod(cell.x * 37 + cell.y * 11, 100)) / 100.0 * period,
			"next": 0, "grit": grit, "warned": -1, "index": i})
		i += 1
	for ch in ["b", "d"]:
		for cell in terrain.markers.get(ch, []):
			rollers.append({"cell": cell, "dir": -1 if ch == "b" else 1, "next": 0,
				"offset": float(posmod(cell.x * 53 + cell.y * 7, 100)) / 100.0 * ROLL_PERIOD})
	var gears: Array = terrain.markers.get("*", []).duplicate()
	gears.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y or (a.y == b.y and a.x < b.x))
	for n in gears.size():
		var cell: Vector2i = gears[n]
		var s := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = Art.tex("res://assets/terrain/props/gear.png")
		var kind: String = String(words[n][2]) if n < words.size() and words[n].size() > 2 else ""
		var icon := maxi(0, ClimbLevel.GEAR_KINDS.find(kind)) if kind != "" else n % ClimbLevel.GEAR_KINDS.size()
		at.region = Rect2(icon * 14, 0, 14, 14)
		s.texture = at
		s.position = Terrain.feet(cell) - Vector2(0, 9)
		add_child(s)
		var had := found.has(n)
		if had:
			s.visible = false
			gear_count += 1
		pickups.append({"cell": cell, "kind": "gear", "index": n, "node": s, "taken": had})
	for cell in terrain.markers.get("w", []):
		var s := Sprite2D.new()
		s.texture = Art.tex("res://assets/terrain/props/water.png")
		s.position = Terrain.feet(cell) - Vector2(0, 7)
		add_child(s)
		var key := "%d,%d" % [cell.x, cell.y]
		var gone := taken.has(key)
		s.visible = not gone
		pickups.append({"cell": cell, "kind": "water", "key": key, "node": s, "taken": gone})
	_flower_tex = Art.tex("res://assets/terrain/props/everlasting.png")
	for cell in terrain.markers.get("f", []):
		var s := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = _flower_tex
		at.region = Rect2(0, 0, 10, 10)
		s.texture = at
		s.position = Terrain.feet(cell) - Vector2(0, 5)
		add_child(s)
		var key := "%d,%d" % [cell.x, cell.y]
		var gone := taken.has(key)
		s.visible = not gone
		flowers_total += 1
		if gone:
			flowers += 1
		pickups.append({"cell": cell, "kind": "flower", "key": key, "node": s, "taken": gone})


## The columns a chute's stones can fall in (the marker and its neighbours),
## and which one drop number `k` takes.
func _column(chute: Dictionary, k: int) -> int:
	var c: Vector2i = chute["cell"]
	return c.x - 1 + posmod(ExpeditionEngine.hash32([c.x, c.y, k]), 3)


func _drop_time(chute: Dictionary, k: int) -> float:
	return FIRST_DROP + chute["offset"] + k * rock_period


## Advances everything to the climber's clock.
func step() -> void:
	var now := climber.clock
	if _clock < 0.0:
		_clock = now
	var dt := clampf(now - _clock, 0.0, 0.1)
	_clock = now
	_slabs(dt, now)
	_rockfall(dt, now)
	_roll(dt, now)
	_pickups()
	# Pacing: warnings and slabs the player is dealing with right now.
	var warned := warned_here()
	if warned and not _was_warned:
		engaged.emit("stone")
	_was_warned = warned
	var breaking := slab_breaking()
	if breaking and not _was_breaking:
		engaged.emit("slab")
	_was_breaking = breaking
	var t := Time.get_ticks_msec() / 1000.0
	for p in pickups:
		if p["kind"] == "flower" and not p["taken"]:
			# A glint now and then, so the eye finds the next one.
			var glint := fposmod(t * 0.7 + p["cell"].x * 0.37, 3.0) < 0.25
			p["node"].texture.region = Rect2(10 if glint else 0, 0, 10, 10)
	for p in pickups:
		if p["kind"] == "gear" and not p["taken"]:
			p["node"].offset.y = sin(t * 3.0 + p["index"]) * 1.5


# --- Slabs --------------------------------------------------------------------

func _under_feet() -> Array:
	var out: Array = []
	if not climber.is_on_floor() or climber.is_climbing():
		return out
	var feet := climber.global_position + Vector2(0, 2)
	for dx in [-Climber.SIZE.x / 2.0 + 1.0, 0.0, Climber.SIZE.x / 2.0 - 1.0]:
		var cell := Terrain.cell_of(feet + Vector2(dx, 0))
		if slabs.has(cell) and not out.has(cell):
			out.append(cell)
	return out


func _slabs(dt: float, now: float) -> void:
	var under := _under_feet()
	for cell in slabs:
		var s: Dictionary = slabs[cell]
		match s["state"]:
			"whole", "breaking":
				if under.has(cell):
					s["t"] += dt
				else:
					s["t"] = maxf(0.0, s["t"] - dt * 0.5)
				if s["t"] >= SLAB_HOLD:
					s["state"] = "gone"
					s["gone_at"] = now
					terrain.set_kind(cell, Terrain.Kind.AIR)
					TerrainTiles.set_slab(ground, cell, "gone")
					_burst(Terrain.feet(cell) - Vector2(0, 8), Color(0.55, 0.45, 0.36), 18)
					Audio.play("rockfall", -4.0)
				elif s["t"] >= SLAB_HOLD * 0.35 and s["state"] == "whole":
					s["state"] = "breaking"
					TerrainTiles.set_slab(ground, cell, "breaking")
					Audio.play("rockfall", -12.0)
				elif s["t"] == 0.0 and s["state"] == "breaking":
					s["state"] = "whole"
					TerrainTiles.set_slab(ground, cell, "whole")
			"gone":
				var r := Rect2(Vector2(cell) * Terrain.TILE, Vector2.ONE * Terrain.TILE)
				if now - s["gone_at"] >= SLAB_BACK and not climber.body_rect().grow(4).intersects(r):
					s["state"] = "whole"
					s["t"] = 0.0
					terrain.set_kind(cell, Terrain.Kind.CRUMBLE)
					TerrainTiles.set_slab(ground, cell, "whole")


## True when the climber is standing on a slab that has started to go.
func slab_breaking() -> bool:
	for cell in _under_feet():
		if slabs[cell]["state"] == "breaking":
			return true
	return false


func is_slab(cell: Vector2i) -> bool:
	return slabs.has(cell)


# --- Rockfall -----------------------------------------------------------------

func _rockfall(dt: float, now: float) -> void:
	for chute in chutes:
		var k: int = chute["next"]
		var at := _drop_time(chute, k)
		var col := _column(chute, k)
		var top := Terrain.feet(chute["cell"]) - Vector2(0, Terrain.TILE)
		var grit: CPUParticles2D = chute["grit"]
		if now >= at - WARN and chute["warned"] != k:
			chute["warned"] = k
			grit.position = Vector2(col * Terrain.TILE + Terrain.TILE / 2.0, top.y)
			grit.restart()
			grit.emitting = true
			if top.distance_to(climber.global_position) < 320.0:
				Audio.play("rockfall", -10.0)
		if now >= at:
			grit.emitting = false
			var s := Sprite2D.new()
			s.texture = _rock_tex
			s.position = Vector2(col * Terrain.TILE + Terrain.TILE / 2.0, top.y)
			add_child(s)
			rocks.append({"node": s, "vy": 0.0, "col": col})
			chute["next"] = k + 1
	for r in rocks.duplicate():
		var node: Sprite2D = r["node"]
		r["vy"] = minf(r["vy"] + ROCK_GRAVITY * dt, ROCK_MAX)
		node.position.y += r["vy"] * dt
		node.rotation += dt * 6.0
		var box := Rect2(node.position - Vector2.ONE * ROCK_HALF, Vector2.ONE * ROCK_HALF * 2.0)
		if box.intersects(climber.body_rect()) and not climber.state in [Climber.State.SLIP, Climber.State.DONE, Climber.State.LOCKED, Climber.State.HELP]:
			_shatter(r)
			climber.slip("rock")
			continue
		if terrain.is_solid(Terrain.cell_of(node.position + Vector2(0, ROCK_HALF))):
			_shatter(r)


func _shatter(r: Dictionary) -> void:
	rocks.erase(r)
	var node: Sprite2D = r["node"]
	_burst(node.position, Color(0.6, 0.52, 0.44), 10)
	if node.position.distance_to(climber.global_position) < 260.0:
		Audio.play("rockfall", -8.0)
	node.queue_free()


## The pixel row where a stone dropped in column `col` from `top` lands.
func _landing(col: int, top: float) -> float:
	var row := Terrain.cell_of(Vector2(0, top)).y
	while row < terrain.height and not terrain.is_solid(Vector2i(col, row)):
		row += 1
	return row * Terrain.TILE


func _in_path(col: int, top: float, x: float, y: float) -> bool:
	if absf(col * Terrain.TILE + Terrain.TILE / 2.0 - x) >= ROCK_HALF + Climber.SIZE.x / 2.0 + 1.0:
		return false
	# The body spans y - height .. y; the stone falls from `top` to its landing.
	return y > top and y - Climber.SIZE.y < _landing(col, top)


## True when a stone is falling, or will start within `horizon` seconds, on a
## line that passes through a climber standing or hanging at x (centre), y
## (feet). Stones behind rock or below the feet do not count.
func threat_at(x: float, horizon: float, y: float = NAN) -> bool:
	if is_nan(y):
		y = climber.global_position.y
	var now := climber.clock
	for r in rocks:
		var node: Sprite2D = r["node"]
		if _in_path(r["col"], node.position.y, x, y):
			return true
	for chute in chutes:
		var k: int = chute["next"]
		var top := Terrain.feet(chute["cell"]).y - Terrain.TILE
		while _drop_time(chute, k) <= now + horizon:
			if _in_path(_column(chute, k), top, x, y):
				return true
			k += 1
	return false


## A warning is showing over the climber's column, and the climber is under
## that chute: for the HUD.
func warned_here() -> bool:
	var x := climber.global_position.x
	for chute in chutes:
		var k: int = chute["next"]
		var cell: Vector2i = chute["cell"]
		var below := climber.global_position.y > cell.y * Terrain.TILE
		if below and absf(x - (cell.x * Terrain.TILE + Terrain.TILE / 2.0)) < Terrain.TILE * 2.5:
			if climber.clock >= _drop_time(chute, k) - WARN or not rocks.is_empty():
				return threat_at(x, WARN)
	return false


## The clock jumped (a regroup, or resuming a save): the stones that would
## have come down meanwhile are long gone. Every chute and roller moves on
## to its next drop after `now`, past the warning, instead of catching up
## all at once.
func skip_to(now: float) -> void:
	for chute in chutes:
		while _drop_time(chute, chute["next"]) < now + WARN:
			chute["next"] = int(chute["next"]) + 1
		chute["warned"] = int(chute["next"]) - 1
	for sp in rollers:
		while _roll_time(sp, sp["next"]) < now + WARN:
			sp["next"] = int(sp["next"]) + 1


# --- Rolling stones -------------------------------------------------------------

func _roll_time(sp: Dictionary, k: int) -> float:
	return 2.5 + sp["offset"] + k * ROLL_PERIOD


func _roll(dt: float, now: float) -> void:
	for sp in rollers:
		var k: int = sp["next"]
		if now >= _roll_time(sp, k):
			sp["next"] = k + 1
			# Never start a stone right on top of the climber (a cairn beside
			# a spawner would be a respawn into a hit).
			if (Terrain.feet(sp["cell"]) - Vector2(0, ROLL_HALF)).distance_to(climber.global_position) < 3.0 * Terrain.TILE:
				continue
			var n := Sprite2D.new()
			n.texture = _rock_tex
			n.scale = Vector2(1.4, 1.4)
			var at := Terrain.feet(sp["cell"]) - Vector2(0, ROLL_HALF)
			n.position = at
			add_child(n)
			rolling.append({"node": n, "dir": sp["dir"], "vy": 0.0, "start": at.x})
			if at.distance_to(climber.global_position) < 360.0:
				Audio.play("rockfall", -10.0)
	for st in rolling.duplicate():
		var n: Sprite2D = st["node"]
		var dir: int = st["dir"]
		n.position.x += dir * ROLL_SPEED * dt
		n.rotation += dir * ROLL_SPEED / ROLL_HALF * dt
		# Follow the ground, slopes included: drop over edges, stop against rock.
		var ground := _surface(n.position.x, n.position.y + ROLL_HALF)
		if ground < n.position.y + ROLL_HALF - 1.5:
			# Stones do not roll uphill.
			_end_roll(st)
			continue
		if ground <= n.position.y + ROLL_HALF + 2.0:
			st["vy"] = 0.0
			n.position.y = ground - ROLL_HALF
		else:
			st["vy"] = minf(st["vy"] + ROCK_GRAVITY * dt, ROCK_MAX)
			n.position.y += st["vy"] * dt
		var box := Rect2(n.position - Vector2.ONE * ROLL_HALF, Vector2.ONE * ROLL_HALF * 2.0)
		if box.intersects(climber.body_rect()) and not climber.state in [Climber.State.SLIP, Climber.State.DONE, Climber.State.LOCKED, Climber.State.HELP]:
			_end_roll(st)
			climber.slip("rock")
			continue
		if not st.get("met", false) and absf(n.position.x - climber.global_position.x) < 2.0 * Terrain.TILE and absf(n.position.y - climber.global_position.y) < 3.0 * Terrain.TILE:
			st["met"] = true
			engaged.emit("roller")
		var ahead := Terrain.cell_of(n.position + Vector2(dir * (ROLL_HALF + 1), -2))
		var k := terrain.kind(ahead)
		var wall := terrain.is_solid(ahead) and k != Terrain.Kind.SLOPE_R and k != Terrain.Kind.SLOPE_L
		if wall or absf(n.position.x - st["start"]) > ROLL_RANGE or n.position.y > terrain.pixel_size().y:
			_end_roll(st)


## The ground's height under x, near y (pixels): slope tiles count by their
## surface, not their top. INF when there is no ground within a tile.
func _surface(x: float, y: float) -> float:
	var col := Terrain.cell_of(Vector2(x, 0)).x
	var row := Terrain.cell_of(Vector2(0, y - Terrain.TILE / 2.0)).y
	for k in 3:
		var cell := Vector2i(col, row + k)
		var kind := terrain.kind(cell)
		var f := fposmod(x, Terrain.TILE) / Terrain.TILE
		match kind:
			Terrain.Kind.SLOPE_R:
				return cell.y * Terrain.TILE + Terrain.TILE * (1.0 - f)
			Terrain.Kind.SLOPE_L:
				return cell.y * Terrain.TILE + Terrain.TILE * f
		if terrain.is_solid(cell):
			return cell.y * Terrain.TILE
	return INF


func _end_roll(st: Dictionary) -> void:
	rolling.erase(st)
	var n: Sprite2D = st["node"]
	_burst(n.position, Color(0.6, 0.52, 0.44), 8)
	n.queue_free()


## A rolling stone coming at x (within `reach` pixels, heading this way).
func roller_near(x: float, y: float, reach: float) -> bool:
	for st in rolling:
		var n: Sprite2D = st["node"]
		var dx := x - n.position.x
		if absf(n.position.y - (y - ROLL_HALF)) < Terrain.TILE and absf(dx) < reach and signf(dx) == float(st["dir"]):
			return true
	return false


# --- Finds --------------------------------------------------------------------

func _pickups() -> void:
	if climber.state == Climber.State.SLIP:
		return  # Nothing is picked up on the way down after a fall.
	var body := climber.body_rect()
	for p in pickups:
		if p["taken"]:
			continue
		var cell: Vector2i = p["cell"]
		if not body.intersects(Rect2(Vector2(cell) * Terrain.TILE, Vector2.ONE * Terrain.TILE)):
			continue
		p["taken"] = true
		if p["kind"] == "flower":
			flowers += 1
			climber.stamina.value = minf(climber.stamina.max_value, climber.stamina.value + FLOWER_BREATH)
			p["node"].visible = false
			_burst(p["node"].position, Color(1.0, 0.98, 0.85), 6)
			Audio.play("chime", -20.0, 0.1)
			level.on_water(p["key"])
			engaged.emit("flower")
			if flowers == flowers_total:
				level.hud.flash("Every everlasting on this climb: %d of %d." % [flowers, flowers_total], 3.0)
			continue
		engaged.emit(p["kind"])
		if p["kind"] == "water":
			climber.stamina.value = minf(climber.stamina.max_value, climber.stamina.value + climber.stamina.max_value * WATER)
			p["node"].visible = false
			_burst(p["node"].position, Color(0.6, 0.8, 1.0), 10)
			Audio.play("chime", -10.0)
			level.hud.flash("A water cache. You drink: stamina back up.")
			level.on_water(p["key"])
		else:
			gear_count += 1
			p["node"].visible = false
			_burst(p["node"].position, Color(1.0, 0.92, 0.6), 16)
			Audio.play("cairn", -4.0)
			var words: Array = gear_words[mini(p["index"], gear_words.size() - 1)] if not gear_words.is_empty() else ["Gear", ""]
			level.hud.flash("Found %s! %s" % [words[0], words[1]], 4.5)
			found_gear.emit(p["index"])


## A fall that counted: everything picked on this climb is dropped and goes
## back on the ground. You start again from the cairn with nothing.
func drop_flowers() -> int:
	var lost := flowers
	if lost == 0:
		return 0
	flowers = 0
	for p in pickups:
		if p["kind"] == "flower" and p["taken"]:
			p["taken"] = false
			p["node"].visible = true
	_burst(climber.global_position - Vector2(0, 12), Color(1.0, 0.98, 0.85), mini(30, 6 + lost))
	return lost


## A raven takes one everlasting you were carrying; it turns up back where it
## grew. False when you had none.
func steal_flower() -> bool:
	if flowers == 0:
		return false
	for i in range(pickups.size() - 1, -1, -1):
		var p: Dictionary = pickups[i]
		if p["kind"] == "flower" and p["taken"]:
			p["taken"] = false
			p["node"].visible = true
			flowers -= 1
			level.forget_taken([p["key"]])
			return true
	return false


## Lost the climb: every piece of gear taken goes back on the ground.
func drop_gear() -> void:
	gear_count = 0
	for p in pickups:
		if p["kind"] == "gear" and p["taken"]:
			p["taken"] = false
			p["node"].visible = true


func gear_total() -> int:
	return terrain.markers.get("*", []).size()


func _burst(at: Vector2, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.gravity = Vector2(0, 260)
	p.color = color
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
