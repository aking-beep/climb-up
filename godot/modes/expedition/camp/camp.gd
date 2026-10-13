extends Control
## The strategy half of the game: the expedition at camp, laid out the way
## mobile strategy games lay out a decision. The painted diorama fills the
## screen (where the party is, the time of day, who is struggling); over it
## the resources as icon chips and the party as portraits with a status
## ring; on the right a card with three tabs:
##
##   Decide  the decision: when and where, the story, and every choice as a
##           card with its consequences as chips (time, each stat up or
##           down in green or red, a risk badge, CLIMB for a played climb).
##           All the choices always fit on the screen (fit() shrinks the
##           story and the type until they do). Tap a choice to preview it
##           (its changes show on the resource chips, and why it is risky),
##           then tap it again or Confirm.
##   Team    the party, what helps them, and the camp beats.
##   Log     what the last decision did.
##
## When the expedition ends the card becomes the scorecard.

const PAPER := Color(0.953, 0.937, 0.902)
const INK := Color(0.11, 0.098, 0.082)
const MUTED := Color(0.42, 0.39, 0.35)
const SPRUCE := Color("#1f3d34")
const EMBER := Color("#a8432a")
const STATS := [
	["health", "Health", false], ["energy", "Energy", false], ["acclimatization", "Used to height", false],
	["teamCondition", "Team", false], ["supplies", "Supplies", false], ["weatherRisk", "Weather risk", true],
]
const CLIMB_NAMES := {"lava-tower": "the Lava Tower", "barranco-wall": "the Barranco Wall", "summit-night": "the summit night", "descent": "the way down"}
const RISK := {"low": ["LOW RISK", Color("#3f8a4a")], "medium": ["RISKY", Color("#c9922e")], "high": ["DANGEROUS", Color("#b8432a")]}

var diorama: Diorama
var _backdrop: TextureRect
## The open tab's content (and the scorecard at the end).
var paper: VBoxContainer
var tab := "decide"
var selected := -1
var choice_cards: Array = []
var chips: Dictionary = {}
var _scroll: ScrollContainer
var _card_box: PanelContainer
var _tabs: HBoxContainer
var _hud: VBoxContainer
var _stats_box: GridContainer
var _portraits: HBoxContainer
var _place: Label
var _story: Label
var _confirm: Button
var _why: Label
var _decide: VBoxContainer
var _news: Button
## The type tier fit() settled on (0 roomiest).
var tier := 0


func _ready() -> void:
	Audio.play_music("camp")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# The same scene, dimmed, behind everything: no bare edges behind the card.
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_backdrop.modulate = Color(0.42, 0.44, 0.48)
	add_child(_backdrop)
	diorama = Diorama.new()
	diorama.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The scene fills the left, running under the card's edge, so the camp
	# sits in the open part of the screen.
	diorama.anchor_right = 0.6
	diorama.show_map = false
	add_child(diorama)
	var inset := Settings.safe_insets()
	# Top left: where, and the resources.
	_hud = VBoxContainer.new()
	_hud.position = Vector2(6 + inset["left"], 4 + inset["top"])
	_hud.add_theme_constant_override("separation", 2)
	add_child(_hud)
	_place = _label("", 10, Color(0.98, 0.97, 0.94), UiFont.display())
	_place.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_place.add_theme_constant_override("outline_size", 3)
	_hud.add_child(_place)
	var plate := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.06, 0.08, 0.55)
	ps.set_corner_radius_all(6)
	ps.content_margin_left = 4
	ps.content_margin_right = 4
	ps.content_margin_top = 3
	ps.content_margin_bottom = 3
	plate.add_theme_stylebox_override("panel", ps)
	_hud.add_child(plate)
	_stats_box = GridContainer.new()
	_stats_box.columns = 2
	_stats_box.add_theme_constant_override("h_separation", 4)
	_stats_box.add_theme_constant_override("v_separation", 2)
	plate.add_child(_stats_box)
	for spec in STATS:
		var chip := CampWidgets.StatChip.new()
		chip.key = spec[0]
		chip.bad_high = spec[2]
		_stats_box.add_child(chip)
		chips[spec[0]] = chip
	# Bottom left: the party.
	_portraits = HBoxContainer.new()
	_portraits.add_theme_constant_override("separation", 2)
	_portraits.anchor_top = 1.0
	_portraits.anchor_bottom = 1.0
	_portraits.offset_left = 6 + inset["left"]
	_portraits.offset_top = -40 - inset["bottom"]
	_portraits.offset_bottom = -4 - inset["bottom"]
	add_child(_portraits)
	# Right: the card.
	_card_box = PanelContainer.new()
	_card_box.anchor_left = 0.47
	_card_box.anchor_right = 1.0
	_card_box.anchor_bottom = 1.0
	_card_box.offset_left = 0
	_card_box.offset_right = -5 - inset["right"]
	_card_box.offset_top = 5 + inset["top"]
	_card_box.offset_bottom = -5 - inset["bottom"]
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.set_corner_radius_all(8)
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 6
	st.shadow_offset = Vector2(0, 2)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	_card_box.add_theme_stylebox_override("panel", st)
	add_child(_card_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_card_box.add_child(col)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 3)
	col.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	paper = VBoxContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.add_theme_constant_override("separation", 4)
	_scroll.add_child(paper)
	Expedition.changed.connect(_on_changed)
	get_viewport().size_changed.connect(func() -> void: fit.call_deferred())
	refresh()
	Audio.set_camp(1.0)


