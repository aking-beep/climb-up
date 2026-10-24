extends Node
## Headless test runner. Runs every res://tests/test_*.gd suite and quits
## with exit code 0 on success, 1 on any failure:
##
##     godot --headless --path godot res://tests/runner.tscn
##
## Pass `-- only=<name>` to run suites whose file name contains <name>, and
## `test=<name>` to run only the tests whose name contains <name>.
##
## A script error during a test (a bad call, a null, a type error) fails
## that test, even when the test's own checks passed.


class ErrorWatch extends Logger:
	var errors: Array = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			_lock.lock()
			errors.append("script error: %s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
			_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array:
		_lock.lock()
		var out := errors.duplicate()
		errors.clear()
		_lock.unlock()
		return out


func _ready() -> void:
	await get_tree().process_frame
	Expedition.navigate = false
	# A fresh climber for every run: no gear or look from this device's own
	# play changes what the tests see.
	Profile.reset()
	var only := ""
	var pick := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
		elif arg.begins_with("test="):
			pick = arg.substr(5)
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd" and (only == "" or only in f):
			files.append(f)
	files.sort()
	var watch := ErrorWatch.new()
	OS.add_logger(watch)
	var passed := 0
	var failed := 0
	for f in files:
		var script: Script = load("res://tests/" + f)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_") or (pick != "" and not pick in name):
				continue
			var suite: TestCase = script.new()
			suite.tree = get_tree()
			suite.root = self
			var started := Time.get_ticks_msec()
			watch.take()
			await suite.call(name)
			for e in watch.take():
				suite.failures.append(e)
			var ms := Time.get_ticks_msec() - started
			if suite.failures.is_empty():
				passed += 1
				print("  ok    %s › %s (%d ms)" % [f.trim_suffix(".gd"), name, ms])
			else:
				failed += 1
				print("  FAIL  %s › %s" % [f.trim_suffix(".gd"), name])
				for failure in suite.failures:
					print("          " + failure)
			for child in get_children():
				child.queue_free()
			await get_tree().process_frame
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
