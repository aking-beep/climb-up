class_name TerrainTiles
extends RefCounted
## Builds the TileSet and fills TileMapLayers from a Terrain. The atlas
## layout is written by tools/art/godot_barranco.py; keep the two in step.
##
## Rows: 0-1 autotiled basalt (column = open-side mask, row = variant);
## 2 slopes (0-1 rising right, 2-3 rising left), face (4-7), loose (8-11),
## scramble (12-15); 3 back wall (0-7), deep rock (8-15).

const ATLAS := "res://assets/terrain/barranco_tiles.png"
## The painted lava-strata cliff (tools/art/scenery.py), cut into a 16 × 16
## grid of tiles and laid seamlessly over deep rock and the back wall.
const CLIFF := "res://assets/scenery/barranco-cliff.png"
const CLIFF_SOURCE := 1
## The same painting, darker: rock you are looking straight into.
const DEEP := "res://assets/scenery/barranco-cliff-deep.png"
const DEEP_SOURCE := 2
const T := Terrain.TILE
const SOURCE := 0


static func build_tileset() -> TileSet:
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
	for pair in [[CLIFF, CLIFF_SOURCE], [DEEP, DEEP_SOURCE]]:
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
	return ts


static func _cliff(cell: Vector2i) -> Vector2i:
	return Vector2i(posmod(cell.x, 16), posmod(cell.y, 16))


static func _variant(cell: Vector2i, count: int) -> int:
	return posmod(cell.x * 73856093 ^ cell.y * 19349663, count)


## Fills `ground` (collision, faces) and `back` (recessed rock) from `terrain`.
static func paint(terrain: Terrain, ground: TileMapLayer, back: TileMapLayer) -> void:
	var ts := build_tileset()
	ground.tile_set = ts
	back.tile_set = ts
	back.collision_enabled = false
	for y in terrain.height:
		for x in terrain.width:
			var cell := Vector2i(x, y)
			var k := terrain.kind(cell)
			var at := Vector2i(-1, -1)
			match k:
				Terrain.Kind.ROCK:
					if terrain.is_deep(cell, 1):
						ground.set_cell(cell, DEEP_SOURCE, _cliff(cell))
						continue
					else:
						at = Vector2i(terrain.open_mask(cell), _variant(cell, 2))
				Terrain.Kind.SLOPE_R:
					at = Vector2i(_variant(cell, 2), 2)
				Terrain.Kind.SLOPE_L:
					at = Vector2i(2 + _variant(cell, 2), 2)
				Terrain.Kind.FACE:
					at = Vector2i(4 + _variant(cell, 4), 2)
				Terrain.Kind.LOOSE:
					at = Vector2i(8 + _variant(cell, 4), 2)
				Terrain.Kind.SCRAMBLE:
					at = Vector2i(12 + _variant(cell, 4), 2)
			if at.x >= 0:
				ground.set_cell(cell, SOURCE, at)
			var open := not terrain.is_solid(cell) or k == Terrain.Kind.SLOPE_R or k == Terrain.Kind.SLOPE_L
			if open and terrain.is_inside(cell):
				back.set_cell(cell, CLIFF_SOURCE, _cliff(cell))