func _on_changed() -> void:
	selected = -1
	refresh()


func refresh() -> void:
	var s: Dictionary = Expedition.state()
	diorama.show_state(s)
	_backdrop.texture = diorama._plate.texture
	_place.text = "%s · %s m" % [Kili.checkpoint_name(s["checkpoint"]), ExpeditionEngine.format_meters(s["altitude"])]
	_fill_stats(s)
	_fill_portraits(s)
	_fill_tabs()
	for c in paper.get_children():
		paper.remove_child(c)
		c.queue_free()
	choice_cards = []
	_confirm = null
	_news = null
	_story = null
	_why = null
	if not Expedition.active():
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_results(s)
	elif tab == "team":
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_party(s)
		_beats(s)
	elif tab == "log":
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		var now := Expedition.card()
		if not now.is_empty() and Expedition.pending() == null:
			paper.add_child(_label("NOW: " + String(now["title"]).to_upper(), 7, MUTED, UiFont.body()))
			_text_label(now["text"], 9, INK)
		_last(s)
		if Expedition.last.is_empty() or String(s["lastNote"]) == "":
			_text_label("Nothing yet: the first decision is still ahead.", 9, MUTED)
		paper.add_child(_label("WORDS ON THE MOUNTAIN", 7, MUTED, UiFont.body()))
		for w in Plain.WORDS:
			_text_label("%s: %s" % w, 8, INK)
		_text_label(String(Expedition.def["disclaimer"]), 7, MUTED)
	else:
		# The decision never scrolls: it is fitted to the screen.
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_card(s)
		fit.call_deferred()
	_scroll.scroll_vertical = 0


func _fill_stats(s: Dictionary) -> void:
	for spec in STATS:
		var chip: CampWidgets.StatChip = chips[spec[0]]
		chip.value = int(s[spec[0]])
		chip.preview = 0
		chip.queue_redraw()


func _fill_portraits(s: Dictionary) -> void:
	for c in _portraits.get_children():
		_portraits.remove_child(c)
		c.queue_free()
	for m in Party.members(s):
		if Trek.is_gone(Expedition.session, m["id"]):
			continue
		var p := CampWidgets.Portrait.new()
		p.who = m["id"]
		p.tex = Art.tex("res://assets/world/%s-map.png" % m["id"])
		p.label = String(m["name"]).split(" ")[0]
		var sick := Trek.sickness(Expedition.session, m["id"])
		p.state = "sick" if not sick.is_empty() else ({"kneel": "down", "lag": "tired"}.get(m["pose"], "ok"))
		p.tooltip_text = "%s · %s" % [m["name"], m["role"]]
		p.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
				_open_tab("team"))
		_portraits.add_child(p)


