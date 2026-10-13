class_name TerrainTiles
extends RefCounted
## Builds the TileSet and fills TileMapLayers from a Terrain. The atlas
## layout is written by tools/art/godot_barranco.py; keep the two in step.
##
## Rows: 0-1 autotiled basalt (column = open-side mask, row = variant);
## 2 slopes (0-1 rising right, 2-3 rising left), face (4-7), loose (8-11),
## scramble (12-15); 3 back wall (0-7), deep rock (8-15).

const ATLAS := "res://assets/terrain/barranco_tiles.png"
## Pixel-art strata (tools/art/godot_backwalls.py), cut into a 16 × 16 grid
## of tiles: the darker copy is the back wall behind open ledges, the lighter
## one is solid rock you look straight into, so walls never read as space.
const CLIFF := "res://assets/scenery/barranco-wall-deep.png"
const CLIFF_SOURCE := 1
const DEEP := "res://assets/scenery/barranco-wall.png"
const DEEP_SOURCE := 2
## Ice and cracked slabs (tools/art/godot_hazards.py). Row 0 ice, row 1
## slabs: columns 0-1 whole, 2-3 breaking.
const HAZARDS := "res://assets/terrain/hazards.png"
const HAZARD_SOURCE := 3
## Per palette (tools/art/godot_rock.py): rows 0-1 edge overlays (column =
## open-side mask), drawn on an Edges layer over solid rock; row 2 slopes
## (0-1 rising right, 2-3 rising left) and climbable faces (4-7).
const EDGE_SOURCE := 4
## Rock you can climb, per palette (tools/art/godot_rock.py): lighter and
## warmer than the walls, painted by position so a face is one surface.
const FACE_SOURCE := 5
const T := Terrain.TILE
const SOURCE := 0


