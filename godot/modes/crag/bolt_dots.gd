class_name BoltDots
extends Node2D
## Under each quickdraw at the crag: one dot per tap the bolt takes to clip.
## Hollow until tapped, filling as you tap, green once clipped.

var clip: Dictionary = {}
var level: Node


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if clip.is_empty():
		return
	var n: int = clip.get("taps", 1)
	var done := 0
	var lvl := get_parent()
	if clip["clipped"]:
		done = n
	elif lvl and lvl.get("clip_target") >= 0 and lvl.clips[lvl.clip_target] == clip:
		done = lvl.clip_taps
	for i in n:
		var at := Vector2((i - (n - 1) / 2.0) * 5.0, 1)
		draw_circle(at, 2.4, Color(0, 0, 0, 0.7))
		var col := Color("#8fd16b") if clip["clipped"] else (Color("#7fb8e8") if i < done else Color(1, 1, 1, 0.75))
		draw_circle(at, 1.7, col)
