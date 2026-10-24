class_name CampWorld
extends Control
## The camp you walk through (CLIMB UP 2.0). Tap the ground to walk there,
## tap a person or a place to go and talk (or use the arrows and E). Every
## camp action is the expedition's own (Expedition.choose, tend, treat,
## medicate, send down, the camp jobs): this is a place to make the same
## decisions as the camp board, never a second set of rules.
##
##   Lena, by the map board:  today's decision (or the climb that waits)
##   Neema, the ranger:       the weather briefing for the next climb
##   Baraka, the cook:        the water on, and the stores
##   Marco and Jun:           how they are, and what you can do for them
##   Juma, the porter:        your pack (gear swaps between climbs)
##   your tent:               how you will feel on the next climb; saved
##   the signpost:            the camp board, everything on one page

const WIDTH := 1100.0
const GROUND := 0.8
const SPEED := 70.0
const NEAR := 26.0

var stage: Control
var you: Hero
var people: Dictionary = {}
## id -> {x, label, verb, act: Callable, who (person id or "")}
var spots: Dictionary = {}
var prompt: Button
var hud_place: Label
var hud_stats: HBoxContainer
var camera_x := 0.0
var target_x := -1.0
var near_id := ""
var sheet: JournalSheet
var sky: Dictionary = {}
var _rain: Array = []
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Settings.back_requested.connect(_on_back)
	Audio.play_music("camp")
	Audio.set_camp(1.0)
	if Expedition.session.is_empty() and Expedition.has_save():
		Expedition.load_saved()
	clip_contents = true
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.draw.connect(_draw_stage)
	add_child(stage)
	_build_people()
	_build_hud()
	Expedition.changed.connect(_refresh)
	_refresh()
	Analytics.event("screen_opened", {"screen": "camp_world"})
	if not Expedition.active():
		_scorecard.call_deferred()
	elif not Profile.has_seen("camp_world"):
		_tip.call_deferred()


func _exit_tree() -> void:
	if Expedition.changed.is_connected(_refresh):
		Expedition.changed.disconnect(_refresh)


func ground_y() -> float:
	return size.y * GROUND


# --- people and places ---------------------------------------------------------


func _person(id: String, x: float, pose: String, facing: float) -> Hero:
	var h := Hero.new()
	h.height = 40.0
	h.set_look(Profile.look if id == "you" else TeamLooks.look(id))
	h.kit = "camp" if id != "you" else "trek"
	h.pose = pose
	h.facing = facing
	h.phase = x * 0.013
	h.position = Vector2(x, 0)
	stage.add_child(h)
	people[id] = h
	return h


func _build_people() -> void:
	_person("lena", 250, "idle", 1)
	_person("cook", 470, "work", -1)
	_person("marco", 640, "sit", 1)
	_person("jun", 700, "idle", -1)
	_person("porter", 880, "crouch", 1)
	_person("ranger", 1010, "idle", -1)
	you = _person("you", 360, "idle", 1)


