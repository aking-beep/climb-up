class_name CragLevel
extends Node2D
## One sport route at the crag (Crag.current), led from the ground: clip the
## bolts as you pass them, and a fall drops you onto the rope at the last
## one you clipped. The anchor at the top is the send. Nothing here touches
## the expedition.
##
## Stamina is the one bar, as on Kilimanjaro: climbing spends it, crimps
## spend it fast (keep moving on them), a jug gives it back while you hang
## there, a dyno costs a hard move. Too many falls and you lower off.

signal finished(result: Dictionary)

const LEAD_FALL := 2.0 * Terrain.TILE
## Clipping a bolt is one tap, on every route. The bolts make the grade:
## further apart the harder the route. Where you clip from matters: one hand
## off a big hold is free, off ordinary rock costs a little stamina, off
## tiny holds costs grip and stamina (more the harder the route).
## On tiny holds a grip meter runs down: slowly while you keep moving
## (GRIP_MOVING of the route's gripDrain a second), fast if you stop on them
## (GRIP_STILL). A tap of GRIP squeezes it back up by GRIP_TAP; taps closer
## together than GRIP_COOLDOWN do nothing more, so mashing does not help,
## a well-timed squeeze does. The tighter your grip, the less the tiny holds
## burn: at full grip they cost GRIP_SAVE of their stamina, at none
## GRIP_BURN. Keep moving and a stretch of tiny holds takes a few squeezes,
## not a stream of taps.
const GRIP_TAP := 0.45
const GRIP_COOLDOWN := 0.2
const GRIP_MOVING := 0.35
const GRIP_STILL := 1.3
const GRIP_SAVE := 0.4
const GRIP_BURN := 1.6
## A lead fall: twice as far as you were above the last clipped bolt, plus
## the slack in the system. Land below the ground and you hit it.
const FALL_SLACK := 1.0 * Terrain.TILE
const GROUND_HIT := 25.0
## After a jump (dyno) you have this long to stick the hold: tap fast.
const CATCH_TIME := 1.0
const CATCH_TAPS := 3
## Once clipped you can sit back on the rope and rest, any time, as often
## as you like: each clip fills a green rest bar worth ROPE_REST stamina,
## given back at ROPE_RATE a second while you sit. Moving ends a rest; the
## rest of the bar waits for the next one. Big holds (jugs) give more.
const ROPE_REST := 20.0
const ROPE_RATE := 15.0
## What clipping costs, by the hold you clip from (stamina; grip off crimps).
const CLIP_FACE := 2.0
const CLIP_CRIMP := 4.0
const CLIP_CRIMP_GRIP := 0.35
## A gap this many rows from the bolt below is a long run-out.
const RUNOUT := 9
const CLIP_REACH := Vector2(4.2, 1.4) * Terrain.TILE

var route: Dictionary = {}
var terrain: Terrain
var climber: Climber
var stamina: StaminaModel
var wind: WindSchedule
var camera: ExpeditionCamera
var panel: StoryPanel
var hud: Hud
var belayer: Companion
var rope: Line2D
var rope_shadow: Line2D
## The bolt in reach glows so the eye finds it.
var _reach_glow: Sprite2D
## Bolts, bottom to top: {cell, node, clipped, hang (feet on the rope there)}.
var clips: Array = []
## What the HUD reads: falls allowed, bolts clipped, the start plus bolts.
var max_slips := Crag.MAX_FALLS
var checkpoint := 0
var cairns: Array[Vector2] = []
var mate_state := "none"
var mate_breath := 0.0
var mate_cooldown := false
## The touch overlay's layout: one big tap button, no BRACE or REST.
var touch_layout := "crag"
var prompt := ""
var action_word := ""
var briefed := false
## The shoes on for this go ("neutral", "aggressive"; "" on the lesson).
var shoes := ""
var result := ""
var outcome: Dictionary = {}
## Pacing, as on the expedition: each moment the player acted.
var pace_log: Array = []
## The taps: the bolt in reach and taps on it so far, the grip meter on tiny
## holds, and a dyno being stuck.
var clip_target := -1
## What the last clip cost (clip_cost), for tests and the HUD.
var last_clip_cost: Dictionary = {}
var grip := 1.0
var on_crimps := false
var catching := 0.0
var catch_taps := 0
var _dyno_air := false
var _tap := false
var meter: Node2D
var grip_drain := 0.55
## The lesson route: what has been explained so far (the game stops for
## each new thing).
var lessons_seen: Array = []
var lesson := ""
## The rest on the rope: the green bar left (rope_left), and resting now.
var resting_rope := false
var rope_left := 0.0
var rope_rests := 0
## Every tap, by what it did: grip, clip, catch, rest, go, or none (a tap
## that did nothing).
var taps := {"grip": 0, "clip": 0, "catch": 0, "rest": 0, "go": 0, "none": 0}
var _grip_cool := 0.0
## Beta taken on this route (a clean first go is a flash, not an onsight).
var beta := false
## Reading the route from the ground before climbing it.
var previewing := false
var _skip_preview := false
var marks: Node2D
## The last fall: how far (m), and whether it reached the ground.
var last_fall_m := 0.0
var ground_falls := 0
var _fall_top := 0.0
var _ended := false
var _start: Vector2
var _top_y := 0.0
var _hold_tex: Texture2D
var _draw_tex: Texture2D


