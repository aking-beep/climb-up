extends TestCase
## Polish checks a player would notice first: menus that fit a phone
## without hiding choices behind a scrollbar, and tips that do not cover
## what they are about.

var screen: SubViewport


func _show(path: String) -> Node:
	screen = SubViewport.new()
	screen.size = Vector2i(480, 270)
	root.add_child(screen)
	var s: Node = load(path).instantiate()
	screen.add_child(s)
	for i in 6:
		await tree.process_frame
	return s


func test_menus_show_everything_without_scrolling_when_it_fits() -> void:
	SaveGame.erase()
	Crag.navigate = false
	Expedition.navigate = false
	for path in ["res://modes/title/title.tscn", "res://modes/expedition/menu.tscn", "res://modes/crag/crag_menu.tscn"]:
		if not ResourceLoader.exists(path):
			continue
		var s: Node = await _show(path)
		var want: float = s.card.get_combined_minimum_size().y
		var room := 270.0 - 2.0 * Screen.EDGE - 22.0
		var shown: float = s.scroll.size.y
		if want <= room:
			check(shown >= want - 1.0, "%s: the whole card shows (%.0f of %.0f px)" % [path.get_file(), shown, want])
		else:
			check(shown >= room - 1.0, "%s: as tall as the screen allows (%.0f px)" % [path.get_file(), shown])
		screen.queue_free()
		await tree.process_frame


func test_a_tip_can_sit_at_the_top_out_of_the_way() -> void:
	screen = SubViewport.new()
	screen.size = Vector2i(480, 270)
	root.add_child(screen)
	var p := StoryPanel.new()
	screen.add_child(p)
	await tree.process_frame
	p.at_top = true
	p.show_panel("Tip", "Clip in", "Tap CLIP to clip your rope to this bolt.", [["ok", "Got it"]])
	for i in 3:
		await tree.process_frame
	var r: Rect2 = p._box.get_global_rect()
	check(r.position.y < 20.0 and r.end.y < 160.0, "the tip is up top, clear of the climber and the buttons (%s)" % r)
	p.choose("ok")
	check(not p.at_top, "and the next panel is back at the bottom")
	p.show_panel("Paused", "", "x", [["ok", "Back"]])
	for i in 3:
		await tree.process_frame
	check(p._box.get_global_rect().end.y > 240.0, "the pause menu sits at the bottom as before")
	screen.queue_free()
	await tree.process_frame
