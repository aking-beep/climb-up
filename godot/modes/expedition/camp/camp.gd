extends Control
## The strategy half of the game: the expedition at camp. On the left the
## diorama (where the party is, the time of day, who is struggling); on
## the right the paper: the decision card from the Expo game, its choices
## (the ones that start a played climb are marked), the camp beats, the
## party, and what the last decision did. When the expedition ends the
## paper becomes the scorecard.

const PAPER := Color(0.953, 0.937, 0.902)
const INK := Color(0.11, 0.098, 0.082)
const MUTED := Color(0.42, 0.39, 0.35)
const SPRUCE := Color("#1f3d34")
const EMBER := Color("#a8432a")
const STATS := [
	["health", "Health", false], ["energy", "Energy", false], ["acclimatization", "Acclim.", false],
	["teamCondition", "Team", false], ["supplies", "Supplies", false], ["weatherRisk", "Weather risk", true],
]
const CLIMB_NAMES := {"lava-tower": "the Lava Tower", "barranco-wall": "the Barranco Wall", "summit-night": "the summit night"}

var diorama: Diorama
var paper: VBoxContainer
var _scroll: ScrollContainer
var _stats_box: GridContainer
var _place: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.12
	row.add_child(left)
	diorama = Diorama.new()
	diorama.set_anchors_preset(Control.PRESET_FULL_RECT)
	left.add_child(diorama)
	_place = _label("", 10, Color(0.98, 0.97, 0.94), UiFont.display())
	_place.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_place.add_theme_constant_override("shadow_offset_y", 1)
	_place.position = Vector2(8, 6)
	left.add_child(_place)
	_stats_box = GridContainer.new()
	_stats_box.columns = 3
	_stats_box.add_theme_constant_override("h_separation", 6)
	_stats_box.add_theme_constant_override("v_separation", 2)
	_stats_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stats_box.offset_left = 8
	_stats_box.offset_top = 22
	left.add_child(_stats_box)

	var sheet := PanelContainer.new()
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.size_flags_stretch_ratio = 1.0
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.border_color = Color(0.36, 0.3, 0.22)
	st.border_width_left = 1
	st.content_margin_left = 10
	st.content_margin_right = 6
	st.content_margin_top = 8
	st.content_margin_bottom = 6
	sheet.add_theme_stylebox_override("panel", st)
	row.add_child(sheet)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(_scroll)
	paper = VBoxContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.add_theme_constant_override("separation", 4)
	_scroll.add_child(paper)

	Expedition.changed.connect(refresh)
	refresh()
	Audio.set_camp(1.0)


func refresh() -> void:
	var s: Dictionary = Expedition.state()
	diorama.show_state(s)
	_place.text = "%s · %s m" % [Kili.checkpoint_name(s["checkpoint"]), ExpeditionEngine.format_meters(s["altitude"])]
	_fill_stats(s)
	for c in paper.get_children():
		c.queue_free()
	if Expedition.active():
		_card(s)
	else:
		_results(s)
	_scroll.scroll_vertical = 0


func _fill_stats(s: Dictionary) -> void:
	for c in _stats_box.get_children():
		c.queue_free()
	for spec in STATS:
		var v := int(s[spec[0]])
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		var l := _label("%s %d" % [spec[1], v], 7, Color(0.98, 0.97, 0.94), UiFont.body())
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("shadow_offset_y", 1)
		col.add_child(l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(44, 3)
		bar.max_value = 100
		bar.value = v
		var bad := v > 55 if spec[2] else v < 35
		var warn := v > 35 if spec[2] else v < 55
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("#c0573e") if bad else (Color("#d9a441") if warn else Color("#8fbf7a"))
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0, 0, 0, 0.45)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", back)
		col.add_child(bar)
		_stats_box.add_child(col)


