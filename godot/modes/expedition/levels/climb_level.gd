class_name ClimbLevel
extends Node2D
## A played climb on Kilimanjaro: the first climb, the middle climb, the
## summit night or the way down, each in the place the route goes (Places:
## nine places up, three ways down). Each level is an ASCII map
## (tools/levels) and a spec (its script, with an entry per route) with the
## climb's difficulty, look, people and words; this class
## assembles the level from them and runs the climb: the brief, cairns,
## slips, wind, the teammate who needs help, retreat, and the outcome,
## which lands on the expedition through the Coordinator exactly once.

signal finished(outcome: ChallengeOutcome)

const REGROUP_SECONDS := 30 * 60

## Set by each level's script. Keys:
##   id, maps (the base path of the route layouts: <maps>_<route>.txt and
##   .json, from tools/levels/route_levels.py), hud,
##   difficulty {recovery, drain, wind, maxSlips, helpCost},
##   theme {night, far, mid, cliff, deep, foreground, tint, snow},
##   mate {person, name, passDir} or {}, people {char: [person, title, lines]},
##   signs [[title, body]], copy {kicker, title, brief, backOff, mateTitle,
##   mateBody, decideHelped, decideLeft, decideBody, doneComplete,
##   doneRetreat, doneFail, cairnVista}
var spec: Dictionary = {}
var max_slips := 3
## The route this climb is laid out for (the long, faster or fastest way),
## and its layout: the order of the cairns and signs, where the gear and the
## artifacts lie, the teammate, and the line a climber takes.
var route := ""
var layout: Dictionary = {}
## What each route's layout is like, for the brief.
const ROUTE_LINES := {
	"lemosho": "The long way: your full stamina bar, and knocks hurt half as much.",
	"machame": "The faster way: half the stamina bar, and knocks hurt in full.",
	"umbwe": "The fastest way: a quarter of the stamina bar, knocks hurt in full, and more in the way.",
}


## The route a session climbs (the long way when none is chosen yet, as in
## the level tests).
static func route_of(session: Dictionary) -> String:
	var r := String(Trek.ensure(session).get("route", ""))
	return r if Trek.ROUTES.has(r) else "lemosho"


func map_path(for_route: String = "") -> String:
	return "%s_%s.txt" % [spec["maps"], for_route if for_route != "" else route_of(Expedition.session)]


func layout_for(for_route: String = "") -> Dictionary:
	var path := map_path(for_route).trim_suffix(".txt") + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## The spec's gear words with each one's cell on this route's map.
func gear_words() -> Array:
	var out: Array = []
	var cells: Array = layout.get("gear", [])
	for i in spec.get("gear", []).size():
		var w: Array = (spec["gear"][i] as Array).slice(0, 3)
		if i < cells.size():
			w.append(cells[i])
		out.append(w)
	return out

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
## Gear in the pack on this attempt, by kind (GEAR), in the order found.
## Lose the climb, or fall in a hole, and it is all gone: back where it was
## found.
var gear_kinds: Array = []
## The pack: what you found is carried, not used. Gear works only while you
## have it on (worn), and you choose: tap it in the pack (keys 1 to 6) to put
## it on or take it off. Drinks wait in the pack until you drink one.
var worn: Array = []
var drinks := 0
const PACK_SLOTS := 6
## A worn rope that has held a slip is done (its catch is spent).
var _rope_caught := 0
## REST refills you at most REST_LIMIT times between two cairns (a rest
## stone, and sitting out the wind, never count). Out of rests, a sit eats a
## snack from the camp's food instead: SNACK supplies, gone for the rest of
## the expedition. With no food to spare, a sit gives nothing back.
const REST_LIMIT := 2
## This route's rests a cairn: the long way's two; as many more as the bar
## is smaller (four on half the bar, eight on a quarter), so every route can
## get back the same stamina between two cairns, a smaller bar at a time.
var rest_limit := REST_LIMIT
const SNACK := 3
var rests_left := REST_LIMIT
var snacks := 0
## A rest lasts until you are full: get up to dodge a stone and sit again,
## and it is the same rest.
var _rest_open := false
## A fire at a cairn: a full rest, your rests back and a breather for the
## teammate, for FIRE_HOURS off the expedition's clock (the permit, and the
## leader points for speed). Once per cairn.
const FIRE_HOURS := 1
var fires: Array = []
## What each piece of gear does. The climb's spec places them (its "gear"
## list, [name, text, kind], bottom to top on the map), each before the
## thing it helps with.
const GEAR_KINDS := ["poles", "gloves", "shell", "crampons", "headlamp", "helmet", "rope"]
const GEAR := {
	"poles": {"label": "Poles", "walk": 0.7},
	"gloves": {"label": "Gloves", "rock": 0.8},
	"shell": {"label": "Goggles"},
	"crampons": {"label": "Crampons", "ice": 0.5},
	"headlamp": {"label": "Headlamp"},
	"helmet": {"label": "Helmet"},
	"rope": {"label": "Rope"},
}
## Pacing: every moment the player had to do something, [clock, kind]. The
## tests read it to check that no stretch of a climb is just walking.
var pace_log: Array = []
## Seconds spent walking (a face being climbed is play in itself; resting
## and reading are the player's choice).
var travel := 0.0
var _travel_clock := -1.0
var _was_on_ice := false
var _was_exposed := false
var _was_bracing := false
var _outcome: ChallengeOutcome
var stars := 0
## A helped teammate's breath: walking drains it (more in thin air, more if
## they are unwell), sitting near them gives it back. At zero they stop.
var mate_breath := 100.0
const ARMS_GRACE := 3.0
## The emptiest the bar got on this go (a share of it): how close the climb
## came to beating you. For balance tests and the results.
var lowest_stamina := 1.0
## Slips this go, by what caused them, and what to try about each.
var slips_by_cause := {}
const SLIP_LESSONS := {
	"rock": ["falling stones", "Watch for grit trickling over a column: a stone follows. Step to the side until it passes."],
	"fall": ["long falls", "Drops of more than four rows hurt. Climb down a face instead of letting go above a ledge."],
	"arms": ["empty arms", "Rest to full before a face (the warning on grabbing it says what it costs), and keep moving on it."],
	"wind": ["the wind", "On exposed ledges, don't move in a gust: when the wind warning shows, stop and REST until it passes, then walk on."],
	"hurt": ["thorns, ants and ravens", "Hop over thistles and ants; keep moving under a raven so it misses."],
	"hole": ["holes", "Hop the gaps: a fall into a hole sends you back to the start."],
}
## The level's day: temperature and light along the route (spec "climate").
var climate: Climate
var degrees := 10.0
var _base_recovery := 1.0
var _base_drain := 1.0
var _tint: ColorRect
## The sunrise at the top (summit night only).
var dawn: SummitDawn
## How far before the summit the sky starts to turn, in tiles.
const DAWN_TILES := 95.0
var _cold_said := false
var _hot_said := false
var _was_failing := false
## The slip under way was a fall into a hole (back to the start).
var _hole := false
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


