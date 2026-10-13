class_name RouteBuilder
extends RefCounted
## Builds a crag route's map from a list of segments, bottom to top: the
## same builder as tools/levels/crag_maps.py (which writes the seven fixed
## routes), so the daily route is made the same way as the others. A test
## builds the seven from their specs and checks they match the files.
##
## Segments:
##   ["up", n]                     n rows of ordinary rock
##   ["crimps", n]                 n rows of crimps (k)
##   ["slopers", n]                n rows of slopers (z)
##   ["pockets", n]                n rows of pockets (u)
##   ["jug", n]                    n rows of jug (2 is one big hold)
##   ["blank", n]                  n rows of blank rock: dyno across
##   ["traverse", dx, k, roof, h]  a two-row band sideways by dx columns, its
##                                 middle k columns hold h (default "k"),
##                                 rock overhead if roof

const W := 36
const WALL_X := 10
const LEDGE := 5
const WIDTH := 3
const CHAR := {"up": "C", "crimps": "k", "slopers": "z", "pockets": "u", "jug": "J", "blank": "."}

var h := 0
var g: Array = []
var line_x: Dictionary = {}
var boltable: Dictionary = {}
## Why the build failed ("" when it did not).
var error := ""


static func rows_of(segments: Array) -> int:
	var n := 0
	for s in segments:
		n += 2 if s[0] == "traverse" else int(s[1])
	return n


## The map text for a route, or "" when it cannot be built (error says why).
static func build(segments: Array, x0: int, bolts: int, spread: float, first: int = 3) -> String:
	var b := RouteBuilder.new()
	if not b._build(segments, x0, bolts, spread, first):
		return ""
	return b.text()


func _build(segments: Array, x0: int, bolts: int, spread: float, first: int) -> bool:
	h = rows_of(segments) + LEDGE + 4
	g = []
	for y in h:
		var row: Array = []
		row.resize(W)
		row.fill(".")
		g.append(row)
	for y in [h - 2, h - 1]:
		for x in W:
			g[y][x] = "#"
	for y in [LEDGE, LEDGE + 1]:
		for x in range(WALL_X, W):
			g[y][x] = "#"
	g[h - 3][4] = "P"
	var x := x0
	var y := h - 3
	for seg in segments:
		var kind: String = seg[0]
		if kind == "traverse":
			var dx: int = seg[1]
			var k: int = seg[2]
			var roof: bool = seg[3]
			var hold: String = seg[4] if seg.size() > 4 else "k"
			var lo := mini(x, x + dx)
			var hi := maxi(x, x + dx) + WIDTH - 1
			if lo < WALL_X or hi >= W - 3:
				error = "traverse leaves the wall"
				return false
			for yy in [y, y - 1]:
				for xx in range(lo, hi + 1):
					g[yy][xx] = "C"
			var mid := (lo + hi) / 2
			for yy in [y, y - 1]:
				for xx in range(mid - k / 2, mid - k / 2 + k):
					g[yy][xx] = hold
			if roof:
				for xx in range(lo, hi + 1):
					if not (x + dx <= xx and xx < x + dx + WIDTH) and not (x <= xx and xx < x + WIDTH):
						g[y - 3][xx] = "#"
			line_x[y] = x + dx
			line_x[y - 1] = x + dx
			x += dx
			y -= 2
			continue
		var n: int = seg[1]
		if not CHAR.has(kind):
			error = "unknown segment " + kind
			return false
		var ch: String = CHAR[kind]
		for i in n:
			for xx in range(x, x + WIDTH):
				g[y][xx] = ch
			line_x[y] = x
			if kind != "blank":
				boltable[y] = true
			y -= 1
	if y != LEDGE + 1:
		error = "segments end at row %d, not %d" % [y, LEDGE + 1]
		return false
	for yy in [LEDGE, LEDGE + 1]:
		for xx in range(x, x + WIDTH):
			g[yy][xx] = "C"
	g[LEDGE - 1][x + WIDTH + 2] = "X"
	return _bolts(bolts, spread, first)


## Python's round(): halves go to the even neighbour.
static func round_even(v: float) -> int:
	var f := floorf(v)
	var d := v - f
	if is_equal_approx(d, 0.5):
		return int(f) if int(f) % 2 == 0 else int(f) + 1
	return int(roundf(v))


func _bolts(count: int, spread: float, first: int) -> bool:
	var foot := h - 3
	var span := float((foot - first) - (LEDGE + 4))
	var weights: Array = []
	for i in count - 1:
		weights.append(1.0 + spread * i)
	var total := 0.0
	for w in weights:
		total += w
	var want: Array = [float(foot - first)]
	for w in weights:
		want.append(float(want[-1]) - span * w / total)
	var placed: Array = []
	for target: float in want:
		var row := -1
		for d in [0, 1, -1, 2, -2, 3, -3]:
			var yy: int = round_even(target) + int(d)
			if boltable.has(yy) and placed.all(func(p: int) -> bool: return absi(yy - p) >= 3):
				row = yy
				break
		if row < 0:
			error = "no room for a bolt near row %.1f" % target
			return false
		var x: int = line_x[row]
		var side := x + WIDTH if g[row][x + WIDTH] == "." else x - 1
		if g[row][side] != ".":
			error = "no room beside the line for a bolt at row %d" % row
			return false
		g[row][side] = "Q"
		placed.append(row)
	return true


func text() -> String:
	var lines: PackedStringArray = []
	for row in g:
		lines.append("".join(PackedStringArray(row)))
	return "\n".join(lines) + "\n"
