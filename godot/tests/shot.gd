extends Node
## Renders the level (or another scene) and saves screenshots. Not a test:
## a tool for reviewing the look without the editor.
##   godot --path godot res://tests/shot.tscn -- out=/tmp/x at=24,77 at=56,67 ...

func _ready() -> void:
	var out := "/tmp/shot"
	var spots: Array[Vector2] = []
	var path := "res://modes/expedition/levels/kilimanjaro/barranco/barranco.tscn"
	var hold := 1.5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
		elif arg.begins_with("at="):
			var p := arg.substr(3).split(",")
			spots.append(Vector2(float(p[0]), float(p[1])))
		elif arg.begins_with("scene="):
			path = arg.substr(6)
		elif arg.begins_with("hold="):
			hold = float(arg.substr(5))
	var scene: Node = load(path).instantiate()
	add_child(scene)
	await get_tree().create_timer(0.5).timeout
	if spots.is_empty():
		await get_tree().create_timer(hold).timeout
		get_viewport().get_texture().get_image().save_png(out + "_0.png")
	for i in spots.size():
		var climber: Node = scene.get("climber")
		if climber:
			scene.panel.hide_panel()
			scene.mate_cooldown = true
			climber.lock(false)
			climber.global_position = Terrain.feet(Vector2i(spots[i]))
			scene.camera.snap()
		await get_tree().create_timer(hold).timeout
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, i])
	get_tree().quit(0)