## Each route climbs its own place here (Places): the spec's "routes"
## entry for the route replaces the base spec's keys (its "copy" is merged
## over the base's, so a place can keep shared lines).
func apply_route(for_route: String) -> void:
	var over: Dictionary = spec.get("routes", {}).get(for_route, {})
	for key in over:
		if key == "copy" and spec.get("copy") is Dictionary:
			var merged: Dictionary = (spec["copy"] as Dictionary).duplicate()
			merged.merge(over[key], true)
			spec["copy"] = merged
		else:
			spec[key] = over[key].duplicate(true) if over[key] is Dictionary or over[key] is Array else over[key]
	spec["place"] = Places.climb_name(String(spec["id"]), for_route)


func _ready() -> void:
	route = route_of(Expedition.session)
	apply_route(route)
	rest_limit = int(ceil(REST_LIMIT / Trek.bar_factor(Expedition.session)))
	rests_left = rest_limit
	var d: Dictionary = spec["difficulty"]
	# The route sets how forgiving the climbs are (Trek.max_slips).
	max_slips = Trek.max_slips(Expedition.session, int(d["maxSlips"]))
	layout = layout_for(route)
	spec["map"] = map_path(route)
	if layout.get("mate") is Dictionary and spec.get("mate", {}).size() > 0:
		spec["mate"]["passDir"] = int(layout["mate"]["passDir"])
	terrain = Terrain.load_file(spec["map"])
	var s: Dictionary = Expedition.state()
	var seed := int(s["seed"])
	var p: Variant = Expedition.pending()
	if p != null and p["challengeId"] == spec["id"]:
		seed = int(p["seed"])
	stamina = StaminaModel.new(float(s["energy"]), float(d["recovery"]), float(d["drain"]))
	# On the mountain only REST (and a rest stone) gives breath back.
	stamina.still_recovers = false
	stamina.thin_air = StaminaModel.thin_air_for(float(spec.get("meters", 4000)), float(s["acclimatization"]))
	# The trek reaches into the climb: a steeper route, and the body the
	# camp choices left you (sleep, food, sickness, medicine).
	trek_factor = Trek.climb_factor(Expedition.session)
	dosed = Expedition.climb.get("challengeId") == spec["id"] and Expedition.climb.get("dosed") == true
	condition = Condition.of(Expedition.session, dosed)
	# The route sets the bar's size (the long way's full bar, half, a
	# quarter: Trek.bar_factor), never below what its walls need.
	stamina.max_value = maxf(Trek.min_bar(Expedition.session), roundf(stamina.max_value * condition["stamina"] * Trek.bar_factor(Expedition.session)))
	stamina.value = stamina.max_value
	stamina.recovery = clampf(stamina.recovery * condition["recovery"], 0.2, 1.2)
	stamina.thin_air *= condition["thinAir"]
	stamina.grip = condition["grip"]
	climate = Climate.from_spec(spec.get("climate", {}))
	_base_recovery = stamina.recovery
	_base_drain = stamina.drain
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
	# In the order the line reaches them (the layout says; on the way down
	# that is top to bottom).
	var ks: Array = layout.get("cairns", []).map(func(k: Array) -> Vector2i: return Vector2i(int(k[0]), int(k[1])))
	if ks.is_empty():
		ks = terrain.markers.get("K", []).duplicate()
		ks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y or (a.y == b.y and a.x < b.x))
	for k in ks:
		cairns.append(Terrain.feet(k))

	_place_props()

	climber = Climber.new()
	climber.name = "Climber"
	# Helping costs a share of the bar: on the smaller bars of the faster
	# ways it is a bigger share, never more than you can have.
	climber.helper_cost = roundf(float(d["helpCost"]) * maxf(0.4, Trek.bar_factor(Expedition.session)))
	climber.setup(terrain, wind, stamina)
	climber.hurt_scale = Trek.hurt_factor(Expedition.session)
	add_child(climber)
	climber.global_position = cairns[0]
	climber.slipped.connect(_on_slipped)
	climber.slip_finished.connect(_on_slip_finished)
	# On Kilimanjaro, empty arms hang on for a moment: time to climb down.
	climber.arms_grace = ARMS_GRACE
	climber.rest_gate = _rest_gate
	climber.grabbed.connect(func() -> void:
		Haptics.tap(12)
		engage("grab")
		_face_warning())
	climber.jumped.connect(func() -> void: engage("hop"))
	climber.mantled.connect(func() -> void: engage("mantle"))
	# Over the edge: the body crosses it with a kick and the top-out sting.
	climber.mantled.connect(func() -> void:
		camera.kick(0.5, 7.0)
		Audio.play("topout", -10.0, 0.05))
	climber.hurt_taken.connect(func(amount: float, reason: String) -> void:
		camera.kick(0.3)
		Haptics.tap(30)
		if reason == "wind":
			hud.flash("The gust staggers you: -%d stamina. Don't move in the wind: REST until it passes." % int(round(amount)), 2.4))

	hazards = Hazards.new()
	hazards.name = "Hazards"
	add_child(hazards)
	var mine: bool = Expedition.climb.get("challengeId") == spec["id"]
	hazards.setup(self, terrain, ground, climber, float(d.get("rockPeriod", 5.0)) / trek_factor["steep"], gear_words(),
		Expedition.climb.get("taken", []) if mine else [], Expedition.climb.get("gear", []) if mine else [])
	hazards.place_artifacts(Artifacts.placed(spec["id"], route, layout.get("artifacts", [])),
		Artifacts.kept_on(Expedition.session, spec["id"]), Expedition.climb.get("taken", []) if mine else [])
	hazards.engaged.connect(engage)
	hazards.found_gear.connect(_on_gear)
	for i in (Expedition.climb.get("gear", []) if mine else []):
		var kind := gear_kind(int(i))
		if not gear_kinds.has(kind):
			gear_kinds.append(kind)
	if mine:
		for k in Expedition.climb.get("worn", []):
			if gear_kinds.has(String(k)) and not worn.has(String(k)):
				worn.append(String(k))
		drinks = int(Expedition.climb.get("drinks", 0))
	_apply_gear()
	if worn.has("rope"):
		climber.spotter = true

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
	# The summit night ends in a sunrise over the cloud sea.
	if spec.get("summit", false):
		dawn = SummitDawn.new()
		add_child(dawn)
	# The light of the hour, over the whole scene (multiplied in: white is
	# none, warm is afternoon sun, orange is sunset, blue is night).
	var tl := CanvasLayer.new()
	tl.layer = 6
	tl.name = "DayLight"
	add_child(tl)
	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tint.material = mul
	tl.add_child(_tint)

	hud = Hud.new()
	hud.title = spec["hud"]
	add_child(hud)
	panel = StoryPanel.new()
	add_child(panel)
	panel.chosen.connect(_on_choice)
	TouchControls.attach(self)
	Settings.interrupted.connect(_on_interrupted)
	Settings.back_requested.connect(_on_back)

	_resume_from_save()
	Audio.set_camp(1.0)
	# Each climb has its own music, under the wind and your breath.
	Audio.play_music(String(spec.get("music", "")))
	if not briefed:
		brief()


