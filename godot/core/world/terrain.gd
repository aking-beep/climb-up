class_name Terrain
extends RefCounted
## A level's ground truth: the ASCII map (see tools/levels/barranco_map.py
## for the legend) as a grid of kinds, plus the markers placed on it.
## Physics comes from the TileMapLayer built from this; gameplay questions
## ("can I climb here? is this loose? exposed?") are answered here.

const TILE := 16

enum Kind { AIR, ROCK, SLOPE_R, SLOPE_L, FACE, LOOSE, SCRAMBLE, EXPOSED, REST, ICE, CRUMBLE }

const SOLID_CHARS := "#/\\"
const KIND_OF := {
	"#": Kind.ROCK, "/": Kind.SLOPE_R, "\\": Kind.SLOPE_L,
	"C": Kind.FACE, "L": Kind.LOOSE, "s": Kind.SCRAMBLE,
	"E": Kind.EXPOSED, "R": Kind.REST,
	"i": Kind.ICE, "c": Kind.CRUMBLE,
}
## Markers stand on air. r: rockfall comes down this column (the marker is
## where rocks start); w: a water cache; *: lost gear to find; b / d: a
## stone rolls from here along the ground, leftward (b) or rightward (d).
const MARKERS := "PXMljmpSTFgoVKrw*bd"

var width := 0
var height := 0
var kinds: PackedByteArray = PackedByteArray()
## Marker character → Array of cells (Vector2i), in reading order.
var markers: Dictionary = {}


static func from_text(text: String) -> Terrain:
	var t := Terrain.new()
	var lines := text.strip_edges(false, true).split("\n")
	t.height = lines.size()
	for line in lines:
		t.width = maxi(t.width, line.length())
	t.kinds.resize(t.width * t.height)
	for y in t.height:
		var line: String = lines[y]
		for x in t.width:
			var ch := line[x] if x < line.length() else "."
			var kind: int = KIND_OF.get(ch, Kind.AIR)
			if ch in MARKERS:
				if not t.markers.has(ch):
					t.markers[ch] = []
				t.markers[ch].append(Vector2i(x, y))
				# A rest stone or cairn marker still stands on air.
			t.kinds[y * t.width + x] = kind
	# Markers sort left to right, then top to bottom.
	for ch in t.markers:
		t.markers[ch].sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return t


static func load_file(path: String) -> Terrain:
	return from_text(FileAccess.get_file_as_string(path))


func kind(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= width:
		return Kind.ROCK  # the world's sides are walls
	if cell.y < 0:
		return Kind.AIR
	if cell.y >= height:
		return Kind.ROCK
	return kinds[cell.y * width + cell.x]


func is_solid(cell: Vector2i) -> bool:
	var k := kind(cell)
	return k == Kind.ROCK or k == Kind.SLOPE_R or k == Kind.SLOPE_L or k == Kind.ICE or k == Kind.CRUMBLE


## Changes one cell (a slab crumbling away, or settling back).
func set_kind(cell: Vector2i, k: int) -> void:
	if cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height:
		kinds[cell.y * width + cell.x] = k


func is_climbable(cell: Vector2i) -> bool:
	var k := kind(cell)
	return k == Kind.FACE or k == Kind.LOOSE or k == Kind.SCRAMBLE


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


## Feet position (bottom centre) of a marker cell.
static func feet(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE / 2.0, (cell.y + 1) * TILE)


## Open sides of a solid cell: 1 top, 2 right, 4 bottom, 8 left.
func open_mask(cell: Vector2i) -> int:
	var m := 0
	if not is_solid(cell + Vector2i.UP):
		m |= 1
	if not is_solid(cell + Vector2i.RIGHT):
		m |= 2
	if not is_solid(cell + Vector2i.DOWN):
		m |= 4
	if not is_solid(cell + Vector2i.LEFT):
		m |= 8
	return m


## True when a cell of rock is at least `margin` cells from any air.
func is_deep(cell: Vector2i, margin: int = 2) -> bool:
	for dy in range(-margin, margin + 1):
		for dx in range(-margin, margin + 1):
			if not is_solid(cell + Vector2i(dx, dy)):
				return false
	return true


## Inside the mountain: air with rock somewhere above it in the column.
func is_inside(cell: Vector2i) -> bool:
	for y in range(cell.y - 1, -1, -1):
		if is_solid(Vector2i(cell.x, y)):
			return true
	return false


## The kinds a body overlaps (`rect` in pixels).
func kinds_in(rect: Rect2) -> Array[int]:
	var out: Array[int] = []
	var a := cell_of(rect.position + Vector2(0.01, 0.01))
	var b := cell_of(rect.end - Vector2(0.01, 0.01))
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var k := kind(Vector2i(x, y))
			if not out.has(k):
				out.append(k)
	return out


func touches_climbable(rect: Rect2) -> bool:
	var ks := kinds_in(rect)
	return ks.has(Kind.FACE) or ks.has(Kind.LOOSE) or ks.has(Kind.SCRAMBLE)


## The climbable kind under the hands (the top quarter of the body), or AIR.
func hold_at(rect: Rect2) -> int:
	var hands := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.35))
	for k in kinds_in(hands):
		if k == Kind.FACE or k == Kind.LOOSE or k == Kind.SCRAMBLE:
			return k
	return Kind.AIR


func pixel_size() -> Vector2:
	return Vector2(width * TILE, height * TILE)
