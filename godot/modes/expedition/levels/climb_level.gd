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
var hazards: Hazards
var creatures: Creatures
## The body the trek left you (Condition.of): health, sleep, food, sickness,
## all of it in the size and refill of the one stamina bar.
var condition: Dictionary = {}
var dosed := false
var _next_dizzy := -1.0
var _next_cramp := -1.0
var ground_layer: TileMapLayer
var gear_this_attempt := 0
## Pacing: every moment the player had to do something, [clock, kind]. The
## tests read it to check that no stretch of a climb is just walking.
var pace_log: Array = []
## Seconds spent walking (a face being climbed is play in itself; resting
## and reading are the player's choice).
var travel := 0.0
var _travel_clock := -1.0
var _was_on_ice := false
var _was_bracing := false
var _outcome: ChallengeOutcome
var stars := 0
## A helped teammate's breath: walking drains it (more in thin air, more if
## they are unwell), sitting near them gives it back. At zero they stop.
var mate_breath := 100.0
var mate_winded := false
var _mate_away := 0.0
var _mate_clock := -1.0
var _mate_spotter := false
var trek_factor: Dictionary = {"steep": 1.0, "sick": 0, "stamina": 1.0}
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
	stamina.thin_air = StaminaModel.thin_air_for(float(spec.get("meters", 4000)), float(s["acclimatization"]))
	# The trek reaches into the climb: a steeper route, and the body the
	# camp choices left you (sleep, food, sickness, medicine).
	trek_factor = Trek.climb_factor(Expedition.session)
	dosed = Expedition.climb.get("challengeId") == spec["id"] and Expedition.climb.get("dosed") == true
	condition = Condition.of(Expedition.session, dosed)
	stamina.max_value = roundf(stamina.max_value * condition["stamina"])
	stamina.value = stamina.max_value
	stamina.recovery = clampf(stamina.recovery * condition["recovery"], 0.2, 1.2)
	stamina.thin_air *= condition["thinAir"]
	stamina.grip = condition["grip"]
	wind = WindSchedule.new(float(s["weatherRisk"]), seed, float(d["wind"]) + (trek_factor["steep"] - 1.0) * 40.0)
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
	ground_layer = ground

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
	climber.grabbed.connect(func() -> void:
		Haptics.tap(12)
		engage("grab"))
	climber.jumped.connect(func() -> void: engage("hop"))
	climber.mantled.connect(func() -> void: engage("mantle"))
	climber.mantled.connect(func() -> void: camera.kick(0.0))
	climber.hurt_taken.connect(func(_amount: float, _reason: String) -> void:
		camera.kick(0.3)
		Haptics.tap(30))

	hazards = Hazards.new()
	hazards.name = "Hazards"
	add_child(hazards)
	var mine: bool = Expedition.climb.get("challengeId") == spec["id"]
	hazards.setup(self, terrain, ground, climber, float(d.get("rockPeriod", 5.0)) / trek_factor["steep"], spec.get("gear", []),
		Expedition.climb.get("taken", []) if mine else [], Expedition.gear_found(spec["id"]))
	hazards.engaged.connect(engage)
	hazards.found_gear.connect(func(i: int) -> void:
		gear_this_attempt += 1
		Expedition.find_gear(spec["id"], i))

	creatures = Creatures.new()
	creatures.name = "Creatures"
	add_child(creatures)
	creatures.setup(self, terrain, climber, spec["id"] == "barranco-wall")
	creatures.engaged.connect(engage)

	var m: Dictionary = spec.get("mate", {})
	if not m.is_empty() and terrain.markers.has("M") and not Trek.is_gone(Expedition.session, m["person"]):
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
			if Trek.is_gone(Expedition.session, who[0]):
				continue
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
	facts += " · at %s m even walking costs breath" % ExpeditionEngine.format_meters(float(spec.get("meters", 4000)))
	for line in condition["lines"]:
		facts += "\n" + line
	if trek_factor["steep"] > 1.0:
		facts += "\nYour route is steep: more wind, and the stones come faster."
	var dangers: Array = spec.get("dangers", [])
	if not dangers.is_empty():
		facts += "\nWatch for: " + ", ".join(dangers) + "."
	if hazards.gear_total() > 0:
		facts += " Lost gear found here: %d of %d." % [hazards.gear_count, hazards.gear_total()]
	var choices: Array = [["start", "Start the climb"]]
	if not dosed and Condition.medicine_helps(Expedition.session):
		choices.append(["medicine", "Take medicine first (%d dose%s left)" % [condition["medicine"], "" if condition["medicine"] == 1 else "s"]])
	choices.append(["backoff", copy["backOff"]])
	panel.show_panel(copy["kicker"], copy["title"], "%s\n%s" % [copy["brief"], facts], choices)


