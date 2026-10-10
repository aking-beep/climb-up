class_name ClimbLevel
extends Node2D
## A played climb on Kilimanjaro: the Lava Tower, the Barranco Wall or the
## summit night. Each level is an ASCII map (tools/levels) and a spec (its
## script) with the climb's difficulty, look, people and words; this class
## assembles the level from them and runs the climb: the brief, cairns,
## slips, wind, the teammate who needs help, retreat, and the outcome,
## which lands on the expedition through the Coordinator exactly once.

signal finished(outcome: ChallengeOutcome)

const REGROUP_SECONDS := 30 * 60

## Set by each level's script. Keys:
##   id, map, hud, difficulty {recovery, drain, wind, maxSlips, helpCost},
##   theme {night, far, mid, cliff, deep, foreground, tint, snow},
##   mate {person, name, passDir} or {}, people {char: [person, title, lines]},
##   signs [[title, body]], copy {kicker, title, brief, backOff, mateTitle,
##   mateBody, decideHelped, decideLeft, decideBody, doneComplete,
##   doneRetreat, doneFail, cairnVista}
var spec: Dictionary = {}
var max_slips := 3

var terrain: Terrain
var climber: Climber
var stamina: StaminaModel
var wind: WindSchedule
var camera: ExpeditionCamera
var panel: StoryPanel
var hud: Hud
var mate: Companion
var people: Array = []        # [{node, title, lines}]
var signs: Array = []         # [{pos, index}]
var cairns: Array[Vector2] = []
var checkpoint := 0
var mate_state := "none"      # none (no teammate on this climb), waiting, helped, left
var mate_cooldown := false
var regrouped := false
var result := ""
var attempt_id := "test"
var prompt := ""
## The touch ACT button's word for what it would do now.
var action_word := ""
var briefed := false
var _talk_index := {}
var _interact_target: Dictionary = {}
var _ended := false
var _vista_seen := false
var _gusting := false
var _panel_closed_at := -1.0


func _ready() -> void:
	var d: Dictionary = spec["difficulty"]
	max_slips = int(d["maxSlips"])
	terrain = Terrain.load_file(spec["map"])
	var s: Dictionary = Expedition.state()
	var seed := int(s["seed"])
	var p: Variant = Expedition.pending()
	if p != null and p["challengeId"] == spec["id"]:
		seed = int(p["seed"])
	stamina = StaminaModel.new(float(s["energy"]), float(d["recovery"]), float(d["drain"]))
	wind = WindSchedule.new(float(s["weatherRisk"]), seed, float(d["wind"]))
	if Expedition.climb.get("challengeId") == spec["id"]:
		attempt_id = Expedition.climb.get("attemptId", attempt_id)

	var theme: Dictionary = spec["theme"]
	var back := TileMapLayer.new()
	back.name = "BackWall"
	back.modulate = Color(0.78, 0.78, 0.84) * Color(theme.get("tint", "#ffffff"))
	back.z_index = -5
	add_child(back)
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.modulate = Color(theme.get("tint", "#ffffff"))
	add_child(ground)
	TerrainTiles.paint(terrain, ground, back, theme)

	# Cairns are reached bottom to top; the start is cairn 0.
	var start: Vector2i = terrain.markers["P"][0]
	cairns.append(Terrain.feet(start))
	var ks: Array = terrain.markers.get("K", []).duplicate()
	ks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y or (a.y == b.y and a.x < b.x))
	for k in ks:
		cairns.append(Terrain.feet(k))

	_place_props()

	climber = Climber.new()
	climber.name = "Climber"
	climber.helper_cost = float(d["helpCost"])
	climber.setup(terrain, wind, stamina)
	add_child(climber)
	climber.global_position = cairns[0]
	climber.slipped.connect(_on_slipped)
	climber.slip_finished.connect(_on_slip_finished)
	climber.grabbed.connect(func() -> void: Haptics.tap(12))
	climber.mantled.connect(func() -> void: camera.kick(0.0))

	var m: Dictionary = spec.get("mate", {})
	if not m.is_empty() and terrain.markers.has("M"):
		mate = Companion.new()
		mate.person = m["person"]
		mate.name = "Mate"
		add_child(mate)
		mate.global_position = Terrain.feet(terrain.markers["M"][0])
		mate.set_waiting()
		mate_state = "waiting"

	camera = ExpeditionCamera.new()
	camera.target = climber
	camera.bounds = Rect2(Vector2.ZERO, terrain.pixel_size())
	for v in terrain.markers.get("V", []):
		camera.reveals.append({"at": Terrain.feet(v), "radius": 9 * Terrain.TILE, "zoom": 0.72, "lift": -40.0})
	add_child(camera)
	camera.snap()

	Scenery.build(self, terrain, camera, theme)

	hud = Hud.new()
	hud.title = spec["hud"]
	add_child(hud)
	panel = StoryPanel.new()
	add_child(panel)
	panel.chosen.connect(_on_choice)
	TouchControls.attach(self)

	_resume_from_save()
	Audio.set_camp(1.0)
	if not briefed:
		brief()


