class_name Meter
extends Control
## A bar with a word: stamina, a party member's condition, an effect of a
## piece of gear. `value` in 0..1. The colour follows the level (good,
## warning, bad) and the word says the same, so it never rests on colour.

var value := 1.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var color := Color(0, 0, 0, 0)
var track := Color(0, 0, 0, 0.12)


static func make(v: float, width: float = 60.0, height: float = 5.0) -> Meter:
	var m := Meter.new()
	m.custom_minimum_size = Vector2(width, height)
	m.value = v
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


static func tone(v: float) -> Color:
	if v >= 0.6:
		return Color("#7fa36b")
	if v >= 0.3:
		return Color("#d9a441")
	return Color("#c0573e")


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, track)
	var c := color if color.a > 0.0 else tone(value)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value, size.y)), c)
	draw_rect(r, Color(0, 0, 0, 0.25), false, 1.0)
