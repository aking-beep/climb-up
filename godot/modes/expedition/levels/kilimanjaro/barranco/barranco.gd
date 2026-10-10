extends Node2D
## The Barranco Wall: Barranco Camp, the approach, the wall, Marco, the
## plateau, and the way on to Karanga. Geometry is barranco.txt (stamped by
## tools/levels/barranco_map.py); this script assembles the level from it
## and runs the climb: cairns, slips, wind, Marco, retreat, and the outcome.

signal finished(outcome: ChallengeOutcome)

const MAP := "res://modes/expedition/levels/kilimanjaro/barranco/barranco.txt"
const MAX_SLIPS := 3
const REGROUP_SECONDS := 30 * 60

const SIGNS := [
	["Barranco Camp · 3,960 m", "The wall above the tents is the way to Karanga. A morning's work, if nobody hurries."],
	["The wall", "Scramble the boulders, then follow the ledges. UP on rock to climb. UP at the top of a face to pull over onto the ledge."],
	["Exposed", "Wind comes across this ledge from the west. When it rises, stop and BRACE. Walk between gusts."],
	["Top of the Barranco Wall", "Karanga is over the rise. Look back: the tents at Barranco are the size of seeds."],
]

const PEOPLE := {
	"l": ["lena", "Lena · Guide", [
		"The wall looks worse than it is. Hands on rock, feet on rock, and nothing in a hurry.",
		"On the exposed ledge, when the wind starts talking, stop and brace. Walk between gusts, not through them.",
		"I'll come up last. If anyone stops, they stop for a reason.",
	]],
	"j": ["jun", "Jun · Doctor", [
		"Marco didn't sleep. If he stalls up there, he'll be too proud to ask.",
		"Sit at the cairns. Your arms come back faster sitting than standing.",
		"Breathe out on the hard moves. It's free.",
	]],
}

var terrain: Terrain
var climber: Climber
var stamina: StaminaModel
var wind: WindSchedule
var camera: ExpeditionCamera
var panel: StoryPanel
var hud: Hud
var marco: Companion
var people: Array = []        # [{node, sheet, title, lines, said}]
var signs: Array = []         # [{pos, index}]
var cairns: Array[Vector2] = []
var checkpoint := 0
var mate_state := "waiting"   # waiting, helped, left
var mate_cooldown := false
var regrouped := false
var result := ""
var attempt_id := "test"
var _talk_index := {}
var _interact_target: Dictionary = {}
var _ended := false
var _vista_seen := false
var prompt := ""


func _ready() -> void:
	terrain = Terrain.load_file(MAP)
	var expedition_state: ExpeditionState = Expedition.state
	stamina = StaminaModel.new(expedition_state.energy, 0.85, 1.0)
	wind = WindSchedule.new(expedition_state.weather_risk, expedition_state.seed, 5.0)
	if not Expedition.climb.is_empty():
		attempt_id = Expedition.climb.get("attemptId", attempt_id)

	var back := TileMapLayer.new()
	back.name = "BackWall"
	back.modulate = Color(0.4, 0.37, 0.37)
	back.z_index = -5
	add_child(back)
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	add_child(ground)
	TerrainTiles.paint(terrain, ground, back)

	# Cairns are reached bottom to top; the camp is cairn 0.
	var start: Vector2i = terrain.markers["P"][0]
	cairns.append(Terrain.feet(start))
	var ks: Array = terrain.markers.get("K", []).duplicate()
	ks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y or (a.y == b.y and a.x < b.x))
	for k in ks:
		cairns.append(Terrain.feet(k))

	_place_props()

	climber = Climber.new()
	climber.name = "Climber"
	climber.setup(terrain, wind, stamina)
	add_child(climber)
	climber.global_position = cairns[0]
	climber.slipped.connect(_on_slipped)
	climber.slip_finished.connect(_on_slip_finished)
	climber.mantled.connect(func() -> void: camera.kick(0.0))

	var m: Vector2i = terrain.markers["M"][0]
	marco = Companion.new()
	marco.person = "marco"
	marco.name = "Marco"
	add_child(marco)
	marco.global_position = Terrain.feet(m)
	marco.set_waiting()

	camera = ExpeditionCamera.new()
	camera.target = climber
	camera.bounds = Rect2(Vector2.ZERO, terrain.pixel_size())
	for v in terrain.markers.get("V", []):
		camera.reveals.append({"at": Terrain.feet(v), "radius": 9 * Terrain.TILE, "zoom": 0.72, "lift": -40.0})
	add_child(camera)
	camera.snap()

	Scenery.build(self, terrain, camera)

	hud = Hud.new()
	add_child(hud)
	panel = StoryPanel.new()
	add_child(panel)
	panel.chosen.connect(_on_choice)
	TouchControls.attach(self)

	_resume_from_save()
	Audio.set_camp(1.0)