func mate_name() -> String:
	return spec.get("mate", {}).get("name", "")


func _place_props() -> void:
	var props := Node2D.new()
	props.name = "Props"
	props.z_index = -1
	add_child(props)
	# Signs are read in the order you climb past them: bottom to top.
	var sign_cells: Array = terrain.markers.get("S", []).duplicate()
	sign_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y or (a.y == b.y and a.x < b.x))
	for cell in sign_cells:
		signs.append({"pos": Terrain.feet(cell), "index": signs.size()})
	for ch in ["T", "F", "S", "g", "o", "K", "R", "X"]:
		for cell in terrain.markers.get(ch, []):
			var feet := Terrain.feet(cell)
			match ch:
				"T":
					props.add_child(_sprite("tent_orange" if int(cell.x) % 2 == 1 else "tent_blue", feet))
				"F":
					props.add_child(_fire(feet))
				"S":
					props.add_child(_sprite("sign", feet))
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
	# Tussock and pebbles on open ledge tops, scattered deterministically.
	var green: bool = spec["theme"].get("grass", true)
	for y in terrain.height:
		for x in terrain.width:
			var cell := Vector2i(x, y)
			if terrain.kind(cell) != Terrain.Kind.ROCK or terrain.is_solid(cell + Vector2i.UP):
				continue
			if terrain.is_climbable(cell + Vector2i.UP) or terrain.markers.get("K", []).has(cell + Vector2i.UP):
				continue
			var h := posmod(x * 92821 + y * 68917, 100)
			if green and h < 22:
				props.add_child(_sprite("grass_%d" % (h % 4), Terrain.feet(cell + Vector2i.UP)))
			elif h < 30:
				props.add_child(_sprite("pebbles_%d" % (h % 3), Terrain.feet(cell + Vector2i.UP)))
	var cast: Dictionary = spec.get("people", {})
	for ch in cast:
		for cell in terrain.markers.get(ch, []):
			var who: Array = cast[ch]
			var c := Companion.new()
			c.person = who[0]
			add_child(c)
			c.global_position = Terrain.feet(cell)
			c.sprite.flip_h = true
			people.append({"node": c, "title": who[1], "lines": who[2]})


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
	if saved.get("challengeId") != spec["id"] or int(saved.get("checkpoint", 0)) <= 0:
		return
	briefed = true
	checkpoint = clampi(int(saved["checkpoint"]), 0, cairns.size() - 1)
	climber.slips = clampi(int(saved.get("slips", 0)), 0, max_slips - 1)
	climber.clock = float(saved.get("seconds", 0.0))
	if mate:
		mate_state = String(saved.get("mate", "waiting"))
	regrouped = saved.get("regrouped") == true
	climber.global_position = cairns[checkpoint]
	climber.reset_physics_interpolation()
	if mate and mate_state == "helped":
		mate.helped()
		mate.catch_up(cairns[checkpoint])
		climber.spotter = saved.get("spotter", false) == true
	elif mate and mate_state == "left":
		mate.left_behind()
	camera.snap()
	hud.flash("Back at cairn %d" % checkpoint)


# --- The brief ----------------------------------------------------------------