func _ready() -> void:
	route = Crag.route(Crag.current)
	terrain = Terrain.load_file(Crag.map_path(route["id"]))
	stamina = StaminaModel.new(100.0, 1.0, 1.0)
	wind = WindSchedule.new(0.0, 1, -60.0)
	var theme := {
		"far": "res://assets/scenery/barranco-kibo.png", "farScale": 0.7,
		"mid": "res://assets/scenery/plateau.png",
		"foreground": "res://assets/scenery/lava-foreground.png",
		"cliff": "res://assets/scenery/lava-wall-deep.png",
		"deep": "res://assets/scenery/lava-wall.png",
		"tint": "#f3e2d4", "grass": true,
	}
	var back := TileMapLayer.new()
	back.name = "BackWall"
	back.modulate = Color(0.8, 0.78, 0.8) * Color(theme["tint"])
	back.z_index = -5
	add_child(back)
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.modulate = Color(theme["tint"])
	add_child(ground)
	TerrainTiles.paint(terrain, ground, back, theme)
	# The cliff is behind everything below its top, blank rock included.
	var ledge := Terrain.cell_of(Terrain.feet(terrain.markers["X"][0])).y
	for y in range(ledge, terrain.height):
		for x in range(_wall_x(), terrain.width):
			var cell := Vector2i(x, y)
			if not terrain.is_solid(cell) and back.get_cell_source_id(cell) == -1:
				back.set_cell(cell, TerrainTiles.CLIFF_SOURCE, TerrainTiles._cliff(cell))
	TerrainTiles.sync_back(back)
	_place_holds()
	_place_jugs()

	_start = Terrain.feet(terrain.markers["P"][0])
	cairns.append(_start)
	var anchor: Vector2i = terrain.markers["X"][0]
	_top_y = Terrain.feet(anchor).y
	var a := _hd_sprite("res://assets/crag/anchor-hd.png", 1.3)
	a.position = Terrain.feet(anchor) - Vector2(0, 10)
	add_child(a)
	_place_clips()

	belayer = Companion.new()
	belayer.person = "lena"
	belayer.name = "Belayer"
	add_child(belayer)
	belayer.global_position = Vector2(_base_x() - 2.5 * Terrain.TILE, _start.y)

	# The rope: a dark outline under a round, shaded orange core, sagging
	# between the bolts.
	rope_shadow = Line2D.new()
	rope_shadow.width = 3.0
	rope_shadow.default_color = Color("#2a1410")
	rope_shadow.z_index = 2
	rope = Line2D.new()
	rope.width = 2.0
	rope.texture = _rope_texture()
	rope.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	rope.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rope.z_index = 2
	for line in [rope_shadow, rope]:
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		add_child(line)

	climber = Climber.new()
	climber.name = "Climber"
	climber.setup(terrain, wind, stamina)
	climber.can_dyno = true
	add_child(climber)
	climber.global_position = _start
	climber.slipped.connect(_on_slipped)
	climber.slip_finished.connect(_on_slip_finished)
	climber.grabbed.connect(func() -> void: engage("grab"))
	climber.mantled.connect(func() -> void: engage("mantle"))
	climber.dynoed.connect(func() -> void:
		engage("dyno")
		_dyno_air = true
		camera.kick(0.2))
	climber.grabbed.connect(_on_grabbed)
	max_slips = int(route.get("falls", Crag.MAX_FALLS))
	grip_drain = float(route.get("gripDrain", 0.55))
	marks = RouteMarks.new()
	marks.level = self
	marks.z_index = 9
	marks.visible = false
	add_child(marks)
	beta = bool(Crag.record(route["id"]).get("beta", false))
	meter = TapMeter.new()
	meter.level = self
	meter.z_index = 8
	add_child(meter)

	camera = ExpeditionCamera.new()
	camera.target = climber
	camera.bounds = Rect2(Vector2.ZERO, terrain.pixel_size())
	add_child(camera)
	camera.snap()
	Scenery.build(self, terrain, camera, theme)

	hud = Hud.new()
	hud.title = "%s · %s" % [route["name"], route["grade"]]
	add_child(hud)
	panel = StoryPanel.new()
	add_child(panel)
	panel.chosen.connect(_on_choice)
	TouchControls.attach(self)
	Settings.interrupted.connect(_on_interrupted)
	Settings.back_requested.connect(_on_back)
	Audio.set_camp(0.0)
	brief()


func mate_name() -> String:
	return ""


## Where the cliff starts: the first column with the ledge over it.
func _wall_x() -> int:
	var row := Terrain.cell_of(Terrain.feet(terrain.markers["X"][0])).y
	for x in terrain.width:
		if terrain.is_solid(Vector2i(x, row)):
			return x
	return 0


## The column the line starts in, at the foot of the cliff.
func _base_x() -> float:
	var row := Terrain.cell_of(_start - Vector2(0, 2)).y
	for x in terrain.width:
		if terrain.is_climbable(Vector2i(x, row)):
			return x * Terrain.TILE
	return _start.x + 8 * Terrain.TILE


## A smooth, illustrated sprite (tools/art/crag_hd.py): drawn at 4x,
## shown at a quarter scale with smooth filtering.
func _hd_sprite(path: String, size: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.scale = Vector2.ONE * size / 4.0
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.z_index = 1
	return s


## A round rope: a texture across its width, dark edges and a lit middle.
static func _rope_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 1.0])
	g.colors = PackedColorArray([Color("#a8381a"), Color("#ff9a5c"), Color("#e8622c"), Color("#9a3216")])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 16
	return t


func _place_holds() -> void:
	_hold_tex = load("res://assets/crag/crimp-hd.png")
	for y in terrain.height:
		for x in terrain.width:
			var k := terrain.kind(Vector2i(x, y))
			if k != Terrain.Kind.CRIMP and k != Terrain.Kind.JUG:
				continue
			# Jugs are drawn whole, one big hold per patch (_place_jugs).
			if k == Terrain.Kind.JUG:
				continue
			var s := _hd_sprite("res://assets/crag/crimp-hd.png")
			s.centered = false
			s.position = Vector2(x, y) * Terrain.TILE
			s.flip_h = posmod(x + y, 2) == 1
			add_child(s)