func _fill_tabs() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	if not Expedition.active():
		_tabs.add_child(_label("EXPEDITION OVER", 7, MUTED, UiFont.body()))
	else:
		var trouble := false
		for m in Party.members(Expedition.state()):
			if not Trek.sickness(Expedition.session, m["id"]).is_empty() or m["pose"] == "kneel":
				trouble = true
		for t in [["decide", "Decide"], ["team", "Team" + (" !" if trouble else "")], ["log", "Log"]]:
			var b := _small_button(t[1], _open_tab.bind(t[0]))
			if t[0] == tab:
				var on := StyleBoxFlat.new()
				on.bg_color = SPRUCE
				on.set_corner_radius_all(4)
				on.content_margin_left = 5
				on.content_margin_right = 5
				for key in ["normal", "hover", "focus", "pressed"]:
					b.add_theme_stylebox_override(key, on)
				for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
					b.add_theme_color_override(key, Color("#eef4ee"))
			_tabs.add_child(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.add_child(gap)
	_tabs.add_child(_small_button("Menu", func() -> void: Expedition.go(Expedition.MENU)))


func _open_tab(id: String) -> void:
	tab = id
	selected = -1
	refresh()


func _when(s: Dictionary) -> String:
	var hour := Party.expedition_hour(float(s["elapsedHours"]))
	var words := {"dawn": "dawn", "day": "daylight", "dusk": "dusk", "night": "night"}
	return "Day %d · %02d:00 · %s" % [ExpeditionEngine.day_of(s) + 1, int(hour), words[Party.day_phase(hour)]]


# --- The decision -------------------------------------------------------------

func _card(s: Dictionary) -> void:
	_decide = paper
	var p: Variant = Expedition.pending()
	var head := _label(_when(s).to_upper() + _permit_words(s), 7, MUTED, UiFont.body())
	head.clip_text = true
	paper.add_child(head)
	if p != null:
		paper.add_child(_label("A climb is waiting", 12, INK, UiFont.display()))
		_story = _text_label("You left %s part way. Pick up where you left it." % CLIMB_NAMES.get(p["challengeId"], "the climb"), 9, INK)
		var b := _choice_card(0, "Go back to %s" % CLIMB_NAMES.get(p["challengeId"], "the climb"), [], "", true)
		b.pressed.connect(Expedition.resume_climb)
		b.grab_focus.call_deferred()
		return
	var card := Expedition.card()
	var emergency := String(card.get("id", "")).begins_with("trek-emergency")
	var title := _label(card["title"], 12, EMBER if emergency else INK, UiFont.display())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(120, 0)
	paper.add_child(title)
	if not Expedition.last.is_empty() and String(s["lastNote"]) != "":
		var news := _small_button("What happened: %s" % _short(String(s["lastNote"]), 60), _open_tab.bind("log"))
		_news = news
		news.alignment = HORIZONTAL_ALIGNMENT_LEFT
		news.clip_text = true
		news.add_theme_font_size_override("font_size", 7)
		paper.add_child(news)
	_story = _text_label(card["text"], 9, INK)
	_story.max_lines_visible = 4
	# Cut short to fit: it ends in "…", and a tap reads it all in the log.
	_story.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	_story.mouse_filter = Control.MOUSE_FILTER_STOP
	_story.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_open_tab("log"))
	var playable := Expedition.playable()
	for i in card["choices"].size():
		var choice: Dictionary = card["choices"][i]
		var climb: String = playable[i]
		var f := Trek.foresee(Expedition.session, choice, Expedition.def)
		var detail: String = choice.get("detail", "")
		var b := _choice_card(i, choice["label"], _chips_for(f, climb), detail, climb != "")
		b.pressed.connect(_pick.bind(i))
	_why = _text_label("", 7, MUTED)
	_why.visible = false
	_confirm = Button.new()
	_confirm.text = "Tap a choice to see what it does"
	_confirm.disabled = true
	_confirm.add_theme_font_size_override("font_size", 9)
	if UiFont.display():
		_confirm.add_theme_font_override("font", UiFont.display())
	_confirm_style(false)
	_confirm.custom_minimum_size = Vector2(0, 22)
	_confirm.pressed.connect(func() -> void:
		if selected >= 0:
			_commit(selected))
	paper.add_child(_confirm)
	if not choice_cards.is_empty():
		choice_cards[0].grab_focus.call_deferred()


func _permit_words(s: Dictionary) -> String:
	var t := Expedition.trek()
	if t["route"] == "":
		return ""
	var left := Trek.hours_left(Expedition.session) / 24.0
	if left < 0.05:
		return " · NO DAYS LEFT ON THE PERMIT"
	if left < 1.0:
		return " · UNDER A DAY LEFT ON THE PERMIT (%d H)" % maxi(1, int(round(left * 24.0)))
	return " · %.1f DAYS LEFT ON THE PERMIT" % left