## What this climb asks, before the first step. Backing off here lands as a
## retreat: the day is spent at camp, the expedition goes on.
func brief() -> void:
	climber.lock(true)
	var copy: Dictionary = spec["copy"]
	var d: Dictionary = spec["difficulty"]
	var facts := "Stamina %d · %d slips end the attempt · the wind is %s" % [
		int(stamina.max_value), max_slips, wind.describe()]
	if d["recovery"] < 0.8:
		facts += " · the cold slows recovery"
	panel.show_panel(copy["kicker"], copy["title"], "%s\n%s" % [copy["brief"], facts],
		[["start", "Start the climb"], ["backoff", copy["backOff"]]])


# --- The climb --------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _ended or climber == null:
		return
	if mate:
		mate.record(climber.global_position, climber.sprite.animation, climber.sprite.flip_h)
	_arrive()
	_meet_mate()
	_find_interaction()
	if panel.open:
		_panel_closed_at = climber.clock
	var settled := climber.clock - _panel_closed_at > 0.3
	if GameInput.pressed_now("interact") and not panel.open and settled:
		_interact()
	if GameInput.pressed_now("pause") and not panel.open:
		pause_menu()
	var near_camp := clampf(1.0 - climber.global_position.distance_to(cairns[0]) / 300.0, 0.0, 1.0)
	Audio.set_camp(near_camp)
	var high := 1.0 - clampf(climber.global_position.y / terrain.pixel_size().y, 0.0, 1.0)
	Audio.set_wind(0.25 + (0.6 if climber.exposed else 0.0) + high * 0.3 - near_camp * 0.25)
	if climber.exposed and climber.gust == WindSchedule.Phase.BLOW and not _gusting:
		Audio.play("gust", -6.0)
		camera.kick(0.15)
		Haptics.tap(25)
	_gusting = climber.exposed and climber.gust == WindSchedule.Phase.BLOW
	var streaks := get_node_or_null("WindStreaks") as CPUParticles2D
	if streaks:
		streaks.emitting = wind.phase_at(climber.clock) == WindSchedule.Phase.BLOW
	hud.update_from(self)


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
			hud.flash(spec["copy"]["vista"])


func _remember() -> void:
	Expedition.remember({
		"checkpoint": checkpoint,
		"slips": climber.slips,
		"mate": mate_state,
		"regrouped": regrouped,
		"spotter": climber.spotter,
		"seconds": climber.clock,
	})


func _meet_mate() -> void:
	if mate == null or mate_state != "waiting" or panel.open:
		return
	var d := climber.global_position - mate.global_position
	if absf(d.x) > 3 * Terrain.TILE:
		mate_cooldown = false
	if climber.state == Climber.State.GROUND and absf(d.x) < 1.5 * Terrain.TILE and absf(d.y) < 0.6 * Terrain.TILE and not mate_cooldown:
		climber.lock(true)
		mate_panel()
	# Walking on past them without stopping leaves them for Lena.
	var pass_dir: int = spec["mate"].get("passDir", 1)
	if d.x * pass_dir > 2.5 * Terrain.TILE and absf(d.y) < Terrain.TILE:
		mate_state = "left"
		mate.left_behind()
		hud.flash("You climb on past %s. Lena will bring %s." % [mate_name(), spec["mate"].get("them", "them")])


func mate_panel() -> void:
	var can := stamina.value >= climber.helper_cost
	var copy: Dictionary = spec["copy"]
	panel.show_panel(
		"Teammate",
		copy["mateTitle"],
		"%s Helping costs you %d stamina now; %s would climb behind you after, and catch you if you slip. Lena is an hour behind." % [copy["mateBody"], int(climber.helper_cost), spec["mate"].get("they", "they")],
		[
			["help", ("Help %s" % mate_name()) if can else "Help %s (need %d stamina: step back and rest)" % [mate_name(), int(climber.helper_cost)], not can],
			["leave", "Leave %s for Lena" % spec["mate"].get("them", "them")],
			["back", "Step back"],
		])


func decide_panel() -> void:
	var copy: Dictionary = spec["copy"]
	var line := "%s climbs behind you now." % mate_name() if mate_state == "helped" else "%s waits for Lena. You are on your own from here." % mate_name()
	panel.show_panel(
		"Halfway up",
		copy["decideHelped"] if mate_state == "helped" else copy["decideLeft"],
		"%s %s Stamina %d%%." % [line, copy["decideBody"], int(stamina.fraction() * 100)],
		[["continue", "Keep climbing"], ["regroup", "Regroup here (half an hour, full stamina)"], ["retreat", spec["copy"]["backOff"]]])


