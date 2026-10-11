class_name TouchControls
extends CanvasLayer
## Two-thumb touch controls for landscape phones.
##
## Left thumb: a floating stick. Touch anywhere on the left of the screen and
## drag; the stick appears under the thumb, so there is no small target to
## find. It is analog: a small push walks slowly, a full push walks at pace;
## up or down climbs.
## Right thumb: JUMP, one context button that says what it will do (CLIMB,
## TALK, READ, HELP), BRACE (hold) and REST. Top right: pause.
## Everything presses the same input actions as keys, so gameplay never
## knows the difference. Shown automatically on touch devices (Settings).

const STICK_RADIUS := 30.0
const DEAD_ZONE := 0.18
## The stick claims touches that start on this fraction of the screen's width.
const STICK_AREA := 0.48

var level: Node
var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_at := Vector2.ZERO
var _stick: Node2D
var _act: TouchScreenButton
var _act_label: Label


static func attach(lvl: Node) -> void:
	var existing := lvl.get_node_or_null("TouchControls")
	if existing:
		existing.queue_free()
	GameInput.touch_move = Vector2.ZERO
	if not Settings.touch_enabled():
		return
	var t := TouchControls.new()
	t.name = "TouchControls"
	t.level = lvl
	lvl.add_child(t)


func _ready() -> void:
	layer = 15
	var vp := get_viewport().get_visible_rect().size
	_stick = Node2D.new()
	_stick.set_script(load("res://core/input/touch_stick.gd"))
	_stick.set("controls", self)
	add_child(_stick)
	var r := Vector2(vp.x - 16, vp.y - 14)
	_button("jump", "JUMP", r + Vector2(-50, -52), 50.0)
	if level and level.get("touch_layout") == "crag":
		# The crag is all tapping: one big button for CLIP and GRIP, by the
		# thumb, and nothing to brace or sit for.
		_act = _button("interact", "CLIMB", r + Vector2(-122, -60), 58.0)
	else:
		_act = _button("interact", "CLIMB", r + Vector2(-46, -104), 42.0)
		_button("brace", "BRACE", r + Vector2(-100, -42), 40.0)
		_button("rest", "REST", r + Vector2(-96, -92), 34.0)
	_act_label = _act.get_child(0)
	_button("pause", "II", Vector2(vp.x - 34, 6), 26.0)
	# Rotating or resizing rebuilds the overlay against the new edges.
	get_viewport().size_changed.connect(func() -> void: TouchControls.attach.call_deferred(level), CONNECT_ONE_SHOT)


func _exit_tree() -> void:
	GameInput.touch_move = Vector2.ZERO


func _button(action: String, word: String, at: Vector2, size: float) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.texture_normal = _disc(size, Color(0.07, 0.066, 0.06, 0.45), Color(0.95, 0.94, 0.91, 0.55))
	b.texture_pressed = _disc(size, Color(0.95, 0.94, 0.91, 0.35), Color(1, 1, 1, 0.9))
	b.action = action
	b.passby_press = false
	b.position = at
	add_child(b)
	var l := Label.new()
	l.text = word
	l.add_theme_font_size_override("font_size", 10 if size > 30 else 9)
	l.add_theme_color_override("font_color", Color(0.98, 0.97, 0.94, 0.95))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 1)
	if UiFont.display():
		l.add_theme_font_override("font", UiFont.display())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(size, size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	return b


## A filled disc with a thin rim, drawn once at the button's size.
static func _disc(size: float, fill: Color, rim: Color) -> ImageTexture:
	var n := int(size)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d < size / 2.0 - 1.5:
				img.set_pixel(x, y, fill)
			elif d < size / 2.0:
				img.set_pixel(x, y, rim)
	return ImageTexture.create_from_image(img)


func _blocked() -> bool:
	var p: Variant = level.get("panel") if level else null
	return p != null and p.open


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var vp := get_viewport().get_visible_rect().size
		if event.pressed and _stick_index < 0 and event.position.x < vp.x * STICK_AREA and event.position.y > 40 and not _blocked():
			_stick_index = event.index
			_stick_origin = event.position
			_stick_at = event.position
			_update()
		elif not event.pressed and event.index == _stick_index:
			_stick_index = -1
			_update()
	elif event is InputEventScreenDrag and event.index == _stick_index:
		_stick_at = event.position
		# The base follows a thumb that runs past the rim, so reversing is instant.
		var off: Vector2 = _stick_at - _stick_origin
		if off.length() > STICK_RADIUS:
			_stick_origin = _stick_at - off.normalized() * STICK_RADIUS
		_update()


func _update() -> void:
	if _stick_index < 0 or _blocked():
		GameInput.touch_move = Vector2.ZERO
	else:
		var off := (_stick_at - _stick_origin) / STICK_RADIUS
		var v := Vector2(off.x, -off.y)
		var m := v.length()
		if m < DEAD_ZONE:
			v = Vector2.ZERO
		else:
			v = v.normalized() * clampf((m - DEAD_ZONE) / (1.0 - DEAD_ZONE), 0.0, 1.0)
		GameInput.touch_move = v
	_stick.queue_redraw()


func stick_state() -> Dictionary:
	return {"active": _stick_index >= 0, "origin": _stick_origin, "at": _stick_at}


func _process(_delta: float) -> void:
	if _blocked() and _stick_index >= 0:
		_stick_index = -1
		_update()
	var word: String = level.get("action_word") if level and level.get("action_word") != null else ""
	_act_label.text = word if word != "" else "ACT"
	_act.modulate.a = 1.0 if word != "" else 0.45