static func _short(text: String, n: int) -> String:
	return text if text.length() <= n else text.left(n - 1).strip_edges() + "…"


## A choice's consequences as chips: time, each stat's change (green when
## it helps, red when it hurts), the risk, and CLIMB when it is played.
func _chips_for(f: Dictionary, climb: String) -> Array:
	var out: Array = []
	if climb != "":
		out.append(CampWidgets.chip("CLIMB", SPRUCE, Color("#eef4ee"), "peak"))
	if f.is_empty():
		return out
	if float(f["hours"]) > 0:
		out.append(CampWidgets.chip("%d h" % int(f["hours"]), Color(0.86, 0.83, 0.76), INK, "clock"))
	var deltas: Dictionary = f.get("deltas", {})
	for key in deltas:
		if not CampWidgets.STAT.has(key):
			continue
		var d := int(deltas[key])
		var info: Array = CampWidgets.STAT[key]
		var good: bool = (d < 0) == bool(info[2])
		out.append(CampWidgets.chip("%s %+d" % [info[1], d], Color("#dcefd8") if good else Color("#f6dcd4"), Color("#24602e") if good else Color("#9a2e1a"), info[0]))
	var risk: Array = RISK[String(f["risk"])]
	out.append(CampWidgets.chip(risk[0], risk[1], Color.WHITE))
	return out


func _choice_card(i: int, title: String, chip_list: Array, detail: String, climb: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 7
	v.offset_right = -5
	v.offset_top = 3
	v.offset_bottom = -3
	b.add_child(v)
	var t := _label(title, 9, INK, UiFont.display())
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 2)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in chip_list:
		flow.add_child(ch)
	v.add_child(flow)
	flow.visible = not chip_list.is_empty()
	# Choices with nothing to show as chips (the route, an emergency) say
	# what they mean in a line; the others show it when picked.
	var d := _label(detail, 7, MUTED, UiFont.body())
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.max_lines_visible = 2
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.visible = chip_list.is_empty() and detail != ""
	v.add_child(d)
	b.set_meta("title", t)
	b.set_meta("flow", flow)
	b.set_meta("detail", d)
	b.set_meta("climb", climb)
	_card_style(b, false, climb)
	paper.add_child(b)
	choice_cards.append(b)
	return b


