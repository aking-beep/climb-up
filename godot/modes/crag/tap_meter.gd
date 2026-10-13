class_name TapMeter
extends Node2D
## Over the climber's head at the crag: the grip meter on tiny holds (warm)
## and slopers (cool), and the catch ring for a dyno: a ring round the
## hands that closes on the hold as they rise to it; tap as it closes.

var level: Node


func _process(_delta: float) -> void:
	if level == null or level.climber == null:
		return
	global_position = level.climber.global_position - Vector2(0, Climber.SIZE.y + 8)
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	if level._dyno_air or level.catching > 0.0:
		_catch_ring()
	elif level.on_crimps or level.on_slopers:
		var w := 20.0
		draw_rect(Rect2(-w / 2.0 - 1, -1, w + 2, 5), Color(0, 0, 0, 0.6))
		var g: float = level.grip
		var col := Color("#c0573e") if g < 0.3 else (Color("#d9a441") if g < 0.6 else Color("#e8e2d0"))
		if level.on_slopers and g >= 0.3:
			col = Color("#9fc4e0")
		draw_rect(Rect2(-w / 2.0, 0, w * g, 3), col)


	# The green rest bar: always there once clipped, refilled at every clip.
	if level.checkpoint > 0 and level.climber.is_climbing():
		var w := 20.0
		var left: float = clampf(level.rope_left / level.ROPE_REST, 0.0, 1.0)
		var y := -7.0
		draw_rect(Rect2(-w / 2.0 - 1, y - 1, w + 2, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2.0, y, w * left, 3), Color("#8fd16b") if level.resting_rope else Color("#5f9a4a"))


## The catch ring, at the hands: a fixed gold ring is the hold; the white
## ring shrinks onto it as the hands rise to the hold's height. When they
## meet (or the hands are on the hold), tap.
func _catch_ring() -> void:
	var hands := Vector2(0, Climber.SIZE.y * 0.15 + 8)
	var target := 5.0
	var r := target
	if level._dyno_air and level.dyno_target_y < INF:
		var gap: float = level.climber.body_rect().position.y - level.dyno_target_y
		r = target + clampf(gap, 0.0, 48.0) * 0.5
	var now: bool = level.catching > 0.0 or r <= target + 3.0
	draw_arc(hands, target, 0, TAU, 24, Color("#f2c14e"), 2.0, true)
	draw_arc(hands, r, 0, TAU, 32, Color(1, 1, 1, 0.95) if now else Color(1, 1, 1, 0.6), 1.5, true)
	if now:
		draw_circle(hands, target - 1.5, Color(0.95, 0.76, 0.3, 0.6))


func _pips(done: int, total: int, col: Color) -> void:
	for i in total:
		var at := Vector2((i - (total - 1) / 2.0) * 7.0, 1.5)
		draw_circle(at, 3.0, Color(0, 0, 0, 0.6))
		draw_circle(at, 2.2, col if i < done else Color(1, 1, 1, 0.25))
