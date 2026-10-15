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
const GRIP_SAVE := 0.5
const GRIP_BURN := 1.35
## A lead fall: twice as far as you were above the last clipped bolt, plus
## the slack in the system. Land below the ground and you hit it.
const FALL_SLACK := 1.0 * Terrain.TILE
const GROUND_HIT := 25.0
## A dyno: leap from the rock, and the hands catch the hold they reach, on
## their own. Timing is a bonus, never a trap: a tap of GRIP from
## CATCH_EARLY before the hands arrive to CATCH_PERFECT after is a perfect
## catch, which gives back half the jump's cost. Missing the timing (or
## tapping in the air) costs nothing.
const CATCH_EARLY := 0.15
const CATCH_PERFECT := 0.15
## Slopers: rounded holds held by friction. Moving on them loses grip
## (SLOPER_SLIDE a second at full speed, by the square of the speed, so
## half speed loses a quarter), holding still lets it settle back
## (SLOPER_SETTLE a second). Squeezing does nothing on an open hand. Out of
## grip, you slide off. The technique is a steady pace with pauses.
const SLOPER_SLIDE := 0.75
const SLOPER_SETTLE := 0.9
## Stamina to clip from a pocket (one hand stays in, the other clips).
const CLIP_POCKET := 1.0
## Why you came off, and what to try next time.
const FALL_LESSONS := {
	"pump": "Pumped: your stamina ran out. Rest on big holds, pockets and the rope before the hard bits.",
	"crimps": "Pumped on the tiny holds. Keep moving on them, and squeeze GRIP when the meter drops below half.",
	"sloper": "Slid off a sloper. Move slowly on them and pause to let your grip settle.",
	"ground": "Hit the ground: the first bolts were too far below. Clip as soon as you can low down.",
}
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
var on_slopers := false
## A dyno: in the air (_dyno_air), the hands' height at the hold it goes for
## (dyno_target_y, px), the window after contact (catching), how the last
## one was caught (catch_quality: perfect, good, late, flail).
var catching := 0.0
var catch_quality := ""
var dyno_target_y := INF
var perfect_catches := 0
var _air_taps := 0
var _air_tap_at := -INF
var _dyno_air := false
## Why the last fall happened (a FALL_LESSONS key) and its lesson; every
## fall's cause this go.
var fall_cause := ""
var falls_by_cause: Dictionary = {}
var _cause := ""
var _last_hold: int = Terrain.Kind.AIR
## The highest the feet got on this go, in rows above the ground.
var high_rows := 0
## Seconds shaking out on big holds this go.
var shakeout_seconds := 0.0
## Bolts clipped from a good hold (a jug, a pocket, ordinary rock), and the
## lowest the grip went on slopers (1 when it never did).
var good_clips := 0
var min_sloper_grip := 1.0
## Squeezes that did nothing useful: with the grip still above
## WASTED_ABOVE, or the third and later taps of a flurry (each inside the
## cooldown of the last: mashing). A quick double tap is not counted.
var wasted_squeezes := 0
var _squeeze_queued := false
const WASTED_ABOVE := 0.7
var _burst := 0
var _shake := 0.0
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
	terrain = Terrain.from_text(Crag.map_text(route["id"]))
	# `pump`: how much every move on this route costs, so the grades climb
	# in steady steps (Crag.ROUTES).
	stamina = StaminaModel.new(100.0, 1.0, float(route.get("pump", 1.0)))
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
	_mark_high_point()

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
	climber.dynoed.connect(_on_dyno)
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
	Audio.play_music("crag")
	if Crag.quick_retry:
		Crag.quick_retry = false
		quick_start()
	else:
		brief()


## Straight back onto the rock after Retry: the same shoes, no brief, the
## go counted once at tie-in. The brief, the route preview and beta are
## still in the pause menu and behind "Change shoes" on the results.
func quick_start() -> void:
	quick_started = true
	if not route.get("tutorial", false):
		wear(Crag.shoes)
	_tie_in()
	var best := ""
	if prev_high_rows > 0 and not _sent_before():
		best = " Your best: %s up." % _m_rows(prev_high_rows)
	hud.flash("Again! %s.%s" % ["Tie in" if route.get("tutorial", false) else Crag.SHOES[shoes]["name"], best], 1.6)


func _sent_before() -> bool:
	if is_daily():
		return int(Crag.daily_record()["sends"]) > 0
	return int(Crag.record(route["id"])["sends"]) > 0


static func _m_rows(rows: int) -> String:
	return "%s m" % Crag._m(rows * Crag.ROW_M)


## Rows from the foot of the line to the anchor.
func route_rows() -> int:
	return int(round((_start.y - _top_y) / Terrain.TILE))


func mate_name() -> String:
	return ""


func is_daily() -> bool:
	return route.get("id", "") == "daily"


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