## The stations: where they stand, what they say, what a tap does.
func _refresh() -> void:
	sky = Briefing.sky(Expedition.state())
	spots.clear()
	var s := Expedition.state()
	var gone: Array = Expedition.trek().get("gone", [])
	spots["tent"] = {"x": 130.0, "label": "Your tent", "verb": "Check in", "act": open_tent, "who": ""}
	spots["lena"] = {"x": 250.0, "label": "Lena · guide", "verb": _lena_verb(), "act": open_decision, "who": "lena"}
	spots["cook"] = {"x": 470.0, "label": "Baraka · cook", "verb": "Talk", "act": open_cook, "who": "cook"}
	for id in ["marco", "jun"]:
		var here := not gone.has(id)
		people[id].visible = here
		if here:
			spots[id] = {"x": people[id].position.x, "label": "%s · %s" % [Trek.NAMES[id], _role(id)], "verb": "How are you?", "act": open_person.bind(id), "who": id}
	people["lena"].visible = not gone.has("lena")
	if gone.has("lena"):
		spots["lena"]["label"] = "The map board"
	spots["porter"] = {"x": 880.0, "label": "Juma · porter", "verb": "Your pack", "act": open_pack, "who": "porter"}
	spots["ranger"] = {"x": 1010.0, "label": "Neema · ranger", "verb": "Weather", "act": open_weather, "who": "ranger"}
	spots["sign"] = {"x": 1070.0, "label": "Signpost", "verb": "Camp board", "act": open_board, "who": ""}
	hud_place.text = "%s · %s m · day %d" % [Hub.camp_name(), ExpeditionEngine.format_meters(s["altitude"]), ExpeditionEngine.day_of(s) + 1]
	for c in hud_stats.get_children():
		c.queue_free()
	for spec in [["energy", "Energy", false], ["health", "Health", false], ["supplies", "Stores", false], ["weatherRisk", "Weather risk", true]]:
		var v := float(s.get(spec[0], 0)) / 100.0
		var cell := UiKit.vbox(0)
		cell.add_child(UiKit.label("%s %d" % [spec[1], int(s.get(spec[0], 0))], UiTokens.TEXT_S, UiTokens.CHALK))
		var m := Meter.make(1.0 - v if spec[2] else v, 44.0, 3.0)
		cell.add_child(m)
		hud_stats.add_child(cell)
	# The sick and the exhausted look it.
	for m in Party.members(s):
		var id: String = m["id"]
		if people.has(id) and id != "you" and id != "lena":
			var sick := not Trek.sickness(Expedition.session, id).is_empty()
			people[id].pose = "sit" if sick or m["pose"] == "kneel" else ("idle" if id == "jun" else "sit")
			people[id].expression = "worried" if sick else ("tired" if m["pose"] != "walk" and m["pose"] != "stand" and m["pose"] != "" and m["pose"] != "ok" else "")
	stage.queue_redraw()
	_update_prompt()


func _role(id: String) -> String:
	for m in Party.members(Expedition.state()):
		if m["id"] == id:
			return String(m["role"]).to_lower()
	return ""


func _lena_verb() -> String:
	if not Expedition.active():
		return "How did we do?"
	if Expedition.pending() != null:
		return "Back to the climb"
	return "Today's decision"


# --- HUD -----------------------------------------------------------------------


func _build_hud() -> void:
	var top := UiKit.vbox(2)
	add_child(top)
	hud_place = UiKit.world_label("", UiTokens.TEXT_L, true)
	top.add_child(hud_place)
	var plate := UiKit.panel(UiTokens.SCRIM, 4.0, Color(0, 0, 0, 0))
	hud_stats = UiKit.hbox(6)
	plate.add_child(hud_stats)
	top.add_child(plate)
	UiKit.pin(top, Control.PRESET_TOP_LEFT, Vector2(8, 6))
	var right := UiKit.hbox(4)
	add_child(right)
	var board := UiKit.button("Camp board", open_board, "dark", UiTokens.TEXT)
	board.name = "Board"
	right.add_child(board)
	right.add_child(UiIcon.button("back", "Home", go_home))
	UiKit.pin(right, Control.PRESET_TOP_RIGHT, Vector2(8, 6))
	prompt = UiKit.button("", _act_near, "primary", UiTokens.TEXT_L)
	prompt.name = "Prompt"
	prompt.custom_minimum_size = Vector2(170, UiTokens.TAP + 4)
	add_child(prompt)
	UiKit.pin(prompt, Control.PRESET_CENTER_BOTTOM, Vector2(0, 8))
	prompt.visible = false


func _update_prompt() -> void:
	if near_id == "" or not spots.has(near_id):
		prompt.visible = false
		return
	var sp: Dictionary = spots[near_id]
	prompt.text = "%s · %s" % [sp["label"].split(" · ")[0], sp["verb"]]
	prompt.visible = sheet == null or not is_instance_valid(sheet)
	if prompt.visible:
		UiKit.pin(prompt, Control.PRESET_CENTER_BOTTOM, Vector2(0, 8))


# --- walking -------------------------------------------------------------------