## Jugs: big incut holds with chalk on the lip, set into the rock like the
## crimps, two to a patch (staggered, a hand and a foot), so they read as
## holds you can hang on, not as a sign.
func _place_jugs() -> void:
	var tex := "res://assets/crag/jug-hd.png"
	for y in terrain.height:
		for x in terrain.width:
			var cell := Vector2i(x, y)
			if terrain.kind(cell) != Terrain.Kind.JUG:
				continue
			if terrain.kind(cell + Vector2i.LEFT) == Terrain.Kind.JUG or terrain.kind(cell + Vector2i.UP) == Terrain.Kind.JUG:
				continue
			var size := Vector2i.ONE
			while terrain.kind(cell + Vector2i(size.x, 0)) == Terrain.Kind.JUG:
				size.x += 1
			while terrain.kind(cell + Vector2i(0, size.y)) == Terrain.Kind.JUG:
				size.y += 1
			var spots: Array = [Vector2(0.3, 0.3), Vector2(0.7, 0.75)] if size.y > 1 else [Vector2(0.5, 0.5)]
			for f in spots:
				var s := _hd_sprite(tex)
				s.position = (Vector2(cell) + Vector2(size) * (f as Vector2)) * Terrain.TILE
				add_child(s)


func _place_clips() -> void:
	_draw_tex = load("res://assets/crag/quickdraw-hd.png")
	_reach_glow = Sprite2D.new()
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	var gg := Gradient.new()
	gg.colors = PackedColorArray([Color(1, 0.95, 0.7, 0.55), Color(1, 0.95, 0.7, 0.0)])
	glow.gradient = gg
	glow.width = 64
	glow.height = 64
	_reach_glow.texture = glow
	_reach_glow.scale = Vector2.ONE * 0.5
	_reach_glow.z_index = 0
	_reach_glow.visible = false
	add_child(_reach_glow)
	var cells: Array = terrain.markers.get("Q", []).duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	for cell in cells:
		# A touch larger than life, so the bolts are easy to find on a phone.
		var s := _hd_sprite("res://assets/crag/quickdraw-hd.png", 1.3)
		var at := AtlasTexture.new()
		at.atlas = _draw_tex
		at.region = Rect2(0, 0, 48, 88)
		s.texture = at
		# The hanger at the bolt, the draw hanging below it.
		s.position = Vector2(cell) * Terrain.TILE + Vector2(4, 11)
		add_child(s)
		var c := {"cell": cell, "node": s, "clipped": false, "hang": _hang_point(cell)}
		clips.append(c)
		cairns.append(Terrain.feet(cell))
	for i in clips.size():
		# Rows up from the bolt below (from the ground for the first).
		clips[i]["gap"] = (clips[i - 1]["cell"].y if i > 0 else terrain.height) - clips[i]["cell"].y


## The longest gap between two bolts, in rows.
func longest_gap() -> int:
	var most := 0
	for i in range(1, clips.size()):
		most = maxi(most, int(clips[i]["gap"]))
	return most


## What clipping costs from where you are now: {stamina, grip, words}.
func clip_cost() -> Dictionary:
	match terrain.hold_at(climber.body_rect()):
		Terrain.Kind.JUG:
			return {"stamina": 0.0, "grip": 0.0, "words": "from this big hold it's free"}
		Terrain.Kind.CRIMP:
			return {"stamina": CLIP_CRIMP * (1.0 + grip_drain), "grip": CLIP_CRIMP_GRIP, "words": "on tiny holds it costs grip and stamina"}
	return {"stamina": CLIP_FACE, "grip": 0.0, "words": "it costs a little stamina"}


## Where you hang on the rope after a fall at this bolt: on the nearest rock
## of the line, level with it.
func _hang_point(cell: Vector2i) -> Vector2:
	for d in range(1, 6):
		for side in [-1, 1]:
			var c: Vector2i = cell + Vector2i(d * side, 0)
			if terrain.is_climbable(c) and terrain.is_climbable(c + Vector2i.DOWN):
				return Terrain.feet(c + Vector2i.DOWN)
	return Terrain.feet(cell)


# --- The brief ------------------------------------------------------------------

func brief() -> void:
	climber.lock(true)
	var r := Crag.record(route["id"])
	var history := "Not tried yet. Climb it first try with no falls for an onsight, the best result."
	if beta and int(r["attempts"]) == 0:
		history = "Not tried yet. You have beta: a first try with no falls is a flash."
	if int(r["sends"]) > 0:
		history = "Climbed %d time%s · best: %s." % [int(r["sends"]), "" if int(r["sends"]) == 1 else "s", Crag.STYLES[r["best"]][0]]
	elif int(r["attempts"]) > 0:
		history = "%d tr%s so far, not topped yet%s. Top it with no falls for a redpoint." % [int(r["attempts"]), "y" if int(r["attempts"]) == 1 else "ies",
			(": high point bolt %d of %d" % [int(r.get("highpoint", 0)), clips.size()]) if int(r.get("highpoint", 0)) > 0 else ""]
	var kicker := "The crag · lesson" if route.get("tutorial", false) else "The crag · grade %s (%s moves)" % [route["grade"], route["level"]]
	var body := "%s\nHardest part: %s\n%s · %s\nFall %d times and you have to come down · %s" % [route["text"], route["crux"],
		Crag.protection_words(route["id"]), Crag.exposure_words(route["id"]), max_slips, history]
	var choices: Array = [["start", "Tie in and climb"]]
	if not route.get("tutorial", false):
		# Pick the shoes, the ones worn last time first.
		choices = []
		for id in ["neutral", "aggressive"]:
			var words := "Neutral shoes: slower, saves stamina" if id == "neutral" else "Aggressive shoes: faster, costs stamina"
			if id == Crag.shoes:
				choices.push_front([id, words])
			else:
				choices.append([id, words])
	choices.append(["look", "Look at the route first"])
	if not route.get("tutorial", false) and not beta and int(r["sends"]) == 0:
		choices.append(["beta", "Ask for beta (tips: a clean first go is then a flash)"])
	choices.append(["menu", "Back to the climbs"])
	panel.show_panel(kicker, route["name"], body, choices)