func mate_name() -> String:
	return spec.get("mate", {}).get("name", "")


func _place_props() -> void:
	var props := Node2D.new()
	props.name = "Props"
	props.z_index = -1
	add_child(props)
	# Signs are read in the order you climb past them (the layout says).
	var sign_cells: Array = layout.get("signs", []).map(func(k: Array) -> Vector2i: return Vector2i(int(k[0]), int(k[1])))
	if sign_cells.is_empty():
		sign_cells = terrain.markers.get("S", []).duplicate()
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
					if spec.get("summit", false):
						# The top of Kilimanjaro: the Uhuru sign and flags.
						var top := SummitTop.new()
						top.name = "SummitTop"
						top.position = feet + Vector2(-44, 0)
						props.add_child(top)
					else:
						props.add_child(_sprite("exit_post", feet))
	# Tussock and pebbles on open ledge tops, scattered deterministically.
	var green: bool = spec["theme"].get("grass", true)
	var flora: Dictionary = spec["theme"].get("flora", {})
	for y in terrain.height:
		for x in terrain.width:
			var cell := Vector2i(x, y)
			if terrain.kind(cell) != Terrain.Kind.ROCK or terrain.is_solid(cell + Vector2i.UP):
				continue
			if terrain.is_climbable(cell + Vector2i.UP) or terrain.markers.get("K", []).has(cell + Vector2i.UP):
				continue
			var h := posmod(x * 92821 + y * 68917, 100)
			# The place's own plants and ice first (theme "flora": name ->
			# share of ledge tops, in percent), then tussock and pebbles.
			var placed := false
			var acc := 0
			for name in flora:
				acc += int(flora[name])
				if h < acc:
					if _decor_room(cell + Vector2i.UP, name):
						var sp := _sprite(name, Terrain.feet(cell + Vector2i.UP))
						sp.z_index = -2 if name.begins_with("tree") else 0
						props.add_child(sp)
					placed = true
					break
			if placed:
				continue
			var hh := h - acc
			if green and hh >= 0 and hh < 22:
				props.add_child(_sprite("grass_%d" % (h % 4), Terrain.feet(cell + Vector2i.UP)))
			elif hh >= 0 and hh < 30:
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
			var said: Array = []
			for line in who[2]:
				var names_gone := false
				for id in Expedition.trek()["gone"]:
					if id != "you" and Trek.NAMES.get(id, "?") in String(line):
						names_gone = true
				if not names_gone:
					said.append(line)
			if said.is_empty():
				said = ["Let's get up this."]
			people.append({"node": c, "title": who[1], "lines": said})


## Room for a plant at `cell` (open, with nothing in the way): trees need
## open air well above them and no marker nearby, so they never hide a find
## or a face.
func _decor_room(cell: Vector2i, name: String) -> bool:
	var rows := 5 if name.begins_with("tree") else 2
	for dy in rows:
		for dx in [-1, 0, 1]:
			var c := cell + Vector2i(dx, -dy)
			if terrain.is_solid(c) or terrain.is_climbable(c):
				return false
	for ch in terrain.markers:
		for m in terrain.markers[ch]:
			if absi(m.x - cell.x) <= 2 and absi(m.y - cell.y) <= 2:
				return false
	# Nor over an artifact (they are on the layout, not the map).
	for a in layout.get("artifacts", []):
		if absi(int(a[0]) - cell.x) <= 3 and absi(int(a[1]) - cell.y) <= 4:
			return false
	return true