func _place_props() -> void:
	var props := Node2D.new()
	props.name = "Props"
	props.z_index = -1
	add_child(props)
	var sign_index := 0
	for ch in ["T", "F", "S", "g", "o", "K", "R", "X"]:
		for cell in terrain.markers.get(ch, []):
			var feet := Terrain.feet(cell)
			match ch:
				"T":
					props.add_child(_sprite("tent_orange" if int(cell.x) % 2 == 1 else "tent_blue", feet))
				"F":
					var fire := _fire(feet)
					props.add_child(fire)
				"S":
					props.add_child(_sprite("sign", feet))
					signs.append({"pos": feet, "index": sign_index})
					sign_index += 1
				"g":
					props.add_child(_sprite("groundsel", feet))
				"o":
					props.add_child(_sprite("lobelia", feet))
				"K":
					props.add_child(_sprite("cairn", feet + Vector2(-4, 0)))
				"R":
					props.add_child(_sprite("rest_stone", feet))
				"X":
					props.add_child(_sprite("exit_post", feet))
	# Tussock grass and pebbles on open ledge tops, scattered deterministically.
	for y in terrain.height:
		for x in terrain.width:
			var cell := Vector2i(x, y)
			if terrain.kind(cell) != Terrain.Kind.ROCK or terrain.is_solid(cell + Vector2i.UP):
				continue
			if terrain.is_climbable(cell + Vector2i.UP):
				continue
			var h := posmod(x * 92821 + y * 68917, 100)
			if h < 22:
				props.add_child(_sprite("grass_%d" % (h % 4), Terrain.feet(cell + Vector2i.UP)))
			elif h < 30:
				props.add_child(_sprite("pebbles_%d" % (h % 3), Terrain.feet(cell + Vector2i.UP)))
	for ch in PEOPLE:
		for cell in terrain.markers.get(ch, []):
			var spec: Array = PEOPLE[ch]
			var c := Companion.new()
			c.person = spec[0]
			add_child(c)
			c.global_position = Terrain.feet(cell)
			c.sprite.flip_h = true
			people.append({"node": c, "title": spec[1], "lines": spec[2]})


func _sprite(name: String, feet: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/terrain/props/%s.png" % name)
	s.centered = false
	s.position = feet - Vector2(s.texture.get_width() / 2.0, s.texture.get_height())
	return s


func _fire(feet: Vector2) -> Node2D:
	var fire := AnimatedSprite2D.new()
	var tex: Texture2D = load("res://assets/terrain/props/fire.png")
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 8.0)
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 32, 0, 32, 24)
		sf.add_frame("default", a)
	fire.sprite_frames = sf
	fire.centered = false
	fire.position = feet - Vector2(16, 24)
	fire.play()
	fire.name = "Fire"
	return fire


func _resume_from_save() -> void:
	var saved: Dictionary = Expedition.climb
	if saved.is_empty() or int(saved.get("checkpoint", 0)) <= 0:
		return
	checkpoint = clampi(int(saved["checkpoint"]), 0, cairns.size() - 1)
	climber.slips = clampi(int(saved.get("slips", 0)), 0, MAX_SLIPS - 1)
	climber.clock = float(saved.get("seconds", 0.0))
	mate_state = String(saved.get("mate", "waiting"))
	regrouped = saved.get("regrouped") == true
	climber.global_position = cairns[checkpoint]
	if mate_state == "helped":
		marco.helped()
		marco.catch_up(cairns[checkpoint])
		climber.spotter = saved.get("spotter", false) == true
	elif mate_state == "left":
		marco.left_behind()
	camera.snap()


# --- The climb --------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _ended or climber == null:
		return
	marco.record(climber.global_position, climber.sprite.animation, climber.sprite.flip_h)
	_arrive()
	_meet_marco()
	_find_interaction()
	if panel.open:
		_panel_closed_at = climber.clock
	var settled := climber.clock - _panel_closed_at > 0.3
	if GameInput.pressed_now("interact") and not panel.open and settled:
		_interact()
	if GameInput.pressed_now("pause") and not panel.open:
		pause_menu()
	var near_camp := clampf(1.0 - absf(climber.global_position.x - cairns[0].x) / 300.0, 0.0, 1.0)
	Audio.set_camp(near_camp)
	Audio.set_wind(0.25 + (0.6 if climber.exposed else 0.0) + (0.3 if climber.global_position.y < 30 * Terrain.TILE else 0.0) - near_camp * 0.25)
	if climber.exposed and climber.gust == WindSchedule.Phase.BLOW and not _gusting:
		Audio.play("gust", -6.0)
		camera.kick(0.15)
	_gusting = climber.exposed and climber.gust == WindSchedule.Phase.BLOW
	var streaks := get_node_or_null("WindStreaks") as CPUParticles2D
	if streaks:
		streaks.emitting = wind.phase_at(climber.clock) == WindSchedule.Phase.BLOW
	hud.update_from(self)