## Reading the route from the ground: the camera runs up the line, with the
## tiny holds, big holds, jumps, bolts and long run-outs marked. Free: a
## look from the ground does not spoil an onsight. Any tap skips it.
func preview() -> void:
	previewing = true
	_skip_preview = false
	panel.hide_panel()
	marks.visible = true
	hud.flash("Reading the route from the ground. Tap to skip.", 3.0)
	var anchor := Terrain.feet(terrain.markers["X"][0])
	var bottom := Vector2(_base_x() + 1.5 * Terrain.TILE, _start.y - 70.0)
	var top := Vector2(anchor.x, anchor.y + 70.0)
	camera.look = bottom
	var length := clampf((bottom.y - top.y) / 120.0, 2.5, 6.0)
	var t := -0.5
	while is_inside_tree() and t < length + 1.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		camera.look = bottom.lerp(top, smoothstep(0.0, 1.0, clampf(t / length, 0.0, 1.0)))
		if t > 0.2 and _skip_preview:
			break
	if not is_inside_tree():
		return
	camera.look = Vector2.INF
	camera.snap()
	marks.visible = false
	previewing = false
	if not briefed:
		brief()
	else:
		pause_menu()


## Beta: how to climb it, worked out from the route. Taking it turns a clean
## first go into a flash rather than an onsight.
func beta_tips() -> String:
	var tips: Array = []
	for i in clips.size():
		var c: Dictionary = clips[i]
		match _hold_by(c["cell"]):
			Terrain.Kind.JUG:
				tips.append("Bolt %d: clip it from the big hold beside it, for free." % (i + 1))
			Terrain.Kind.CRIMP:
				tips.append("Bolt %d sits on tiny holds: clipping there costs grip. Squeeze, clip, keep moving." % (i + 1))
		if i > 0 and int(c["gap"]) >= RUNOUT:
			tips.append("Between bolts %d and %d is a long run-out (%s m): rest on the rope at bolt %d first." % [i, i + 1, Crag._m(int(c["gap"]) * Crag.ROW_M), i])
	if dyno_count() > 0:
		tips.append("%s across blank rock: jump from the top of the holds below, then tap GRIP 3 times to stick it." % ("A leap" if dyno_count() == 1 else "%d leaps" % dyno_count()))
	tips.append("On the tiny holds, keep moving: one squeeze of GRIP when the meter drops below half. Stopping drains it fast.")
	return "\n".join(tips)


## Stretches of blank rock on the line (a jump each).
func dyno_count() -> int:
	return int(marks.sections().filter(func(m: Dictionary) -> bool: return m["kind"] == "blank").size())


## The kind of hold on the line level with a bolt (what you clip from).
func _hold_by(cell: Vector2i) -> int:
	for d in range(1, 6):
		for side in [-1, 1]:
			var k := terrain.kind(cell + Vector2i(d * side, 0))
			if k == Terrain.Kind.FACE or k == Terrain.Kind.CRIMP or k == Terrain.Kind.JUG:
				return k
	return Terrain.Kind.FACE


## Puts on a pair of shoes (Crag.SHOES): climbing speed and what the rock
## costs.
func wear(id: String) -> void:
	shoes = id
	var s: Dictionary = Crag.SHOES[id]
	climber.pace = float(s["pace"])
	stamina.shoes = float(s["stamina"])
	if Crag.shoes != id:
		Crag.shoes = id
		Crag.save_progress()


# --- The climb --------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _ended or climber == null:
		return
	var pressed := GameInput.pressed_now("interact")
	_tap = pressed and not panel.open and not previewing
	if previewing:
		# pressed_now() is an edge each caller consumes: read it here, once.
		if pressed or GameInput.pressed_now("jump") or GameInput.pressed_now("pause"):
			_skip_preview = true
		return
	if _tap:
		var kind := "catch" if catching > 0.0 else action_word.to_lower()
		taps[kind if taps.has(kind) else "none"] += 1
	if panel.open:
		# Reading: nothing runs down while a panel is up.
		_draw_rope()
		hud.update_from(self)
		return
	if route.get("tutorial", false) and _teach():
		return
	var dt := get_physics_process_delta_time()
	_catch(dt)
	_grip(dt)
	_clip()
	_rope(dt)
	climber.on_rope = resting_rope
	# On lead, a fall stops on the rope a little below the last bolt.
	if climber.state == Climber.State.AIR and checkpoint > 0 and climber.global_position.y - climber.fall_from > LEAD_FALL:
		climber.slip("fall")
	if climber.state == Climber.State.GROUND and climber.global_position.y <= _top_y + 1.0:
		finish(true)
		return
	_draw_rope()
	prompt = ""
	action_word = "CLIMB" if climber.can_grab() else ""
	if resting_rope:
		action_word = "GO"
		prompt = "Resting on the rope"
	elif can_rest() and not on_crimps:
		action_word = "REST"
		prompt = "Rest on the rope?"
	elif catching > 0.0:
		action_word = "GRIP"
		prompt = "Stick it! (%d/%d)" % [catch_taps, CATCH_TAPS]
	elif clip_target >= 0:
		action_word = "CLIP"
		prompt = "Clip in?"
	elif on_crimps:
		action_word = "GRIP"
		prompt = "Grip! (%d%%)" % int(grip * 100.0)
	if GameInput.pressed_now("pause") and not panel.open:
		pause_menu()
	hud.update_from(self)


