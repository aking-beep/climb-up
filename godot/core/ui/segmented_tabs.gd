class_name SegmentedTabs
extends HBoxContainer
## A row of tabs, one selected: the selected one is spruce, the others
## paper. Emits `changed` with the index.

signal changed(index: int)

var selected := 0
var _buttons: Array[Button] = []


static func make(labels: Array, start: int = 0) -> SegmentedTabs:
	var t := SegmentedTabs.new()
	t.add_theme_constant_override("separation", 2)
	for i in labels.size():
		var b := UiKit.button(String(labels[i]), t.select.bind(i), "paper", UiTokens.TEXT)
		b.custom_minimum_size = Vector2(0, UiTokens.TAP)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t._buttons.append(b)
		t.add_child(b)
	t.selected = start
	t._paint()
	return t


func select(i: int) -> void:
	if i == selected:
		return
	selected = i
	_paint()
	changed.emit(i)


func button_at(i: int) -> Button:
	return _buttons[i]


func _paint() -> void:
	for i in _buttons.size():
		UiKit.style_button(_buttons[i], "primary" if i == selected else "paper")