static func build_tileset(cliff: String = CLIFF, deep: String = DEEP, edges: String = "", face: String = "") -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = load(ATLAS)
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, SOURCE)
	var square := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var rising_right := PackedVector2Array([Vector2(-8, 8), Vector2(8, -8), Vector2(8, 8)])
	var rising_left := PackedVector2Array([Vector2(-8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for row in 4:
		for col in 16:
			var coord := Vector2i(col, row)
			src.create_tile(coord)
			var data := src.get_tile_data(coord, 0)
			var poly := PackedVector2Array()
			if row <= 1 or (row == 3 and col >= 8):
				poly = square
			elif row == 2 and col <= 1:
				poly = rising_right
			elif row == 2 and col <= 3:
				poly = rising_left
			if not poly.is_empty():
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, poly)
	for pair in [[cliff, CLIFF_SOURCE], [deep, DEEP_SOURCE]]:
		var painted := TileSetAtlasSource.new()
		painted.texture = load(pair[0])
		painted.texture_region_size = Vector2i(T, T)
		ts.add_source(painted, pair[1])
		var grid: int = painted.texture.get_width() / T
		for row in grid:
			for col in grid:
				var coord := Vector2i(col, row)
				painted.create_tile(coord)
				var data := painted.get_tile_data(coord, 0)
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, square)
	var haz := TileSetAtlasSource.new()
	haz.texture = load(HAZARDS)
	haz.texture_region_size = Vector2i(T, T)
	ts.add_source(haz, HAZARD_SOURCE)
	for row in 2:
		for col in 4:
			haz.create_tile(Vector2i(col, row))
			var data := haz.get_tile_data(Vector2i(col, row), 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	if face != "" and ResourceLoader.exists(face):
		var f := TileSetAtlasSource.new()
		f.texture = load(face)
		f.texture_region_size = Vector2i(T, T)
		ts.add_source(f, FACE_SOURCE)
		for row in f.texture.get_height() / T:
			for col in f.texture.get_width() / T:
				f.create_tile(Vector2i(col, row))
	if edges != "" and ResourceLoader.exists(edges):
		var e := TileSetAtlasSource.new()
		e.texture = load(edges)
		e.texture_region_size = Vector2i(T, T)
		ts.add_source(e, EDGE_SOURCE)
		for row in 3:
			for col in 16:
				var coord := Vector2i(col, row)
				e.create_tile(coord)
				# Only slopes collide: faces and boulders are climbed through.
				var poly := PackedVector2Array()
				if row == 2 and col <= 1:
					poly = rising_right
				elif row == 2 and col <= 3:
					poly = rising_left
				if not poly.is_empty():
					var data := e.get_tile_data(coord, 0)
					data.add_collision_polygon(0)
					data.set_collision_polygon_points(0, 0, poly)
	return ts


## The palette's edge atlas: "res://assets/scenery/lava-wall.png" →
## "res://assets/terrain/edges-lava.png".
static func edges_for(deep: String) -> String:
	return "res://assets/terrain/edges-%s.png" % deep.get_file().get_slice("-wall", 0)


## A cracked slab: whole, breaking, or gone (crumbled away).
static func set_slab(ground: TileMapLayer, cell: Vector2i, stage: String) -> void:
	match stage:
		"whole":
			ground.set_cell(cell, HAZARD_SOURCE, Vector2i(_variant(cell, 2), 1))
		"breaking":
			ground.set_cell(cell, HAZARD_SOURCE, Vector2i(2 + _variant(cell, 2), 1))
		_:
			ground.erase_cell(cell)


static func _cliff(cell: Vector2i) -> Vector2i:
	return Vector2i(posmod(cell.x, 16), posmod(cell.y, 16))


static func _variant(cell: Vector2i, count: int) -> int:
	return posmod(cell.x * 73856093 ^ cell.y * 19349663, count)


static func _faces_inside(terrain: Terrain, cell: Vector2i) -> bool:
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var n: Vector2i = cell + d
		if not terrain.is_solid(n) and terrain.is_inside(n):
			return true
	return false


## Fills `ground` (collision, faces) and `back` (recessed rock) from `terrain`.
## `theme` may name its own cliff paintings ({cliff, deep}).
static func paint(terrain: Terrain, ground: TileMapLayer, back: TileMapLayer, theme: Dictionary = {}) -> void:
	var deep_path: String = theme.get("deep", DEEP)
	var edge_path := edges_for(deep_path)
	var face_path := deep_path.replace("-wall.png", "-face.png")
	var ts := build_tileset(theme.get("cliff", CLIFF), deep_path, edge_path, face_path)
	var has_face := ts.has_source(FACE_SOURCE)
	ground.tile_set = ts
	back.tile_set = ts
	back.collision_enabled = false
	# Solid rock is one texture throughout; its edges (lit lip, outline,
	# undercut shadow) are an overlay on top, so edge and interior match.
	var has_edges := ts.has_source(EDGE_SOURCE)
	var edges := ground.get_node_or_null("Edges") as TileMapLayer
	if has_edges and edges == null:
		edges = TileMapLayer.new()
		edges.name = "Edges"
		ground.add_child(edges)
	if edges:
		edges.tile_set = ts
		edges.collision_enabled = false
	for y in terrain.height:
		for x in terrain.width:
			var cell := Vector2i(x, y)
			var k := terrain.kind(cell)
			var at := Vector2i(-1, -1)
			match k:
				Terrain.Kind.ROCK:
					if has_edges:
						ground.set_cell(cell, DEEP_SOURCE, _cliff(cell))
						var mask := terrain.open_mask(cell)
						if mask != 0:
							edges.set_cell(cell, EDGE_SOURCE, Vector2i(mask, _variant(cell, 2)))
					elif terrain.is_deep(cell, 1):
						ground.set_cell(cell, DEEP_SOURCE, _cliff(cell))
						continue
					else:
						at = Vector2i(terrain.open_mask(cell), _variant(cell, 2))
				Terrain.Kind.SLOPE_R:
					if has_edges:
						ground.set_cell(cell, EDGE_SOURCE, Vector2i(_variant(cell, 2), 2))
					else:
						at = Vector2i(_variant(cell, 2), 2)
				Terrain.Kind.SLOPE_L:
					if has_edges:
						ground.set_cell(cell, EDGE_SOURCE, Vector2i(2 + _variant(cell, 2), 2))
					else:
						at = Vector2i(2 + _variant(cell, 2), 2)
				Terrain.Kind.FACE, Terrain.Kind.CRIMP, Terrain.Kind.JUG:
					# Crimps and jugs get their holds drawn on top (the crag),
					# on plain faces.
					if has_face and has_edges:
						ground.set_cell(cell, FACE_SOURCE, _cliff(cell))
						# Holds on the face; the crag draws its own.
						if k == Terrain.Kind.FACE and not terrain.markers.has("Q") and _variant(cell, 3) != 0:
							edges.set_cell(cell, EDGE_SOURCE, Vector2i(4 + _variant(cell, 4), 2))
					else:
						at = Vector2i(4 + _variant(cell, 4), 2)
				Terrain.Kind.LOOSE:
					if has_edges:
						ground.set_cell(cell, EDGE_SOURCE, Vector2i(8 + _variant(cell, 4), 2))
					else:
						at = Vector2i(8 + _variant(cell, 4), 2)
				Terrain.Kind.SCRAMBLE:
					if has_edges:
						ground.set_cell(cell, EDGE_SOURCE, Vector2i(12 + _variant(cell, 4), 2))
					else:
						at = Vector2i(12 + _variant(cell, 4), 2)
				Terrain.Kind.ICE:
					ground.set_cell(cell, HAZARD_SOURCE, Vector2i(_variant(cell, 4), 0))
				Terrain.Kind.CRUMBLE:
					set_slab(ground, cell, "whole")
			if at.x >= 0:
				ground.set_cell(cell, SOURCE, at)
			var open := not terrain.is_solid(cell) or k == Terrain.Kind.SLOPE_R or k == Terrain.Kind.SLOPE_L
			if open and terrain.is_inside(cell):
				back.set_cell(cell, CLIFF_SOURCE, _cliff(cell))
			elif (k == Terrain.Kind.CRUMBLE or k == Terrain.Kind.ICE) and (terrain.is_inside(cell) or _faces_inside(terrain, cell)):
				# What shows when a slab has crumbled away.
				back.set_cell(cell, CLIFF_SOURCE, _cliff(cell))
			elif k == Terrain.Kind.ROCK and _faces_inside(terrain, cell):
				# Edge tiles have rounded corners: inside the mountain, the
				# back wall shows through them, not the sky.
				back.set_cell(cell, CLIFF_SOURCE, _cliff(cell))
