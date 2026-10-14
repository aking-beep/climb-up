class_name TouchControls
extends CanvasLayer
## Two-thumb touch controls for landscape phones.
##
## Left thumb: a floating stick. Touch anywhere on the left of the screen and
## drag; the stick appears under the thumb, so there is no small target to
## find. It is analog: a small push walks slowly, a full push walks at pace;
## up or down climbs.
## Right thumb: JUMP, one context button that says what it will do (CLIMB,
## TALK, READ, HELP) and REST (also for sitting out a gust). Top right: pause.
## Everything presses the same input actions as keys, so gameplay never
## knows the difference. Shown automatically on touch devices (Settings).
##
## The player can make the controls bigger or smaller (Settings.touch_scale)
## and swap the sides for the left hand (Settings.left_handed). Everything
## keeps clear of notches and rounded corners (Settings.safe_insets()).

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
## Where the screen is safe to put things (view units), and the button scale.
var safe := {"left": 0.0, "right": 0.0, "top": 0.0, "bottom": 0.0}
var scale_k := 1.0
var buttons: Dictionary = {}


static func attach(lvl: Node) -> void:
	var existing := lvl.get_node_or_null("TouchControls")
	if existing:
		# Out of the tree now, so the new overlay takes the name at once.
		lvl.remove_child(existing)
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
	safe = Settings.safe_insets()
	scale_k = Settings.touch_scale
	_stick = Node2D.new()
	_stick.set_script(load("res://core/input/touch_stick.gd"))
	_stick.set("controls", self)
	add_child(_stick)
	# Laid out for the right thumb from the bottom-right corner (inside the
	# safe area), each offset scaled with the buttons; mirrored for the left.
	var r := Vector2(vp.x - 16 - safe["right"], vp.y - 14 - safe["bottom"])
	var k := scale_k
	_button("jump", "JUMP", r + Vector2(-50, -52) * k, 50.0 * k)
	if level and level.get("touch_layout") == "crag":
		# The crag is all tapping: one big button for CLIP and GRIP, by the
		# thumb, and nothing to sit for.
		_act = _button("interact", "CLIMB", r + Vector2(-122, -60) * k, 58.0 * k)
	else:
		_act = _button("interact", "CLIMB", r + Vector2(-46, -104) * k, 42.0 * k)
		# REST is also how you sit out a gust: no separate brace button.
		_button("rest", "REST", r + Vector2(-100, -42) * k, 40.0 * k)
	_act_label = _act.get_child(0)
	# Pause stays top right for both hands: clear of the stats, top left.
	_button("pause", "II", Vector2(vp.x - 38 - safe["right"], 4 + safe["top"]), 32.0)
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
	if Settings.left_handed and action != "pause":
		# Mirrored across the screen, keeping clear of the left cutout.
		var vp := get_viewport().get_visible_rect().size
		b.position.x = vp.x - at.x - size - safe["right"] + safe["left"]
	buttons[action] = b
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


## A filled disc with a thin rim, drawn once at four times the button's
## size with soft (anti-aliased) edges and a gentle top-lit gradient, and
## shown at the button's size, so it stays round on a phone's screen.
static func _disc(size: float, fill: Color, rim: Color) -> ImageTexture:
	var k := Art.HD
	var n := int(size) * k
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n / 2.0, n / 2.0)
	var outer := n / 2.0 - 0.5
	var inner := outer - 1.5 * k
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var cover := clampf(outer - d + 0.5, 0.0, 1.0)
			if cover <= 0.0:
				continue
			var lit := 1.0 + 0.18 * (0.5 - float(y) / n)
			var body := Color(fill.r * lit, fill.g * lit, fill.b * lit, fill.a)
			var col := body.lerp(rim, clampf(d - inner + 0.5, 0.0, 1.0))
			col.a *= cover
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(int(size), int(size)))
	return tex


func _blocked() -> bool:
	var p: Variant = level.get("panel") if level else null
	return p != null and p.open


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var vp := get_viewport().get_visible_rect().size
		var on_stick_side: bool = event.position.x > vp.x * (1.0 - STICK_AREA) if Settings.left_handed else event.position.x < vp.x * STICK_AREA
		if event.pressed and _stick_index < 0 and on_stick_side and event.position.y > 40 and not _blocked():
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
		if off.length() > radius():
			_stick_origin = _stick_at - off.normalized() * radius()
		_update()


func _update() -> void:
	if _stick_index < 0 or _blocked():
		GameInput.touch_move = Vector2.ZERO
	else:
		var off := (_stick_at - _stick_origin) / radius()
		var v := Vector2(off.x, -off.y)
		var m := v.length()
		if m < DEAD_ZONE:
			v = Vector2.ZERO
		else:
			v = v.normalized() * clampf((m - DEAD_ZONE) / (1.0 - DEAD_ZONE), 0.0, 1.0)
		GameInput.touch_move = v
	_stick.queue_redraw()


## The stick's radius at the player's chosen control size.
func radius() -> float:
	return STICK_RADIUS * scale_k


func stick_state() -> Dictionary:
	return {"active": _stick_index >= 0, "origin": _stick_origin, "at": _stick_at}


func _process(_delta: float) -> void:
	if _blocked() and _stick_index >= 0:
		_stick_index = -1
		_update()
	var word: String = level.get("action_word") if level and level.get("action_word") != null else ""
	_act_label.text = word if word != "" else "ACT"
	_act.modulate.a = 1.0 if word != "" else 0.45
