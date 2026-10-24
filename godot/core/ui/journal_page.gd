class_name JournalPage
extends Control
## A full-screen page of the field journal (CLIMB UP 2.0): paper with faint
## ruled lines, a top bar (back, title, a kicker line), and a body below.
## The profile, the locker, the world map and the school are pages. Back
## (the button or Android's back) returns to `back_to`.

var back_to := "res://modes/hub/hub.tscn"
var body: Control
var top: HBoxContainer
var heading: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Settings.back_requested.connect(_on_back_requested)
	var paper := _Paper.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	var safe: Dictionary = Settings.safe_insets()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(12 + float(safe.get("left", 0.0))))
	margin.add_theme_constant_override("margin_right", int(12 + float(safe.get("right", 0.0))))
	margin.add_theme_constant_override("margin_top", int(8 + float(safe.get("top", 0.0))))
	margin.add_theme_constant_override("margin_bottom", int(8 + float(safe.get("bottom", 0.0))))
	add_child(margin)
	var col := UiKit.vbox(6)
	margin.add_child(col)
	top = UiKit.hbox(8)
	col.add_child(top)
	var back := UiIcon.button("back", "Back", go_back, false)
	top.add_child(back)
	heading = UiKit.label("", UiTokens.TITLE + 2, UiTokens.INK, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(heading)
	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	build()
	Analytics.event("screen_opened", {"screen": name.to_snake_case()})


## Override: fill `body`.
func build() -> void:
	pass


func set_title(t: String) -> void:
	heading.text = t


func _on_back_requested() -> void:
	for c in get_children():
		if c is JournalSheet:
			return
	go_back()


func go_back() -> void:
	if Crag.navigate and is_inside_tree():
		Transition.go(get_tree(), back_to)


## A scrolling column that fills a part of the body.
static func scroller(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.follow_focus = true
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


class _Paper:
	extends Control

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiTokens.PAPER)
		var y := 30.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.42, 0.55, 0.7, 0.08), 1.0)
			y += 14.0
		draw_line(Vector2(34, 0), Vector2(34, size.y), Color(0.75, 0.3, 0.2, 0.1), 1.0)