func _when(s: Dictionary) -> String:
	var hour := Party.expedition_hour(float(s["elapsedHours"]))
	var words := {"dawn": "dawn", "day": "daylight", "dusk": "dusk", "night": "night"}
	return "Day %d · %02d:00 · %s" % [ExpeditionEngine.day_of(s) + 1, int(hour), words[Party.day_phase(hour)]]


# --- The decision -------------------------------------------------------------

func _card(s: Dictionary) -> void:
	var top := HBoxContainer.new()
	var k := _label(_when(s).to_upper(), 7, MUTED, UiFont.body())
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(k)
	var menu := _small_button("Menu", func() -> void: Expedition.go(Expedition.MENU))
	top.add_child(menu)
	paper.add_child(top)
	_last(s)
	var p: Variant = Expedition.pending()
	if p != null:
		_text_label("A climb is waiting: %s." % CLIMB_NAMES.get(p["challengeId"], "the climb"), 9, INK)
		_choice_button("Go back to %s" % CLIMB_NAMES.get(p["challengeId"], "the climb"), "Pick up where you left it.", true, Expedition.resume_climb).grab_focus()
		return
	var card := Expedition.card()
	_permit(s, card)
	paper.add_child(_label(card["title"], 13, EMBER if String(card["id"]).begins_with("trek-emergency") else INK, UiFont.display()))
	_text_label(card["text"], 9, INK)
	var playable := Expedition.playable()
	var first: Button = null
	for i in card["choices"].size():
		var choice: Dictionary = card["choices"][i]
		var climb: String = playable[i]
		var detail: String = choice.get("detail", "")
		if climb != "":
			detail = "Played climb · %s. %s" % [CLIMB_NAMES[climb], detail]
		detail = (detail + " " + _cost(choice)).strip_edges()
		var b := _choice_button(choice["label"], detail, climb != "", Expedition.choose.bind(i))
		if first == null:
			first = b
	if first:
		first.call_deferred("grab_focus")
	if card.get("trek", false):
		return
	_beats(s)
	_party(s)
	_text_label(String(Expedition.def["disclaimer"]), 7, MUTED)


## The permit and the route, above every decision: the days are the budget.
func _permit(s: Dictionary, card: Dictionary) -> void:
	var t := Expedition.trek()
	if t["route"] == "":
		return
	var r := Trek.route(Expedition.session)
	var left := Trek.hours_left(Expedition.session) / 24.0
	var line := "%s · permit day %d of %d · %s left" % [r["name"], ExpeditionEngine.day_of(s) + 1, int(r["permit"]),
		("%.1f days" % left) if left > 0 else "none"]
	paper.add_child(_wrap(_label(line.to_upper(), 7, EMBER if left < 2.0 else MUTED, UiFont.body())))


## What a choice spends: hours of the permit, and the risk of going higher.
func _cost(choice: Dictionary) -> String:
	var e: Dictionary = choice.get("effect", {})
	if e.is_empty():
		return ""
	var bits: Array = []
	var h := float(e.get("hours", 6))
	if h > 0:
		bits.append("%d h of the permit" % int(h))
	var move := String(e.get("move", "hold"))
	if move == "up" or move == "summit":
		bits.append("higher: sickness more likely")
	elif move == "down" or move == "retreat":
		bits.append("lower: the sick get better")
	return "[" + " · ".join(bits) + "]" if not bits.is_empty() else ""