func _sprite(name: String, feet: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex("res://assets/terrain/props/%s.png" % name)
	s.centered = false
	s.position = feet - Vector2(s.texture.get_width() / 2.0, s.texture.get_height())
	return s


func _fire(feet: Vector2) -> Node2D:
	var fire := AnimatedSprite2D.new()
	var tex: Texture2D = Art.tex("res://assets/terrain/props/fire.png")
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
	if saved.get("challengeId") != spec["id"]:
		return
	# Anything happened on this go (a cairn, a slip, the clock, a teammate):
	# carry on from it. Only an untouched climb starts with the brief.
	var started: bool = int(saved.get("checkpoint", 0)) > 0 or int(saved.get("slips", 0)) > 0 \
		or float(saved.get("seconds", 0.0)) >= 1.0 or String(saved.get("mate", "")) in ["helped", "left"]
	if not started:
		return
	briefed = true
	checkpoint = clampi(int(saved["checkpoint"]), 0, cairns.size() - 1)
	climber.slips = clampi(int(saved.get("slips", 0)), 0, max_slips - 1)
	climber.clock = float(saved.get("seconds", 0.0))
	if mate:
		mate_state = String(saved.get("mate", "waiting"))
	regrouped = saved.get("regrouped") == true
	rests_left = clampi(int(saved.get("rests", rest_limit)), 0, rest_limit)
	snacks = maxi(0, int(saved.get("snacks", 0)))
	for f in saved.get("fires", []):
		fires.append(int(f))
		add_child(_fire(cairns[clampi(int(f), 0, cairns.size() - 1)] + Vector2(Terrain.TILE * 1.2, 0)))
	climber.global_position = cairns[checkpoint]
	climber.reset_physics_interpolation()
	if mate and mate_state == "helped":
		mate.helped()
		mate.catch_up(cairns[checkpoint])
		climber.spotter = saved.get("spotter", false) == true
	elif mate and mate_state == "left":
		mate.left_behind()
	camera.snap()
	hazards.skip_to(climber.clock)
	# Where you are matters more than the weather, which you met before.
	_cold_said = true
	_hot_said = true
	hud.flash("Back at cairn %d" % checkpoint if checkpoint > 0 else "Back at the start of the climb")


# --- The brief ----------------------------------------------------------------

## What this climb asks, before the first step. Backing off here lands as a
## retreat: the day is spent at camp, the expedition goes on.
func brief() -> void:
	climber.lock(true)
	var copy: Dictionary = spec["copy"]
	var d: Dictionary = spec["difficulty"]
	var st: Dictionary = Expedition.state()
	# What camp did to the body, row by row, with the numbers the climb uses.
	var rows := Condition.report(condition, stamina, float(st["energy"]), float(spec.get("meters", 4000)), float(st["acclimatization"]), float(d["recovery"]))
	# The weather along the way: where it starts and ends, and what it does.
	var t0 := climate.degrees(0.0, 0.0)
	var t1 := climate.degrees(1.0, 0.0)
	var coldest := minf(t0, t1)
	for k in climate.temps:
		coldest = minf(coldest, float(k[1]))
	var weather := "Starts at %d°C, ends near %d°C." % [int(round(t0)), int(round(t1))]
	if coldest < Climate.COOL:
		weather += " In the cold you move up to %d%% slower and rest works less." % int(round((1.0 - Climate.pace(coldest)) * 100.0))
	if maxf(t0, t1) >= Climate.WARM:
		weather += " In the heat every move costs up to %d%% more." % int(round((Climate.heat(maxf(t0, t1)) - 1.0) * 100.0))
	weather += " The longer you take, the more it changes."
	rows.append({"tone": "bad" if coldest < 0.0 or maxf(t0, t1) >= Climate.WARM else "info", "icon": "cloud", "title": "Weather", "text": weather})
	# The climb itself, in one smaller paragraph.
	var facts: Array = [String(ROUTE_LINES.get(route, "")), "Fall %d times and you turn back." % max_slips, "Wind: %s." % wind.describe()]
	if float(d["drain"]) > 1.0:
		facts.append("Up here every move costs %d%% more." % int(round((float(d["drain"]) - 1.0) * 100.0)))
	if trek_factor["steep"] > 1.0:
		facts.append("Your route is steep: more wind, and the stones come faster.")
	var missing: Array = []
	for id in Expedition.trek()["gone"]:
		if id != "you":
			missing.append(Trek.NAMES[id])
	if not missing.is_empty():
		facts.append("Without %s: the rope team is smaller than it was." % " and ".join(missing))
	var dangers: Array = spec.get("dangers", [])
	if not dangers.is_empty():
		facts.append("Watch for: " + ", ".join(dangers) + ".")
	rows.append({"tone": "info", "icon": "clock", "title": "%d rests a cairn" % rest_limit, "text": "REST fills you up %d times between two cairns (a rest lasts until you are full; rest stones and sitting out the wind don't count). After that, each rest eats camp food: supplies -%d, gone for the rest of the trip (you have %d)." % [rest_limit, SNACK, food_left()]})
	rows.append({"tone": "info", "icon": "bolt", "title": "Costs", "text": "Hops, ice, uphill and rock all cost stamina: more in the heat, the cold and thin air. In a gust, don't move: REST until it passes."})
	if hazards.gear_total() > 0:
		var names: Array = []
		for g in spec.get("gear", []):
			names.append(String(g[0]))
		rows.append({"tone": "good", "icon": "crate", "title": "Gear", "text": "Hidden on this climb, each before what it helps with: %s. Each one makes the climb easier. Fail the climb or fall in a hole and you start again with none: it goes back where it was." % ", ".join(names)})
	var left := hazards.artifacts_total() - hazards.artifacts_kept
	if left > 0:
		rows.append({"tone": "good", "icon": "crate", "title": "Artifacts", "text": "%s of Kilimanjaro's history hidden on the most dangerous ground of this climb (different on each route). Each one you bring home is worth %d leader points at the end. A slip drops every one you carry, ravens snatch them, and a failed climb leaves them behind." % ["Two pieces" if left == 2 else "One piece", Artifacts.POINTS]})
	# What the climb costs back at camp, before you start it.
	var stakes: Dictionary = Coordinator.CLIMBS.get(spec["id"], {}).get("stakes", {})
	if not stakes.is_empty():
		facts.append("After: each slip costs the party %d health at camp (up to %d); topping out under 25%% stamina costs 4 energy." % [int(stakes["slip"]), int(stakes["slipMax"])])
	var choices: Array = [["start", "Start the climb"]]
	if not dosed and Condition.medicine_helps(Expedition.session):
		var what: String = {"ams": "Take a painkiller first (like Tylenol)", "stomach": "Take stomach pills first", "cold": "Hand warmers first"}.get(String(condition["sick"]), "Take medicine first")
		choices.append(["medicine", "%s · %d left in the kit" % [what, condition["medicine"]]])
	if String(copy["backOff"]) != "":
		choices.append(["backoff", copy["backOff"]])
	panel.show_panel(copy["kicker"], copy["title"], _brief_words(), choices)
	panel.show_rows("Your climber, from your camp choices", rows, " ".join(facts))


## The level's brief, without the line about a teammate who has gone down.
func _brief_words() -> String:
	var words: String = spec["copy"]["brief"]
	if mate == null and mate_name() != "":
		var keep: Array = []
		for sentence in words.split(". "):
			if not (mate_name() in sentence and "somewhere" in sentence):
				keep.append(sentence)
		words = ". ".join(keep)
		if not words.ends_with("."):
			words += "."
	return words


# --- The climb --------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _ended or climber == null:
		return
	# Down a hole and out of the bottom of the map: there is no floor to
	# land on, so it is a fall that ends this go at the climb.
	if climber.global_position.y > terrain.pixel_size().y + Terrain.TILE and not climber.state in [Climber.State.SLIP, Climber.State.DONE, Climber.State.LOCKED]:
		climber.slip("hole")
	hazards.step()
	creatures.step()
	_pack_input()
	if briefed and climber.state != Climber.State.LOCKED:
		lowest_stamina = minf(lowest_stamina, stamina.fraction())
	_arms()
	_weather()
	_symptoms()
	_mate_breath()
	if _travel_clock >= 0.0 and climber.last_activity in ["walk", "walk_up", "ice"]:
		# At normal walking pace: the cold slows you, but the spacing of
		# things along the route is what this measures.
		travel += clampf(climber.clock - _travel_clock, 0.0, 0.1) * climber.chill
	_travel_clock = climber.clock
	# Stepping onto ice is a challenge of its own: keep your footing.
	if climber.on_ice and not _was_on_ice:
		engage("ice")
	_was_on_ice = climber.on_ice
	# So is stepping out into the wind: walk between the gusts.
	if climber.exposed and not _was_exposed and climber.state == Climber.State.GROUND:
		engage("wind")
	_was_exposed = climber.exposed
	# A rest is spent once it has filled you up.
	if _rest_open and stamina.value >= stamina.max_value - 0.5:
		_rest_open = false
	# Sitting out a gust on an exposed ledge.
	var sheltering := climber.state == Climber.State.REST and climber.exposed and climber.gust == WindSchedule.Phase.BLOW
	if sheltering and not _was_bracing:
		engage("shelter")
	_was_bracing = sheltering
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


## Stamina the face above costs to climb in one go, at this pace and with
## what this climb asks (thin air does not reach the arms; the cold does).
func face_cost() -> float:
	var f := climber.face_above()
	if f.x <= 0:
		return 0.0
	# At the speed you will actually climb: the cold slows you, and so does
	# being tired (under 30% of the bar).
	var speed := Climber.CLIMB_UP * climber.pace * (Climber.FATIGUE_SLOW if stamina.is_tired() else 1.0)
	var secs_per_row := Terrain.TILE / speed
	return (f.x - f.y) * secs_per_row * stamina.rate("climb") + f.y * secs_per_row * stamina.rate("climb", true)


## On grabbing the rock: say whether the arms will last to the top.
func _face_warning() -> void:
	var cost := face_cost()
	if cost <= 0.0:
		return
	if cost > stamina.value:
		hud.flash("This face takes about %d stamina and you have %d. Climb down and rest first." % [ceili(cost), int(stamina.value)], 3.0)
	elif cost > stamina.value * 0.7:
		hud.flash("Tight: this face takes about %d of your %d stamina. Keep moving." % [ceili(cost), int(stamina.value)], 2.6)


## The temperature here and now, and what it does: slower in the cold,
## slower to recover, dearer to move in the heat. Said once each way.
func _weather() -> void:
	var p := route_progress()
	degrees = climate.degrees(p, climber.clock)
	# A headlamp: you see your footing, and the cold and dark don't slow you.
	climber.chill = 1.0 if gear_kinds.has("headlamp") else Climate.pace(degrees)
	# A rest stone is shelter: out of the wind, the cold does not slow rest.
	var sheltered := climber.last_activity == "rest_stone"
	stamina.recovery = clampf(_base_recovery * (1.0 if sheltered else Climate.rest(degrees)), 0.2, 1.2)
	stamina.drain = clampf(_base_drain * Climate.heat(degrees), 0.5, 2.0)
	if _tint:
		_tint.color = climate.tint(p)
	if dawn:
		var top: Vector2 = Terrain.feet(terrain.markers["X"][0]) if terrain.markers.has("X") else climber.global_position
		var near := 1.0 - climber.global_position.distance_to(top) / (DAWN_TILES * Terrain.TILE)
		var want := smoothstep(0.0, 1.0, clampf(near, 0.0, 1.0))
		# The sun only rises: it never sets again if you step back.
		dawn.amount = maxf(dawn.amount, want)
		Audio.set_music_mood(dawn.amount)
		# Warm light over the world as the sun comes up.
		if _tint:
			_tint.color = _tint.color.lerp(Color(1.0, 0.9, 0.82), dawn.amount * 0.8)
	if roundf(degrees) < 0.0 and not _cold_said:
		_cold_said = true
		hud.flash("Below freezing (%d°C): you move slower and rest works less, except on a rest stone (shelter)." % int(round(degrees)), 3.2)
	elif degrees >= Climate.WARM and not _hot_said:
		_hot_said = true
		hud.flash("Hot sun (%d°C): every move costs a little more. Water helps." % int(round(degrees)), 3.0)


func climate_line() -> String:
	if climber.last_activity == "rest_stone" and degrees < Climate.COOL:
		return "%d°C · sheltered by the rest stone: full rest" % int(round(degrees))
	return Climate.words(degrees)


## Arms empty on the rock: say so the moment it starts.
func _arms() -> void:
	if climber.arms_failing and not _was_failing:
		hud.flash("Your arms are giving out! Climb down now, or you fall.", 2.5)
		Haptics.tap(40)
		Audio.play("grip", -2.0)
	_was_failing = climber.arms_failing


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
			var fresh := rests_left < rest_limit
			rests_left = rest_limit
			_rest_open = false
			hud.flash("Cairn %d of %d%s" % [checkpoint, cairns.size() - 1, " · rests back to %d" % rest_limit if fresh else ""])
			# The teammate you helped climbs with you, and says so.
			var said: Array = spec.get("mate", {}).get("climbLines", [])
			if mate_state == "helped" and not said.is_empty():
				hud.flash("Cairn %d of %d · %s" % [checkpoint, cairns.size() - 1, said[checkpoint % said.size()]], 3.0)
			_remember()
	# The exit post stands three tiles tall: hopping something just before
	# it still ends the climb there, not past it.
	for cell in terrain.markers.get("X", []):
		if climber.body_rect().intersects(Rect2(Vector2(cell.x, cell.y - 2) * Terrain.TILE, Vector2(1, 3) * Terrain.TILE)):
			finish("complete")
			return
	for v in terrain.markers.get("V", []):
		if not _vista_seen and feet.distance_to(Terrain.feet(v)) < 3 * Terrain.TILE:
			_vista_seen = true
			hud.flash(spec["copy"]["vista"])


## The app went to the background, the tab or window lost focus, or the
## phone locked: stop the clock under the pause menu, and save where the
## climb is so a closed app resumes from here.
func _on_interrupted() -> void:
	if _ended or panel.open or climber == null:
		return
	pause_menu()
	_remember()


func _on_back() -> void:
	if not _ended and not panel.open:
		pause_menu()


func _remember() -> void:
	Expedition.remember({
		"checkpoint": checkpoint,
		"slips": climber.slips,
		"mate": mate_state,
		"regrouped": regrouped,
		"spotter": climber.spotter,
		"seconds": climber.clock,
		"rests": rests_left,
		"snacks": snacks,
		"fires": fires,
	})


func _meet_mate() -> void:
	if mate == null or mate_state != "waiting" or panel.open:
		return
	var d := climber.global_position - mate.global_position
	if absf(d.x) > 3 * Terrain.TILE:
		mate_cooldown = false
	if climber.state == Climber.State.GROUND and absf(d.x) < 1.5 * Terrain.TILE and absf(d.y) < 0.6 * Terrain.TILE and not mate_cooldown:
		climber.lock(true)
		engage("mate")
		mate_panel()
	# Walking on past them without stopping leaves them for Lena.
	var pass_dir: int = spec["mate"].get("passDir", 1)
	if d.x * pass_dir > 2.5 * Terrain.TILE and absf(d.y) < Terrain.TILE:
		mate_state = "left"
		mate.left_behind()
		hud.flash("You climb on past %s. %s" % [mate_name(), _who_brings()])


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
				hud.flash("You went on without %s. %s" % [mate_name(), _who_brings()], 3.5)
				_remember()
				return
		if mate_breath >= 100.0:
			mate_winded = false
			climber.spotter = _mate_spotter
			mate.helped()
			mate.catch_up(climber.global_position)
			hud.flash("%s is ready. On you go, together." % mate_name())
	mate_breath = clampf(mate_breath, 0.0, 100.0)


func _no_lena() -> bool:
	return Trek.is_gone(Expedition.session, "lena")


func _who_brings() -> String:
	if _no_lena():
		return "With Lena gone, %s turns back down." % spec["mate"].get("they", "they")
	return "Lena will bring %s." % spec["mate"].get("them", "them")


func mate_panel() -> void:
	var can := stamina.value >= climber.helper_cost
	var copy: Dictionary = spec["copy"]
	panel.show_panel(
		"Teammate",
		copy["mateTitle"],
		"%s%s Helping costs you %d stamina now; %s would climb behind you after, and catch you if you slip. %s" % [copy["mateBody"], _mate_sick_words(), int(climber.helper_cost), spec["mate"].get("they", "they"),
			"Lena is an hour behind." if not _no_lena() else "Lena went down. If you leave %s, %s turns back for good." % [spec["mate"].get("them", "them"), spec["mate"].get("they", "they")]],
		[
			["help", ("Help %s" % mate_name()) if can else "Help %s (need %d stamina: step back and rest)" % [mate_name(), int(climber.helper_cost)], not can],
			["leave", ("Leave %s for Lena" % spec["mate"].get("them", "them")) if not _no_lena() else "Go on without %s" % spec["mate"].get("them", "them")],
			["back", "Step back"],
		])


## A teammate who is sick at camp is sick on the rock too: they stop for
## breath more often.
func _mate_sick_words() -> String:
	var sick := Trek.sickness(Expedition.session, String(spec["mate"].get("person", "")))
	if int(sick.get("stage", 0)) <= 0:
		return ""
	return " %s is unwell (%s): %s will need to stop for breath more often." % [mate_name(), Trek.describe(String(sick.get("kind", "")), int(sick["stage"])), spec["mate"].get("they", "they")]


func decide_panel() -> void:
	var copy: Dictionary = spec["copy"]
	var line := "%s climbs behind you now." % mate_name() if mate_state == "helped" else ("%s waits for Lena. You are on your own from here." % mate_name() if not _no_lena() else "%s turns back down. You are on your own from here." % mate_name())
	panel.show_panel(
		"Halfway up",
		copy["decideHelped"] if mate_state == "helped" else (copy["decideLeft"] if not _no_lena() else "On your own. Now what?"),
		"%s %s Stamina %d%%." % [line, copy["decideBody"], int(stamina.fraction() * 100)],
		[["continue", "Keep climbing"], ["regroup", "Regroup here (about an hour: full stamina, +2 energy at camp)"], ["retreat", spec["copy"]["backOff"]]])


func pause_menu() -> void:
	climber.lock(true)
	panel.show_panel(
		"Paused",
		spec["hud"],
		"Turning back is always open. It costs the day, not the expedition.",
		[
			["resume", "Resume"],
			["retreat", spec["copy"]["backOff"]],
			["settings", "Settings"],
			["quit", "Save and go to the menu"],
		])


## Settings, a page of their own so the pause menu stays short on a phone.
func settings_menu() -> void:
	climber.lock(true)
	panel.show_panel("Settings", spec["hud"], "", SettingsMenu.choices() + [["paused", "Back"]])


func _on_choice(id: String) -> void:
	if SettingsMenu.apply(id, self):
		settings_menu()
		return
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
			else:
				hud.flash("No dose left in the kit: you start without one.", 3.0)
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
			# Time passed: the stones of that hour are long gone.
			hazards.skip_to(climber.clock)
			hud.flash("The party catches up. About an hour passes.")
			_remember()
			climber.lock(false)
		"retreat":
			finish("retreat")
		"settings":
			settings_menu()
		"paused":
			pause_menu()
		"quit":
			_remember()
			Expedition.go(Expedition.MENU)
		"camp":
			land()
		"talk":
			climber.lock(false)
		"fire":
			make_fire()


func _on_helped() -> void:
	mate_state = "helped"
	mate.helped()
	hud.flash("%s is moving. %s'll catch your next slip." % [mate_name(), spec["mate"].get("They", "They")])
	_remember()
	decide_panel()


func _on_slipped(saved: bool, reason: String) -> void:
	# A fall is a moment in the climb's pacing too, caught or not.
	engage("slip")
	if saved:
		camera.kick(0.0)
	else:
		# The hit: a hold of a few frames, then a short hard kick.
		HitStop.freeze(self)
		camera.kick(1.0, 9.0)
	Haptics.tap(20 if saved else 60)
	if saved:
		hud.flash("%s grabs your pack. That slip doesn't count." % mate_name())
		return
	_hole = reason == "hole"
	slips_by_cause[reason] = int(slips_by_cause.get(reason, 0)) + 1
	var line: String = {"rock": "A falling stone knocks you off. Back to the last cairn.", "fall": "Fell too far. Back to the last cairn.",
		"arms": "Your arms gave out on the rock. Back to the last cairn: rest before the next face."}.get(reason, "Slipped. Back to the last cairn.")
	if _hole:
		line = "You fell into a hole. Back to the start of the climb."
		if lose_gear():
			line += " Your gear is gone: it is back where you found it."
	elif reason == "wind":
		line = "A gust takes the last of your strength. Back to the last cairn."
	elif reason == "hurt":
		line = "Too hurt to go on: you collapse. Back to the last cairn."
	if climber.slips >= max_slips:
		line = "Slip %d of %d: the climb is over." % [climber.slips, max_slips]
	var lost := hazards.drop_artifacts()
	if lost > 0:
		# Carried artifacts are this attempt's: forget them in the save too.
		forget_taken(hazards.artifact_keys())
		line += " You drop %s: back where you found %s." % (["the artifact", "it"] if lost == 1 else ["both artifacts", "them"])
	hud.flash(line, 3.0)


func _on_slip_finished() -> void:
	if climber.slips >= max_slips:
		finish("fail")
		return
	if _hole:
		# A hole is the worst fall there is: you start the climb again.
		_hole = false
		checkpoint = 0
	climber.respawn(cairns[checkpoint])
	# Back at a cairn: a fresh stretch, with its rests.
	rests_left = rest_limit
	_rest_open = false
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
		if checkpoint > 0 and not fires.has(checkpoint) and feet.distance_to(cairns[checkpoint]) < 20.0:
			_interact_target = {"kind": "fire"}
			prompt = "Make a fire at the cairn (%d hour)" % FIRE_HOURS
			action_word = "FIRE"
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
		"fire":
			climber.lock(true)
			Audio.play("chime", -14.0)
			panel.show_panel("Cairn %d" % checkpoint, "Make a fire?",
				"A fire and a hot drink: full stamina, your rests back%s. It costs %d hour of the expedition: the permit's clock, and the leader points for speed." % [
					", and %s gets their breath back" % mate_name() if mate and mate_state == "helped" else "", FIRE_HOURS],
				[["fire", "Make a fire (%d hour)" % FIRE_HOURS], ["talk", "Not now, keep moving"]])
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
## The kind of the gear at `index` (the spec's gear list, bottom to top).
func gear_kind(index: int) -> String:
	var list: Array = hazards.gear_words if hazards and not hazards.gear_words.is_empty() else spec.get("gear", [])
	if list.is_empty():
		return "poles"
	var g: Array = list[clampi(index, 0, list.size() - 1)]
	return String(g[2]) if g.size() > 2 else "poles"


## Found a piece of gear: into the pack. It does nothing until you put it on.
func _on_gear(index: int) -> void:
	gear_this_attempt += 1
	var kind := gear_kind(index)
	if not gear_kinds.has(kind):
		gear_kinds.append(kind)
	# The collection (kept across attempts, for the record only).
	Expedition.find_gear(spec["id"], index)
	var held: Array = Expedition.climb.get("gear", [])
	if not held.has(index):
		held.append(index)
	Expedition.remember({"gear": held})
	var slot := gear_kinds.find(kind) + 1
	hud.flash("%s is in your pack. Put it on when you want it: tap it in the pack (key %d)." % [String(GEAR[kind]["label"]), slot], 4.0)


## Found a drink: into the pack, for when you choose.
func on_drink(key: String) -> void:
	drinks += 1
	on_water(key)
	Expedition.remember({"drinks": drinks})
	hud.flash("%s, in your pack. Drink it when you need it (key %d)." % [String(spec.get("drink", "A drink")).capitalize(), pack_slots().size()], 3.5)


## What is in the pack, in slot order: gear in the order found, then the
## drinks. [{id, label, on, count}].
func pack_slots() -> Array:
	var out: Array = []
	for k in gear_kinds:
		out.append({"id": k, "label": String(GEAR[k]["label"]), "on": worn.has(k), "count": 1})
	if drinks > 0:
		out.append({"id": "drink", "label": "Drink", "on": false, "count": drinks})
	return out.slice(0, PACK_SLOTS)


## Uses what is in pack slot `i` (0-based): puts gear on or takes it off,
## or drinks. Returns false when the slot is empty or it cannot be used now.
func use_slot(i: int) -> bool:
	var slots := pack_slots()
	if i < 0 or i >= slots.size() or climber.state in [Climber.State.SLIP, Climber.State.DONE, Climber.State.LOCKED]:
		return false
	var item: Dictionary = slots[i]
	var id := String(item["id"])
	if id == "drink":
		drinks -= 1
		stamina.value = minf(stamina.max_value, stamina.value + stamina.max_value * Hazards.WATER)
		Audio.play("chime", -10.0)
		hud.flash("You drink %s: stamina back up." % String(spec.get("drink", "some water")), 2.5)
		engage("drink")
		Expedition.remember({"drinks": drinks})
		return true
	if worn.has(id):
		worn.erase(id)
		hud.flash("%s off, back in the pack." % String(GEAR[id]["label"]), 2.0)
	else:
		worn.append(id)
		hud.flash("%s on." % String(GEAR[id]["label"]), 2.0)
		Audio.play("clip", -8.0)
	if id == "rope":
		# A short rope: someone (the guide) can hold your next slip on it.
		climber.spotter = worn.has("rope")
		_rope_caught = climber.caught
	engage("gear")
	Expedition.remember({"worn": worn.duplicate()})
	_apply_gear()
	return true


## What the gear you have on does: to stamina costs, the ice, the wind.
func _apply_gear() -> void:
	stamina.walk_gear = float(GEAR["poles"]["walk"]) if worn.has("poles") else 1.0
	stamina.rock_gear = float(GEAR["gloves"]["rock"]) if worn.has("gloves") else 1.0
	stamina.ice_gear = float(GEAR["crampons"]["ice"]) if worn.has("crampons") else 1.0
	climber.crampons = worn.has("crampons")
	climber.helmet = worn.has("helmet")
	climber.wind_shell = worn.has("shell")


## The pack's buttons (keys 1 to 6, the touch pack row), and a worn rope
## used up by the slip it held.
func _pack_input() -> void:
	for i in PACK_SLOTS:
		if GameInput.pressed_now("use_%d" % (i + 1)) and not panel.open:
			use_slot(i)
	if worn.has("rope") and climber.caught > _rope_caught:
		worn.erase("rope")
		gear_kinds.erase("rope")
		Expedition.remember({"worn": worn.duplicate()})
		hud.flash("The rope held you. It is done for this climb.", 3.0)


## Lost the climb (or fell in a hole): all the gear goes back where it was
## found, and you start again with none. True if there was any.
func lose_gear() -> bool:
	var had := not gear_kinds.is_empty()
	gear_kinds.clear()
	worn.clear()
	hazards.drop_gear()
	Expedition.remember({"gear": [], "worn": []})
	_apply_gear()
	return had


## The top of Kilimanjaro: the sun all the way up, petals on the wind, the
## team cheering, and the view.
func _summit_moment() -> void:
	if dawn:
		var tw := create_tween()
		tw.tween_property(dawn, "amount", 1.0, 1.5)
	var petals := CPUParticles2D.new()
	petals.name = "Petals"
	petals.position = climber.global_position - Vector2(0, 24)
	petals.amount = 90
	petals.lifetime = 4.0
	petals.one_shot = true
	petals.explosiveness = 0.7
	petals.direction = Vector2(0.2, -1)
	petals.spread = 70.0
	petals.initial_velocity_min = 40.0
	petals.initial_velocity_max = 110.0
	petals.gravity = Vector2(14, 38)
	petals.angular_velocity_min = -180.0
	petals.angular_velocity_max = 180.0
	petals.scale_amount_min = 1.5
	petals.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.82, 0.9))
	ramp.set_color(1, Color(1.0, 0.95, 0.7, 0.0))
	ramp.add_point(0.5, Color(1, 1, 1))
	petals.color_ramp = ramp
	petals.color_initial_ramp = ramp
	add_child(petals)
	petals.emitting = true
	if mate and mate_state == "helped":
		mate.global_position = climber.global_position + Vector2(-20, 0)
	# The top: a kick and the top-out sting, then the bell and the words.
	camera.kick(0.7, 6.0)
	Audio.play("topout", -3.0, 0.0)
	Audio.play("cairn", -2.0)
	Haptics.tap(80)
	hud.flash("Uhuru Peak, 5,895 m. The sun comes up over the whole of Africa, and you are standing on its roof.", 4.5)


