extends Node
## Renders the level (or another scene) and saves screenshots. Not a test:
## a tool for reviewing the look without the editor.
##   godot --path godot res://tests/shot.tscn -- out=/tmp/x at=24,77 at=56,67 ...

var finish_climb := false


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
		elif arg == "finish":
			finish_climb = true
		elif arg == "fresh":
			Expedition.navigate = false
			Expedition.new_expedition(7)
		elif arg.begins_with("sick="):
			var b := arg.substr(5).split(":")
			Expedition.trek()["sick"][b[0]] = {"kind": "ams", "stage": int(b[1])}
		elif arg.begins_with("emerg="):
			Expedition.trek()["emergency"] = {"who": arg.substr(6)}
			Expedition.trek()["sick"][arg.substr(6)] = {"kind": "ams", "stage": 3}
		elif arg == "touch":
			Settings.touch_controls = true
		elif arg.begins_with("crag="):
			# A crag route: crag=leap-of-faith (with scene=res://modes/crag/crag_level.tscn).
			Crag.current = arg.substr(5)
		elif arg.begins_with("park="):
			# The expedition at a climb's gate; "park=barranco-wall:card" shows
			# the card with the climb's choice instead of the pending climb.
			var bits := arg.substr(5).split(":")
			Expedition.navigate = false
			Expedition.session = TestSessions.at(bits[0])
			if bits.size() > 1:
				Expedition.session["pending"] = null
			else:
				Expedition.resume_climb()
			Expedition.last = {}
	var scene: Node = load(path).instantiate()
	add_child(scene)
	if finish_climb:
		await get_tree().create_timer(0.5).timeout
		scene.panel.hide_panel()
		scene.climber.lock(false)
		scene.hazards.flowers = int(scene.hazards.flowers_total * 0.8)
		scene.finish("complete")
		await get_tree().create_timer(2.0).timeout
		get_viewport().get_texture().get_image().save_png(out + "_0.png")
		get_tree().quit(0)
		return
	await get_tree().create_timer(0.5).timeout
	if spots.is_empty():
		await get_tree().create_timer(hold).timeout
		get_viewport().get_texture().get_image().save_png(out + "_0.png")
	for i in spots.size():
		var climber: Node = scene.get("climber")
		if climber:
			scene.panel.hide_panel()
			scene.briefed = true
			scene.mate_cooldown = true
			climber.lock(false)
			climber.global_position = Terrain.feet(Vector2i(spots[i]))
			if scene is CragLevel:
				# On the rock, with the bolts below clipped.
				climber.hang_at(Terrain.feet(Vector2i(spots[i])))
				for c in scene.clips:
					if c["cell"].y > spots[i].y:
						c["clipped"] = true
						c["node"].texture.region = Rect2(8, 0, 8, 14)
			scene.camera.snap()
		await get_tree().create_timer(hold).timeout
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, i])
	get_tree().quit(0)
