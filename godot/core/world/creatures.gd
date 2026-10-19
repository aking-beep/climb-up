class_name Creatures
extends Node2D
## What lives on the mountain and can hurt you. Like Hazards, everything runs
## on the climber's clock, so a climb replays exactly.
##
## Thistles and nettles (n): the spiny Kilimanjaro thistle on the tower, a
## stinging nettle in the Barranco valley. Walk into one and it stings; hop
## over it.
## Siafu (a): a column of safari ants marching back and forth along the
## ground. They bite. Hop over them.
## Ravens (v): a white-necked raven circles over its stretch of path. Stand
## about under it and it calls, then dives at the spot where you were: keep
## moving and it misses. A hit hurts, and it snatches an artifact you carry
## and drops it back where you found it.
##
## A hit costs stamina (Climber.hurt), never a slip by itself; a hit you
## have no stamina left for is a collapse, and that is a slip.

## Something the player had to deal with: for the level's pacing log.
signal engaged(kind: String)

const PLANT_HURT := 10.0
const ANT_HURT := 12.0
const RAVEN_HURT := 12.0
const ANT_SPEED := 14.0
const ANT_RANGE := 2.0 * 16.0
const ANT_SIZE := Vector2(18.0, 5.0)
## A raven calls for RAVEN_WARN seconds, then dives in RAVEN_DIVE to where you
## were when it called, climbs back in RAVEN_BACK, and waits RAVEN_REST.
const RAVEN_WARN := 0.7
const RAVEN_DIVE := 0.45
const RAVEN_BACK := 1.0
const RAVEN_REST := 3.5
## Its stretch of path: this far either side, and down to the ground below.
const RAVEN_REACH := 6.0 * 16.0
const RAVEN_DEPTH := 8.0 * 16.0
const RAVEN_SIZE := Vector2(12.0, 8.0)

var level: Node
var terrain: Terrain
var climber: Climber
var plants: Array = []   # {cell, node, rect}
var ants: Array = []     # {node, x0, x, y, dir}
var ravens: Array = []   # {node, home, phase, t, target, from, hit}
var stings := 0
var bites := 0
var raven_hits := 0
var _clock := -1.0


func setup(lvl: Node, t: Terrain, c: Climber, lush: bool) -> void:
	level = lvl
	terrain = t
	climber = c
	var plant_tex: Texture2D = Art.tex("res://assets/terrain/props/thistle.png")
	for cell in terrain.markers.get("n", []):
		var s := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = plant_tex
		at.region = Rect2(16 if lush else 0, 0, 16, 16)
		s.texture = at
		var feet := Terrain.feet(cell)
		s.position = feet - Vector2(0, 8)
		add_child(s)
		# The spiny part: most of the tile, from the ground up.
		plants.append({"cell": cell, "node": s, "rect": Rect2(feet.x - 5.0, feet.y - 12.0, 10.0, 12.0)})
	var ant_tex: Texture2D = Art.tex("res://assets/terrain/props/ants.png")
	for cell in terrain.markers.get("a", []):
		var s := AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		sf.set_animation_speed("default", 6.0)
		for i in 3:
			var a := AtlasTexture.new()
			a.atlas = ant_tex
			a.region = Rect2(i * 24, 0, 24, 6)
			sf.add_frame("default", a)
		s.sprite_frames = sf
		s.play()
		var feet := Terrain.feet(cell)
		s.position = feet - Vector2(0, 3)
		add_child(s)
		ants.append({"node": s, "x0": feet.x, "x": feet.x, "y": feet.y, "dir": 1 if posmod(cell.x, 2) == 0 else -1})
	var raven_tex: Texture2D = Art.tex("res://assets/terrain/props/raven.png")
	for cell in terrain.markers.get("v", []):
		var s := AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		sf.set_animation_speed("default", 5.0)
		for i in 2:
			var a := AtlasTexture.new()
			a.atlas = raven_tex
			a.region = Rect2(i * 18, 0, 18, 12)
			sf.add_frame("default", a)
		s.sprite_frames = sf
		s.play()
		var home := Terrain.feet(cell) - Vector2(0, 8)
		s.position = home
		add_child(s)
		ravens.append({"node": s, "home": home, "phase": "circle", "t": 0.0, "target": home, "from": home,
			"hit": false, "seed": float(posmod(cell.x * 31 + cell.y * 17, 100)) / 100.0})


## Advances everything to the climber's clock.
func step() -> void:
	var now := climber.clock
	if _clock < 0.0:
		_clock = now
	var dt := clampf(now - _clock, 0.0, 0.1)
	_clock = now
	var body := climber.body_rect()
	var airborne := climber.state == Climber.State.AIR
	for p in plants:
		if body.intersects(p["rect"]) and not (airborne and body.end.y < p["rect"].position.y + 3.0):
			if climber.hurt(PLANT_HURT, "thistle"):
				stings += 1
				_puff(p["node"].position, Color(0.75, 0.55, 0.85))
				level.hud.flash("Stung! %s. Hop over them." % ("Nettles" if p["node"].texture.region.position.x > 0 else "Thistle spines"))
	for a in ants:
		_march(a, dt)
		var r := Rect2(a["x"] - ANT_SIZE.x / 2.0, a["y"] - ANT_SIZE.y, ANT_SIZE.x, ANT_SIZE.y)
		if body.intersects(r) and climber.hurt(ANT_HURT, "ants"):
			bites += 1
			_puff(Vector2(a["x"], a["y"] - 3.0), Color(0.6, 0.25, 0.15))
			level.hud.flash("Siafu! The ants bite. Hop over the column.")
	for rv in ravens:
		_fly(rv, dt, now)


