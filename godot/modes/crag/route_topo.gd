class_name RouteTopo
extends Control
## A route's topo, drawn from its map (the same file the climb loads): the
## line of holds by type (shape and colour: crimps, jugs, slopers,
## pockets, plain face), the bolts, the anchor at the top and where you
## start. The guidebook view before you tie in.

const HOLD_COLOURS := {
	Terrain.Kind.FACE: Color("#b9ad98"), Terrain.Kind.CRIMP: Color("#f2c14e"), Terrain.Kind.JUG: Color("#e6dcc8"),
	Terrain.Kind.SLOPER: Color("#9fc4e0"), Terrain.Kind.POCKET: Color("#3a2a22"), Terrain.Kind.SCRAMBLE: Color("#c8b48a"),
	Terrain.Kind.REST: Color("#7fa36b"),
}

var terrain: Terrain
## The rows of your best high point (0: none), drawn as a chalk mark.
var high_rows := 0
var _box := Rect2i()


func show_route(id: String) -> void:
	terrain = Terrain.from_text(Crag.map_text(id))
	high_rows = int(Crag.record(id).get("highRows", 0)) if id != "daily" else int(Crag.daily_record().get("highRows", 0))
	# The climbed part: every hold cell, the bolts and the ends.
	var lo := Vector2i(terrain.width, terrain.height)
	var hi := Vector2i(-1, -1)
	for y in terrain.height:
		for x in terrain.width:
			var k := terrain.kind(Vector2i(x, y))
			if k in Terrain.HOLDS:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	for ch in ["Q", "X", "P"]:
		for m in terrain.markers.get(ch, []):
			lo = Vector2i(mini(lo.x, m.x), mini(lo.y, m.y))
			hi = Vector2i(maxi(hi.x, m.x), maxi(hi.y, m.y))
	_box = Rect2i(lo - Vector2i(2, 1), hi - lo + Vector2i(5, 3))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#d9cdb6"))
	if terrain == null or _box.size.x <= 0:
		return
	var cell := minf(size.x / float(_box.size.x), size.y / float(_box.size.y))
	var off := (size - Vector2(_box.size) * cell) / 2.0
	var at := func(c: Vector2i) -> Vector2: return off + Vector2(c - _box.position) * cell
	# The rock, then the holds by type (shape tells them apart too).
	for y in range(_box.position.y, _box.end.y):
		for x in range(_box.position.x, _box.end.x):
			var c := Vector2i(x, y)
			if not terrain.is_inside(c):
				continue
			var k := terrain.kind(c)
			var p: Vector2 = at.call(c)
			if terrain.is_solid(c):
				draw_rect(Rect2(p, Vector2(cell, cell)), Color("#8e7a5e"))
			elif k in HOLD_COLOURS:
				draw_rect(Rect2(p, Vector2(cell, cell)), Color("#a8987c"))
				var col: Color = HOLD_COLOURS[k]
				var mid := p + Vector2(cell, cell) / 2.0
				match k:
					Terrain.Kind.CRIMP:
						draw_rect(Rect2(mid - Vector2(cell * 0.35, cell * 0.12), Vector2(cell * 0.7, cell * 0.24)), col)
					Terrain.Kind.JUG:
						draw_circle(mid, cell * 0.36, col)
					Terrain.Kind.SLOPER:
						draw_circle(mid + Vector2(0, cell * 0.08), cell * 0.3, col)
					Terrain.Kind.POCKET:
						draw_circle(mid, cell * 0.22, col)
					_:
						draw_rect(Rect2(p + Vector2(1, 1), Vector2(cell - 2, cell - 2)), Color(col, 0.35))
	# Your high point, in chalk.
	if high_rows > 0 and terrain.markers.has("P"):
		var foot: Vector2i = terrain.markers["P"][0]
		var y: float = (at.call(Vector2i(_box.position.x, foot.y - high_rows)) as Vector2).y
		draw_dashed_line(Vector2(2, y), Vector2(size.x - 2, y), Color(1, 1, 1, 0.85), 1.0, 3.0)
	for q in terrain.markers.get("Q", []):
		var p: Vector2 = at.call(q) + Vector2(cell, cell) / 2.0
		draw_circle(p, maxf(1.6, cell * 0.32), Color("#e9e5dc"))
		draw_arc(p, maxf(1.6, cell * 0.32), 0, TAU, 10, UiTokens.INK, 1.0)
	for x in terrain.markers.get("X", []):
		var p: Vector2 = at.call(x) + Vector2(cell, cell) / 2.0
		draw_circle(p, maxf(2.2, cell * 0.45), UiTokens.EMBER)
	for s in terrain.markers.get("P", []):
		var p: Vector2 = at.call(s) + Vector2(cell / 2.0, cell)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(3, 0), p + Vector2(0, -4)]), UiTokens.SPRUCE)
	draw_rect(Rect2(Vector2.ZERO, size), UiTokens.PAPER_EDGE, false, 1.0)
