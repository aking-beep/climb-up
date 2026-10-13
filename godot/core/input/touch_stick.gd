extends Node2D
## Draws the floating stick for TouchControls: a faint hint where the left
## thumb goes when idle, the base and knob while a thumb is down.

var controls: Node


func _draw() -> void:
	if controls == null:
		return
	var s: Dictionary = controls.stick_state()
	var r: float = controls.radius()
	if not s["active"]:
		var vp := get_viewport_rect().size
		var inset: Dictionary = controls.safe
		var hint := Vector2(56 + inset["left"], vp.y - 54 - inset["bottom"])
		if Settings.left_handed:
			hint.x = vp.x - 56 - inset["right"]
		draw_circle(hint, r, Color(0.07, 0.066, 0.06, 0.22))
		draw_arc(hint, r, 0, TAU, 40, Color(0.95, 0.94, 0.91, 0.35), 1.0)
		draw_circle(hint, r * 0.42, Color(0.95, 0.94, 0.91, 0.28))
		return
	var o: Vector2 = s["origin"]
	var at: Vector2 = s["at"]
	var knob := o + (at - o).limit_length(r)
	draw_circle(o, r, Color(0.07, 0.066, 0.06, 0.35))
	draw_arc(o, r, 0, TAU, 40, Color(0.95, 0.94, 0.91, 0.6), 1.0)
	draw_circle(knob, r * 0.45, Color(0.95, 0.94, 0.91, 0.6))