func pause_menu() -> void:
	climber.lock(true)
	panel.show_panel(
		"Paused",
		spec["hud"],
		"Turning back is always open. It costs the day, not the expedition.",
		[
			["resume", "Resume"],
			["retreat", spec["copy"]["backOff"]],
			["quality", "Graphics: %s" % ["Full", "Reduced", "Low power"][Settings.quality]],
			["motion", "Reduced motion: %s" % ("On" if Settings.reduced_motion else "Off")],
			["touch", "Touch controls: %s" % ("On" if Settings.touch_enabled() else "Off")],
			["quit", "Save and go to the menu"],
		])


func _on_choice(id: String) -> void:
	match id:
		"start":
			briefed = true
			climber.lock(false)
		"backoff":
			_ended = true
			Expedition.abandon_climb()
		"help":
			if climber.help(_on_helped):
				mate.sprite.play("help")
			else:
				climber.lock(false)
		"leave":
			mate_state = "left"
			mate.left_behind()
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
			hud.flash("The party catches up. Half an hour passes.")
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
	mate.helped()
	hud.flash("%s is moving. %s'll catch your next slip." % [mate_name(), spec["mate"].get("They", "They")])
	_remember()
	decide_panel()


func _on_slipped(saved: bool, reason: String) -> void:
	camera.kick(0.0 if saved else 0.8)
	Haptics.tap(20 if saved else 60)
	if saved:
		hud.flash("%s grabs your pack. That slip doesn't count." % mate_name())
	elif reason == "wind":
		hud.flash("The gust takes your balance.")
	else:
		hud.flash("Slipped. Back to the last cairn.")


func _on_slip_finished() -> void:
	if climber.slips >= max_slips:
		finish("fail")
		return
	climber.respawn(cairns[checkpoint])
	if mate and mate_state == "helped":
		mate.catch_up(cairns[checkpoint])
	camera.snap()
	_remember()


# --- Interaction ------------------------------------------------------------

func _find_interaction() -> void:
	_interact_target = {}
	prompt = ""
	action_word = ""
	if panel.open:
		return
	if climber.state == Climber.State.GROUND:
		var feet := climber.global_position
		for p in people:
			if feet.distance_to(p["node"].global_position) < 22.0:
				_interact_target = {"kind": "person", "data": p}
				prompt = "Talk to %s" % String(p["title"]).get_slice(" ·", 0)
				action_word = "TALK"
				return
		for s in signs:
			if feet.distance_to(s["pos"]) < 18.0:
				_interact_target = {"kind": "sign", "data": s}
				prompt = "Read the sign"
				action_word = "READ"
				return
		if mate and mate_state == "waiting" and mate_cooldown and feet.distance_to(mate.global_position) < 26.0:
			_interact_target = {"kind": "mate"}
			prompt = "Talk to %s" % mate_name()
			action_word = "HELP"
			return
	if climber.can_grab():
		_interact_target = {"kind": "grab"}
		action_word = "CLIMB"


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
			var all: Array = spec["signs"]
			var text: Array = all[mini(s["index"], all.size() - 1)]
			climber.lock(true)
			Audio.play("chime", -14.0)
			panel.show_panel("Sign", text[0], text[1], [["talk", "OK"]])
		"mate":
			mate_cooldown = false
			climber.lock(true)
			mate_panel()
		"grab":
			climber.grab_now()


# --- The end ----------------------------------------------------------------

func outcome_now(kind: String) -> ChallengeOutcome:
	var o := ChallengeOutcome.new()
	o.attempt_id = attempt_id
	o.challenge_id = spec["id"]
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
	# Topping out past a teammate you never stopped for leaves them for Lena.
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
	var copy: Dictionary = spec["copy"]
	hud.flash({"complete": copy["doneComplete"], "retreat": copy["doneRetreat"], "fail": copy["doneFail"]}[kind])
	await get_tree().create_timer(1.8 if is_inside_tree() else 0.0).timeout
	if Expedition.climb.get("attemptId") == attempt_id:
		Expedition.finish_climb(o.to_expo())
