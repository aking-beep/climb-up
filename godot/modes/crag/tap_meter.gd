class_name TapMeter
extends Node2D
## Over the climber's head at the crag: the grip meter on tiny holds, and
## pips for the taps a clip or a stuck dyno needs.

var level: Node


func _process(_delta: float) -> void:
	if level == null or level.climber == null:
		return
	global_position = level.climber.global_position - Vector2(0, Climber.SIZE.y + 8)
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	if level.catching > 0.0:
		_pips(level.catch_taps, level.CATCH_TAPS, Color("#f2c14e"))
	elif level.clip_target >= 0:
		_pips(level.clip_taps, level.clip_needed, Color("#7fb8e8"))
	elif level.on_crimps:
		var w := 20.0
		draw_rect(Rect2(-w / 2.0 - 1, -1, w + 2, 5), Color(0, 0, 0, 0.6))
		var g: float = level.grip
		var col := Color("#c0573e") if g < 0.3 else (Color("#d9a441") if g < 0.6 else Color("#e8e2d0"))
		draw_rect(Rect2(-w / 2.0, 0, w * g, 3), col)


	# The green rest bar: always there once clipped, refilled at every clip.
	if level.checkpoint > 0 and level.climber.is_climbing():
		var w := 20.0
		var left: float = clampf(level.rope_left / level.ROPE_REST, 0.0, 1.0)
		var y := -7.0
		draw_rect(Rect2(-w / 2.0 - 1, y - 1, w + 2, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2.0, y, w * left, 3), Color("#8fd16b") if level.resting_rope else Color("#5f9a4a"))


func _pips(done: int, total: int, col: Color) -> void:
	for i in total:
		var at := Vector2((i - (total - 1) / 2.0) * 7.0, 1.5)
		draw_circle(at, 3.0, Color(0, 0, 0, 0.6))
		draw_circle(at, 2.2, col if i < done else Color(1, 1, 1, 0.25))