func _gui_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if not tap or (sheet != null and is_instance_valid(sheet)):
		return
	var wx: float = e.position.x + camera_x
	# A tap on a person or a place walks there and talks.
	for id in spots:
		if absf(float(spots[id]["x"]) - wx) < 16.0 and e.position.y > ground_y() - 60.0:
			walk_to(float(spots[id]["x"]) - 14.0, id)
			return
	walk_to(wx)


var _talk_on_arrive := ""


func walk_to(x: float, then_talk: String = "") -> void:
	target_x = clampf(x, 20.0, WIDTH - 20.0)
	_talk_on_arrive = then_talk


func _process(delta: float) -> void:
	_t += delta
	if stage == null:
		return
	var dx := GameInput.move().x
	if absf(dx) > 0.3:
		target_x = -1.0
		_talk_on_arrive = ""
	elif target_x >= 0.0:
		var d := target_x - you.position.x
		dx = signf(d) if absf(d) > 2.0 else 0.0
		if dx == 0.0:
			target_x = -1.0
			if _talk_on_arrive != "":
				near_id = _talk_on_arrive
				_talk_on_arrive = ""
				interact()
	var busy := sheet != null and is_instance_valid(sheet)
	if busy:
		dx = 0.0
	you.position.x = clampf(you.position.x + dx * SPEED * delta, 20.0, WIDTH - 20.0)
	you.pose = "walk" if absf(dx) > 0.1 else "idle"
	if absf(dx) > 0.1:
		you.facing = signf(dx)
	# Everyone stands on the ground.
	for id in people:
		people[id].position.y = ground_y() + 2.0
	# The camera keeps you a third in from the edge you walk toward.
	var want := clampf(you.position.x - size.x * 0.45, 0.0, maxf(0.0, WIDTH - size.x))
	camera_x = lerpf(camera_x, want, 1.0 - exp(-delta * 5.0)) if not Settings.reduced_motion else want
	stage.position = Vector2(-camera_x, 0)
	stage.size = Vector2(WIDTH, size.y)
	# Who is near.
	var best := ""
	var best_d := NEAR
	for id in spots:
		var d := absf(float(spots[id]["x"]) - you.position.x)
		if d < best_d:
			best_d = d
			best = id
	if best != near_id:
		near_id = best
		_update_prompt()
		# The person you walk up to turns to you.
		if best != "" and spots[best]["who"] != "" and people.has(spots[best]["who"]):
			people[spots[best]["who"]].facing = signf(you.position.x - float(spots[best]["x"]))
	if not busy and GameInput.pressed_now("interact") and near_id != "":
		interact()
	if float(sky.get("rain", 0.0)) > 0.0 and not Settings.reduced_motion:
		stage.queue_redraw()


func interact() -> void:
	if near_id == "" or not spots.has(near_id):
		return
	Analytics.event("camp_interacted", {"spot": near_id})
	Audio.play("tap", -12.0, 0.05, false, 1.2)
	(spots[near_id]["act"] as Callable).call()


func _act_near() -> void:
	interact()


func _sheet(title: String, who: String = "", width: float = 300.0) -> JournalSheet:
	if sheet != null and is_instance_valid(sheet):
		sheet.close()
	sheet = JournalSheet.open(self, title, width)
	sheet.closed.connect(func() -> void:
		sheet = null
		_update_prompt.call_deferred())
	prompt.visible = false
	if who != "" and people.has(who):
		people[who].pose = "talk"
		sheet.closed.connect(func() -> void: _refresh.call_deferred())
	return sheet


# --- what each place does --------------------------------------------------------


