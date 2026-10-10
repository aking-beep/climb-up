extends CanvasModulate
## Open sky or under rock: the world dims as the camera moves in under an
## overhang or into the wall's ledges, and brightens again in the open.
## At night the world is dark blue and pales toward dawn the higher the
## climber gets. The change is eased, never a flash.

const OPEN := Color(1.0, 0.985, 0.95)
const UNDER := Color(0.62, 0.59, 0.6)
const NIGHT := Color(0.5, 0.55, 0.74)
const DAWN := Color(0.86, 0.8, 0.8)
const NIGHT_UNDER := Color(0.4, 0.44, 0.62)

var terrain: Terrain
var night := false
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
	if night:
		var dawn := 1.0 - clampf(center.y / terrain.pixel_size().y, 0.0, 1.0)
		var open := NIGHT.lerp(DAWN, dawn * dawn)
		color = open.lerp(NIGHT_UNDER, _cover * 0.5)
	else:
		color = OPEN.lerp(UNDER, _cover)
