extends JournalPage
## The locker: how your climber looks, and the gear you take on the
## expedition. Looks change nothing in play. Gear is a trade (better at one
## thing, worse at another) and only matters on expedition climbs. Locked
## options say what opens them: always something you do, never something
## you buy.

var tabs: SegmentedTabs
var pane: VBoxContainer
var hero: Hero
var note: Label


func build() -> void:
	set_title("Gear and look")
	var row := UiKit.hbox(10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(row)
	var left := UiKit.vbox(4)
	left.custom_minimum_size = Vector2(120, 0)
	row.add_child(left)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(120, 130)
	stage.draw.connect(func() -> void:
		stage.draw_rect(Rect2(Vector2.ZERO, stage.size), UiTokens.GLACIER)
		stage.draw_rect(Rect2(Vector2(0, stage.size.y - 12), Vector2(stage.size.x, 12)), Color("#8a7a52"))
		stage.draw_rect(Rect2(Vector2.ZERO, stage.size), UiTokens.PAPER_EDGE, false, 1.0))
	left.add_child(stage)
	hero = Hero.new()
	hero.height = 96.0
	hero.set_look(Profile.look)
	hero.position = Vector2(60, 122)
	stage.add_child(hero)
	var poses := UiKit.hbox(2)
	left.add_child(poses)
	for p in [["Stand", "idle"], ["Climb", "climb"], ["Walk", "walk"]]:
		var b := UiKit.button(p[0], func() -> void: hero.pose = p[1], "paper", UiTokens.TEXT_S)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		poses.add_child(b)
	note = UiKit.label("", UiTokens.TEXT_S, UiTokens.INK_MUTED, false, 120.0)
	left.add_child(note)
	var right := UiKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	tabs = SegmentedTabs.make(["Look", "Gear"])
	tabs.changed.connect(_show)
	right.add_child(tabs)
	pane = UiKit.vbox(5)
	right.add_child(JournalPage.scroller(pane))
	_show(0)


func _show(i: int) -> void:
	for c in pane.get_children():
		c.queue_free()
	if i == 0:
		hero.pose = "idle"
		var open := CosmeticCatalog.open_count()
		note.text = "%d of %d looks open. Looks change nothing in a climb." % [open.x, open.y]
		for slot in CosmeticCatalog.ORDER:
			_look_row(slot)
	else:
		hero.pose = "climb"
		note.text = "Gear works on expedition climbs. Crag routes use the shoes you pick before each route."
		for slot in EquipmentCatalog.SLOTS:
			_gear_slot(slot)


func _look_row(slot: String) -> void:
	var def: Dictionary = CosmeticCatalog.SLOTS[slot]
	pane.add_child(UiKit.label(String(def["label"]), UiTokens.TEXT, UiTokens.INK_MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 3)
	pane.add_child(flow)
	var chosen := CosmeticCatalog.chosen(Profile.look, slot)
	for o in CosmeticCatalog.options(slot):
		var open := CosmeticCatalog.open(o)
		var colour := String(o["value"]).begins_with("#")
		var b: Button
		if colour:
			b = _Swatch.make(Color(String(o["value"])), o["id"] == chosen, open)
		else:
			b = UiKit.button(String(o["label"]), Callable(), "primary" if o["id"] == chosen else "paper", UiTokens.TEXT_S)
			if not open:
				b.text = String(o["label"]) + " · locked"
		b.name = "%s_%s" % [slot, o["id"]]
		b.tooltip_text = String(o["label"])
		b.pressed.connect(_pick_look.bind(slot, o["id"]))
		flow.add_child(b)


func _pick_look(slot: String, id: String) -> void:
	var o := CosmeticCatalog.option(slot, id)
	if not CosmeticCatalog.open(o):
		note.text = "%s is locked. Opens with: %s." % [o["label"], Unlocks.words(o.get("lock", {}))]
		return
	Profile.choose_look(slot, id)
	hero.set_look(Profile.look)
	_show.call_deferred(0)


func _gear_slot(slot: String) -> void:
	var p := UiKit.panel(UiTokens.PAPER_RAISED, 6.0)
	var col := UiKit.vbox(3)
	p.add_child(col)
	var now := Profile.item(slot)
	var head := UiKit.hbox(6)
	col.add_child(head)
	head.add_child(UiKit.label(String(EquipmentCatalog.SLOT_NAMES[slot]), UiTokens.TEXT_L, UiTokens.INK, true))
	head.add_child(UiKit.chip(String(now["name"]), UiTokens.SPRUCE, UiTokens.SPRUCE_INK, 6))
	for g in EquipmentCatalog.items(slot):
		var open := EquipmentCatalog.open(g)
		var on: bool = g["id"] == now["id"]
		var r := UiKit.hbox(6)
		col.add_child(r)
		var t := UiKit.vbox(0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(t)
		t.add_child(UiKit.label(String(g["name"]), UiTokens.TEXT, UiTokens.INK if open else UiTokens.INK_MUTED, true))
		t.add_child(UiKit.label(String(g["text"]), UiTokens.TEXT_S, UiTokens.INK_MUTED, false, 190.0))
		t.add_child(UiKit.label(EquipmentCatalog.effect_words(g.get("effect", {})) if open else "Opens with: %s" % Unlocks.words(g.get("lock", {})),
			UiTokens.TEXT_S, UiTokens.SPRUCE if open else UiTokens.EMBER))
		var b := UiKit.button("On" if on else ("Take" if open else "Locked"), _equip.bind(slot, String(g["id"])), "primary" if on else "paper", UiTokens.TEXT_S)
		b.name = "%s_%s" % [slot, g["id"]]
		b.disabled = not open or on
		b.custom_minimum_size = Vector2(44, UiTokens.TAP)
		r.add_child(b)
	pane.add_child(p)


func _equip(slot: String, id: String) -> void:
	if Profile.equip(slot, id):
		note.text = "Packed: %s." % EquipmentCatalog.item(slot, id)["name"]
		_show.call_deferred(1)


class _Swatch:
	extends Button
	var colour := Color.WHITE
	var chosen := false
	var open := true

	static func make(c: Color, is_chosen: bool, is_open: bool) -> _Swatch:
		var s := _Swatch.new()
		s.colour = c
		s.chosen = is_chosen
		s.open = is_open
		s.custom_minimum_size = Vector2(UiTokens.TAP, UiTokens.TAP)
		s.flat = true
		s.focus_mode = Control.FOCUS_ALL
		return s

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 3.0
		draw_circle(c, r + 1.5, UiTokens.INK if chosen else UiTokens.PAPER_EDGE)
		draw_circle(c, r, colour)
		if chosen:
			draw_arc(c, r + 3.0, 0, TAU, 24, UiTokens.SPRUCE, 1.5, true)
		if not open:
			draw_circle(c, r, Color(UiTokens.PAPER, 0.55))
			draw_rect(Rect2(c + Vector2(-3, -1), Vector2(6, 5)), UiTokens.INK_SOFT)
			draw_arc(c + Vector2(0, -1), 2.2, PI, TAU, 8, UiTokens.INK_SOFT, 1.2)
