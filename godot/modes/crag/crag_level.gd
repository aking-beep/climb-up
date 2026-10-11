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
var prompt := ""
var action_word := ""
var briefed := false
var result := ""
var outcome: Dictionary = {}
## Pacing, as on the expedition: each moment the player acted.
var pace_log: Array = []
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
		camera.kick(0.2))

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
			# A jug is one big hold: draw it once per pair of rows.
			if k == Terrain.Kind.JUG and (posmod(y, 2) == 1 or posmod(x, 3) != 1):
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
	var history := "Not tried yet: a clean first go is an onsight."
	if int(r["sends"]) > 0:
		history = "Sent %d time%s · best: %s." % [int(r["sends"]), "" if int(r["sends"]) == 1 else "s", Crag.STYLES[r["best"]][0]]
	elif int(r["attempts"]) > 1:
		history = "%d goes so far, not sent yet. A clean send now is a redpoint." % (int(r["attempts"]) - 1)
	panel.show_panel("The crag · grade %s" % route["grade"], route["name"],
		"%s\nCrux: %s\n%d bolts · %d falls and you lower off · %s" % [route["text"], route["crux"], clips.size(), max_slips, history],
		[["start", "Tie in and climb"], ["menu", "Back to the routes"]])


# --- The climb --------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _ended or climber == null:
		return
	_clip()
	# On lead, a fall stops on the rope a little below the last bolt.
	if climber.state == Climber.State.AIR and checkpoint > 0 and climber.global_position.y - climber.fall_from > LEAD_FALL:
		climber.slip("fall")
	if climber.state == Climber.State.GROUND and climber.global_position.y <= _top_y + 1.0:
		finish(true)
		return
	_draw_rope()
	prompt = ""
	action_word = "CLIMB" if climber.can_grab() else ""
	if GameInput.pressed_now("pause") and not panel.open:
		pause_menu()
	hud.update_from(self)


func _clip() -> void:
	if not climber.is_climbing():
		return
	var chest := climber.global_position - Vector2(0, Climber.SIZE.y * 0.5)
	for i in clips.size():
		var c: Dictionary = clips[i]
		if c["clipped"]:
			continue
		var at := Vector2(c["cell"]) * Terrain.TILE + Vector2.ONE * Terrain.TILE / 2.0
		if absf(at.x - chest.x) < CLIP_REACH.x and absf(at.y - chest.y) < CLIP_REACH.y:
			c["clipped"] = true
			c["node"].texture.region = Rect2(8, 0, 8, 14)
			checkpoint = maxi(checkpoint, i + 1)
			engage("clip")
			Audio.play("cairn", -8.0)
			hud.flash("Clipped bolt %d of %d." % [i + 1, clips.size()], 1.4)


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
	return "Stamina %d%% · Falls %d/%d · Bolts %d/%d" % [pct, climber.slips, max_slips, checkpoint, clips.size()]


## The crag's own advice, ahead of the HUD's general hints.
func hint_now() -> String:
	if climber.state != Climber.State.CLIMB:
		return ""
	var key := "JUMP" if Settings.touch_enabled() else "SPACE"
	var hold := terrain.hold_at(climber.body_rect())
	if dyno_above():
		return "Blank rock. %s to dyno for the holds above." % key
	if hold == Terrain.Kind.CRIMP:
		return "Crimps: keep moving. Hanging here empties your arms."
	if hold == Terrain.Kind.JUG and stamina.fraction() < 0.95:
		return "A jug: hang here and your arms come back."
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
