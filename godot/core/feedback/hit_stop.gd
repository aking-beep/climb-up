class_name HitStop
extends RefCounted
## A hit-stop: the world holds still for a few frames on an impact (a fall
## caught by the rope, a perfect dyno catch), so the hit lands before the
## camera kicks. Time is frozen with Engine.time_scale and always given
## back, by a timer that ignores the freeze. Nested calls extend it.
## The freeze touches no rule: clocks simply do not run for those frames.

## About three frames at 60 fps.
const SHORT := 0.05

## The last freeze asked for (seconds), for tests.
static var last := 0.0
## Freezes still running (each gives time back when its timer ends; the
## last one out restores it).
static var _pending := 0


static func freeze(node: Node, seconds: float = SHORT) -> void:
	if node == null or not node.is_inside_tree():
		return
	last = seconds
	var tree := node.get_tree()
	_pending += 1
	Engine.time_scale = 0.0
	# process_always, process_in_physics = false, ignore_time_scale = true
	tree.create_timer(seconds, true, false, true).timeout.connect(_release)


static func _release() -> void:
	_pending = maxi(0, _pending - 1)
	if _pending == 0:
		Engine.time_scale = 1.0


## Gives time back now (a scene that leaves mid-freeze).
static func release() -> void:
	_pending = 0
	Engine.time_scale = 1.0
