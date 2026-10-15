extends Screen
## The online account: sign up (age first), restore with a recovery code,
## and once signed in the friend code, adding friends, sending what waits,
## signing out and deleting the account. Reached from the records screen's
## Friends and Global tabs. Only in a build that names a service
## (Online.available()); every record stays on the device either way.

const SCREEN := "res://modes/records/account_screen.tscn"
## Shown under the sign-up form; the full policy is at Online.privacy_url().
const PRIVACY_SUMMARY := "What the service keeps: a random player id, your age group (not your age), the name you choose (optional), your friends, and each finished climb with its moves. No email, no location, no contacts, no ads. Delete it all here at any time."

var _status: Label
var _busy := false
var _delete_armed := false
## The age, name, code and friend fields (for tests).
var age_field: LineEdit
var name_field: LineEdit
var code_field: LineEdit
var friend_field: LineEdit
var consent: CheckBox


func _ready() -> void:
	super._ready()
	kicker("Records · online account")
	var o := Records.online
	if not o.available():
		title("Not connected", 14)
		text("This build has no CLIMB UP online service. Your records stay on this device.", 8, MUTED)
	elif o.signed_in():
		_signed_in()
	elif o.under_age:
		title("Records on this device", 14)
		text("Online records are for players %d and over. Everything you climb is still kept on this device." % Online.MIN_ACCOUNT_AGE, 8, MUTED)
	else:
		_sign_up()
	_status = text("", 8, Color("#8a3b2a"))
	_status.name = "Status"
	var back := button("Back", on_back)
	back.grab_focus()


func _sign_up() -> void:
	title("Online records", 14)
	text("Make a free account to put your climbs on the Global and Friends boards, checked by the server. No email or password.", 8)
	age_field = _field("How old are you?", "Age", LineEdit.KEYBOARD_TYPE_NUMBER)
	name_field = _field("A public name (optional, 3 to 16 letters or numbers; you can play without one)", "Name", LineEdit.KEYBOARD_TYPE_DEFAULT)
	text(PRIVACY_SUMMARY, 7, MUTED)
	if Online.privacy_url() != "":
		button("Read the privacy policy", func() -> void: OS.shell_open(Online.privacy_url()))
	consent = CheckBox.new()
	consent.name = "Consent"
	consent.text = "I agree to the privacy policy"
	consent.add_theme_font_size_override("font_size", 8)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		consent.add_theme_color_override(key, INK)
	if UiFont.body():
		consent.add_theme_font_override("font", UiFont.body())
	card.add_child(consent)
	var make := button("Create my account", _create, true)
	make.name = "Create"
	text("Already have an account? Paste its recovery code:", 7, MUTED)
	code_field = _field("", "Recovery code", LineEdit.KEYBOARD_TYPE_DEFAULT)
	var restore := button("Restore my account", _restore)
	restore.name = "Restore"


func _signed_in() -> void:
	var o := Records.online
	title(o.display_name if o.display_name != "" else "Signed in", 14)
	var vis := {"public": "Your records show on the Global boards.", "friends": "Your records show to your friends only.",
		"private": "Your records are private to you."}
	text(vis.get(o.visibility, ""), 8)
	text("Your friend code: %s" % o.friend_code, 9, INK).name = "FriendCode"
	friend_field = _field("Add a friend by their code", "Friend code", LineEdit.KEYBOARD_TYPE_DEFAULT)
	button("Add friend", _add_friend).name = "AddFriend"
	var waiting := Records.pending().size()
	text("%d finished go%s waiting to be sent." % [waiting, "" if waiting == 1 else "es"] if waiting > 0 else "Everything is sent.", 8, MUTED)
	if waiting > 0:
		button("Send now", _send).name = "Send"
	text("Your recovery code restores this account on another device. Keep it private: anyone with it can use your account.", 7, MUTED)
	button("Copy my recovery code", func() -> void:
		DisplayServer.clipboard_set(o.token)
		_say("Copied. Keep it somewhere safe.")).name = "CopyCode"
	button("Sign out on this device", func() -> void:
		o.forget()
		_reload()).name = "SignOut"
	button("Delete my online account", _delete).name = "Delete"


func _field(label: String, hint: String, kind: int) -> LineEdit:
	if label != "":
		text(label, 8)
	var f := LineEdit.new()
	f.name = hint.replace(" ", "")
	f.placeholder_text = hint
	f.virtual_keyboard_type = kind
	f.custom_minimum_size = Vector2(0, 20)
	f.add_theme_font_size_override("font_size", 9)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.9)
	box.border_color = Color(0.8, 0.76, 0.68)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 6
	f.add_theme_stylebox_override("normal", box)
	var on := box.duplicate()
	on.border_color = Color("#1f3d34")
	f.add_theme_stylebox_override("focus", on)
	f.add_theme_color_override("font_color", INK)
	f.add_theme_color_override("font_placeholder_color", MUTED)
	if UiFont.body():
		f.add_theme_font_override("font", UiFont.body())
	card.add_child(f)
	return f


func _say(msg: String) -> void:
	if is_instance_valid(_status):
		_status.text = msg


func _create() -> void:
	if _busy:
		return
	var age := age_field.text.strip_edges()
	if not age.is_valid_int() or int(age) < 4 or int(age) > 120:
		_say("Enter your age in years.")
		return
	if not consent.button_pressed:
		_say("Please read and agree to the privacy policy first.")
		return
	if int(age) >= Online.MIN_ACCOUNT_AGE and name_field.text.strip_edges() != "":
		var problem := Online.name_problem(name_field.text)
		if problem != "":
			_say(problem)
			return
	_busy = true
	_say("Creating your account...")
	var why := await Records.online.register("", int(age), name_field.text if int(age) >= Online.MIN_ACCOUNT_AGE else "")
	_busy = false
	if not is_inside_tree():
		return
	if why != "" and not Records.online.under_age:
		_say(why)
		return
	Records.sync_soon()
	_reload()


func _restore() -> void:
	if _busy or code_field.text.strip_edges() == "":
		return
	_busy = true
	_say("Checking the code...")
	var why := await Records.online.restore("", code_field.text)
	_busy = false
	if not is_inside_tree():
		return
	if why != "":
		_say(why)
		return
	Records.sync_soon()
	_reload()


func _add_friend() -> void:
	if _busy or friend_field.text.strip_edges() == "":
		return
	_busy = true
	var why := await Records.online.add_friend(friend_field.text)
	_busy = false
	_say(why if why != "" else "Friend added. Their climbs show on your Friends boards.")


func _send() -> void:
	if _busy:
		return
	_busy = true
	_say("Sending...")
	var n := await Records.sync()
	_busy = false
	if not is_inside_tree():
		return
	var left := Records.pending().size()
	_say("Sent %d. %s" % [n, "All done." if left == 0 else "%d still waiting: no connection right now, they will go later." % left])


func _delete() -> void:
	if _busy:
		return
	if not _delete_armed:
		_delete_armed = true
		var b := card.get_node_or_null("Delete") as Button
		if b:
			b.text = "Tap again: delete my account and online records"
		return
	_busy = true
	_say("Deleting...")
	var why := await Records.online.delete_account()
	_busy = false
	if not is_inside_tree():
		return
	if why != "":
		_say(why)
		return
	_reload()


func _reload() -> void:
	get_tree().reload_current_scene()


func on_back() -> void:
	if Crag.navigate:
		Transition.go(get_tree(), Records.SCREEN)