## A fire at the cairn you are at: full stamina, the rests back, the
## teammate's breath back, an hour off the expedition.
func make_fire() -> void:
	if checkpoint <= 0 or fires.has(checkpoint):
		climber.lock(false)
		return
	fires.append(checkpoint)
	engage("fire")
	stamina.value = stamina.max_value
	rests_left = rest_limit
	_rest_open = false
	if mate and mate_state == "helped":
		mate_breath = 100.0
		mate_winded = false
	var f := _fire(cairns[checkpoint] + Vector2(Terrain.TILE * 1.2, 0))
	add_child(f)
	Audio.play("cairn", -6.0)
	hud.flash("A fire at cairn %d: full stamina and fresh rests. The expedition is %d hour%s later." % [checkpoint, fires.size() * FIRE_HOURS, "" if fires.size() * FIRE_HOURS == 1 else "s"], 3.0)
	climber.lock(false)
	_remember()


## Camp food left to eat on the climb (the expedition's supplies, less the
## snacks already eaten here).
func food_left() -> int:
	return int(Expedition.state().get("supplies", 0)) - snacks * SNACK


## A sit that would refill you: one of this stretch's rests, else a snack
## from camp, else nothing.
func _rest_gate() -> bool:
	if _rest_open:
		return true
	if rests_left > 0:
		rests_left -= 1
		_rest_open = true
		if rests_left == 0:
			hud.flash("Your last rest before the next cairn. After this, resting eats camp food.", 2.6)
		_remember()
		return true
	if food_left() >= SNACK:
		snacks += 1
		_rest_open = true
		Haptics.tap(10)
		hud.flash("No rests left: you eat from the camp food (supplies -%d). Get to the next cairn for fresh rests." % SNACK, 3.0)
		_remember()
		return true
	hud.flash("No rests left and no food to spare: nothing comes back. Make for the next cairn.", 3.0)
	return false


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
	o.food = snacks * SNACK
	o.fire_hours = fires.size() * FIRE_HOURS
	o.artifacts = hazards.artifacts_kept + (0 if kind == "fail" else hazards.artifacts.size())
	o.artifacts_total = hazards.artifacts_total()
	o.stars = star_count(kind, o)
	o.hurt = int(round(climber.hurt_total))
	o.dosed = dosed
	return o