# --- The climb --------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _ended or climber == null:
		return
	hazards.step()
	creatures.step()
	_symptoms()
	_mate_breath()
	if _travel_clock >= 0.0 and climber.last_activity in ["walk", "walk_up", "ice"]:
		travel += clampf(climber.clock - _travel_clock, 0.0, 0.1)
	_travel_clock = climber.clock
	# Stepping onto ice is a challenge of its own: keep your footing.
	if climber.on_ice and not _was_on_ice:
		engage("ice")
	_was_on_ice = climber.on_ice
	var bracing := climber.state == Climber.State.BRACE
	if bracing and not _was_bracing:
		engage("brace")
	_was_bracing = bracing
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


## Being unwell, from the trek: a dizzy spell or a cramp now and then, on
## the ground, until medicine or a descent sorts it out.
func _symptoms() -> void:
	if climber.state != Climber.State.GROUND or panel.open:
		return
	var now := climber.clock
	var dizzy: int = condition.get("dizzy", 0)
	if dizzy > 0:
		if _next_dizzy < 0.0:
			_next_dizzy = now + Condition.spell_period(dizzy, false)
		elif now >= _next_dizzy:
			_next_dizzy = now + Condition.spell_period(dizzy, false)
			climber.dizzy = 1.4
			hud.flash("Dizzy: the ground tilts. Slow down and it passes.", 1.6)
	var cramps: int = condition.get("cramps", 0)
	if cramps > 0:
		if _next_cramp < 0.0:
			_next_cramp = now + Condition.spell_period(cramps, true) * 0.6
		elif now >= _next_cramp:
			_next_cramp = now + Condition.spell_period(cramps, true)
			climber.cramp = 1.0
			hud.flash("A cramp doubles you over.", 1.4)


func _arrive() -> void:
	if climber.state != Climber.State.GROUND and climber.state != Climber.State.REST:
		return
	var feet := climber.global_position
	for i in range(checkpoint + 1, cairns.size()):
		var c := cairns[i]
		if absf(feet.x - c.x) < 1.4 * Terrain.TILE and absf(feet.y - c.y) < 0.6 * Terrain.TILE:
			checkpoint = i
			engage("cairn")
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


func _mate_breath() -> void:
	var now := climber.clock
	var dt := clampf(now - _mate_clock, 0.0, 0.1) if _mate_clock >= 0.0 else 0.0
	_mate_clock = now
	if mate == null or mate_state != "helped" or dt <= 0.0:
		return
	var near := climber.global_position.distance_to(mate.global_position) < 4.0 * Terrain.TILE
	var resting := climber.state == Climber.State.REST
	if not mate_winded:
		var sick: int = Trek.sickness(Expedition.session, spec["mate"]["person"]).get("stage", 0)
		if climber.state == Climber.State.GROUND and climber.last_activity in ["walk", "walk_up", "ice"]:
			mate_breath -= 1.3 * stamina.thin_air * (1.0 + 0.5 * sick) * dt
		elif near and resting:
			mate_breath += 14.0 * dt
		elif near and climber.last_activity == "still":
			mate_breath += 5.0 * dt
		if mate_breath <= 0.0 and climber.state == Climber.State.GROUND:
			mate_winded = true
			engage("breather")
			_mate_away = 0.0
			_mate_spotter = climber.spotter
			climber.spotter = false
			mate.winded()
			hud.flash("%s has to stop: no breath left. Go back and sit with %s." % [mate_name(), spec["mate"].get("them", "them")], 3.5)
	else:
		if near and resting:
			mate_breath += 20.0 * dt
		elif climber.global_position.distance_to(mate.global_position) > 18.0 * Terrain.TILE:
			_mate_away += dt
			if _mate_away > 30.0:
				mate_winded = false
				mate_state = "left"
				mate.left_behind()
				hud.flash("You went on without %s. Lena will bring %s up." % [mate_name(), spec["mate"].get("them", "them")], 3.5)
				_remember()
				return
		if mate_breath >= 100.0:
			mate_winded = false
			climber.spotter = _mate_spotter
			mate.helped()
			mate.catch_up(climber.global_position)
			hud.flash("%s is ready. On you go, together." % mate_name())
	mate_breath = clampf(mate_breath, 0.0, 100.0)


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
		"medicine":
			if Trek.dose_for_climb(Expedition.session):
				dosed = true
				condition = Condition.of(Expedition.session, true)
				stamina.grip = condition["grip"]
				Expedition.remember({"dosed": true})
				Expedition.save()
				hud.flash("You take a dose. The symptoms stay off for this climb.", 3.0)
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
		"camp":
			land()
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
		return
	var line := "Slipped. Back to the last cairn."
	if reason == "wind":
		line = "The gust takes your balance."
	elif reason == "hurt":
		line = "Too hurt to go on: you collapse. Back to the last cairn."
	var lost := hazards.drop_flowers()
	if lost > 0:
		# Picked flowers are this attempt's: forget them in the save too.
		var keys: Array = []
		for cell in terrain.markers.get("f", []):
			keys.append("%d,%d" % [cell.x, cell.y])
		forget_taken(keys)
		line += " You drop all %d everlastings: they are back on the ground." % lost
	hud.flash(line, 3.0)


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
			engage("talk")
			var p: Dictionary = _interact_target["data"]
			var title: String = p["title"]
			var i: int = _talk_index.get(title, 0)
			var lines: Array = p["lines"]
			_talk_index[title] = (i + 1) % lines.size()
			climber.lock(true)
			Audio.play("chime", -14.0)
			panel.show_panel("", title, lines[i], [["talk", "OK"]])
		"sign":
			engage("sign")
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

