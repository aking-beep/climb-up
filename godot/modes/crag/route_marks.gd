class_name RouteMarks
extends Node2D
## Reading the route: labels beside the line for what is coming (tiny holds,
## big holds to rest on, blank rock to jump, the bolts and the long run-outs
## between them). Shown while the camera runs up the route before a go.

var level: Node
var _sections: Array = []


## The line's stretches, bottom to top: [{kind: crimp/jug/blank, from, to
## (rows), x (px, just right of the line)}].
func sections() -> Array:
	if not _sections.is_empty() or level == null:
		return _sections
	var t: Terrain = level.terrain
	var start_row := Terrain.cell_of(level._start - Vector2(0, 2)).y
	var top_row := Terrain.cell_of(Terrain.feet(t.markers["X"][0])).y + 2
	var last_x := 0
	var run: Dictionary = {}
	for y in range(start_row, top_row, -1):
		var kind := ""
		var right := -1
		for x in t.width:
			var k := t.kind(Vector2i(x, y))
			if k == Terrain.Kind.CRIMP:
				kind = "crimp"
			elif k == Terrain.Kind.JUG and kind == "":
				kind = "jug"
			if t.is_climbable(Vector2i(x, y)):
				right = x
		if right < 0:
			kind = "blank"
			right = last_x
		last_x = right
		if not run.is_empty() and run["kind"] == kind and run["to"] == y + 1:
			run["to"] = y
			continue
		if not run.is_empty():
			_sections.append(run)
		run = {"kind": kind, "from": y, "to": y, "x": (right + 1.5) * Terrain.TILE} if kind != "" else {}
	if not run.is_empty():
		_sections.append(run)
	return _sections


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if level == null:
		return
	var font := UiFont.body() if UiFont.body() else ThemeDB.fallback_font
	var words := {"crimp": ["Tiny holds: keep moving", Color("#f2c14e")], "jug": ["Big hold: rest", Color("#8fd16b")], "blank": ["Blank: jump", Color("#e0663c")]}
	for m in sections():
		var w: Array = words[m["kind"]]
		var y := (float(m["from"] + m["to"]) / 2.0 + 0.5) * Terrain.TILE
		var x: float = m["x"]
		draw_line(Vector2(x - 4, m["to"] * Terrain.TILE), Vector2(x - 4, (m["from"] + 1) * Terrain.TILE), w[1], 1.0)
		_label(font, Vector2(x, y + 3), w[0], w[1])
	var clips: Array = level.clips
	for i in clips.size():
		var c: Dictionary = clips[i]
		# Bolt labels go on the far side of the line from the stretch labels.
		var cell: Vector2i = c["cell"]
		var left := cell.x
		var t: Terrain = level.terrain
		while left > 0 and (t.is_climbable(Vector2i(left - 1, cell.y)) or left == cell.x):
			left -= 1
		var text := "Bolt %d" % (i + 1)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var at := Vector2(left * Terrain.TILE - w - 4, (cell.y + 0.5) * Terrain.TILE + 3)
		draw_line(Vector2(left * Terrain.TILE - 2, (cell.y + 0.5) * Terrain.TILE), Vector2(cell.x * Terrain.TILE, (cell.y + 0.5) * Terrain.TILE), Color("#cfe3f5", 0.5), 1.0)
		_label(font, at, text, Color("#cfe3f5"))
		if i > 0 and int(c["gap"]) >= CragLevel.RUNOUT:
			var below: Vector2 = Vector2(clips[i - 1]["cell"]) * Terrain.TILE
			var mid := Vector2(at.x - 10, (at.y + below.y) / 2.0)
			_label(font, mid, "Run-out %s m" % Crag._m(int(c["gap"]) * Crag.ROW_M), Color("#ff8a6b"))


func _label(font: Font, at: Vector2, text: String, col: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.85))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