## The brief's words for how far apart the bolts are on this route.
func _spacing_words() -> String:
	var most := longest_gap()
	if most <= 5:
		return "close together"
	if most < RUNOUT:
		return "spreading out higher up"
	if most < 14:
		return "far apart higher up: long climbs between clips"
	return "very far apart up high: big falls if you come off"


## A bolt in reach asks to be clipped: one tap. Climb on without it and it
## stays unclipped (a fall then drops you to the last one you did clip).
func _clip() -> void:
	var target := -1
	if climber.state == Climber.State.CLIMB:
		var chest := climber.global_position - Vector2(0, Climber.SIZE.y * 0.5)
		for i in clips.size():
			var c: Dictionary = clips[i]
			var at := Vector2(c["cell"]) * Terrain.TILE + Vector2.ONE * Terrain.TILE / 2.0
			if c["clipped"]:
				continue
			if absf(at.x - chest.x) < CLIP_REACH.x and absf(at.y - chest.y) < CLIP_REACH.y:
				target = i
			elif chest.y < at.y - 2.5 * Terrain.TILE and not c.get("passed", false):
				c["passed"] = true
				hud.flash("You climbed past bolt %d without clipping in. A fall now will be a long one." % (i + 1), 2.4)
	clip_target = target
	if clip_target < 0 or not _tap:
		return
	var c: Dictionary = clips[clip_target]
	# One hand off the rock to clip: what that costs depends on the hold.
	var cost := clip_cost()
	climber.stamina.value = maxf(0.0, climber.stamina.value - float(cost["stamina"]))
	grip = maxf(0.0, grip - float(cost["grip"]))
	last_clip_cost = cost
	c["clipped"] = true
	c["node"].texture.region = Rect2(48, 0, 48, 88)
	checkpoint = maxi(checkpoint, clip_target + 1)
	engage("clip")
	Haptics.tap(15)
	# The rope snapping in: the gate clicks, chalk off the fingers, the
	# quickdraw jumps, a bell.
	Audio.play("clip", -3.0, 0.06)
	Audio.play("cairn", -8.0)
	puff(Vector2(c["cell"]) * Terrain.TILE + Vector2(4, 9), Color(1, 1, 1, 0.8), 10)
	var draw: Node2D = c["node"]
	var tw := create_tween()
	var base := draw.scale
	tw.tween_property(draw, "scale", base * 1.5, 0.08)
	tw.tween_property(draw, "scale", base, 0.2)
	var head := "Clipped! Rest bar full." if int(c["gap"]) >= RUNOUT and clip_target > 0 else "Clipped in."
	if int(c["gap"]) >= RUNOUT and clip_target > 0:
		Audio.play("chime", -4.0)
	var how := ""
	match terrain.hold_at(climber.body_rect()):
		Terrain.Kind.JUG:
			how = " A clean clip from a big hold."
		Terrain.Kind.CRIMP:
			how = " Clipping off tiny holds cost you grip."
	hud.flash("%s Bolt %d of %d.%s Tap %s to rest on the rope." % [head, clip_target + 1, clips.size(), how, _key("REST")], 2.4)
	clip_target = -1
	# A fresh green rest bar with every clip.
	rope_left = ROPE_REST
	# The tap that clipped does not also take the rest.
	_tap = false


## Sitting back on the rope: a little stamina back while you hang there.
## Tap REST to sit back (any time once clipped, while the green bar has some
## left); tap again, or move, to climb on.
func _rope(dt: float) -> void:
	if climber.state != Climber.State.CLIMB:
		resting_rope = false
		return
	var moving := GameInput.move() != Vector2.ZERO
	if resting_rope:
		var give := minf(ROPE_RATE * dt, rope_left)
		climber.stamina.value = minf(climber.stamina.max_value, climber.stamina.value + give)
		rope_left -= give
		if _tap or moving or rope_left <= 0.0 or climber.stamina.value >= climber.stamina.max_value:
			resting_rope = false
			hud.flash("Back on the rock." if rope_left > 0.0 else "Rest bar used up: clip the next bolt for a new one.", 1.6)
		return
	if _tap and can_rest() and not on_crimps:
		resting_rope = true
		rope_rests += 1
		engage("rest")
		hud.flash("You sit back on the rope and shake your arms out.", 1.6)


## The lesson route stops the game the first time each new thing comes up
## and explains it. Returns true while a lesson is showing.
const LESSONS := {
	"rock": ["The rock", "The pale band is rock you can climb. Walk to it, then push the stick UP (or tap CLIMB) to grab on. Climbing uses stamina: the green bar at the top left. Up here, moving and hanging on both use it."],
	"bolt": ["A bolt: clip in", "The metal ring beside you is a bolt. Tap CLIP to clip your rope into it. Once you are clipped, a fall stops at this bolt instead of the ground. Clipping from a big hold is free; from tiny holds it costs grip. On harder climbs the bolts are further apart."],
	"rest": ["Rest on the rope", "Clipped in! The green bar over your head is a rest. Tap REST to sit back on the rope and get stamina back. Moving, or tapping GO, ends the rest. Every new bolt gives you a fresh bar."],
	"crimps": ["Tiny holds", "These are tiny holds (crimps). They burn stamina fast. A grip meter shows over your head: tap GRIP to squeeze when it drops, and keep moving. Stopping on tiny holds drains it fast."],
	"jug": ["A big hold", "This is a big hold (a jug). Hang here and your stamina comes back. Rest on big holds between the bolts."],
	"dyno": ["Jump for it", "There are no holds above you, only blank rock. Press JUMP to leap for the holds higher up (a dyno). When you catch them, tap GRIP 3 times fast to hold on."],
}