func engage(kind: String) -> void:
	pace_log.append([climber.clock, kind, travel, climber.global_position / Terrain.TILE])


## How far along the route: cairns reached, and the way to the next one (or
## the exit), 0 at the start, 1 at the end.
func route_progress() -> float:
	var points: Array = cairns.duplicate()
	for cell in terrain.markers.get("X", []):
		points.append(Terrain.feet(cell))
	if points.size() < 2:
		return 0.0
	var i := clampi(checkpoint, 0, points.size() - 2)
	var a: Vector2 = points[i]
	var b: Vector2 = points[i + 1]
	var along := clampf(1.0 - climber.global_position.distance_to(b) / maxf(1.0, a.distance_to(b)), 0.0, 1.0)
	return clampf((i + along) / float(points.size() - 1), 0.0, 1.0)


## Puts picked things back in the save's list of what is still on the ground.
func forget_taken(keys: Array) -> void:
	var taken: Array = Expedition.climb.get("taken", [])
	Expedition.remember({"taken": taken.filter(func(k: Variant) -> bool: return not keys.has(k))})


func on_water(key: String) -> void:
	var taken: Array = Expedition.climb.get("taken", [])
	if not taken.has(key):
		taken.append(key)
	Expedition.remember({"taken": taken})


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
	o.gear_found = gear_this_attempt
	o.flowers = hazards.flowers
	o.flowers_total = hazards.flowers_total
	o.stars = star_count(kind, o)
	o.hurt = int(round(climber.hurt_total))
	o.dosed = dosed
	return o


## Up to three: reach the top; no slips that counted; three in four of the
## everlastings picked.
func star_count(kind: String, o: ChallengeOutcome) -> int:
	if kind != "complete":
		return 0
	var n := 1
	if o.slips == 0:
		n += 1
	if hazards.flowers_total == 0 or hazards.flowers * 4 >= hazards.flowers_total * 3:
		n += 1
	return n


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
	_outcome = o
	stars = o.stars
	var best := Expedition.record_best(spec["id"], o.stars, o.flowers)
	var head: String = {"complete": copy["doneComplete"], "retreat": copy["doneRetreat"], "fail": copy["doneFail"]}[kind]
	var lines: Array = []
	if kind == "complete":
		lines.append("%d of 3 stars%s" % [o.stars, "  ·  a new best" if best else ""])
		lines.append("Star: topped out")
		lines.append(("Star: " if o.slips == 0 else "Missed: ") + "no slips that counted (%d)" % o.slips)
		lines.append(("Star: " if o.flowers * 4 >= o.flowers_total * 3 else "Missed: ") + "everlastings %d of %d (three in four)" % [o.flowers, o.flowers_total])
		if o.stars == 3:
			lines.append("Three stars: the party's spirits lift at camp.")
	else:
		lines.append("Everlastings %d of %d · cairn %d of %d" % [o.flowers, o.flowers_total, checkpoint, cairns.size() - 1])
	if o.gear_found > 0:
		lines.append("Lost gear found: %d" % o.gear_found)
	if o.hurt > 0:
		lines.append("Stamina lost to hits: %d (thistles %d, ants %d, ravens %d)%s" % [o.hurt, creatures.stings, creatures.bites, creatures.raven_hits,
			"; the party feels it at camp" if o.hurt >= 10 else ""])
	lines.append("%d min on the mountain" % maxi(1, o.seconds / 60))
	hud.flash(head)
	await get_tree().create_timer(1.2 if is_inside_tree() else 0.0).timeout
	panel.show_panel("Climb over", head, "\n".join(lines), [["camp", "Back to camp"]])
	# Lands by itself if nobody taps.
	await get_tree().create_timer(15.0 if is_inside_tree() else 0.0).timeout
	land()


## The outcome goes to the expedition, once.
func land() -> void:
	if _outcome != null and Expedition.climb.get("attemptId") == attempt_id:
		panel.hide_panel()
		Expedition.finish_climb(_outcome.to_dict())