func _card_style(b: Button, on: bool, climb: bool) -> void:
	for key in ["normal", "hover", "focus", "pressed"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(1, 0.995, 0.975) if not on else Color("#e6f0e6")
		st.border_color = SPRUCE if on or key == "focus" else Color(0.8, 0.76, 0.68)
		st.set_border_width_all(2 if on else 1)
		st.border_width_left = 4 if climb or on else 1
		if climb and not on:
			st.border_color = SPRUCE if key == "focus" else Color("#5f8a6e")
		st.set_corner_radius_all(5)
		if key == "hover" and not on:
			st.bg_color = Color(1, 1, 0.99)
		b.add_theme_stylebox_override(key, st)


func _confirm_style(on: bool) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = SPRUCE if on else Color(0.85, 0.83, 0.78)
	st.set_corner_radius_all(5)
	st.content_margin_left = 8
	for key in ["normal", "hover", "focus", "pressed", "disabled"]:
		_confirm.add_theme_stylebox_override(key, st)
	for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		_confirm.add_theme_color_override(key, Color("#eef4ee") if on else MUTED)
	_confirm.add_theme_color_override("font_disabled_color", MUTED)


## A choice tapped: the first tap previews it, the second commits.
func _pick(i: int) -> void:
	if selected == i:
		_commit(i)
		return
	selected = i
	var card := Expedition.card()
	var choice: Dictionary = card["choices"][i]
	var f := Trek.foresee(Expedition.session, choice, Expedition.def)
	for k in choice_cards.size():
		var b: Button = choice_cards[k]
		_card_style(b, k == i, b.get_meta("climb"))
		var d: Label = b.get_meta("detail")
		d.visible = (k == i and d.text != "") or (b.get_meta("flow").visible == false and d.text != "")
	# The preview on the resources.
	for key in chips:
		chips[key].preview = int(f.get("deltas", {}).get(key, 0))
		chips[key].queue_redraw()
	var why: Array = f.get("why", [])
	_why.text = ("Why it's risky: " + ", ".join(why) + ".") if not why.is_empty() and String(f.get("risk", "low")) != "low" else ""
	_why.visible = _why.text != ""
	_confirm.disabled = false
	_confirm.text = "Confirm: %s" % _short(String(choice["label"]), 34)
	_confirm_style(true)
	fit.call_deferred()


func _commit(i: int) -> void:
	selected = -1
	Expedition.choose(i)


## Makes the decision fit the card without scrolling: the story gets fewer
## lines, then the type gets smaller, until every choice and the confirm
## button are on screen. Returns the tier used.
func fit() -> int:
	if not is_inside_tree() or tab != "decide" or not Expedition.active() or choice_cards.is_empty():
		return tier
	var room := _scroll.size.y
	if room <= 0.0:
		return tier
	# [story lines, choice title size, story size, details on picked cards,
	#  lines of detail on cards without chips, show the "what happened" link]
	var tiers := [[4, 9, 9, true, 2, true], [3, 9, 8, true, 2, true], [2, 8, 8, true, 2, true], [1, 8, 8, false, 2, true],
		[0, 7, 7, false, 2, true], [0, 7, 7, false, 1, true], [0, 7, 7, false, 1, false], [0, 7, 7, false, 0, false]]
	for k in tiers.size():
		tier = k
		var t: Array = tiers[k]
		if _story:
			_story.visible = int(t[0]) > 0
			_story.max_lines_visible = maxi(1, int(t[0]))
			_story.add_theme_font_size_override("font_size", int(t[2]))
		if _news:
			_news.visible = bool(t[5])
		for b in choice_cards:
			(b.get_meta("title") as Label).add_theme_font_size_override("font_size", int(t[1]))
			var d: Label = b.get_meta("detail")
			if b.get_meta("flow").visible:
				if not bool(t[3]):
					d.visible = false
			else:
				d.visible = d.text != "" and int(t[4]) > 0
				d.max_lines_visible = maxi(1, int(t[4]))
		if _why:
			_why.visible = _why.text != "" and bool(t[3])
		if _content_height() <= room:
			break
	# Each card exactly as tall as what it shows.
	for b in choice_cards:
		b.custom_minimum_size.y = _card_height(b, _scroll.size.x)
	return tier


## The decision's height as laid out at the card's width.
func _content_height() -> float:
	var w := _scroll.size.x
	var total := 0.0
	var n := 0
	for c in paper.get_children():
		if not (c as Control).visible:
			continue
		n += 1
		if c is Label:
			total += _label_height(c, w)
		elif c is Button and choice_cards.has(c):
			total += _card_height(c, w)
		else:
			total += (c as Control).get_combined_minimum_size().y
	return total + maxi(0, n - 1) * paper.get_theme_constant("separation")


## A choice card's height at width `w`: title, chips, detail, padding.
func _card_height(b: Button, w: float) -> float:
	var inner := 6.0 + 2.0
	inner += _label_height(b.get_meta("title"), w - 12)
	var flow: HFlowContainer = b.get_meta("flow")
	if flow.visible:
		inner += _flow_height(flow, w - 12) + 2.0
	var d: Label = b.get_meta("detail")
	if d.visible:
		inner += _label_height(d, w - 12) + 2.0
	return ceilf(inner)


static func _label_height(l: Label, w: float) -> float:
	var font: Font = l.get_theme_font("font")
	var size := l.get_theme_font_size("font_size")
	var lines := 1
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
		var para := TextParagraph.new()
		para.add_string(l.text, font, size)
		para.width = maxf(10.0, w)
		para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		lines = maxi(1, para.get_line_count())
	if l.max_lines_visible > 0:
		lines = mini(lines, l.max_lines_visible)
	return lines * (font.get_height(size) + l.get_theme_constant("line_spacing"))


static func _flow_height(flow: HFlowContainer, w: float) -> float:
	var x := 0.0
	var rows := 1
	var row_h := 0.0
	for ch in flow.get_children():
		var m := (ch as Control).get_combined_minimum_size()
		row_h = maxf(row_h, m.y)
		if x > 0.0 and x + m.x > w:
			rows += 1
			x = 0.0
		x += m.x + 2.0
	return rows * row_h + (rows - 1) * 2.0


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
		if o.get("challengeId", "") == "descent":
			heading = "Down safely" if o["result"] == "complete" else "Brought down"
		v.add_child(_wrap(_label("%s · %s" % [heading, CLIMB_NAMES.get(o.get("challengeId", ""), "the climb")], 9, SPRUCE if o["result"] == "complete" else EMBER, UiFont.display())))
		if int(o.get("seconds", 0)) > 0:
			var bits := ["%d slip%s" % [int(o["slips"]), "" if int(o["slips"]) == 1 else "s"], "stamina left %d%%" % int(o["staminaLeft"]), "%d min" % maxi(1, int(o["seconds"]) / 60)]
			if o.get("assisted") == true:
				bits.append("you helped")
			elif o.get("assisted") == false:
				bits.append("you left them for Lena" if not Trek.is_gone(Expedition.session, "lena") else "you went on without them")
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
				v.add_child(_wrap(_label("%s %+d · %s" % [Plain.score(ExpeditionEngine.BUCKET_LABEL[bucket]), d, n["label"]], 8, SPRUCE if d >= 0 else EMBER, UiFont.body())))
	paper.add_child(box)


func _beats(s: Dictionary) -> void:
	# A beat whose person went down goes with them.
	var lost := Trek.lost_roles(Expedition.session)
	var open := Party.routines(s).filter(func(r: Dictionary) -> bool: return r["enabled"] and not lost.has(r["id"]))
	if open.is_empty() and lost.is_empty():
		return
	paper.add_child(_label("CAMP JOBS · QUICK, THE DAY GOES ON", 7, MUTED, UiFont.body()))
	for id in lost:
		_text_label(lost[id], 8, MUTED)
	var flow := _action_flow()
	for r in open:
		var b := _small_button(r["label"], Expedition.play_routine.bind(r["id"]))
		b.tooltip_text = r["detail"]
		flow.add_child(b)
	paper.add_child(flow)


## Buttons that wrap onto the next line instead of pushing the card wider.
func _action_flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 3)
	return flow