## What the slips were, and the one thing to try next time (for the
## cause that cost the most): the climb's own coaching, as the crag does.
func slip_summary() -> String:
	if slips_by_cause.is_empty():
		return ""
	var parts: Array = []
	var worst := ""
	for k in slips_by_cause:
		parts.append("%d from %s" % [slips_by_cause[k], SLIP_LESSONS.get(k, [k])[0]])
		if worst == "" or int(slips_by_cause[k]) > int(slips_by_cause[worst]):
			worst = k
	var tip: String = SLIP_LESSONS.get(worst, ["", ""])[1]
	return "Slips: %s.%s" % [", ".join(parts), (" Try next: " + tip) if tip != "" else ""]


## Up to three: reach the top; no slips that counted; both artifacts kept.
func star_count(kind: String, o: ChallengeOutcome) -> int:
	if kind != "complete":
		return 0
	var n := 1
	if o.slips == 0:
		n += 1
	if o.artifacts >= o.artifacts_total:
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
	if kind == "fail":
		# Lost the climb: the next go starts with no gear, and the artifacts
		# carried go back where they were found.
		lose_gear()
		hazards.drop_artifacts()
		forget_taken(hazards.artifact_keys())
	else:
		# The top, or a retreat walked down: what you carry is yours.
		Artifacts.keep(Expedition.session, spec["id"], hazards.artifacts)
	panel.hide_panel()
	Audio.stop_ambience()
	var o := outcome_now(kind)
	finished.emit(o)
	var copy: Dictionary = spec["copy"]
	_outcome = o
	stars = o.stars
	var best := Expedition.record_best(spec["id"], o.stars, o.artifacts)
	var head: String = {"complete": copy["doneComplete"], "retreat": copy["doneRetreat"], "fail": copy["doneFail"]}[kind]
	var summit: bool = kind == "complete" and spec.get("summit", false)
	if summit:
		_summit_moment()
	var lines: Array = []
	if kind == "complete":
		lines.append("%d of 3 stars%s" % [o.stars, "  ·  a new best" if best else ""])
		lines.append("Star: topped out")
		lines.append(("Star: " if o.slips == 0 else "Missed: ") + "no slips that counted (%d)" % o.slips)
		lines.append(("Star: " if o.artifacts >= o.artifacts_total else "Missed: ") + "artifacts %d of %d" % [o.artifacts, o.artifacts_total])
		if o.stars == 3:
			lines.append("Three stars: the party's spirits lift at camp.")
	else:
		lines.append("Artifacts %d of %d · cairn %d of %d" % [o.artifacts, o.artifacts_total, checkpoint, cairns.size() - 1])
	var mine := Artifacts.kept_on(Expedition.session, spec["id"])
	if not mine.is_empty() and kind != "fail":
		lines.append("Kept: %s (+%d leader points each, if the team gets home)" % [", ".join(mine.map(func(i: int) -> String: return String(hazards.artifact_words[i][0]))), Artifacts.POINTS])
	if not fires.is_empty():
		lines.append("Fires at the cairns: %d (the expedition is %d hour%s later)" % [fires.size(), fires.size() * FIRE_HOURS, "" if fires.size() * FIRE_HOURS == 1 else "s"])
	if snacks > 0:
		lines.append("Camp food eaten on the climb: %d snack%s (supplies -%d)" % [snacks, "" if snacks == 1 else "s", snacks * SNACK])
	if hazards.gear_total() > 0:
		lines.append("Gear: %d of %d%s" % [gear_kinds.size(), hazards.gear_total(), (" (" + ", ".join(gear_kinds.map(func(k: String) -> String: return String(GEAR[k]["label"]).to_lower())) + ")") if not gear_kinds.is_empty() else ""])
	if o.hurt > 0:
		lines.append("Stamina lost to hits: %d (thistles %d, ants %d, ravens %d)%s" % [o.hurt, creatures.stings, creatures.bites, creatures.raven_hits,
			"; the party feels it at camp" if o.hurt >= 10 else ""])
	lines.append("%d min on the mountain" % maxi(1, o.seconds / 60))
	var why := slip_summary()
	if why != "":
		lines.append(why)
	if not summit:
		hud.flash(head)
	# On the summit, time to look around before the results.
	await get_tree().create_timer((4.5 if summit else 1.2) if is_inside_tree() else 0.0).timeout
	panel.show_panel("Climb over", head, "\n".join(lines), [["camp", "Back to camp"]])
	# Lands by itself if nobody taps.
	await get_tree().create_timer(45.0 if is_inside_tree() else 0.0).timeout
	land()


## The outcome goes to the expedition, once.
func land() -> void:
	if _outcome != null and Expedition.climb.get("attemptId") == attempt_id:
		panel.hide_panel()
		Expedition.finish_climb(_outcome.to_dict())


func _exit_tree() -> void:
	# Never leave the world frozen behind a scene change mid hit-stop.
	HitStop.release()
