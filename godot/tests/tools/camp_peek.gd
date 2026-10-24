extends Node
## Opens the camp world past its first tip, for a screenshot (not a test).
func _ready() -> void:
	Profile.see("camp_world")
	Expedition.navigate = false
	Expedition.new_expedition(7)
	var c: Node = load("res://modes/expedition/camp/camp_world.tscn").instantiate()
	add_child(c)
	await get_tree().create_timer(0.3).timeout
	if "talk" in OS.get_cmdline_user_args():
		c.walk_to(236, "lena")