## Small holds, one drawn on each cell (slopers and pockets on every other
## cell, staggered): crimps are little edges, slopers round grey domes,
## pockets dark holes. Each has its own shape and colour, so the line reads
## at a glance. Jugs are drawn whole (_place_jugs).
const HOLD_ART := {
	Terrain.Kind.CRIMP: "res://assets/crag/crimp-hd.png",
	Terrain.Kind.SLOPER: "res://assets/crag/sloper-hd.png",
	Terrain.Kind.POCKET: "res://assets/crag/pocket-hd.png",
}


func _place_holds() -> void:
	_hold_tex = load("res://assets/crag/crimp-hd.png")
	for y in terrain.height:
		for x in terrain.width:
			var k := terrain.kind(Vector2i(x, y))
			if not HOLD_ART.has(k):
				continue
			if k != Terrain.Kind.CRIMP and posmod(x + y, 2) == 1:
				continue
			var s := _hd_sprite(HOLD_ART[k])
			s.centered = false
			s.position = Vector2(x, y) * Terrain.TILE
			s.flip_h = posmod(x * 7 + y * 3, 2) == 1
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


## Not sent yet but tried: a chalk line across the route at the highest
## you have been, so the next go has something to beat.
var high_mark: Node2D
## The best height before this go (rows up the wall from the foot), and
## where along the wall it was: for the chalk mark, passing it mid-climb,
## and near-miss words. Daily routes keep their own, per day.
var prev_high_rows := 0
var prev_high_x := 0
var high_x := 0
var _passed_high := false
## This go began with one tap from the results (no menu, no brief).
var quick_started := false
## Milliseconds from the Retry tap to playable, or -1.
var retry_ms := -1
## The near-miss words this go ended with ("" when there was none).
var near_miss := ""
## What happened on this go, for the records service to check (Records):
## [seconds, kind, data] for the tie-in, each clip, fall, rest and catch,
## the height once a second, and the end.
var attempt_log: Array = []
var _log_next := 1.0


func log_event(kind: String, info: Variant = null) -> void:
	attempt_log.append([snappedf(climber.clock if climber else 0.0, 0.01), kind, info])


func _mark_high_point() -> void:
	var rec := Crag.daily_record() if is_daily() else Crag.record(route["id"])
	prev_high_rows = int(rec.get("highRows", 0))
	prev_high_x = int(rec.get("highX", 0))
	high_mark = Node2D.new()
	high_mark.z_index = 3
	add_child(high_mark)
	if _sent_before():
		# Topped before: the record is the time, written by the anchor.
		var secs := int(rec.get("bestSeconds", -1))
		if secs > 0:
			var anchor := Terrain.feet(terrain.markers["X"][0])
			_chalk_label("best %s" % _clock(secs), anchor + Vector2(12, -18))
		return
	if prev_high_rows <= 2:
		return
	# A chalk tick on the rock either side of the line at the best height,
	# never across the holds, and a small word beside it.
	var y := _start.y - prev_high_rows * Terrain.TILE
	var row := Terrain.cell_of(Vector2(0, y - 1)).y
	var xs: Array = []
	for x in terrain.width:
		if terrain.is_climbable(Vector2i(x, row)):
			xs.append(x)
	if xs.is_empty():
		return
	var left: float = xs.min() * Terrain.TILE
	var right: float = (xs.max() + 1) * Terrain.TILE
	for seg in [[left - 11.0, left - 3.0], [right + 3.0, right + 11.0]]:
		var line := Line2D.new()
		line.width = 1.6
		line.default_color = Color(1, 1, 1, 0.55)
		line.points = PackedVector2Array([Vector2(seg[0], y), Vector2(seg[1], y)])
		high_mark.add_child(line)
	_chalk_label("best %s" % _m_rows(prev_high_rows), Vector2(right + 13.0, y - 6.0))