## Lena: today's decision, the climb that waits, or the scorecard.
func open_decision() -> void:
	if not Expedition.active():
		_scorecard()
		return
	var p: Variant = Expedition.pending()
	if p != null:
		var sh := _sheet("A climb is waiting", "lena")
		sh.text("You left %s part way. Pick up where you left it." % Places.climb_name(String(p["challengeId"]), Places.route_of(Expedition.session)))
		var go := UiKit.button("Go back to the climb", func() -> void:
			if Crag.navigate:
				Expedition.resume_climb(), "primary", UiTokens.TEXT)
		go.name = "Resume"
		sh.add(go)
		return
	var card := Expedition.card()
	if card.is_empty():
		return
	var route := Places.route_of(Expedition.session)
	var sh := _sheet(Places.say(String(card["title"]), route), "lena", 330.0)
	sh.name = "Decision"
	sh.text(Plain.say(Places.say(String(card["text"]), route)), UiTokens.TEXT, UiTokens.INK_SOFT)
	var playable := Expedition.playable()
	var why := UiKit.label("", UiTokens.TEXT_S, UiTokens.INK_MUTED, false, 300.0)
	for i in card["choices"].size():
		var choice: Dictionary = card["choices"][i]
		var f := Trek.foresee(Expedition.session, choice, Expedition.def)
		var b := UiKit.button("", Callable(), "paper", UiTokens.TEXT)
		b.name = "Choice%d" % i
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 30)
		var v := UiKit.vbox(1)
		v.position = Vector2(7, 3)
		b.add_child(v)
		v.add_child(UiKit.label(Places.say(String(choice["label"]), route), UiTokens.TEXT, UiTokens.INK, true))
		var tags := UiKit.hbox(3)
		v.add_child(tags)
		if i < playable.size() and String(playable[i]) != "":
			tags.add_child(UiKit.chip("YOU CLIMB", UiTokens.SPRUCE, UiTokens.SPRUCE_INK, 6))
		if not f.is_empty():
			if float(f.get("hours", 0)) > 0:
				tags.add_child(UiKit.chip("%d h" % int(f["hours"]), UiTokens.PAPER_SUNK, UiTokens.INK_SOFT, 6))
			var band := String(f.get("risk", "low"))
			tags.add_child(UiKit.chip("%s RISK" % band.to_upper(), {"low": UiTokens.GOOD, "medium": UiTokens.WARN, "high": UiTokens.BAD}.get(band, UiTokens.INK_MUTED), UiTokens.CHALK, 6))
		b.pressed.connect(_choose.bind(i, b, f, why))
		sh.add(b)
	sh.add(why)


var _armed := -1


## The first tap shows what a choice does; the second makes it.
func _choose(i: int, b: Button, f: Dictionary, why: Label) -> void:
	if _armed == i:
		_armed = -1
		if sheet:
			sheet.close()
		Expedition.choose(i)
		return
	_armed = i
	for c in b.get_parent().get_children():
		if c is Button:
			UiKit.style_button(c, "primary" if c == b else "paper")
	var words: Array = f.get("why", [])
	why.text = "Tap again to decide." + (" Why it is risky: " + ", ".join(words) + "." if not words.is_empty() and String(f.get("risk", "low")) != "low" else "")


func open_weather() -> void:
	var route := Places.route_of(Expedition.session)
	var s := Expedition.state()
	var sh := _sheet("Weather briefing", "ranger")
	sh.text(Briefing.risk_words(s), UiTokens.TEXT, UiTokens.INK)
	var next := next_climb()
	if next != "":
		var b := Briefing.for_climb(next, route)
		sh.add(UiKit.label("Next climb: %s · %s m" % [b["place"], ExpeditionEngine.format_meters(b["meters"])], UiTokens.TEXT_L, UiTokens.INK, true))
		sh.text(Briefing.line(b))
		for h in Briefing.gear_hints(b):
			sh.text("Would help: %s (Juma has your pack)." % EquipmentCatalog.item(h[0], h[1])["name"], UiTokens.TEXT_S, UiTokens.SPRUCE)
	sh.text("Game weather, simplified: not a forecast for a real mountain.", UiTokens.TEXT_S, UiTokens.INK_MUTED)


## The next played climb still ahead on this expedition ("" if none):
## the first whose gate is this camp or a later one.
static func next_climb() -> String:
	var s := Expedition.state()
	var stops: Array = Kili.def()["route"]
	var here := 0
	for i in stops.size():
		if stops[i]["id"] == s["checkpoint"]:
			here = i
	for c in Briefing.CLIMBS:
		var gate: String = Coordinator.CLIMBS[c]["gate"]
		for i in stops.size():
			if stops[i]["id"] == gate and i >= here:
				return c
	return ""


