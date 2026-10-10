extends Node
## Headless test runner. Runs every res://tests/test_*.gd suite and quits
## with exit code 0 on success, 1 on any failure:
##
##     godot --headless --path godot res://tests/runner.tscn
##
## Pass `-- only=<name>` to run suites whose file name contains <name>.

func _ready() -> void:
	await get_tree().process_frame
	Expedition.navigate = false
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd" and (only == "" or only in f):
			files.append(f)
	files.sort()
	var passed := 0
	var failed := 0
	for f in files:
		var script: Script = load("res://tests/" + f)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var suite: TestCase = script.new()
			suite.tree = get_tree()
			suite.root = self
			var started := Time.get_ticks_msec()
			await suite.call(name)
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
