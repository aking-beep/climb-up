class_name JournalSheet
extends Control
## A page of the field journal over the current screen: a dim scrim and a
## paper card with a title, a close button and a scrolling body. Used for
## settings, records, dialogue, the tent and the briefing. Back (or a tap
## on the scrim) closes it.

signal closed

var body: VBoxContainer
var card: PanelContainer
var heading: Label
var _scroll: ScrollContainer


## A sheet `width` wide, added to `host` (a full-screen Control).
static func open(host: Node, title: String, width: float = 300.0) -> JournalSheet:
	var s := JournalSheet.new()
	s._build(title, width)
	host.add_child(s)
	return s


func _build(title: String, width: float) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = UiTokens.SCRIM_SOFT
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(scrim)
	card = UiKit.panel(UiTokens.PAPER, 10.0)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size = Vector2(width, 0)
	add_child(card)
	var col := UiKit.vbox(4)
	card.add_child(col)
	var top := UiKit.hbox(6)
	col.add_child(top)
	heading = UiKit.label(title, UiTokens.TITLE, UiTokens.INK, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var x := UiKit.button("Close", close, "ghost", UiTokens.TEXT)
	x.name = "Close"
	top.add_child(x)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	col.add_child(_scroll)
	body = UiKit.vbox(4)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	body.minimum_size_changed.connect(func() -> void: _fit.call_deferred())
	_fit.call_deferred()
	if Settings.back_requested.is_connected(_on_back) == false:
		Settings.back_requested.connect(_on_back)
	if not Settings.reduced_motion:
		card.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(card, "modulate:a", 1.0, UiTokens.MEDIUM)


func _fit() -> void:
	if not is_inside_tree():
		return
	var want := body.get_combined_minimum_size()
	var room := get_viewport_rect().size.y - 2.0 * UiTokens.EDGE - 46.0
	_scroll.custom_minimum_size = Vector2(want.x, minf(want.y, room))


func _on_back() -> void:
	# Only the top sheet closes.
	var parent := get_parent()
	if parent and parent.get_child(parent.get_child_count() - 1) == self:
		close()


func add(c: Control) -> Control:
	body.add_child(c)
	return c


func text(value: String, size: int = UiTokens.TEXT, color: Color = UiTokens.INK_SOFT) -> Label:
	return add(UiKit.label(value, size, color, false, card.custom_minimum_size.x - 24.0)) as Label


func is_open() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func close() -> void:
	if is_queued_for_deletion():
		return
	if Settings.back_requested.is_connected(_on_back):
		Settings.back_requested.disconnect(_on_back)
	closed.emit()
	queue_free()