func open_cook() -> void:
	var s := Expedition.state()
	var sh := _sheet("Baraka · the mess tent", "cook")
	sh.text("Stores: %d. %s" % [int(s["supplies"]), "Plenty for now." if int(s["supplies"]) >= 40 else "Getting thin: rest days eat into them."])
	_routine_buttons(sh, ["water"])


func _routine_buttons(sh: JournalSheet, ids: Array) -> void:
	var lost := Trek.lost_roles(Expedition.session)
	for r in Party.routines(Expedition.state()):
		if not ids.has(r["id"]):
			continue
		var b := UiKit.button(String(r["label"]), func() -> void:
			Expedition.play_routine(r["id"])
			sh.close(), "paper", UiTokens.TEXT)
		b.name = "Routine_" + String(r["id"])
		b.disabled = not r["enabled"] or lost.has(r["id"])
		b.tooltip_text = String(r["detail"])
		sh.add(b)
		sh.text(String(r["detail"]) + (" Done today." if r["done"] else ""), UiTokens.TEXT_S, UiTokens.INK_MUTED)


func open_person(id: String) -> void:
	var s := Expedition.state()
	var session := Expedition.session
	var m: Dictionary = {}
	for x in Party.members(s):
		if x["id"] == id:
			m = x
	var sh := _sheet(Trek.NAMES[id], id)
	var sick := Trek.sickness(session, id)
	var explain := Trek.explain_sickness(session, id)
	if not sick.is_empty():
		sh.text(String(explain["what"]), UiTokens.TEXT, UiTokens.BAD)
		sh.text("Why: %s What helps: %s" % [explain["why"], explain["helps"]], UiTokens.TEXT_S, UiTokens.INK_MUTED)
	else:
		sh.text(String(m.get("line", "")), UiTokens.TEXT, UiTokens.INK)
	sh.add(Meter.make(float(m.get("energy", 50)) / 100.0, 120.0, 4.0))
	var row := HFlowContainer.new()
	sh.add(row)
	if Party.tend_effect(s, id) != null:
		row.add_child(UiKit.button("Sit with them", _do.bind(Expedition.tend.bind(id)), "paper", UiTokens.TEXT))
	if Trek.can_treat(session, id):
		row.add_child(UiKit.button("Jun treats", _do.bind(Expedition.treat.bind(id)), "paper", UiTokens.TEXT))
	if Trek.can_medicate(session, id):
		row.add_child(UiKit.button(Trek.medicine_label(session, id), _do.bind(Expedition.medicate.bind(id)), "paper", UiTokens.TEXT))
	if not sick.is_empty():
		row.add_child(UiKit.button("Send down", _do.bind(Expedition.send_down.bind(id)), "danger", UiTokens.TEXT))
	if id == "jun":
		_routine_buttons(sh, ["head-count"])
	sh.text("Game fiction: illness here is a simplified rule, not medical advice.", UiTokens.TEXT_S, UiTokens.INK_MUTED)


func _do(action: Callable) -> void:
	action.call()
	if sheet:
		sheet.close()


func open_tent() -> void:
	var session := Expedition.session
	var sh := _sheet("Your tent", "")
	var t := Expedition.trek()
	var night: String = {"well": "Last night you slept well.", "badly": "Last night you slept badly."}.get(String(t.get("sleep", "")), "")
	if night != "":
		sh.text(night)
	var lines: Array = Condition.of(session)["lines"]
	sh.text("On the next climb: " + (" ".join(lines) if not lines.is_empty() else "you feel ready."), UiTokens.TEXT, UiTokens.INK)
	sh.add(UiKit.label("In your pack", UiTokens.TEXT, UiTokens.INK_MUTED))
	for slot in EquipmentCatalog.SLOTS:
		var g := Profile.item(slot)
		sh.text("%s: %s · %s" % [EquipmentCatalog.SLOT_NAMES[slot], g["name"], EquipmentCatalog.effect_words(g.get("effect", {}))], UiTokens.TEXT_S, UiTokens.INK_SOFT)
	var saved := Expedition.save()
	sh.text("Camp is a checkpoint: the expedition is saved." if saved else "Could not save: your phone may be full.", UiTokens.TEXT_S, UiTokens.SPRUCE if saved else UiTokens.BAD)
	if Expedition.active() and Expedition.pending() == null:
		_routine_buttons(sh, ["pole-pole"])


