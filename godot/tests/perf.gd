extends Node
## Not a test: how much CPU each climb's simulation and scene take per frame
## on this machine, with a climber walking and climbing, every hazard live.
## Rendering is not measured (headless); real frame rate needs a phone.
##   godot --headless --path godot res://tests/perf.tscn


func _ready() -> void:
	Expedition.navigate = false
	Crag.navigate = false
	var rows: Array = []
	for id in ["lava-tower", "barranco-wall", "summit-night"]:
		Expedition.new_expedition(7)
		Expedition.session = TestSessions.at(id)
		Expedition.climb = {}
		Expedition.resume_climb()
		rows.append(await _measure(id, load(Expedition.LEVELS[id]).instantiate()))
	for id in ["warm-up", "thunderhead"]:
		Crag.current = id
		rows.append(await _measure("crag " + id, load(Crag.LEVEL).instantiate()))
	for r in rows:
		print("PERF %-20s CPU per frame avg %.2f ms · p95 %.2f ms · max %.2f ms · nodes %d" % r)
	SaveGame.erase()
	get_tree().quit(0)


func _measure(name: String, level: Node) -> Array:
	add_child(level)
	await get_tree().physics_frame
	level.panel.choose("start" if not (level is CragLevel) or name.ends_with("lesson") else "neutral")
	if level.panel.open:
		level.panel.choose("start")
	# Headless with --fixed-fps runs frames back to back: wall time per frame
	# is the CPU the whole frame (simulation, scene, scripts) costs.
	var frames: Array = []
	for i in 600:
		GameInput.scripted = {"move_right": i % 120 < 90, "climb_up": true, "jump": i % 50 == 0}
		var t := Time.get_ticks_usec()
		await get_tree().physics_frame
		frames.append((Time.get_ticks_usec() - t) / 1000.0)
	GameInput.scripted = {}
	frames.sort()
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	level.queue_free()
	await get_tree().physics_frame
	var avg := func(a: Array) -> float: return a.reduce(func(x, y): return x + y, 0.0) / a.size()
	return [name, avg.call(frames), frames[int(frames.size() * 0.95)], frames.max(), nodes]