func _march(a: Dictionary, dt: float) -> void:
	var nx: float = a["x"] + a["dir"] * ANT_SPEED * dt
	var ahead := Terrain.cell_of(Vector2(nx + a["dir"] * ANT_SIZE.x / 2.0, a["y"] - 2.0))
	var floor_ahead := ahead + Vector2i.DOWN
	if absf(nx - a["x0"]) > ANT_RANGE or terrain.is_solid(ahead) or not terrain.is_solid(floor_ahead):
		a["dir"] = -a["dir"]
		return
	a["x"] = nx
	var n: AnimatedSprite2D = a["node"]
	n.position.x = nx
	n.flip_h = a["dir"] < 0


func _in_reach(home: Vector2) -> bool:
	var feet := climber.global_position
	return absf(feet.x - home.x) < RAVEN_REACH and feet.y > home.y and feet.y - home.y < RAVEN_DEPTH


func _fly(rv: Dictionary, dt: float, now: float) -> void:
	var n: AnimatedSprite2D = rv["node"]
	var home: Vector2 = rv["home"]
	rv["t"] += dt
	match rv["phase"]:
		"circle", "rest":
			var w: float = now * 1.6 + rv["seed"] * TAU
			n.position = home + Vector2(cos(w) * 14.0, sin(w * 2.0) * 4.0)
			n.flip_h = sin(w) > 0.0
			var on_foot := climber.state in [Climber.State.GROUND, Climber.State.REST]
			var ready: bool = rv["phase"] == "circle" or rv["t"] >= RAVEN_REST
			if ready and on_foot and _in_reach(home):
				rv["phase"] = "warn"
				rv["t"] = 0.0
				rv["hit"] = false
				# It marks where you are now. Be somewhere else when it lands.
				rv["target"] = climber.global_position - Vector2(0, Climber.SIZE.y * 0.55)
				rv["from"] = n.position
				engaged.emit("raven")
				Audio.play("chime", -8.0, 0.3)
				level.hud.flash("A raven calls overhead: keep moving!", 1.4)
			elif ready:
				rv["phase"] = "circle"
		"warn":
			n.position = rv["from"] + Vector2(sin(rv["t"] * 40.0) * 1.5, 0)
			n.flip_h = rv["target"].x > n.position.x
			if rv["t"] >= RAVEN_WARN:
				rv["phase"] = "dive"
				rv["t"] = 0.0
		"dive":
			var k := clampf(rv["t"] / RAVEN_DIVE, 0.0, 1.0)
			n.position = (rv["from"] as Vector2).lerp(rv["target"], k * k)
			if not rv["hit"]:
				var r := Rect2(n.position - RAVEN_SIZE / 2.0, RAVEN_SIZE)
				if climber.body_rect().intersects(r) and climber.hurt(RAVEN_HURT, "raven"):
					rv["hit"] = true
					raven_hits += 1
					_puff(n.position, Color(0.2, 0.2, 0.22))
					var took: String = level.hazards.steal_artifact() if level.get("hazards") else ""
					level.hud.flash("The raven strikes%s" % ((" and snatches %s: it drops it back where you found it." % took) if took != "" else "."))
			if k >= 1.0:
				rv["phase"] = "back"
				rv["t"] = 0.0
				rv["from"] = n.position
		"back":
			var k := clampf(rv["t"] / RAVEN_BACK, 0.0, 1.0)
			n.position = (rv["from"] as Vector2).lerp(home, k)
			if k >= 1.0:
				rv["phase"] = "rest"
				rv["t"] = 0.0


## True when an ant column or a thistle is on the ground just ahead of a
## climber at x (centre), y (feet) facing `dir`: for hints and the test bot.
func danger_ahead(x: float, y: float, dir: int, reach: float = 22.0) -> bool:
	for p in plants:
		var r: Rect2 = p["rect"]
		var dx: float = (r.get_center().x - x) * dir
		if dx > 0.0 and dx < reach + 5.0 and absf(r.end.y - y) < 4.0:
			return true
	for a in ants:
		var dx: float = (a["x"] - x) * dir
		if dx > -ANT_SIZE.x / 2.0 and dx < reach + ANT_SIZE.x / 2.0 and absf(a["y"] - y) < 4.0:
			return true
	return false


## A raven that has called and is about to dive, or diving.
func raven_coming() -> bool:
	for rv in ravens:
		if rv["phase"] in ["warn", "dive"]:
			return true
	return false


func _puff(at: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 10
	p.lifetime = 0.5
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2(0, 200)
	p.color = color
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