func open_pack() -> void:
	var sh := _sheet("Juma · your pack", "porter", 320.0)
	sh.text("Swap gear between climbs. Each piece is a trade.", UiTokens.TEXT_S, UiTokens.INK_MUTED)
	for slot in EquipmentCatalog.SLOTS:
		var row := UiKit.hbox(4)
		sh.add(row)
		var g := Profile.item(slot)
		var l := UiKit.label("%s: %s" % [EquipmentCatalog.SLOT_NAMES[slot], g["name"]], UiTokens.TEXT, UiTokens.INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var open := EquipmentCatalog.items(slot).filter(func(x: Dictionary) -> bool: return EquipmentCatalog.open(x))
		var b := UiKit.button("Swap", _swap.bind(slot), "paper", UiTokens.TEXT_S)
		b.name = "Swap_" + slot
		b.disabled = open.size() < 2
		row.add_child(b)
		sh.text(EquipmentCatalog.effect_words(g.get("effect", {})), UiTokens.TEXT_S, UiTokens.SPRUCE)


func _swap(slot: String) -> void:
	var open := EquipmentCatalog.items(slot).filter(func(x: Dictionary) -> bool: return EquipmentCatalog.open(x))
	var i := 0
	for k in open.size():
		if open[k]["id"] == Profile.item(slot)["id"]:
			i = k
	Profile.equip(slot, open[(i + 1) % open.size()]["id"])
	open_pack()


func open_board() -> void:
	if Crag.navigate and is_inside_tree():
		Transition.go(get_tree(), Expedition.CAMP)


## The end of the expedition: the scorecard (Trek's ending, the game's
## score and the leader points that rank it on the boards).
func _scorecard() -> void:
	var s := Expedition.state()
	var sc := ExpeditionEngine.score(s)
	var end := Trek.ending(Expedition.session)
	var sh := _sheet(String(end[0]), "lena", 320.0)
	sh.name = "Scorecard"
	if end.size() > 1:
		sh.text(String(end[1]))
	var grid := GridContainer.new()
	grid.columns = 2
	sh.add(grid)
	for k in [["overall", "Score"], ["judgment", "Judgment"], ["riskManagement", "Risk"], ["teamwork", "Teamwork"], ["preparation", "Preparation"]]:
		grid.add_child(UiKit.label(Plain.score(String(k[1])), UiTokens.TEXT, UiTokens.INK_MUTED))
		grid.add_child(UiKit.label(str(int(sc.get(k[0], 0))), UiTokens.TEXT_L, UiTokens.INK, true))
	var row := UiKit.hbox(4)
	sh.add(row)
	row.add_child(UiKit.button("Records", func() -> void: Records.open("expedition", Hub.PATH), "paper", UiTokens.TEXT))
	row.add_child(UiKit.button("Home", go_home, "primary", UiTokens.TEXT))


func _tip() -> void:
	Profile.see("camp_world")
	var sh := _sheet("Camp", "")
	sh.text("Tap the ground to walk, tap someone to talk. Lena has today's decision; Neema has the weather; Juma has your pack. The signpost opens the camp board with everything on one page.")


func go_home() -> void:
	Expedition.save()
	if Crag.navigate and is_inside_tree():
		Transition.go(get_tree(), Hub.PATH)


func _on_back() -> void:
	if sheet != null and is_instance_valid(sheet):
		return
	go_home()


# --- the place, drawn --------------------------------------------------------------


func _draw_stage() -> void:
	var w := WIDTH
	var h := size.y
	var gy := ground_y()
	var night: bool = sky.get("night", false)
	var cloud: float = sky.get("cloud", 0.0)
	var top := Color("#5f8fb3").lerp(Color("#7d8794"), cloud)
	var low := Color("#e6e0cc").lerp(Color("#b9bcbf"), cloud)
	if night:
		top = Color("#141a33")
		low = Color("#3a3f5c")
	stage.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, gy), Vector2(0, gy)]), PackedColorArray([top, top, low, low]))
	# Kibo far off, the same on every camp; it moves a little slower than the
	# camp (parallax).
	var px := camera_x * 0.6
	var kb := gy - 10.0
	stage.draw_colored_polygon(PackedVector2Array([Vector2(px + 150, kb), Vector2(px + 330, kb - 92), Vector2(px + 420, kb - 102), Vector2(px + 520, kb - 90), Vector2(px + 760, kb)]),
		Color("#6c6a78").lerp(low, 0.62))
	stage.draw_colored_polygon(PackedVector2Array([Vector2(px + 330, kb - 92), Vector2(px + 420, kb - 102), Vector2(px + 520, kb - 90), Vector2(px + 480, kb - 80), Vector2(px + 420, kb - 86), Vector2(px + 370, kb - 80)]),
		(Color("#f3f1ea") if not night else Color("#9aa2b8")).lerp(low, 0.25))
	# Cloud bank, thicker with bad weather: long flat banks, not puffs.
	var cc := low.lerp(Color.WHITE, 0.35 - cloud * 0.2)
	for i in int(4 + cloud * 8):
		var cx := fposmod(float(i) * 170.0 + _t * 4.0, w + 240.0) - 120.0
		var cy := gy - 150.0 + float(i % 3) * 16.0
		var len := 70.0 + float(i % 4) * 20.0 + cloud * 40.0
		var pts := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0
			pts.append(Vector2(cx + cos(a) * len * 0.5, cy + sin(a) * (7.0 + cloud * 6.0) - (4.0 if a > PI else 0.0) * absf(sin(a * 3.0))))
		stage.draw_colored_polygon(pts, cc)
	# A near ridge of moorland between the peak and the camp.
	var ridge := PackedVector2Array([Vector2(0, gy)])
	for k in 23:
		var x := float(k) / 22.0 * w
		ridge.append(Vector2(x, gy - 34.0 - sin(x * 0.011) * 12.0 - sin(x * 0.031) * 5.0))
	ridge.append(Vector2(w, gy))
	stage.draw_colored_polygon(ridge, Color("#8a7a52").lerp(low, 0.35) if not night else Color("#2a2e40"))
	# The ground, and the trodden path through camp.
	stage.draw_rect(Rect2(Vector2(0, gy), Vector2(w, h - gy)), Color("#7b6a4a"))
	stage.draw_rect(Rect2(Vector2(0, gy), Vector2(w, 3)), Color("#5a4a32"))
	stage.draw_rect(Rect2(Vector2(0, gy + 8), Vector2(w, 10)), Color("#8e7c58"))
	var tuft := RandomNumberGenerator.new()
	tuft.seed = 21
	for i in 60:
		var x := tuft.randf() * w
		for k in 3:
			stage.draw_line(Vector2(x + k * 1.5, gy + 1), Vector2(x + k * 1.5 + tuft.randf_range(-2, 2), gy - tuft.randf_range(3, 7)), Color("#6f7a3f"), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 70:
		var x := rng.randf() * w
		stage.draw_circle(Vector2(x, gy + 6 + rng.randf() * (h - gy - 8)), rng.randf_range(0.8, 2.2), Color("#6a5a3c"))
	# Tents, the mess tent, the fire, the map board, the gear rack, the hut.
	_tent(Vector2(130, gy), Color("#c98a2e"), 1.6)
	_tent(Vector2(600, gy), Color("#2d5a4b"), 1.45)
	_tent(Vector2(770, gy), Color("#a8432a"), 1.4)
	stage.draw_rect(Rect2(Vector2(410, gy - 52), Vector2(100, 52)), Color("#e8e1d2"))
	stage.draw_colored_polygon(PackedVector2Array([Vector2(400, gy - 52), Vector2(460, gy - 74), Vector2(520, gy - 52)]), Color("#d8cfba"))
	stage.draw_rect(Rect2(Vector2(450, gy - 34), Vector2(20, 34)), Color(0.2, 0.15, 0.1, 0.5))
	stage.draw_rect(Rect2(Vector2(410, gy - 52), Vector2(100, 4)), Color("#a8432a"))
	# The fire, flickering.
	var f := 0.8 + 0.2 * sin(_t * 9.0)
	stage.draw_circle(Vector2(540, gy - 4), 5.0 * f, Color("#f2b33d"))
	stage.draw_circle(Vector2(540, gy - 7), 3.0 * f, Color("#ffd37a"))
	if night:
		stage.draw_circle(Vector2(540, gy - 6), 40.0, Color(1, 0.75, 0.4, 0.08))
	# The map board.
	stage.draw_rect(Rect2(Vector2(268, gy - 36), Vector2(30, 20)), Color("#e9dcc0"))
	stage.draw_line(Vector2(272, gy - 22), Vector2(294, gy - 30), Color("#a8432a"), 1.0)
	stage.draw_line(Vector2(283, gy - 16), Vector2(283, gy), Color("#5a3d2e"), 2.0)
	# The gear rack with loads.
	stage.draw_rect(Rect2(Vector2(900, gy - 22), Vector2(40, 3)), Color("#5a3d2e"))
	for k in 3:
		stage.draw_rect(Rect2(Vector2(904 + k * 12, gy - 19), Vector2(9, 19)), [Color("#c98a2e"), Color("#4a7593"), Color("#a8432a")][k])
	# The ranger hut and the weather board.
	stage.draw_rect(Rect2(Vector2(1030, gy - 44), Vector2(56, 44)), Color("#8e6a4a"))
	stage.draw_colored_polygon(PackedVector2Array([Vector2(1024, gy - 44), Vector2(1058, gy - 62), Vector2(1092, gy - 44)]), Color("#5a3d2e"))
	stage.draw_line(Vector2(1070, gy), Vector2(1070, gy - 34), Color("#5a3d2e"), 2.0)
	stage.draw_rect(Rect2(Vector2(1056, gy - 40), Vector2(28, 9)), Color("#e9c46a"))
	# Rain, from the weather in the state (a pure function of it).
	var rain: float = sky.get("rain", 0.0)
	if rain > 0.0:
		var rr := RandomNumberGenerator.new()
		rr.seed = 4
		for i in int(rain * 160):
			var x := rr.randf() * w
			var y := fposmod(rr.randf() * h + _t * 220.0, gy)
			stage.draw_line(Vector2(x, y), Vector2(x - 2, y + 6), Color(0.85, 0.9, 1.0, 0.45), 1.0)
	# Labels over the places you can talk to (only near ones are bold).
	var font := UiFont.body()
	if font:
		for id in spots:
			var sp: Dictionary = spots[id]
			var near: bool = id == near_id
			var text := String(sp["label"]).split(" · ")[0]
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
			var at := Vector2(float(sp["x"]) - tw / 2.0, gy - 58)
			stage.draw_rect(Rect2(at + Vector2(-3, -8), Vector2(tw + 6, 11)), Color(0, 0, 0, 0.55 if near else 0.3))
			stage.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 1.0 if near else 0.8))


func _tent(at: Vector2, c: Color, k: float) -> void:
	var w := 44.0 * k
	var h := 30.0 * k
	stage.draw_colored_polygon(PackedVector2Array([at + Vector2(-w / 2.0, 0), at + Vector2(0, -h), at + Vector2(w / 2.0, 0)]), c)
	stage.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -h), at + Vector2(w / 2.0, 0), at + Vector2(w * 0.1, 0)]), c.darkened(0.2))
	stage.draw_colored_polygon(PackedVector2Array([at + Vector2(-6 * k, 0), at + Vector2(0, -h * 0.5), at + Vector2(6 * k, 0)]), Color(0, 0, 0, 0.4))
	stage.draw_line(at + Vector2(-w / 2.0 - 4, 0), at + Vector2(0, -h), Color(0.3, 0.25, 0.2, 0.6), 0.8)
