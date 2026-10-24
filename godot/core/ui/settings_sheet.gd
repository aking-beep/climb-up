class_name SettingsSheet
extends RefCounted
## The settings as a journal sheet over any screen (the hub, the profile):
## the same choices as the pause menu's settings page (SettingsMenu), each
## a button that steps to the next value. Touch-control changes take
## effect in the next climb (the hub has no thumbsticks).


static func open_on(host: Control) -> SettingsSheet:
	var s := SettingsSheet.new()
	s._open(host)
	return s


var sheet: JournalSheet
var _host: Control


func _open(host: Control) -> void:
	_host = host
	sheet = JournalSheet.open(host, "Settings", 280.0)
	sheet.name = "SettingsSheet"
	_fill()


func _fill() -> void:
	for c in sheet.body.get_children():
		c.queue_free()
	for choice in SettingsMenu.choices():
		var b := UiKit.button(String(choice[1]), _apply.bind(String(choice[0])), "paper", UiTokens.TEXT)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.name = String(choice[0])
		sheet.add(b)
	sheet.text("Privacy: the usage log stays on this phone. Nothing is sent unless you choose to share it.", UiTokens.TEXT_S, UiTokens.INK_MUTED)


func _apply(id: String) -> void:
	# The pause menu's rules, applied to a stand-in level: the hub has no
	# touch controls or fog to update.
	var stand_in := Node.new()
	SettingsMenu.apply(id, stand_in)
	stand_in.free()
	_fill.call_deferred()