func _party(s: Dictionary) -> void:
	var session := Expedition.session
	paper.add_child(_label("THE TEAM", 7, MUTED, UiFont.body()))
	for id in Expedition.trek()["gone"]:
		_text_label("%s went down with the porters." % Trek.NAMES[id], 8, MUTED)
	for line in Trek.absence_lines(session, Expedition.def):
		_text_label(line, 8, INK)
	# The people in trouble first: their buttons are what this tab is for.
	var members: Array = Party.members(s).filter(func(m: Dictionary) -> bool: return not Trek.is_gone(session, m["id"]))
	var rank := func(m: Dictionary) -> int:
		if not Trek.sickness(session, m["id"]).is_empty():
			return 0
		return {"kneel": 1, "lag": 2}.get(m["pose"], 3)
	members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return rank.call(a) < rank.call(b))
	for m in members:
		paper.add_child(_person_card(s, m))
	# What the next climb will feel like: camp choices carry onto the rock.
	var t := Expedition.trek()
	var night: String = {"well": "Last night: slept well.", "badly": "Last night: slept badly."}.get(String(t.get("sleep", "")), "")
	var doses := int(t.get("medicine", 0))
	_text_label(("%s Medicine kit: %d dose%s." % [night, doses, "" if doses == 1 else "s"]).strip_edges(), 8, MUTED)
	var body: Array = Condition.of(session)["lines"]
	if not body.is_empty():
		_text_label("On the next climb: " + " ".join(body), 8, Color("#8a6a1e"))


