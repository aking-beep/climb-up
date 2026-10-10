extends Node
## Loads a scene, runs it for a few seconds, and quits. For catching script
## errors headless:  godot --headless --path godot res://tests/smoke.tscn -- scene=<path>

func _ready() -> void:
	var path := "res://modes/expedition/levels/kilimanjaro/barranco/barranco.tscn"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("scene="):
			path = arg.substr(6)
	var scene: Node = load(path).instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	print("SMOKE OK ", path)
	get_tree().quit(0)
