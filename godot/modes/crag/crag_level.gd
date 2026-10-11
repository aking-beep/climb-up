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
## Clipping a bolt takes three taps (pull up rope, open the gate, clip).
const CLIP_TAPS := 3
## On tiny holds a grip meter runs down; each tap squeezes it back up. At
## empty your fingers peel off.
const GRIP_DRAIN := 0.55
const GRIP_DRAIN_HANGING := 0.95
const GRIP_TAP := 0.25
## After a jump (dyno) you have this long to stick the hold: tap fast.
const CATCH_TIME := 1.0
const CATCH_TAPS := 3
## Once clipped you can sit back on the rope and rest, any time, as often
## as you like: each clip fills a green rest bar worth ROPE_REST stamina,
## given back at ROPE_RATE a second while you sit. Moving ends a rest; the
## rest of the bar waits for the next one. Big holds (jugs) give more.
const ROPE_REST := 20.0
const ROPE_RATE := 15.0
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
var result := ""
var outcome: Dictionary = {}
## Pacing, as on the expedition: each moment the player acted.
var pace_log: Array = []
## The taps: the bolt in reach and taps on it so far, the grip meter on tiny
## holds, and a dyno being stuck.
var clip_target := -1
var clip_taps := 0
var grip := 1.0
var on_crimps := false
var catching := 0.0
var catch_taps := 0
var _dyno_air := false
var _tap := false
var meter: Node2D
## The rest on the rope: the green bar left (rope_left), and resting now.
var resting_rope := false
var rope_left := 0.0
var rope_rests := 0
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
	_place_holds()
	_place_jugs()

	_start = Terrain.feet(terrain.markers["P"][0])
	cairns.append(_start)
	var anchor: Vector2i = terrain.markers["X"][0]
	_top_y = Terrain.feet(anchor).y
	var a := Sprite2D.new()
	a.texture = load("res://assets/crag/anchor.png")
	a.position = Terrain.feet(anchor) - Vector2(0, 10)
	add_child(a)
	_place_clips()

	belayer = Companion.new()
	belayer.person = "lena"
	belayer.name = "Belayer"
	add_child(belayer)
	belayer.global_position = Vector2(_base_x() - 2.5 * Terrain.TILE, _start.y)

	rope = Line2D.new()
	rope.width = 1.0
	rope.default_color = Color("#e0663c")
	rope.z_index = 2
	add_child(rope)

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


func _place_holds() -> void:
	_hold_tex = load("res://assets/crag/holds.png")
	for y in terrain.height:
		for x in terrain.width:
			var k := terrain.kind(Vector2i(x, y))
			if k != Terrain.Kind.CRIMP and k != Terrain.Kind.JUG:
				continue
			# Jugs are drawn whole, one big hold per patch (_place_jugs).
			if k == Terrain.Kind.JUG:
				continue
			var s := Sprite2D.new()
			var at := AtlasTexture.new()
			at.atlas = _hold_tex
			at.region = Rect2(0 if k == Terrain.Kind.CRIMP else 16, 0, 16, 16)
			s.texture = at
			s.centered = false
			s.position = Vector2(x, y) * Terrain.TILE + (Vector2(0, 8) if k == Terrain.Kind.JUG else Vector2.ZERO)
			s.flip_h = posmod(x + y, 2) == 1 and k == Terrain.Kind.CRIMP
			s.z_index = 1
			add_child(s)


## Jugs: big incut holds with chalk on the lip, set into the rock like the
## crimps, two to a patch (staggered, a hand and a foot), so they read as
## holds you can hang on, not as a sign.
func _place_jugs() -> void:
	var tex: Texture2D = load("res://assets/crag/jug.png")
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
				var s := Sprite2D.new()
				s.texture = tex
				s.position = (Vector2(cell) + Vector2(size) * (f as Vector2)) * Terrain.TILE
				s.z_index = 1
				add_child(s)


func _place_clips() -> void:
	_draw_tex = load("res://assets/crag/quickdraw.png")
	var cells: Array = terrain.markers.get("Q", []).duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	for cell in cells:
		var s := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = _draw_tex
		at.region = Rect2(0, 0, 8, 14)
		s.texture = at
		s.position = Vector2(cell) * Terrain.TILE + Vector2(4, 7)
		s.z_index = 1
		add_child(s)
		clips.append({"cell": cell, "node": s, "clipped": false, "hang": _hang_point(cell)})
		cairns.append(Terrain.feet(cell))


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
	if int(r["sends"]) > 0:
		history = "Sent %d time%s · best: %s." % [int(r["sends"]), "" if int(r["sends"]) == 1 else "s", Crag.STYLES[r["best"]][0]]
	elif int(r["attempts"]) > 1:
		history = "%d tries so far, not finished yet. Finish it with no falls for a redpoint." % (int(r["attempts"]) - 1)
	panel.show_panel("The crag · grade %s (%s)" % [route["grade"], route["level"]], route["name"],
		"%s\nHardest part: %s\n%d bolts to clip · fall %d times and you have to come down · %s" % [route["text"], route["crux"], clips.size(), max_slips, history],
		[["start", "Tie in and climb"], ["menu", "Back to the climbs"]])


