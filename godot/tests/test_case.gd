class_name TestCase
extends RefCounted
## Base for test suites. Methods named test_* run in order; a test may
## `await` (physics frames, timers). `tree` and `root` are set by the runner.

var tree: SceneTree
var root: Node
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %.3f ± %.3f, got %.3f" % [message, expected, tolerance, actual])


func physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