## What the last decision did: its note, the changes, any score notes.
func _last(s: Dictionary) -> void:
	var last: Dictionary = Expedition.last
	if last.is_empty() or String(s["lastNote"]) == "":
		return
	var box := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.9, 0.88, 0.82)
	st.set_corner_radius_all(2)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	var o: Variant = last.get("outcome")
	if o != null:
		var heading: String = {"complete": "Climbed", "retreat": "Backed off", "fail": "Turned back by the mountain"}.get(o["result"], "")
		v.add_child(_wrap(_label("%s · %s" % [heading, CLIMB_NAMES.get(o.get("challengeId", ""), "the climb")], 9, SPRUCE if o["result"] == "complete" else EMBER, UiFont.display())))
		if int(o.get("seconds", 0)) > 0:
			var bits := ["%d slip%s" % [int(o["slips"]), "" if int(o["slips"]) == 1 else "s"], "stamina left %d%%" % int(o["staminaLeft"]), "%d min" % maxi(1, int(o["seconds"]) / 60)]
			if o.get("assisted") == true:
				bits.append("you helped")
			elif o.get("assisted") == false:
				bits.append("you left them for Lena")
			if o.get("regrouped") == true:
				bits.append("regrouped")
			if int(o.get("stars", 0)) > 0:
				bits.append("%d of 3 stars" % int(o["stars"]))
			if int(o.get("flowersTotal", 0)) > 0:
				bits.append("%d of %d everlastings" % [int(o["flowers"]), int(o["flowersTotal"])])
			if int(o.get("gearFound", 0)) > 0:
				bits.append("found %d lost gear" % int(o["gearFound"]))
			v.add_child(_wrap(_label(" · ".join(bits), 8, MUTED, UiFont.body())))
	v.add_child(_wrap(_label(s["lastNote"], 9, INK, UiFont.body())))
	var before: Dictionary = last.get("before", {})
	var changes: Array[String] = []
	for spec in STATS:
		var now := int(s[spec[0]])
		var was := int(before.get(spec[0], now))
		if now != was:
			changes.append("%s %d → %d" % [spec[1], was, now])
	if not changes.is_empty():
		v.add_child(_wrap(_label(" · ".join(changes), 8, MUTED, UiFont.body())))
	var had := {}
	for bucket in ExpeditionEngine.BUCKETS:
		for n in before.get("ledger", {}).get(bucket, []):
			had[n["mark"]] = true
	for bucket in ExpeditionEngine.BUCKETS:
		for n in s["ledger"][bucket]:
			if not had.has(n["mark"]):
				var d := int(n["delta"])
				v.add_child(_wrap(_label("%s %+d · %s" % [ExpeditionEngine.BUCKET_LABEL[bucket], d, n["label"]], 8, SPRUCE if d >= 0 else EMBER, UiFont.body())))
	paper.add_child(box)


func _beats(s: Dictionary) -> void:
	var open := Party.routines(s).filter(func(r: Dictionary) -> bool: return r["enabled"])
	if open.is_empty():
		return
	paper.add_child(_label("AT CAMP · DOESN'T SPEND THE DAY", 7, MUTED, UiFont.body()))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 3)
	for r in open:
		var b := _small_button(r["label"], Expedition.play_routine.bind(r["id"]))
		b.tooltip_text = r["detail"]
		flow.add_child(b)
	paper.add_child(flow)


func _party(s: Dictionary) -> void:
	paper.add_child(_label("THE PARTY", 7, MUTED, UiFont.body()))
	var session := Expedition.session
	for id in Expedition.trek()["gone"]:
		_text_label("%s went down with the porters." % Trek.NAMES[id], 8, MUTED)
	for m in Party.members(s):
		if Trek.is_gone(session, m["id"]):
			continue
		var sick := Trek.sickness(session, m["id"])
		if not sick.is_empty():
			m["line"] = "Unwell: %s." % Trek.describe(sick["kind"], sick["stage"])
			m["pose"] = "kneel" if sick["stage"] >= 2 else "lag"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var who := _label("%s · %s" % [m["name"], m["role"]], 8, INK, UiFont.display())
		who.custom_minimum_size = Vector2(70, 0)
		row.add_child(who)
		var line := _label(m["line"], 8, EMBER if m["pose"] == "kneel" else (Color("#8a6a1e") if m["pose"] == "lag" else MUTED), UiFont.body())
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(line)
		if Party.tend_effect(s, m["id"]) != null:
			row.add_child(_small_button("Sit with", Expedition.tend.bind(m["id"])))
		if Trek.can_treat(session, m["id"]):
			row.add_child(_small_button("Jun treats", Expedition.treat.bind(m["id"])))
		if not sick.is_empty() and m["id"] != "you":
			row.add_child(_small_button("Send down", Expedition.send_down.bind(m["id"])))
		paper.add_child(row)