var _gusting := false
var _panel_closed_at := -1.0


func _arrive() -> void:
	if climber.state != Climber.State.GROUND and climber.state != Climber.State.REST:
		return
	var feet := climber.global_position
	for i in range(checkpoint + 1, cairns.size()):
		var c := cairns[i]
		if absf(feet.x - c.x) < 1.4 * Terrain.TILE and absf(feet.y - c.y) < 0.6 * Terrain.TILE:
			checkpoint = i
			Audio.play("cairn", -8.0)
			hud.flash("Cairn %d of %d" % [checkpoint, cairns.size() - 1])
			_remember()
	for cell in terrain.markers.get("X", []):
		if climber.body_rect().intersects(Rect2(Vector2(cell) * Terrain.TILE, Vector2.ONE * Terrain.TILE)):
			finish("complete")
			return
	for v in terrain.markers.get("V", []):
		if not _vista_seen and feet.distance_to(Terrain.feet(v)) < 3 * Terrain.TILE:
			_vista_seen = true
			hud.flash("Barranco Camp, far below")


func _remember() -> void:
	Expedition.remember({
		"checkpoint": checkpoint,
		"slips": climber.slips,
		"mate": mate_state,
		"regrouped": regrouped,
		"spotter": climber.spotter,
		"seconds": climber.clock,
	})


func _meet_marco() -> void:
	if mate_state != "waiting" or panel.open:
		return
	var d := climber.global_position - marco.global_position
	if absf(d.x) > 3 * Terrain.TILE:
		mate_cooldown = false
	if climber.state == Climber.State.GROUND and absf(d.x) < 1.5 * Terrain.TILE and absf(d.y) < 0.6 * Terrain.TILE and not mate_cooldown:
		climber.lock(true)
		marco_panel()
	# Walking on past him without stopping leaves him for Lena.
	if d.x > 2.5 * Terrain.TILE and absf(d.y) < Terrain.TILE:
		mate_state = "left"
		marco.left_behind()
		hud.flash("You climb on past Marco. Lena will bring him.")


func marco_panel() -> void:
	var can := stamina.value >= climber.helper_cost
	panel.show_panel(
		"Teammate",
		"Marco has stopped on the ledge",
		"His pack is wedged against the rock and he has frozen above the drop. Helping costs you %d stamina now; he would climb behind you after, and catch you if you slip. Lena is an hour behind." % int(climber.helper_cost),
		[
			["help", "Help Marco up" if can else "Help Marco (need %d stamina: step back and rest)" % int(climber.helper_cost), not can],
			["leave", "Leave him for Lena"],
			["back", "Step back"],
		])


func decide_panel() -> void:
	var line := "Marco climbs behind you now." if mate_state == "helped" else "Marco waits for Lena. You are on your own from here."
	panel.show_panel(
		"Halfway up",
		"Marco is moving again. Now what?" if mate_state == "helped" else "Lena will bring Marco. Now what?",
		"%s The loose gully above is the last of the wall. Stamina %d%%." % [line, int(stamina.fraction() * 100)],
		[["continue", "Keep climbing"], ["regroup", "Regroup here (half an hour, full stamina)"], ["retreat", "Turn back to Barranco"]])


func pause_menu() -> void:
	climber.lock(true)
	panel.show_panel(
		"Paused",
		"On the wall",
		"Turning back is always open. It costs the day, not the expedition.",
		[
			["resume", "Resume"],
			["retreat", "Turn back to Barranco"],
			["quality", "Graphics: %s" % ["Full", "Reduced", "Low power"][Settings.quality]],
			["motion", "Reduced motion: %s" % ("On" if Settings.reduced_motion else "Off")],
			["touch", "Touch controls: %s" % ("On" if Settings.touch_enabled() else "Off")],
			["quit", "Save and quit to menu"],
		])