func _teach() -> bool:
	var hold := terrain.hold_at(climber.body_rect())
	var checks := {
		"rock": climber.state == Climber.State.GROUND and climber.can_grab(),
		"bolt": clip_target >= 0,
		"rest": checkpoint > 0 and can_rest() and clip_target < 0,
		"crimps": climber.state == Climber.State.CLIMB and hold == Terrain.Kind.CRIMP,
		"jug": climber.state == Climber.State.CLIMB and hold == Terrain.Kind.JUG,
		"dyno": climber.state == Climber.State.CLIMB and dyno_above(),
	}
	for key in LESSONS:
		if lessons_seen.has(key) or not checks[key]:
			continue
		lessons_seen.append(key)
		lesson = key
		climber.lock(true)
		var words: Array = LESSONS[key]
		panel.show_panel("Lesson %d of %d" % [lessons_seen.size(), LESSONS.size()], words[0], words[1], [["lesson", "Got it"]])
		return true
	return false


## A rest on the rope is there to take: clipped in, on the rock, nothing
## else asking for a tap, and green left in the bar.
func can_rest() -> bool:
	return climber.state == Climber.State.CLIMB and checkpoint > 0 and rope_left > 0.0 \
		and catching <= 0.0 and clip_target < 0 and not resting_rope


## Tiny holds: a grip meter that runs down while you are on them (much
## faster if you stop); a squeeze (a tap) brings it back up. A slack grip
## burns stamina fast.
func _grip(dt: float) -> void:
	var now := climber.state == Climber.State.CLIMB and terrain.hold_at(climber.body_rect()) == Terrain.Kind.CRIMP
	if now and not on_crimps:
		grip = 1.0
	on_crimps = now
	if not on_crimps:
		grip = minf(1.0, grip + dt)
		climber.stamina.grip = 1.0
		return
	_grip_cool -= dt
	if catching > 0.0 or resting_rope:
		return
	grip -= grip_drain * (GRIP_STILL if climber.last_activity == "crimp_hang" else GRIP_MOVING) * dt
	if _tap and _grip_cool <= 0.001:
		grip = minf(1.0, grip + GRIP_TAP)
		_grip_cool = GRIP_COOLDOWN
		Audio.play("chalk", -14.0, 0.15)
		puff(climber.global_position - Vector2(0, Climber.SIZE.y), Color(1, 1, 1, 0.6), 4)
	grip = maxf(0.0, grip)
	# A tight grip saves stamina; a slack one burns it.
	# Eased so a grip kept above about half is nearly as good as a full one.
	climber.stamina.grip = lerpf(GRIP_BURN, GRIP_SAVE, sqrt(grip))


func _on_grabbed() -> void:
	engage("grab")
	if _dyno_air:
		_dyno_air = false
		catching = CATCH_TIME
		catch_taps = 0
		hud.flash("Stick it! Tap %s 3 times, fast!" % _key("GRIP"), 1.2)


## Just caught a hold after a dyno: tap fast to stick it, or slip off.
func _catch(dt: float) -> void:
	if climber.state != Climber.State.CLIMB:
		if climber.state != Climber.State.AIR:
			_dyno_air = false
		catching = 0.0
		return
	if catching <= 0.0:
		return
	if _tap:
		catch_taps += 1
		Audio.play("grip", -10.0, 0.2)
		if catch_taps >= CATCH_TAPS:
			catching = 0.0
			engage("catch")
			Haptics.tap(25)
			Audio.play("chalk", -6.0)
			puff(climber.global_position - Vector2(0, Climber.SIZE.y), Color(1, 1, 1, 0.85), 12)
			hud.flash("Stuck it!", 1.0)
			return
	catching -= dt
	if catching <= 0.0:
		climber.peel_off()
		hud.flash("Too slow: the hold slips out of your hands.", 2.0)