func _chalk_label(text: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	l.add_theme_constant_override("outline_size", 3)
	if UiFont.body():
		l.add_theme_font_override("font", UiFont.body())
	l.position = at
	high_mark.add_child(l)


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
		Terrain.Kind.SLOPER:
			return {"stamina": CLIP_CRIMP, "grip": CLIP_CRIMP_GRIP, "words": "off a sloper it costs grip: settle first"}
		Terrain.Kind.POCKET:
			return {"stamina": CLIP_POCKET, "grip": 0.0, "words": "from a pocket it costs very little"}
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
	if is_daily():
		Crag.see_daily()
		var d := Crag.daily_record()
		kicker = "Daily route · %s · grade %s" % [route["date"], route["grade"]]
		history = "First go today: climb it clean for an onsight."
		if int(d["sends"]) > 0:
			history = "Today: %s in %s, %d go%s." % [Crag.STYLES[d["best"]][0], _clock(int(d["bestSeconds"])), int(d["attempts"]), "" if int(d["attempts"]) == 1 else "s"]
		elif int(d["attempts"]) > 0:
			history = "%d go%s today, not topped yet." % [int(d["attempts"]), "" if int(d["attempts"]) == 1 else "s"]
		if not Crag.daily_counts():
			history = "Your device's date is earlier than a day you have already played, so today's goes are practice: they will not be logged."
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
	if not route.get("tutorial", false) and not is_daily() and not beta and int(r["sends"]) == 0:
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
		tips.append("%s across blank rock: jump from the top of the holds below and your hands catch the hold. Tap GRIP as you arrive for a perfect catch." % ("A leap" if dyno_count() == 1 else "%d leaps" % dyno_count()))
	if _count_kind(Terrain.Kind.SLOPER) > 0:
		tips.append("Slopers (round grey holds): move slowly, and pause on them to let your grip settle. Squeezing does not help.")
	if _count_kind(Terrain.Kind.POCKET) > 0:
		tips.append("Pockets (dark holes): hang on them for free. Good places to clip and to wait.")
	tips.append("On the tiny holds, keep moving: one squeeze of GRIP when the meter drops below half. Stopping drains it fast.")
	return "\n".join(tips)


func _count_kind(k: int) -> int:
	var n := 0
	for i in terrain.kinds.size():
		if terrain.kinds[i] == k:
			n += 1
	return n


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
	if quick_started and retry_ms < 0 and climber.state != Climber.State.LOCKED:
		retry_ms = maxi(0, Crag.retry_landed())
	if briefed and climber.clock >= _log_next:
		_log_next = floorf(climber.clock) + 1.0
		log_event("h", high_rows)
	var pressed := GameInput.pressed_now("interact")
	_tap = pressed and not panel.open and not previewing
	if previewing:
		# pressed_now() is an edge each caller consumes: read it here, once.
		if pressed or GameInput.pressed_now("jump") or GameInput.pressed_now("pause"):
			_skip_preview = true
		return
	if _tap:
		var kind := "catch" if catching > 0.0 or _dyno_air else action_word.to_lower()
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
	_sloper(dt)
	_clip()
	_rope(dt)
	_shakeout(dt)
	if climber.state == Climber.State.GROUND:
		_cause = ""
	if climber.state == Climber.State.CLIMB:
		_last_hold = terrain.hold_at(climber.body_rect())
		var up := int((_start.y - climber.global_position.y) / Terrain.TILE)
		if up > high_rows:
			high_rows = up
			high_x = int(climber.global_position.x)
		# Past your best, while it happens: once a go, never on a first go.
		if not _passed_high and prev_high_rows > 2 and high_rows > prev_high_rows and not _sent_before():
			_passed_high = true
			hud.flash("NEW HIGH POINT", 1.4)
			Audio.play("record", -6.0, 0.0)
			Haptics.tap(25)
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
	elif catching > 0.0 or _dyno_air:
		action_word = "GRIP"
		prompt = "Catch it!"
	elif clip_target >= 0:
		action_word = "CLIP"
		prompt = "Clip in?"
	elif on_crimps:
		action_word = "GRIP"
		prompt = "Grip! (%d%%)" % int(grip * 100.0)
	elif on_slopers:
		prompt = "Sloper: slow and steady (%d%%)" % int(grip * 100.0)
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
	var from := terrain.hold_at(climber.body_rect())
	if from != Terrain.Kind.CRIMP and from != Terrain.Kind.SLOPER:
		good_clips += 1
	c["clipped"] = true
	c["node"].texture.region = Rect2(48, 0, 48, 88)
	checkpoint = maxi(checkpoint, clip_target + 1)
	log_event("clip", [clip_target, int((_start.y - climber.global_position.y) / Terrain.TILE)])
	engage("clip")
	Haptics.tap(28)
	# The rope snapping in: one click of the gate (louder than any chime),
	# chalk off the fingers, the quickdraw jumps.
	Audio.play("clip", -2.0, 0.06, false)
	puff(Vector2(c["cell"]) * Terrain.TILE + Vector2(4, 9), Color(1, 1, 1, 0.8), 10)
	var draw: Node2D = c["node"]
	if not Settings.reduced_motion:
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
		log_event("rest", checkpoint)
		engage("rest")
		hud.flash("You sit back on the rope and shake your arms out.", 1.6)


## The lesson route stops the game the first time each new thing comes up
## and explains it. Returns true while a lesson is showing.
## Short on purpose: one idea each, two sentences at most. The game says
## the rest as it happens (the HUD hints).
const LESSONS := {
	"rock": ["The rock", "Walk to the pale rock and push UP (or tap CLIMB) to grab it. Climbing uses stamina: the bar at the top left."],
	"bolt": ["Clip in", "Tap CLIP to clip your rope to this bolt. If you fall now, it catches you."],
	"rest": ["Rest on the rope", "The green bar over your head is a rest: tap REST to sit back and get stamina back. Every bolt you clip refills it."],
	"crimps": ["Tiny holds", "Tiny holds drain you fast: the seconds beside your stamina are how long your arms last here. Keep moving, and tap GRIP once when the meter over your head drops below half."],
	"jug": ["A big hold", "Stay on big holds to shake out and get your stamina back."],
	"dyno": ["Jump for it", "No holds above: press JUMP to leap, and your hands catch the hold. Tap GRIP just as you arrive for a perfect catch: stamina back."],
	"fall": ["You fell. That's fine.", "The rope caught you at your last bolt. Climb on from here: falls are how you learn a route."],
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
		"fall": climber.slips > 0 and climber.state != Climber.State.SLIP and climber.state != Climber.State.AIR,
	}
	for key in LESSONS:
		if lessons_seen.has(key) or not checks[key]:
			continue
		lessons_seen.append(key)
		if Crag.lessons_seen.has(key):
			# Seen on an earlier go: a short reminder, the game keeps going.
			hud.flash("%s: %s" % LESSONS[key], 2.6)
			continue
		Crag.see_lesson(key)
		lesson = key
		climber.lock(true)
		var words: Array = LESSONS[key]
		# Up top, so the climber and the button the tip is about stay in view.
		panel.at_top = true
		panel.show_panel("First climb · tip %d" % lessons_seen.size(), words[0], words[1], [["lesson", "Got it"]])
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
	if now and not on_crimps and not on_slopers:
		grip = 1.0
	on_crimps = now
	if not on_crimps:
		if not on_slopers:
			grip = minf(1.0, grip + dt)
		climber.stamina.grip = 1.0
		return
	_grip_cool -= dt
	if catching > 0.0 or resting_rope:
		return
	grip -= grip_drain * (GRIP_STILL if climber.last_activity == "crimp_hang" else GRIP_MOVING) * dt
	# A tap is a squeeze only when the button says GRIP (not when it was
	# for a clip or a rest).
	var squeeze := _tap and action_word == "GRIP"
	if squeeze:
		_burst = _burst + 1 if _grip_cool > 0.001 else 0
		if grip > WASTED_ABOVE or _burst >= 2:
			wasted_squeezes += 1
		# A tap during the cooldown waits for it, so no tap goes unanswered;
		# it answers at once with a quiet, lower tick (it adds no grip now).
		if _grip_cool > 0.001:
			_squeeze_queued = true
			Audio.play("chalk", -16.0, 0.0, false, 0.75)
	if (squeeze or _squeeze_queued) and _grip_cool <= 0.001:
		_squeeze_queued = false
		grip = minf(1.0, grip + GRIP_TAP)
		_grip_cool = GRIP_COOLDOWN
		# An accepted squeeze: felt and heard over the music.
		Haptics.tap(15)
		Audio.play("chalk", -10.0, 0.15, false)
		puff(climber.global_position - Vector2(0, Climber.SIZE.y), Color(1, 1, 1, 0.6), 4)
	grip = maxf(0.0, grip)
	# A tight grip saves stamina; a slack one burns it.
	# Eased so a grip kept above about half is nearly as good as a full one.
	climber.stamina.grip = lerpf(GRIP_BURN, GRIP_SAVE, sqrt(grip))


## Slopers: grip slides away as you move (by the square of your speed) and
## settles back while you hold still. Out of grip, you come off.
func _sloper(dt: float) -> void:
	var now := climber.state == Climber.State.CLIMB and terrain.hold_at(climber.body_rect()) == Terrain.Kind.SLOPER
	if now and not on_slopers and not on_crimps:
		grip = 1.0
	on_slopers = now
	if not on_slopers or catching > 0.0 or resting_rope:
		return
	# How fast, as a share of full speed on each axis.
	var v := climber.get_real_velocity()
	var speed := clampf(maxf(absf(v.y) / (Climber.CLIMB_UP * climber.pace), absf(v.x) / (Climber.CLIMB_SIDE * climber.pace)), 0.0, 1.0)
	if speed > 0.05:
		grip -= SLOPER_SLIDE * (0.5 + grip_drain) * speed * speed * dt
	else:
		grip = minf(1.0, grip + SLOPER_SETTLE * dt)
	var before := grip
	grip = maxf(0.0, grip)
	min_sloper_grip = minf(min_sloper_grip, grip)
	if before < 0.3 and int(climber.clock * 4.0) != int((climber.clock - dt) * 4.0):
		Haptics.tap(8)
	if grip <= 0.0:
		_cause = "sloper"
		Audio.play("slip", -8.0)
		climber.peel_off()


## Shaking out on a big hold: still, with stamina to win back. Chalk off the
## hands now and then, so the rest is something you see.
func _shakeout(dt: float) -> void:
	if climber.state != Climber.State.CLIMB or climber.last_activity != "jug" or stamina.fraction() >= 0.99:
		_shake = 0.0
		return
	shakeout_seconds += dt
	_shake += dt
	if _shake >= 1.1:
		_shake = 0.0
		Audio.play("chalk", -16.0, 0.2)
		puff(climber.global_position - Vector2(4 * climber.facing, Climber.SIZE.y * 0.6), Color(1, 1, 1, 0.5), 3)


## Off the rock for a dyno: the hold it goes for is the first climbable
## row above the blank, where the hands will be.
func _on_dyno() -> void:
	engage("dyno")
	_dyno_air = true
	_air_taps = 0
	_air_tap_at = -INF
	catch_quality = ""
	camera.kick(0.2)
	dyno_target_y = INF
	var hands := climber.body_rect().position
	var top := Terrain.cell_of(hands)
	for dy in range(1, 6):
		var c := Vector2i(Terrain.cell_of(climber.global_position).x, top.y - dy)
		if terrain.is_climbable(c) and not terrain.is_climbable(c + Vector2i.DOWN):
			dyno_target_y = (c.y + 1) * Terrain.TILE
			break


func _on_grabbed() -> void:
	engage("grab")
	if _dyno_air:
		_dyno_air = false
		if climber.clock - _air_tap_at <= CATCH_EARLY:
			_stick(true)
			return
		# On the rock: the hands have it. A tap in the next moment still
		# makes it a perfect catch.
		_stick(false)
		catching = CATCH_PERFECT


## In the air after a dyno, and the catch window once the hands touch: one
## well-timed tap sticks it.
func _catch(dt: float) -> void:
	if climber.state == Climber.State.AIR and _dyno_air:
		if _tap:
			# A tap close to the hold is a reach; one far from it is a snatch.
			var hands_y := climber.body_rect().position.y
			if dyno_target_y < INF and hands_y - dyno_target_y > 1.2 * Terrain.TILE:
				# Too early to count as a reach; harmless.
				_air_taps += 1
			else:
				_air_tap_at = climber.clock
		return
	if climber.state != Climber.State.CLIMB:
		if climber.state != Climber.State.AIR:
			_dyno_air = false
		catching = 0.0
		return
	if catching <= 0.0:
		return
	if _tap:
		# Right on the contact: upgrade to a perfect catch.
		_stick(true)
		return
	catching -= dt


## The catch. A perfect one (right on the contact) gives back half the
## jump's stamina.
func _stick(perfect: bool) -> void:
	var upgrade := catching > 0.0 and catch_quality == "good"
	catching = 0.0
	# The tap that caught the hold does nothing else (no clip, no squeeze).
	_tap = false
	catch_quality = "perfect" if perfect else "good"
	if not upgrade:
		log_event("catch", catch_quality)
		engage("catch")
	Haptics.tap(45 if perfect else 22)
	Audio.play("catch", -4.0 if perfect else -7.0, 0.05)
	puff(climber.global_position - Vector2(0, Climber.SIZE.y), Color(1, 1, 1, 0.9), 16 if perfect else 10)
	if perfect:
		perfect_catches += 1
		climber.stamina.value = minf(climber.stamina.max_value, climber.stamina.value + Climber.DYNO_COST * 0.5)
		# A perfect catch hits like an impact: a hold, then a kick.
		HitStop.freeze(self)
		camera.kick(0.5, 9.0)
		Audio.play("perfect", -6.0, 0.0)
		hud.flash("Perfect catch!", 1.2)
	else:
		hud.flash("Caught it.", 1.0)


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
		_reach_glow.modulate.a = 0.8 if Settings.reduced_motion else 0.6 + 0.4 * sin(climber.clock * 6.0)


func _on_slipped(_saved: bool, reason: String) -> void:
	log_event("fall", [reason, int((_start.y - climber.global_position.y) / Terrain.TILE)])
	_fall_top = minf(climber.fall_from, climber.global_position.y)
	fall_cause = _cause
	if fall_cause == "":
		if stamina.is_empty() or stamina.fraction() < 0.05:
			fall_cause = "crimps" if _last_hold == Terrain.Kind.CRIMP else "pump"
		elif _last_hold == Terrain.Kind.SLOPER:
			fall_cause = "sloper"
		else:
			fall_cause = "pump"
	if checkpoint == 0 and reason == "fall" and _cause == "":
		fall_cause = "ground"
	_cause = ""
	falls_by_cause[fall_cause] = int(falls_by_cause.get(fall_cause, 0)) + 1
	camera.kick(0.6)
	if checkpoint > 0:
		Audio.play("whip", -6.0, 0.1)
	Haptics.tap(50)
	engage("fall")
	if checkpoint > 0:
		hud.flash("Falling! Falls %d of %d." % [climber.slips, max_slips], 1.2)
	elif reason == "fall":
		var why: String = FALL_LESSONS.get(fall_cause, "") if fall_cause != "ground" else "Clip the first bolt sooner."
		hud.flash("You hit the ground. %s Falls %d of %d." % [why, climber.slips, max_slips], 3.0)


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
			_impact(1.3)
			puff(_start, Color("#a58b6c"), 18)
			hud.flash("You hit the ground! A %s m fall, and the bolt was too low to stop it. %s" % [Crag._m(snappedf(last_fall_m, 0.5)), FALL_LESSONS.get(fall_cause, "")], 3.6)
		else:
			climber.hang_at(land)
			_impact(1.0)
			hud.flash("A %s m fall: the rope catches you below bolt %d. %s" % [Crag._m(snappedf(last_fall_m, 0.5)), checkpoint, FALL_LESSONS.get(fall_cause, "")], 3.6)
		# Hanging on the rope after a fall: a fresh rest bar before you try
		# again.
		rope_left = ROPE_REST
	else:
		climber.respawn(_start)
		_impact(1.0)
		hud.flash(FALL_LESSONS.get(fall_cause, ""), 3.2)
	camera.snap()


## The moment a fall ends (the rope catches, or the ground): the world
## holds for a few frames, then one short hard kick. Reduced motion keeps
## the hold and skips the kick (ExpeditionCamera.kick).
func _impact(strength: float) -> void:
	HitStop.freeze(self)
	camera.kick(strength, 9.0)


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
	# The hold's clock beside the bar: how long the arms last here, or that
	# this hold gives them back.
	var here := ""
	if climber.state == Climber.State.CLIMB:
		var secs := arms_seconds()
		if not is_inf(secs) and secs <= 45.0:
			here = " (%d s here)" % maxi(1, int(secs))
		elif stamina.rate(climber.last_activity) < 0.0 and stamina.fraction() < 0.99:
			here = " (resting)"
	return "Stamina %d%%%s · Falls %d/%d · Clipped %d/%d" % [pct, here, climber.slips, max_slips, _clipped(), clips.size()]


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
		return "Now! Tap %s to catch it." % _key("GRIP")
	if clip_target >= 0:
		var cost := clip_cost()
		var tip := " A big hold nearby? Clip from there, it's free." if terrain.hold_at(climber.body_rect()) == Terrain.Kind.CRIMP else ""
		return "A bolt. Clip in? Tap %s: %s.%s" % [_key("CLIP"), cost["words"], tip]
	if on_slopers:
		if grip < 0.4:
			return "Sliding! Stop and let your grip settle (%d%%)." % int(grip * 100.0)
		return "Slopers: move slowly, pause to settle. Squeezing does not help here.%s" % arms_words()
	if on_crimps:
		if grip < 0.5:
			return "Grip fading: tap %s to squeeze (grip %d%%), and keep moving.%s" % [_key("GRIP"), int(grip * 100.0), arms_words()]
		return "Tiny holds: keep moving. Squeeze with %s when the grip drops below half.%s" % [_key("GRIP"), arms_words()]
	var key := "JUMP" if Settings.touch_enabled() else "SPACE"
	var hold := terrain.hold_at(climber.body_rect())
	if dyno_above():
		return "No holds above. Press %s to jump for the next hold (a dyno)." % key
	if hold == Terrain.Kind.JUG and stamina.fraction() < 0.95:
		return "A big hold (a jug): stay here and shake out to get your stamina back."
	if hold == Terrain.Kind.POCKET and stamina.fraction() < 0.9:
		return "A pocket: hanging here costs nothing. Wait, clip, plan the next bit."
	if can_rest() and stamina.fraction() < 0.9:
		return "Tired? Tap %s to rest on the rope (the green bar).%s" % [_key("REST"), arms_words()]
	var side := traverse_dir()
	if side != 0:
		return "The line goes sideways here: move %s along the band." % ("right" if side > 0 else "left")
	return ""


## How long the arms last on the hold you are on, doing what you are doing:
## each kind of hold costs its own amount a second (StaminaModel.RATES),
## so a stretch of tiny holds is a clock and a jug or a pocket stops it.
func arms_seconds() -> float:
	if climber.state != Climber.State.CLIMB:
		return INF
	return stamina.seconds_left(climber.last_activity)


func arms_words() -> String:
	var secs := arms_seconds()
	if is_inf(secs) or secs > 45.0:
		return ""
	return " Arms last about %d s here." % maxi(1, int(secs))


## When the hands are at the top of the rock but the line carries on along
## a band to one side: which way (1 right, -1 left), else 0.
func traverse_dir() -> int:
	var hands := climber.body_rect().position + Vector2(0, 4)
	var row := Terrain.cell_of(hands).y
	var col := Terrain.cell_of(climber.global_position).x
	if terrain.is_climbable(Vector2i(col, row - 1)) or terrain.is_solid(Vector2i(col, row - 1)):
		return 0
	if Terrain.cell_of(Terrain.feet(terrain.markers["X"][0])).y >= row - 2:
		return 0
	for dir in [1, -1]:
		for k in range(1, 14):
			var x: int = col + dir * k
			if not terrain.is_climbable(Vector2i(x, row)) and not terrain.is_climbable(Vector2i(x, row + 1)):
				break
			if terrain.is_climbable(Vector2i(x, row - 1)):
				return dir
	return 0


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
	attempt_log = []
	log_event("tie_in", shoes)
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
	panel.show_panel("Settings", route["name"], "", SettingsMenu.choices() + [["paused", "Back"]])


func _on_choice(id: String) -> void:
	if SettingsMenu.apply(id, self):
		settings_menu()
		return
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
		"settings":
			settings_menu()
		"paused":
			pause_menu()
		"retry":
			Crag.retry(route["id"])
		"again":
			Crag.climb(route["id"])
		"next":
			Crag.climb(outcome.get("unlocked", route["id"]))
		"suggested":
			Crag.climb(outcome.get("suggested", route["id"]))
		"share":
			share()
		"menu":
			Crag.go(Crag.MENU)


## Shares today's result: the text goes to the clipboard (paste it
## anywhere), and the picture card is saved (and downloaded on the web).
func share() -> void:
	var text := Crag.daily_share_text()
	shared_text = text
	DisplayServer.clipboard_set(text)
	Analytics.event("daily_shared", {"date": route.get("date", "")})
	hud.flash("Result copied: paste it anywhere.", 2.4)
	# Back to the results at once, so there is always a way on (the card
	# is drawn in the background).
	if not _results_panel.is_empty():
		panel.show_panel(_results_panel[0], _results_panel[1], _results_panel[2], _results_panel[3])
	var lines: Array = text.split("\n").slice(2)
	var path: String = await ShareCard.save(self, route, lines)
	if path != "" and is_inside_tree():
		hud.flash("Result copied, and the card saved%s." % (" (downloading)" if OS.has_feature("web") else ""), 2.4)


## The results card as last shown: [kicker, title, body, choices].
var _results_panel: Array = []
## The last result shared (for tests).
var shared_text := ""


## What this go was like, for the logbook (Logbook.challenge_done) and the
## results card.
func go_stats() -> Dictionary:
	return {"grip_taps": int(taps["grip"]), "wasted": wasted_squeezes, "rests": rope_rests, "perfect": perfect_catches, "dynos": climber.dynos,
		"bolts": clips.size(), "clipped": _clipped(), "good_clips": good_clips, "min_sloper_grip": min_sloper_grip,
		"causes": falls_by_cause.duplicate(), "high_rows": high_rows, "high_x": high_x, "moves": climber.moves, "shoes": shoes}


static func _clock(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]


static func _stars_text(n: int) -> String:
	return "Stars %d of 3" % n


func finish(sent: bool) -> void:
	if _ended:
		return
	_ended = true
	result = "sent" if sent else "lowered"
	if sent:
		climber.state = Climber.State.DONE
		Audio.play("topout", -3.0, 0.0)
		Haptics.tap(40)
		puff(climber.global_position - Vector2(0, Climber.SIZE.y), Color(1, 0.95, 0.8, 0.9), 24)
	else:
		climber.lock(true)
	panel.hide_panel()
	log_event("end", ["top" if sent else "lowered", high_rows, climber.slips])
	var stats := go_stats()
	var best_before := int((Crag.daily_record() if is_daily() else Crag.record(route["id"]))["bestSeconds"])
	var best_style_before := String((Crag.daily_record() if is_daily() else Crag.record(route["id"]))["best"])
	outcome = Crag.finish(route["id"], sent, climber.slips, int(climber.clock), checkpoint, stats)
	outcome["sent"] = sent
	outcome["falls"] = climber.slips
	outcome["seconds"] = int(climber.clock)
	outcome["stats"] = stats
	outcome["shoes"] = shoes
	near_miss = near_miss_words(sent)
	outcome["nearMiss"] = near_miss
	finished.emit(outcome)
	var record_line: String = Records.crag_attempt(route, outcome, self)
	var lines: Array = []
	var head := "Lowered off"
	var improved: Array = []
	if sent:
		var style: Array = Crag.STYLES[outcome["style"]]
		head = style[0] + "!"
		lines.append(style[1])
		if outcome.get("better", false) and best_style_before != "":
			improved.append("better style than your %s" % Crag.STYLES[best_style_before][0].to_lower())
	else:
		if outcome.get("newHighPoint", false):
			head = "NEW HIGH POINT"
		lines.append("Bolts clipped: %d of %d · high point %s of %s." % [checkpoint, clips.size(), _m_rows(high_rows), _m_rows(route_rows())])
	if near_miss != "":
		lines.push_front(near_miss)
	# Time, against the best.
	var time := "Time %s" % _clock(int(climber.clock))
	if sent and int(outcome.get("fasterBy", 0)) > 0:
		time += " · new best, %d s faster!" % int(outcome["fasterBy"])
		improved.append("%d s faster" % int(outcome["fasterBy"]))
	elif sent and best_before < 0:
		time += " · your first time to beat"
	elif best_before > 0:
		time += " · best %s" % _clock(best_before)
	lines.append("%s · %s · falls %d%s" % [_stars_text(int(outcome.get("stars", 0))), time, climber.slips, (" (%d to the ground)" % ground_falls) if ground_falls > 0 else ""])
	# Grade, and the best you have done on it.
	var best_now := String((Crag.daily_record() if is_daily() else Crag.record(route["id"]))["best"])
	lines.append("Grade %s · best ascent: %s" % [route["grade"], Crag.STYLES[best_now][0] if best_now != "" else "not topped yet"])
	if outcome.get("newHighPoint", false):
		improved.append("%s higher than ever" % _m_rows(high_rows - int(outcome.get("highRowsBefore", 0))))
	if not improved.is_empty():
		lines.append("Better than before: " + ", ".join(improved) + ".")
	if record_line != "":
		lines.append(record_line)
	# The route's challenge.
	var ch: Array = Logbook.CHALLENGES.get(route["id"], [])
	if is_daily():
		if outcome.get("practice", false):
			lines.append("Practice: your device's date is behind a day already played, so this go is not logged.")
		elif sent and int(outcome.get("streak", 0)) > 1:
			lines.append("Daily streak: %d days." % int(outcome["streak"]))
		if not outcome.get("practice", false):
			lines.append("Today: %d go%s%s. Same route all day: beat your time." % [int(Crag.daily_record()["attempts"]), "" if int(Crag.daily_record()["attempts"]) == 1 else "s",
				(", best %s" % _clock(int(Crag.daily_record()["bestSeconds"]))) if int(Crag.daily_record()["bestSeconds"]) > 0 else ""])
	if not ch.is_empty():
		var s := stats.duplicate()
		s["sent"] = sent
		s["falls"] = climber.slips
		s["style"] = outcome["style"]
		lines.append("Challenge, %s: %s" % [ch[0], Logbook.challenge_progress(route["id"], s) if not Crag.record(route["id"]).get("challenge", false) or outcome.get("challenge", false) else "done before"])
	for a in outcome.get("achievements", []):
		lines.append("Achievement: %s! %s" % Logbook.ACHIEVEMENTS[a])
	# What the falls teach.
	if not falls_by_cause.is_empty():
		var worst := ""
		for k in falls_by_cause:
			if worst == "" or int(falls_by_cause[k]) > int(falls_by_cause[worst]):
				worst = k
		lines.append("Try next: " + String(FALL_LESSONS.get(worst, "")))
	# The way on: Retry first after a fall short; after the top, the next
	# route first and a replay second.
	var choices: Array = []
	if sent:
		if outcome.get("unlocked", "") != "":
			var next := Crag.route(outcome["unlocked"])
			lines.append("New route open: %s (%s): %s." % [next["name"], next["grade"], next.get("skill", "")])
			choices.append(["next", "Next route: %s" % next["name"]])
		elif not is_daily():
			var next_id := Crag.next_route()
			if next_id != "" and next_id != route["id"]:
				outcome["suggested"] = next_id
				choices.append(["suggested", "Next route: %s" % Crag.route(next_id)["name"]])
		choices.append(["retry", "Replay"])
	else:
		choices.append(["retry", "Retry"])
	if is_daily() and not outcome.get("practice", false):
		choices.append(["share", "Share today's result"])
	choices.append(["again", "Change shoes, read the brief"])
	choices.append(["menu", "Back to the routes"])
	hud.flash(head)
	var props := {"route": route["id"], "sent": sent, "falls": climber.slips, "seconds": int(climber.clock), "rows": high_rows, "retry": quick_started}
	Analytics.event("attempt_ended", props)
	if outcome.get("newHighPoint", false):
		Analytics.event("new_high_point", {"route": route["id"], "rows": high_rows, "before": int(outcome.get("highRowsBefore", 0))})
	if near_miss != "":
		Analytics.event("near_miss", {"route": route["id"], "rows": high_rows, "kind": "anchor" if "anchor" in near_miss else "best"})
	if is_daily():
		pass
	elif sent:
		Analytics.event("route_completed", {"route": route["id"], "style": outcome["style"], "falls": climber.slips, "seconds": int(climber.clock)})
	else:
		Analytics.event("route_failed", {"route": route["id"], "bolts": checkpoint, "falls": climber.slips, "seconds": int(climber.clock)})
	if sent and (outcome.get("better", false) or int(outcome.get("fasterBy", 0)) > 0) or outcome.get("newHighPoint", false):
		Audio.play("record", -5.0, 0.0)
	# A beat to see the top or the fall, skipped by any tap.
	var waited := 0.0
	while is_inside_tree() and waited < 1.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		if GameInput.pressed_now("interact") or GameInput.pressed_now("jump") or GameInput.pressed_now("pause") or _skip_celebration:
			break
	if is_inside_tree():
		var kicker := "The crag · lesson" if route.get("tutorial", false) else ("Daily route · grade %s" % route["grade"] if is_daily() else "The crag · grade %s" % route["grade"])
		_results_panel = [kicker, "%s · %s" % [head, route["name"]], "\n".join(lines), choices]
		panel.show_panel(kicker, "%s · %s" % [head, route["name"]], "\n".join(lines), choices)


## Skips the beat before the results (tests, and a tap on the screen).
var _skip_celebration := false


## A short, true message when a go ends close to something: the best
## height before it, or the anchor. Measured on the wall in rows (half a
## metre each), never a made-up percentage; "" when nothing was close.
func near_miss_words(sent: bool) -> String:
	if sent:
		return ""
	var to_anchor := route_rows() - high_rows
	var close_to_top := to_anchor > 0 and to_anchor <= 4
	if outcome.get("newHighPoint", false):
		if close_to_top:
			return "New high point, and only %s from the anchor." % _m_rows(to_anchor)
		return ""
	var before := int(outcome.get("highRowsBefore", 0))
	if before > 2 and not _sent_before():
		var short := before - high_rows
		if short == 0:
			return "Level with your best height (%s). One more move." % _m_rows(before)
		if short > 0 and short <= 2:
			return "Just %s short of your best: one or two moves." % _m_rows(short)
	if close_to_top:
		return "Almost at the anchor: %s to go." % _m_rows(to_anchor)
	return ""


func _exit_tree() -> void:
	# Never leave the world frozen behind a scene change mid hit-stop.
	HitStop.release()