func _on_choice(id: String) -> void:
	match id:
		"help":
			if climber.help(_on_helped):
				marco.sprite.play("help")
			else:
				climber.lock(false)
		"leave":
			mate_state = "left"
			marco.left_behind()
			_remember()
			decide_panel()
		"back":
			mate_cooldown = true
			climber.lock(false)
		"continue", "resume":
			climber.lock(false)
		"regroup":
			regrouped = true
			stamina.refill(1.0)
			climber.clock += REGROUP_SECONDS
			hud.flash("Lena and Jun catch up. Half an hour passes.")
			_remember()
			climber.lock(false)
		"retreat":
			finish("retreat")
		"quality":
			Settings.set_quality((Settings.quality + 1) % 3)
			Scenery.apply_quality(self)
			pause_menu()
		"motion":
			Settings.set_reduced_motion(not Settings.reduced_motion)
			pause_menu()
		"touch":
			Settings.set_touch_controls(not Settings.touch_enabled())
			TouchControls.attach(self)
			pause_menu()
		"quit":
			_remember()
			Expedition.go(Expedition.MENU)
		"talk":
			climber.lock(false)


func _on_helped() -> void:
	mate_state = "helped"
	marco.helped()
	hud.flash("Marco is free. He'll catch your next slip.")
	_remember()
	decide_panel()


func _on_slipped(saved: bool, reason: String) -> void:
	camera.kick(0.0 if saved else 0.8)
	if saved:
		hud.flash("Marco grabs your pack. That slip doesn't count.")
	elif reason == "wind":
		hud.flash("The gust takes your balance.")
	else:
		hud.flash("Slipped. Back to the last cairn.")


func _on_slip_finished() -> void:
	if climber.slips >= MAX_SLIPS:
		finish("fail")
		return
	climber.respawn(cairns[checkpoint])
	if mate_state == "helped":
		marco.catch_up(cairns[checkpoint])
	camera.snap()
	_remember()


# --- Interaction ------------------------------------------------------------

func _find_interaction() -> void:
	_interact_target = {}
	prompt = ""
	if panel.open or climber.state != Climber.State.GROUND:
		return
	var feet := climber.global_position
	for p in people:
		if feet.distance_to(p["node"].global_position) < 22.0:
			_interact_target = {"kind": "person", "data": p}
			prompt = "Talk to %s" % String(p["title"]).get_slice(" ·", 0)
			return
	for s in signs:
		if feet.distance_to(s["pos"]) < 18.0:
			_interact_target = {"kind": "sign", "data": s}
			prompt = "Read the sign"
			return
	if mate_state == "waiting" and mate_cooldown and feet.distance_to(marco.global_position) < 26.0:
		_interact_target = {"kind": "marco"}
		prompt = "Talk to Marco"


func _interact() -> void:
	match _interact_target.get("kind", ""):
		"person":
			var p: Dictionary = _interact_target["data"]
			var title: String = p["title"]
			var i: int = _talk_index.get(title, 0)
			var lines: Array = p["lines"]
			_talk_index[title] = (i + 1) % lines.size()
			climber.lock(true)
			Audio.play("chime", -14.0)
			panel.show_panel("", title, lines[i], [["talk", "OK"]])
		"sign":
			var s: Dictionary = _interact_target["data"]
			var text: Array = SIGNS[min(s["index"], SIGNS.size() - 1)]
			climber.lock(true)
			Audio.play("chime", -14.0)
			panel.show_panel("Sign", text[0], text[1], [["talk", "OK"]])
		"marco":
			mate_cooldown = false
			climber.lock(true)
			marco_panel()


# --- The end ----------------------------------------------------------------

func outcome_now(kind: String) -> ChallengeOutcome:
	var o := ChallengeOutcome.new()
	o.attempt_id = attempt_id
	o.result = kind
	o.stamina_left = int(round(stamina.fraction() * 100.0))
	o.slips = climber.slips
	o.assisted = true if mate_state == "helped" else (false if mate_state == "left" else null)
	o.regrouped = regrouped
	o.seconds = int(climber.clock)
	o.caught = climber.caught
	o.wind_strikes = climber.wind_strikes
	o.loose_seconds = climber.loose_seconds
	o.rest_seconds = climber.rest_seconds
	o.checkpoint = checkpoint
	return o


func finish(kind: String) -> void:
	if _ended:
		return
	_ended = true
	result = kind
	# Topping out past a Marco you never stopped for leaves him for Lena.
	if kind == "complete" and mate_state == "waiting":
		mate_state = "left"
	if kind == "complete":
		climber.state = Climber.State.DONE
	else:
		climber.lock(true)
	panel.hide_panel()
	Audio.stop_ambience()
	var o := outcome_now(kind)
	finished.emit(o)
	hud.flash({"complete": "Over the top. Karanga is ahead.", "retreat": "You turn back for Barranco.", "fail": "The team calls it."}[kind])
	await get_tree().create_timer(1.6 if is_inside_tree() else 0.0).timeout
	if Expedition.climb.get("attemptId") == attempt_id:
		Expedition.finish_climb(o)
