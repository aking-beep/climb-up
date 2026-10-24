extends JournalPage
## Before you go (CLIMB UP 2.0): the route you picked, the team, Lena's
## briefing for each of the three climbs (from the levels' own weather),
## and your pack. Gear is a trade, so the briefing says what would help:
## a hard shell for rain, a down layer for the freezing summit night.

var pack_box: VBoxContainer
var go_button: Button


func build() -> void:
	var route := Places.route_of(Expedition.session)
	var r: Dictionary = Trek.ROUTES[route]
	set_title("Before you go · %s" % r["name"])
	back_to = Expedition.MENU
	var row := UiKit.hbox(8)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(row)
	# Left: the briefing.
	var left := UiKit.vbox(3)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(JournalPage.scroller(left))
	left.add_child(UiKit.label("Lena's briefing", UiTokens.TEXT_L, UiTokens.INK, true))
	left.add_child(UiKit.label("%s, %d days. %s" % [r["name"], int(r["permit"]), Briefing.risk_words(Expedition.state())], UiTokens.TEXT_S, UiTokens.INK_SOFT, false, 220.0))
	var hints: Array = []
	for climb in Briefing.CLIMBS:
		var b := Briefing.for_climb(climb, route)
		var p := UiKit.panel(UiTokens.PAPER_RAISED, 5.0)
		var v := UiKit.vbox(1)
		p.add_child(v)
		v.add_child(UiKit.label("%s · %s m" % [b["place"], ExpeditionEngine.format_meters(b["meters"])], UiTokens.TEXT, UiTokens.INK, true))
		v.add_child(UiKit.label(Briefing.line(b), UiTokens.TEXT_S, UiTokens.INK_SOFT, false, 210.0))
		left.add_child(p)
		for h in Briefing.gear_hints(b):
			if not h in hints:
				hints.append(h)
	# Right: the team and the pack (it scrolls), and the way on below.
	var side := UiKit.vbox(3)
	side.custom_minimum_size = Vector2(200, 0)
	row.add_child(side)
	var right := UiKit.vbox(3)
	side.add_child(JournalPage.scroller(right))
	var team := Control.new()
	team.custom_minimum_size = Vector2(190, 46)
	team.draw.connect(func() -> void: team.draw_rect(Rect2(Vector2(0, 40), Vector2(team.size.x, 6)), Color("#8a7a52")))
	right.add_child(team)
	var x := 22.0
	for who in ["you", "lena", "marco", "jun"]:
		var h := Hero.new()
		h.height = 36.0
		h.set_look(Profile.look if who == "you" else TeamLooks.look(who))
		h.kit = "trek"
		h.pose = "wave" if who == "lena" else "idle"
		h.phase = x
		h.position = Vector2(x, 42)
		team.add_child(h)
		x += 48.0
	right.add_child(UiKit.label("Your pack · tap to swap", UiTokens.TEXT, UiTokens.INK_MUTED))
	pack_box = UiKit.vbox(2)
	right.add_child(pack_box)
	_fill_pack(hints)
	go_button = UiKit.button("Walk into camp", _go_camp, "primary", UiTokens.TEXT_L)
	go_button.name = "WalkIn"
	side.add_child(go_button)
	go_button.grab_focus.call_deferred()


func _fill_pack(hints: Array) -> void:
	for c in pack_box.get_children():
		c.queue_free()
	for slot in EquipmentCatalog.SLOTS:
		var now := Profile.item(slot)
		var open := EquipmentCatalog.items(slot).filter(func(g: Dictionary) -> bool: return EquipmentCatalog.open(g))
		var b := UiKit.button("%s: %s" % [EquipmentCatalog.SLOT_NAMES[slot], now["name"]], _swap.bind(slot, hints), "paper", UiTokens.TEXT_S)
		b.name = "Pack_" + slot
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 20)
		b.disabled = open.size() < 2
		b.tooltip_text = EquipmentCatalog.effect_words(now.get("effect", {}))
		pack_box.add_child(b)
	for h in hints:
		if Profile.item(h[0])["id"] != h[1]:
			pack_box.add_child(UiKit.label("Would help: %s" % EquipmentCatalog.item(h[0], h[1])["name"], UiTokens.TEXT_S, UiTokens.SPRUCE))


## The next open item in the slot.
func _swap(slot: String, hints: Array) -> void:
	var open := EquipmentCatalog.items(slot).filter(func(g: Dictionary) -> bool: return EquipmentCatalog.open(g))
	var i := 0
	for k in open.size():
		if open[k]["id"] == Profile.item(slot)["id"]:
			i = k
	Profile.equip(slot, open[(i + 1) % open.size()]["id"])
	_fill_pack.call_deferred(hints)


func _go_camp() -> void:
	if Crag.navigate and is_inside_tree():
		Transition.go(get_tree(), Expedition.camp_scene())
