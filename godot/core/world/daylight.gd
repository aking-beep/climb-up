extends CanvasModulate
## Open sky or under rock: the world dims as the camera moves in under an
## overhang or into the wall's ledges, and brightens again in the open.
## The change is eased, never a flash.

const OPEN := Color(1.0, 0.985, 0.95)
const UNDER := Color(0.6, 0.57, 0.58)

var terrain: Terrain
var _cover := 0.0


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or terrain == null:
		return
	# How much of the view, sampled on a coarse grid, has rock overhead.
	var center := cam.get_screen_center_position()
	var inside := 0
	var total := 0
	for dy in [-60, -20, 20, 60]:
		for dx in [-160, -80, 0, 80, 160]:
			var cell := Terrain.cell_of(center + Vector2(dx, dy))
			if not terrain.is_solid(cell):
				total += 1
				if terrain.is_inside(cell):
					inside += 1
	var want := float(inside) / float(maxi(1, total))
	_cover = lerpf(_cover, want, clampf(delta * 1.5, 0.0, 1.0))
	color = OPEN.lerp(UNDER, _cover)
