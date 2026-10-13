class_name Transition
extends RefCounted
## Scene changes as a short fade through the night colour of the mountain,
## so going from camp to the rock (or a menu to a route) reads as a cut in
## a film rather than a jump. Instant with reduced motion.

const OUT := 0.16
const IN := 0.28
const COLOR := Color("#0b0b0e")


static func go(tree: SceneTree, path: String) -> void:
	if Settings.reduced_motion:
		tree.call_deferred("change_scene_to_file", path)
		return
	# On the root, not the scene, so it lives through the change.
	var layer := CanvasLayer.new()
	layer.layer = 100
	var veil := ColorRect.new()
	veil.color = Color(COLOR, 0.0)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(veil)
	tree.root.add_child(layer)
	var tw := layer.create_tween()
	tw.tween_property(veil, "color:a", 1.0, OUT)
	tw.tween_callback(func() -> void: tree.change_scene_to_file(path))
	tw.tween_interval(0.05)
	tw.tween_property(veil, "color:a", 0.0, IN)
	tw.tween_callback(layer.queue_free)