# --- The climb --------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _ended or climber == null:
		return
	_tap = GameInput.pressed_now("interact") and not panel.open
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
		prompt = "Clip in? (%d/%d)" % [clip_taps, CLIP_TAPS]
	elif on_crimps:
		action_word = "GRIP"
		prompt = "Grip! (%d%%)" % int(grip * 100.0)
	if GameInput.pressed_now("pause") and not panel.open:
		pause_menu()
	hud.update_from(self)


## A bolt in reach asks to be clipped: three taps. Climb on without it and
## it stays unclipped (a fall then drops you to the last one you did clip).
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
	if target != clip_target:
		clip_target = target
		clip_taps = 0
	if clip_target < 0 or not _tap:
		return
	clip_taps += 1
	Audio.play("grip", -12.0, 0.2)
	if clip_taps < CLIP_TAPS:
		return
	var c: Dictionary = clips[clip_target]
	c["clipped"] = true
	c["node"].texture.region = Rect2(8, 0, 8, 14)
	checkpoint = maxi(checkpoint, clip_target + 1)
	engage("clip")
	Audio.play("cairn", -8.0)
	hud.flash("Clipped in! Bolt %d of %d. Tap %s to rest on the rope." % [clip_target + 1, clips.size(), _key("REST")], 2.2)
	clip_target = -1
	clip_taps = 0
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


## A rest on the rope is there to take: clipped in, on the rock, nothing
## else asking for a tap, and green left in the bar.
func can_rest() -> bool:
	return climber.state == Climber.State.CLIMB and checkpoint > 0 and rope_left > 0.0 \
		and catching <= 0.0 and clip_target < 0 and not resting_rope


## Tiny holds: a grip meter that runs down while you are on them (faster if
## you stop); taps squeeze it back. At empty the fingers peel off.
func _grip(dt: float) -> void:
	var now := climber.state == Climber.State.CLIMB and terrain.hold_at(climber.body_rect()) == Terrain.Kind.CRIMP
	if now and not on_crimps:
		grip = 1.0
	on_crimps = now
	if not on_crimps:
		grip = minf(1.0, grip + dt)
		return
	if catching > 0.0 or resting_rope:
		return
	grip -= (GRIP_DRAIN_HANGING if climber.last_activity == "crimp_hang" else GRIP_DRAIN) * dt
	if _tap:
		grip = minf(1.0, grip + GRIP_TAP)
	if grip <= 0.0:
		grip = 1.0
		on_crimps = false
		climber.peel_off()
		hud.flash("Your fingers peel off the tiny holds.", 2.0)


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
			hud.flash("Stuck it!", 1.0)
			return
	catching -= dt
	if catching <= 0.0:
		climber.peel_off()
		hud.flash("Too slow: the hold slips out of your hands.", 2.0)


func _key(button: String) -> String:
	return button if Settings.touch_enabled() else "E"


func _draw_rope() -> void:
	var pts := PackedVector2Array([belayer.global_position - Vector2(0, 12)])
	for c in clips:
		if c["clipped"]:
			pts.append(Vector2(c["cell"]) * Terrain.TILE + Vector2(4, 11))
	pts.append(climber.global_position - Vector2(0, 11))
	rope.points = pts


func _on_slipped(_saved: bool, reason: String) -> void:
	camera.kick(0.6)
	Haptics.tap(50)
	engage("fall")
	if checkpoint > 0:
		hud.flash("Falling! The rope catches you at bolt %d. Falls %d of %d." % [checkpoint, climber.slips, max_slips], 2.4)
	elif reason == "fall":
		hud.flash("You hit the ground: clip the first bolt sooner. Falls %d of %d." % [climber.slips, max_slips], 2.4)


func _on_slip_finished() -> void:
	if _ended:
		return
	if climber.slips >= max_slips:
		finish(false)
		return
	if checkpoint > 0:
		climber.hang_at(clips[checkpoint - 1]["hang"])
	else:
		climber.respawn(_start)
	camera.snap()


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
		return "A bolt. Clip in? Tap %s 3 times (%d/%d)." % [_key("CLIP"), clip_taps, CLIP_TAPS]
	if on_crimps:
		return "Tiny holds: tap %s to hang on, and keep climbing. Grip %d%%." % [_key("GRIP"), int(grip * 100.0)]
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

func pause_menu() -> void:
	climber.lock(true)
	panel.show_panel("Paused", route["name"], "Lowering off ends this go. The route will still be here.", [
		["resume", "Resume"],
		["lower", "Lower off"],
		["touch", "Touch controls: %s" % ("On" if Settings.touch_enabled() else "Off")],
		["fps", "Show FPS: %s" % ("On" if Settings.show_fps else "Off")],
		["menu", "Back to the routes"],
	])


func _on_choice(id: String) -> void:
	match id:
		"start":
			briefed = true
			climber.lock(false)
		"resume":
			climber.lock(false)
		"lower":
			finish(false)
		"touch":
			Settings.set_touch_controls(not Settings.touch_enabled())
			TouchControls.attach(self)
			pause_menu()
		"fps":
			Settings.set_show_fps(not Settings.show_fps)
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
	else:
		climber.lock(true)
	panel.hide_panel()
	outcome = Crag.finish(route["id"], sent, climber.slips, int(climber.clock))
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
		lines.append("Bolts clipped: %d of %d. Rest up and try again." % [checkpoint, clips.size()])
	lines.append("Falls: %d · %d min %02d s · dynos: %d" % [climber.slips, int(climber.clock) / 60, int(climber.clock) % 60, climber.dynos])
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