# --- The end -------------------------------------------------------------------

func _results(s: Dictionary) -> void:
	var sc := ExpeditionEngine.score(s)
	paper.add_child(_label("EXPEDITION OVER · %s" % _when(s).to_upper(), 7, MUTED, UiFont.body()))
	var end := Trek.ending(Expedition.session)
	paper.add_child(_label(end[0], 14, INK, UiFont.display()))
	_text_label(end[1], 9, INK)
	_text_label(Trek.route(Expedition.session)["name"] + " · " + Trek.route(Expedition.session)["line"], 8, MUTED)
	_last(s)
	paper.add_child(_label("%d" % int(sc["overall"]), 26, SPRUCE if sc["successful"] else EMBER, UiFont.display()))
	_text_label("Highest point %s m. %s" % [ExpeditionEngine.format_meters(sc["highestAltitude"]), sc["explanation"]], 9, INK)
	for pair in [["Judgment", "judgment"], ["Risk management", "riskManagement"], ["Teamwork", "teamwork"], ["Preparation", "preparation"]]:
		var row := HBoxContainer.new()
		var l := _label(pair[0], 9, INK, UiFont.body())
		l.custom_minimum_size = Vector2(90, 0)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.value = sc[pair[1]]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(70, 5)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = SPRUCE
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		row.add_child(_label(" %d" % int(sc[pair[1]]), 9, INK, UiFont.body()))
		paper.add_child(row)
	paper.add_child(_label("WHAT COUNTED", 7, MUTED, UiFont.body()))
	var lines: Array = sc["lines"].duplicate()
	lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absi(int(a["delta"])) > absi(int(b["delta"])))
	for n in lines.slice(0, 8):
		_text_label("%s %+d · %s" % [n["bucket"], int(n["delta"]), n["label"]], 8, SPRUCE if int(n["delta"]) >= 0 else EMBER)
	_choice_button("Start a new expedition", "A new seed: different weather, different nights.", true, func() -> void:
		Expedition.new_expedition(int(s["seed"]) + 1)).grab_focus()
	_choice_button("Menu", "", false, func() -> void: Expedition.go(Expedition.MENU))


# --- Pieces -------------------------------------------------------------------

func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(150, 0)
	return l


func _text_label(text: String, size: int, color: Color) -> Label:
	var l := _wrap(_label(text, size, color, UiFont.body()))
	paper.add_child(l)
	return l


func _choice_button(label: String, detail: String, highlight: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = label if detail == "" else "%s\n%s" % [label, detail]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 9)
	if UiFont.body():
		b.add_theme_font_override("font", UiFont.body())
	UiStyle.paper_button(b)
	if highlight:
		var st: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
		st.border_color = SPRUCE
		st.set_border_width_all(1)
		st.border_width_left = 3
		b.add_theme_stylebox_override("normal", st)
	for key in ["normal", "hover", "focus", "pressed", "disabled"]:
		var box: StyleBoxFlat = b.get_theme_stylebox(key)
		box.content_margin_top = 4
		box.content_margin_bottom = 4
	b.custom_minimum_size = Vector2(0, 24)
	b.pressed.connect(on_press)
	paper.add_child(b)
	return b


func _small_button(label: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.add_theme_font_size_override("font_size", 8)
	if UiFont.display():
		b.add_theme_font_override("font", UiFont.display())
	UiStyle.paper_button(b)
	b.custom_minimum_size = Vector2(0, 18)
	b.pressed.connect(on_press)
	return b
