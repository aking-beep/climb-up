extends PointLight2D
## A fire's light: never quite steady.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	energy = 0.85 + 0.12 * sin(_t * 9.0) * sin(_t * 3.7 + 1.0)