## One person: name, how they are in a word and a sentence, what helps,
## and what you can do, as buttons that wrap to the card's width.
func _person_card(s: Dictionary, m: Dictionary) -> PanelContainer:
	var session := Expedition.session
	var sick := Trek.sickness(session, m["id"])
	var explain := Trek.explain_sickness(session, m["id"])
	var state := "ok"
	var line: String = m["line"]
	if not sick.is_empty():
		state = "sick"
		line = explain["what"]
	elif m["pose"] == "kneel":
		state = "down"
		line = "Too tired to walk on (energy %d). Sit with them, or rest a day before going higher." % int(m["energy"])
	elif m["pose"] == "lag":
		state = "tired"
		line = "Getting tired (energy %d)." % int(m["energy"])
	var tag: Array = {"ok": ["OK", CampWidgets.GOOD], "tired": ["TIRED", CampWidgets.WARN], "down": ["EXHAUSTED", CampWidgets.BAD], "sick": ["SICK", Color("#8a4fae")]}[state]
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 0.99, 0.96)
	st.border_color = tag[1] if state != "ok" else Color(0.8, 0.76, 0.68)
	st.set_border_width_all(1)
	st.border_width_left = 3
	st.set_corner_radius_all(4)
	st.content_margin_left = 5
	st.content_margin_right = 4
	st.content_margin_top = 2
	st.content_margin_bottom = 3
	card.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	var who := _label("%s · %s" % [m["name"], m["role"]], 8, INK, UiFont.display())
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	head.add_child(who)
	var chip := CampWidgets.chip(tag[0], tag[1], Color.WHITE, "", 6)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(chip)
	v.add_child(head)
	var say := _wrap(_label(line, 7, INK if state != "ok" else MUTED, UiFont.body()))
	say.custom_minimum_size.x = 0
	say.add_theme_constant_override("line_spacing", -3)
	v.add_child(say)
	if not explain.is_empty():
		var why := _wrap(_label("Why: %s What helps: %s" % [explain["why"], explain["helps"]], 7, MUTED, UiFont.body()))
		why.custom_minimum_size.x = 0
		why.add_theme_constant_override("line_spacing", -3)
		v.add_child(why)
	var flow := _action_flow()
	if Party.tend_effect(s, m["id"]) != null:
		flow.add_child(_small_button("Sit with them", Expedition.tend.bind(m["id"])))
	if Trek.can_treat(session, m["id"]):
		flow.add_child(_small_button("Jun treats", Expedition.treat.bind(m["id"])))
	if Trek.can_medicate(session, m["id"]):
		flow.add_child(_small_button(Trek.medicine_label(session, m["id"]), Expedition.medicate.bind(m["id"])))
	if not sick.is_empty() and m["id"] != "you":
		flow.add_child(_small_button("Send down", Expedition.send_down.bind(m["id"])))
	if flow.get_child_count() > 0:
		v.add_child(flow)
	else:
		flow.free()
	return card


# --- The end -------------------------------------------------------------------

func _results(s: Dictionary) -> void:
	var sc := ExpeditionEngine.score(s)
	paper.add_child(_label("EXPEDITION OVER · %s" % _when(s).to_upper(), 7, MUTED, UiFont.body()))
	var end := Trek.ending(Expedition.session)
	var title := _wrap(_label(end[0], 14, INK, UiFont.display()))
	title.custom_minimum_size.x = 0
	paper.add_child(title)
	_text_label(end[1], 9, INK)
	_text_label(Trek.route(Expedition.session)["name"] + " · " + Trek.route(Expedition.session)["line"], 8, MUTED)
	_last(s)
	paper.add_child(_label("%d" % int(sc["overall"]), 26, SPRUCE if sc["successful"] else EMBER, UiFont.display()))
	var why := String(sc["explanation"])
	for name in Plain.SCORE:
		why = why.replace(name, Plain.score(name))
	_text_label("Highest point %s m. %s" % [ExpeditionEngine.format_meters(sc["highestAltitude"]), why], 9, INK)
	for pair in [["Judgment", "judgment"], ["Risk management", "riskManagement"], ["Teamwork", "teamwork"], ["Preparation", "preparation"]]:
		var row := HBoxContainer.new()
		var l := _label(Plain.score(pair[0]), 9, INK, UiFont.body())
		l.custom_minimum_size = Vector2(66, 0)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.value = sc[pair[1]]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(40, 5)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		_text_label("%s %+d · %s" % [Plain.score(n["bucket"]), int(n["delta"]), n["label"]], 8, SPRUCE if int(n["delta"]) >= 0 else EMBER)
	_choice_button("Start a new expedition", "A new seed: different weather, different nights.", true, func() -> void:
		Expedition.new_expedition(int(s["seed"]) + 1)).grab_focus()
	_choice_button("Menu", "", false, func() -> void: Expedition.go(Expedition.MENU))


# --- Pieces -------------------------------------------------------------------

func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	# Every word on the camp screen in plain language (core/ui/plain.gd).
	l.text = Plain.say(text)
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
	for key in ["normal", "hover", "focus", "pressed", "disabled"]:
		var box: StyleBoxFlat = b.get_theme_stylebox(key)
		box.content_margin_left = 5
		box.content_margin_right = 5
	b.custom_minimum_size = Vector2(0, 18)
	b.pressed.connect(on_press)
	return b
