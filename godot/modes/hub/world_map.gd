extends JournalPage
## The world: seven continents, and the places to climb on each. Africa
## has the two that are in the game now (Lion Rock and Kilimanjaro). The
## others are marked "not in the game yet": the shape of what the game can
## grow into, never pretend content. The World Passport stamps a place when
## you finish it (Records.passport).

## Places beyond Africa, planned and locked: [name, kind, continent, x, y].
const PLANNED := [
	["Aconcagua", "expedition", "south-america", 0.305, 0.74],
	["Patagonia granite", "crag", "south-america", 0.3, 0.86],
	["Denali", "expedition", "north-america", 0.13, 0.2],
	["Yosemite walls", "crag", "north-america", 0.17, 0.36],
	["Mont Blanc", "expedition", "europe", 0.49, 0.29],
	["Fontainebleau boulders", "crag", "europe", 0.47, 0.25],
	["Everest region", "expedition", "asia", 0.69, 0.4],
	["Limestone of the south", "crag", "asia", 0.77, 0.52],
	["Aoraki / Mount Cook", "expedition", "oceania", 0.93, 0.86],
	["Sandstone of the Blue Mountains", "crag", "oceania", 0.86, 0.76],
	["Vinson Massif", "expedition", "antarctica", 0.5, 0.95],
]

## Low-poly continents, as fractions of the map.
const SHAPES := {
	"north-america": [[0.05, 0.16], [0.16, 0.1], [0.3, 0.12], [0.28, 0.24], [0.22, 0.34], [0.2, 0.44], [0.24, 0.5], [0.2, 0.52], [0.14, 0.42], [0.09, 0.32], [0.04, 0.24]],
	"south-america": [[0.24, 0.54], [0.31, 0.56], [0.36, 0.64], [0.33, 0.74], [0.3, 0.84], [0.28, 0.9], [0.27, 0.8], [0.25, 0.68]],
	"europe": [[0.44, 0.18], [0.53, 0.14], [0.56, 0.2], [0.53, 0.3], [0.47, 0.33], [0.44, 0.28]],
	"africa": [[0.44, 0.38], [0.53, 0.36], [0.6, 0.44], [0.6, 0.54], [0.56, 0.66], [0.52, 0.76], [0.49, 0.68], [0.47, 0.54], [0.43, 0.48]],
	"asia": [[0.56, 0.14], [0.72, 0.1], [0.9, 0.16], [0.88, 0.3], [0.8, 0.42], [0.76, 0.56], [0.7, 0.48], [0.64, 0.44], [0.6, 0.34], [0.57, 0.24]],
	"oceania": [[0.8, 0.66], [0.9, 0.64], [0.93, 0.74], [0.88, 0.8], [0.81, 0.77]],
	"antarctica": [[0.2, 0.94], [0.4, 0.91], [0.6, 0.92], [0.82, 0.94], [0.8, 0.99], [0.2, 0.99]],
}

var map: Control
var info: Label
var pins: Dictionary = {}


func build() -> void:
	set_title("The world")
	var col := UiKit.vbox(4)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(col)
	var pp: Dictionary = Records.passport()
	var live: int = pp["continents"].size()
	info = UiKit.label("%d of 7 continents have places in the game. Tap a place." % live, UiTokens.TEXT, UiTokens.INK_MUTED)
	col.add_child(info)
	map = Control.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.draw.connect(_draw_map)
	map.resized.connect(_place_pins)
	col.add_child(map)
	_pin("lion-rock", "Lion Rock", "Crag · 7 routes and a daily route", 0.5, 0.6, true, bool(pp["places"]["lion-rock"]["done"]))
	_pin("kilimanjaro", "Kilimanjaro", "Expedition · three routes", 0.56, 0.58, true, bool(pp["places"]["kilimanjaro"]["done"]))
	for p in PLANNED:
		_pin(String(p[0]).to_snake_case(), String(p[0]), "%s · not in the game yet" % ("Expedition" if p[1] == "expedition" else "Crag"), p[3], p[4], false, false)
	_place_pins.call_deferred()


func _pin(id: String, label: String, line: String, x: float, y: float, open: bool, done: bool) -> void:
	var b := Button.new()
	b.flat = true
	b.name = id
	b.tooltip_text = label
	b.custom_minimum_size = Vector2(UiTokens.TAP, UiTokens.TAP)
	b.set_meta("at", Vector2(x, y))
	b.draw.connect(func() -> void:
		var c := b.size / 2.0
		var col := UiTokens.EMBER if open else UiTokens.INK_MUTED
		b.draw_circle(c + Vector2(0, 1), 6.0, Color(0, 0, 0, 0.2))
		b.draw_circle(c, 5.5, UiTokens.CHALK)
		b.draw_circle(c, 4.0, col)
		if done:
			b.draw_arc(c, 8.0, 0, TAU, 20, UiTokens.STAR, 1.5, true)
		if not open:
			b.draw_rect(Rect2(c + Vector2(-1.5, -1), Vector2(3, 2.5)), UiTokens.CHALK))
	b.pressed.connect(_tap.bind(id, label, line, open))
	map.add_child(b)
	pins[id] = b


func _place_pins() -> void:
	for id in pins:
		var b: Button = pins[id]
		b.size = b.custom_minimum_size
		b.position = map.size * (b.get_meta("at") as Vector2) - b.size / 2.0


func _tap(id: String, label: String, line: String, open: bool) -> void:
	info.text = "%s · %s%s" % [label, line, "" if open else ". Your passport has room for it."]
	if not open or not Crag.navigate:
		return
	if id == "lion-rock":
		Crag.go(Crag.MENU)
	elif id == "kilimanjaro":
		Expedition.go(Expedition.MENU)


func _draw_map() -> void:
	var s := map.size
	map.draw_rect(Rect2(Vector2.ZERO, s), Color("#cfdde2"))
	for i in range(1, 6):
		map.draw_line(Vector2(0, s.y * i / 6.0), Vector2(s.x, s.y * i / 6.0), Color(1, 1, 1, 0.35), 1.0)
		map.draw_line(Vector2(s.x * i / 6.0, 0), Vector2(s.x * i / 6.0, s.y), Color(1, 1, 1, 0.35), 1.0)
	var pp: Dictionary = Records.passport()
	for id in SHAPES:
		var pts := PackedVector2Array()
		for q in SHAPES[id]:
			pts.append(Vector2(q[0], q[1]) * s)
		var live: bool = pp["continents"].has(id)
		map.draw_colored_polygon(pts, Color("#c9b98f") if live else Color("#ddd3bd"))
		var closed := pts.duplicate()
		closed.append(pts[0])
		map.draw_polyline(closed, Color(0.4, 0.33, 0.22, 0.6), 1.0, true)
		var centre := Vector2.ZERO
		for q in pts:
			centre += q
		centre /= pts.size()
		var font := UiFont.body()
		if font:
			var name: String = Records.CONTINENTS[id]
			var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
			map.draw_string(font, centre + Vector2(-w / 2.0, -8), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.25, 0.2, 0.14, 0.8))
	map.draw_rect(Rect2(Vector2.ZERO, s), UiTokens.PAPER_EDGE, false, 1.0)