## A small burst at `at`: chalk off the hands (white), or dust off the
## ground. Fewer with lower graphics settings.
func puff(at: Vector2, col: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = maxi(2, int(amount * Settings.particle_scale()))
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.gravity = Vector2(0, 14)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = col
	var fade := Gradient.new()
	fade.set_color(0, col)
	fade.set_color(1, Color(col, 0.0))
	p.color_ramp = fade
	p.position = at
	p.z_index = 7
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _key(button: String) -> String:
	return button if Settings.touch_enabled() else "E"


func _draw_rope() -> void:
	var knots: Array[Vector2] = [belayer.global_position - Vector2(0, 12)]
	for c in clips:
		if c["clipped"]:
			knots.append(Vector2(c["cell"]) * Terrain.TILE + Vector2(4, 19))
	knots.append(climber.global_position - Vector2(0, 11))
	# Each span sags a little under its own weight (less when pulled up
	# steeply), drawn as a few points along a curve.
	var pts := PackedVector2Array()
	for i in knots.size() - 1:
		var a := knots[i]
		var b := knots[i + 1]
		var length := a.distance_to(b)
		var slack := clampf(length * 0.05, 0.0, 6.0) * (1.0 - absf(b.y - a.y) / maxf(length, 1.0) * 0.7)
		for k in 8:
			var t := k / 8.0
			pts.append(a.lerp(b, t) + Vector2(0, slack * 4.0 * t * (1.0 - t)))
	pts.append(knots[-1])
	rope.points = pts
	rope_shadow.points = pts
	# The bolt in reach glows.
	_reach_glow.visible = clip_target >= 0
	if clip_target >= 0:
		_reach_glow.position = Vector2(clips[clip_target]["cell"]) * Terrain.TILE + Vector2(4, 10)
		_reach_glow.modulate.a = 0.6 + 0.4 * sin(climber.clock * 6.0)


func _on_slipped(_saved: bool, reason: String) -> void:
	_fall_top = minf(climber.fall_from, climber.global_position.y)
	camera.kick(0.6)
	if checkpoint > 0:
		Audio.play("whip", -6.0, 0.1)
	Haptics.tap(50)
	engage("fall")
	if checkpoint > 0:
		hud.flash("Falling! Falls %d of %d." % [climber.slips, max_slips], 1.2)
	elif reason == "fall":
		hud.flash("You hit the ground: clip the first bolt sooner. Falls %d of %d." % [climber.slips, max_slips], 2.4)


func _on_slip_finished() -> void:
	if _ended:
		return
	if climber.slips >= max_slips:
		finish(false)
		return
	if checkpoint > 0:
		var land := lead_fall_landing(_fall_top)
		last_fall_m = maxf(0.0, (land.y - _fall_top) / Terrain.TILE * Crag.ROW_M)
		if land.y >= _start.y - 0.5 * Terrain.TILE:
			# The bolt was too far below: the rope stretches out and you
			# hit the ground.
			ground_falls += 1
			climber.respawn(_start)
			climber.stamina.value = maxf(1.0, climber.stamina.value - GROUND_HIT)
			Haptics.tap(90)
			Audio.play("thud", -2.0)
			camera.kick(1.0)
			puff(_start, Color("#a58b6c"), 18)
			hud.flash("You hit the ground! A %s m fall, and the bolt was too low to stop it. Clip sooner low down." % Crag._m(snappedf(last_fall_m, 0.5)), 3.0)
		else:
			climber.hang_at(land)
			hud.flash("A %s m fall: the rope catches you below bolt %d." % [Crag._m(snappedf(last_fall_m, 0.5)), checkpoint], 2.4)
		# Hanging on the rope after a fall: a fresh rest bar before you try
		# again.
		rope_left = ROPE_REST
	else:
		climber.respawn(_start)
	camera.snap()


## Where a lead fall from `top_y` (feet, px) ends: as far below the last
## clipped bolt as you were above it, plus slack, on the nearest rock of the
## line there. Below the foot of the cliff is the ground.
func lead_fall_landing(top_y: float) -> Vector2:
	var bolt: Vector2 = clips[checkpoint - 1]["hang"]
	var above := maxf(0.0, bolt.y - top_y)
	var land_y := bolt.y + above + FALL_SLACK
	if land_y >= _start.y - 0.5 * Terrain.TILE:
		return Vector2(bolt.x, _start.y)
	var row := Terrain.cell_of(Vector2(0, land_y)).y
	var col := Terrain.cell_of(bolt).x
	# The nearest rock to hang on, from the landing row up to the bolt.
	for dy in range(0, maxi(1, row - Terrain.cell_of(bolt).y + 1)):
		for dx in [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6]:
			var c := Vector2i(col + dx, row - dy)
			if terrain.is_climbable(c) and terrain.is_climbable(c + Vector2i.UP):
				return Terrain.feet(c)
	return bolt


# --- Words for the HUD ---------------------------------------------------------------

func stats_line(pct: int) -> String:
	return "Stamina %d%% · Falls %d/%d · Clipped %d/%d" % [pct, climber.slips, max_slips, _clipped(), clips.size()]


func _clipped() -> int:
	var n := 0
	for c in clips:
		if c["clipped"]:
			n += 1
	return n


## The crag's own advice, ahead of the HUD's general hints.
func hint_now() -> String:
	if climber.state != Climber.State.CLIMB:
		return ""
	if resting_rope:
		return "Resting on the rope: stamina coming back. Tap %s or move to climb on." % _key("GO")
	if catching > 0.0:
		return "Stick it! Tap %s 3 times, fast (%d/%d)." % [_key("GRIP"), catch_taps, CATCH_TAPS]
	if clip_target >= 0:
		var cost := clip_cost()
		var tip := " A big hold nearby? Clip from there, it's free." if terrain.hold_at(climber.body_rect()) == Terrain.Kind.CRIMP else ""
		return "A bolt. Clip in? Tap %s: %s.%s" % [_key("CLIP"), cost["words"], tip]
	if on_crimps:
		if grip < 0.5:
			return "Grip fading: tap %s to squeeze (grip %d%%), and keep moving." % [_key("GRIP"), int(grip * 100.0)]
		return "Tiny holds: keep moving. Squeeze with %s when the grip drops below half." % _key("GRIP")
	var key := "JUMP" if Settings.touch_enabled() else "SPACE"
	var hold := terrain.hold_at(climber.body_rect())
	if dyno_above():
		return "No holds above. Press %s to jump for the next hold (a dyno)." % key
	if hold == Terrain.Kind.JUG and stamina.fraction() < 0.95:
		return "A big hold (a jug): stay here to get your stamina back."
	if can_rest() and stamina.fraction() < 0.9:
		return "Tired? Tap %s to rest on the rope (the green bar)." % _key("REST")
	return ""


## Holds within dyno reach above the hands, across blank rock.
func dyno_above() -> bool:
	var top := Terrain.cell_of(climber.body_rect().position)
	for x in [top.x, Terrain.cell_of(climber.body_rect().end - Vector2(1, 0)).x]:
		var blank := false
		for dy in range(1, 4):
			var c := Vector2i(x, top.y - dy)
			if terrain.is_solid(c):
				return false
			if terrain.is_climbable(c):
				return blank
			blank = true
	return false


func engage(kind: String) -> void:
	pace_log.append([climber.clock, kind])


# --- Menus and the end ------------------------------------------------------------

## The app went to the background, or the window lost focus: pause, so a
## climber is never left hanging on a clock nobody is watching.
func _on_interrupted() -> void:
	if _ended or previewing or panel.open or climber == null:
		return
	pause_menu()


func _on_back() -> void:
	if _ended:
		return
	if previewing:
		_skip_preview = true
	elif not panel.open:
		pause_menu()


func _tie_in() -> void:
	briefed = true
	Crag.tie_in(route["id"])
	climber.lock(false)


func pause_menu() -> void:
	climber.lock(true)
	panel.show_panel("Paused", route["name"], "Lowering off ends this go. The route will still be here.", [
		["resume", "Resume"],
		["look", "Look at the route"],
		["lower", "Lower off"],
		["settings", "Settings"],
		["menu", "Back to the routes"],
	])


## Settings, a page of their own so the pause menu stays short on a phone.
func settings_menu() -> void:
	climber.lock(true)
	panel.show_panel("Settings", route["name"], "", [
		["touch", "Touch controls: %s" % ("On" if Settings.touch_enabled() else "Off")],
		["quality", "Graphics: %s" % ["Full", "Reduced", "Low power"][Settings.quality]],
		["motion", "Reduced motion: %s" % ("On" if Settings.reduced_motion else "Off")],
		["haptics", "Vibration: %s" % ("On" if Settings.haptics else "Off")],
		["fps", "Show FPS: %s" % ("On" if Settings.show_fps else "Off")],
		["paused", "Back"],
	])


func _on_choice(id: String) -> void:
	match id:
		"start":
			_tie_in()
		"neutral", "aggressive":
			wear(id)
			_tie_in()
			hud.flash("%s on: %s" % [Crag.SHOES[id]["name"], "slower, less stamina" if id == "neutral" else "faster, more stamina"])
		"lesson":
			lesson = ""
			climber.lock(false)
		"look":
			preview()
		"beta":
			beta = true
			Crag.take_beta(route["id"])
			panel.show_panel("Beta · %s" % route["grade"], route["name"], beta_tips(), [["brief", "Got it"]])
		"brief":
			brief()
		"resume":
			climber.lock(false)
		"lower":
			finish(false)
		"touch":
			Settings.set_touch_controls(not Settings.touch_enabled())
			TouchControls.attach(self)
			settings_menu()
		"fps":
			Settings.set_show_fps(not Settings.show_fps)
			settings_menu()
		"quality":
			Settings.set_quality((Settings.quality + 1) % 3)
			Scenery.apply_quality(self)
			settings_menu()
		"motion":
			Settings.set_reduced_motion(not Settings.reduced_motion)
			settings_menu()
		"haptics":
			Settings.set_haptics(not Settings.haptics)
			Haptics.tap(30)
			settings_menu()
		"settings":
			settings_menu()
		"paused":
			pause_menu()
		"again":
			Crag.climb(route["id"])
		"next":
			Crag.climb(outcome.get("unlocked", route["id"]))
		"menu":
			Crag.go(Crag.MENU)


func finish(sent: bool) -> void:
	if _ended:
		return
	_ended = true
	result = "sent" if sent else "lowered"
	if sent:
		climber.state = Climber.State.DONE
		Audio.play("cairn", -2.0)
		Haptics.tap(40)
	else:
		climber.lock(true)
	panel.hide_panel()
	outcome = Crag.finish(route["id"], sent, climber.slips, int(climber.clock), checkpoint)
	outcome["sent"] = sent
	outcome["falls"] = climber.slips
	outcome["seconds"] = int(climber.clock)
	finished.emit(outcome)
	var lines: Array = []
	var head := "Lowered off"
	if sent:
		var style: Array = Crag.STYLES[outcome["style"]]
		head = style[0] + "!"
		lines.append(style[1])
		if outcome["better"]:
			lines.append("Your best on this route.")
	else:
		lines.append("Bolts clipped: %d of %d.%s Rest up and try again." % [checkpoint, clips.size(), " A new high point!" if outcome.get("highpoint", false) else ""])
	lines.append("Falls: %d%s · %d min %02d s · %d moves · dynos: %d" % [climber.slips, (" (%d to the ground)" % ground_falls) if ground_falls > 0 else "", int(climber.clock) / 60, int(climber.clock) % 60, climber.moves, climber.dynos])
	if shoes != "":
		lines.append("In %s." % String(Crag.SHOES[shoes]["name"]).to_lower())
	outcome["shoes"] = shoes
	var choices: Array = []
	if outcome.get("unlocked", "") != "":
		var next := Crag.route(outcome["unlocked"])
		lines.append("New route open: %s (%s)." % [next["name"], next["grade"]])
		choices.append(["next", "Climb %s" % next["name"]])
	choices.append(["again", "Climb it again"])
	choices.append(["menu", "Back to the routes"])
	hud.flash(head)
	await get_tree().create_timer(1.0 if is_inside_tree() else 0.0).timeout
	if is_inside_tree():
		panel.show_panel("The crag · grade %s" % route["grade"], "%s · %s" % [head, route["name"]], "\n".join(lines), choices)
