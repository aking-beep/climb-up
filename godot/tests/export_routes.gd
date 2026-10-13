extends Node
## Writes the crag routes as the records server checks them, from the
## game's own maps and daily generator, so the two can never disagree:
##   godot --headless --path godot res://tests/export_routes.tscn -- out=ABS_PATH from=YYYY-MM-DD days=N
## (see docs/records-backend.md).
## Per route: rows from the foot to the anchor, the bolts' rows, falls
## allowed, and the map hash the client sends (FNV-1a of the map text).


func _ready() -> void:
	var out := "server/records_service/data/routes.json"
	var from := ""
	var days := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("from="):
			from = a.substr(5)
		elif a.begins_with("days="):
			days = int(a.substr(5))
	var routes := {}
	for r in Crag.ROUTES:
		var text := FileAccess.get_file_as_string("res://modes/crag/routes/%s.txt" % r["id"])
		routes[r["id"]] = _shape(text, int(r.get("falls", 5)), r["grade"])
	var daily := {}
	if from != "":
		var t0 := Time.get_unix_time_from_datetime_string(from + "T00:00:00")
		for i in days:
			var date := Daily.date_key(int(t0) + i * 86400)
			var d: Dictionary = Daily.route_for(date)
			daily[date] = _shape(d["map"], int(d.get("falls", 5)), d["grade"])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"routes": routes, "daily": daily, "rowMetres": 0.5}, "  "))
	f.close()
	print("wrote ", out, " (", routes.size(), " routes, ", daily.size(), " daily)")
	get_tree().quit(0)


func _shape(text: String, falls: int, grade: String) -> Dictionary:
	var lines := text.split("\n")
	var foot := -1
	var top := -1
	var bolts: Array = []
	for y in lines.size():
		var line: String = lines[y]
		if "P" in line:
			foot = y
		if "X" in line:
			top = y
	for y in lines.size():
		if "Q" in lines[y]:
			for k in lines[y].count("Q"):
				bolts.append(foot - y)
	bolts.sort()
	return {"rows": foot - top, "bolts": bolts, "maxFalls": falls, "grade": grade, "mapHash": Daily.fnv1a(text)}
