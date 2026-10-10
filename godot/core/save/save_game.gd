class_name SaveGame
extends RefCounted
## Versioned JSON saves in user://. Never trusts what it reads: a missing,
## corrupt, unknown-newer or wrong-shaped file loads as "no save", and an
## older version is migrated forward step by step.

const VERSION := 1
const PATH := "user://climb_up_save.json"

## Each entry upgrades data saved at version N to N + 1.
const MIGRATIONS := {}


static func write(data: Dictionary, path: String = PATH) -> bool:
	var wrapped := {"version": VERSION, "game": "climb-up", "data": data}
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(wrapped))
	file.close()
	# Replace in one step, so a crash mid-write never leaves half a save.
	return DirAccess.rename_absolute(tmp, path) == OK


## The saved data, or null. `reason` (if given) receives why not.
static func read(path: String = PATH, reason: Array = []) -> Variant:
	if not FileAccess.file_exists(path):
		reason.append("missing")
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return validate(parsed, reason)


static func validate(parsed: Variant, reason: Array = []) -> Variant:
	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("game") != "climb-up":
		reason.append("corrupt")
		return null
	var version := int(parsed.get("version", 0))
	if version > VERSION:
		reason.append("newer")
		return null
	if version < 1:
		reason.append("corrupt")
		return null
	var data: Variant = parsed.get("data")
	if typeof(data) != TYPE_DICTIONARY:
		reason.append("corrupt")
		return null
	while version < VERSION:
		var step: Callable = MIGRATIONS.get(version)
		data = step.call(data)
		version += 1
	return data


static func erase(path: String = PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
