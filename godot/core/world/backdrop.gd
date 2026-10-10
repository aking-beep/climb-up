class_name Backdrop
extends Node2D
## One painted layer at a distance. Lives in a CanvasLayer and places itself
## from the camera each frame: `factor` is how much of the camera's motion
## it follows (0 = at infinity, 1 = with the world, > 1 = closer than the
## world). It repeats sideways and can drift (fog).

var texture: Texture2D
var factor := Vector2(0.1, 0.1)
## World point that sits at screen height `screen_y` when the camera is on it.
var anchor := Vector2.ZERO
var screen_y := 200.0
var scale_by := 0.5
var drift := 0.0
var repeat := true
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var cam := get_viewport().get_camera_2d()
	var vp := get_viewport_rect().size
	var center := cam.get_screen_center_position() if cam else anchor
	var zoom := cam.zoom.x if cam else 1.0
	var w := texture.get_width() * scale_by * zoom
	var h := texture.get_height() * scale_by * zoom
	var x := vp.x / 2.0 + (anchor.x - center.x) * factor.x * zoom + _t * drift
	var bottom := screen_y + (anchor.y - center.y) * factor.y * zoom
	if bottom - h > vp.y or bottom < 0.0:
		return
	if repeat:
		var start := fposmod(x, w) - w
		while start < vp.x:
			draw_texture_rect(texture, Rect2(start, bottom - h, w, h), false)
			start += w
	else:
		draw_texture_rect(texture, Rect2(x - w / 2.0, bottom - h, w, h), false)
