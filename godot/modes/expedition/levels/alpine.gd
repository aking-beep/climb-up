class_name Alpine
extends Node2D
## The fastest way's alpine pitches (the Umbwe climbs): long chimneys and
## couloirs climbed on a rope with a partner, crag-style.
##
## A pitch is a tall cleft with pitons up it and an anchor on the ledge at
## the top (the layout's "pitches", from tools/levels/route_levels.py). Your
## partner stays at the foot to belay. On the way up, tap CLIP when a piton
## is in reach (a little breath, one hand off the rock). Once clipped:
##   - a fall (empty arms, a slip) is held by the rope: no slip
##     counted, but the knock hurts, and you hang as far below the last
##     piton as you were above it, plus the stretch (no further down than
##     the foot of the pitch);
##   - REST sits back on the rope: each clip is worth ROPE_REST of the bar,
##     given back while you hang there.
## At the anchor you clip in and bring your partner up: tap PULL, PULLS
## times; each pull costs a little breath. Only then does the climb go on:
## the partner follows you to the next pitch, cleaning the pitons as they
## come. Fall off before the first piton, or off the rope altogether, and it
## is a slip like any other: back to the cairn, the pitch to lead again.

const T := Terrain.TILE
## How close the chest must be to a piton to clip it.
const CLIP_REACH := Vector2(1.5 * T, 1.3 * T)
const CLIP_COST := 1.0
## The rope's stretch below where the fall would stop.
const SLACK := 1.0 * T
## What a fall onto the rope costs at least (the whip on the harness).
const ROPE_KNOCK := 4.0
## A rest on the rope: each clip is worth this share of the bar, given back
## at ROPE_RATE of the bar a second while you sit back.
const ROPE_REST := 0.6
const ROPE_RATE := 0.35
## Pulls to bring the partner up one pitch, and the breath each one costs.
const PULLS := 8
const PULL_COST := 0.4
## The anchor takes you once you stand this close to it.
const ANCHOR_REACH := 1.4 * T
## Who ties in with you, the first of these the trek still has.
const PARTNERS := ["lena", "marco", "jun"]

var level: ClimbLevel
var climber: Climber
## Bottom to top along the line: {x (the column climbed, tiles), base (feet
## at the foot), top (the row stood on at the top), pitons: [{cell, node,
## clipped}], anchor (feet), node (the anchor's sprite), done}.
var pitches: Array = []
## The pitch being led: the first not done.
var lead := 0
var clip_target := -1
var resting := false
var rope_left := 0.0
var belaying := false
var pulls := 0
var partner: Companion
var partner_name := ""
## Counts, for the tests and the results.
var clips_made := 0
var hauls := 0
var _caught := false
var _fall_top := 0.0
var _fall_from_stamina := 0.0
var _rope: Line2D
## Holding still this long once clipped hangs you on the rope.
const HANG_STILL := 0.5
var _still := 0.0
var _hang_said := false
var _draw_tex: Texture2D


func setup(lvl: ClimbLevel, defs: Array) -> void:
	level = lvl
	climber = lvl.climber
	_draw_tex = load("res://assets/crag/quickdraw-hd.png")
	for d in defs:
		var p := {"x": float(d["x"]), "base": Terrain.feet(Vector2i(int(d["base"][0]), int(d["base"][1]))),
			"top": int(d["top"]), "anchor": Terrain.feet(Vector2i(int(d["anchor"][0]), int(d["anchor"][1]))),
			"pitons": [], "done": false}
		for cell in d["pitons"]:
			var c := Vector2i(int(cell[0]), int(cell[1]))
			var s := _quickdraw()
			s.position = Vector2(c) * T + Vector2(4, 11)
			add_child(s)
			p["pitons"].append({"cell": c, "node": s, "clipped": false})
		# The anchor: two pitons and a sling on the ledge's back wall.
		var a := _quickdraw()
		a.position = p["anchor"] + Vector2(T * 0.6, -T * 1.1)
		a.modulate = Color(1.0, 0.85, 0.55)
		add_child(a)
		p["node"] = a
		pitches.append(p)
	_rope = Line2D.new()
	_rope.width = 1.6
	_rope.default_color = Color("#e8622c")
	_rope.joint_mode = Line2D.LINE_JOINT_ROUND
	_rope.antialiased = true
	_rope.z_index = 2
	add_child(_rope)
	for who in PARTNERS:
		if not Trek.is_gone(Expedition.session, who):
			partner = Companion.new()
			partner.person = who
			partner.name = "Partner"
			partner_name = String(Trek.NAMES.get(who, who.capitalize()))
			lvl.add_child(partner)
			partner.helped()
			partner.catch_up(climber.global_position)
			break
	climber.rope_catch = _catches
	_refresh()


func _quickdraw() -> Sprite2D:
	var s := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = _draw_tex
	at.region = Rect2(0, 0, 48, 88)
	s.texture = at
	s.scale = Vector2.ONE * 1.3 / 4.0
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.z_index = 1
	return s


func current() -> Dictionary:
	return pitches[lead] if lead < pitches.size() else {}


## On the pitch being led: on its rock, between its foot and its top.
func on_pitch() -> bool:
	var p := current()
	if p.is_empty():
		return false
	var f := climber.global_position
	return absf(f.x / T - float(p["x"])) < 2.6 and f.y < float(p["base"].y) - 2.0 and f.y > (float(p["top"]) - 1.0) * T


func clipped() -> int:
	var n := 0
	for pt in current().get("pitons", []):
		if pt["clipped"]:
			n += 1
	return n


## The highest piton clipped on the pitch being led, or -1.
func last_clip() -> int:
	var best := -1
	var pts: Array = current().get("pitons", [])
	for i in pts.size():
		if pts[i]["clipped"] and (best < 0 or pts[i]["cell"].y < pts[best]["cell"].y):
			best = i
	return best


## Climber.rope_catch: a fall on the pitch with a piton clipped is held.
func _catches(_reason: String) -> bool:
	if last_clip() < 0 or not on_pitch():
		return false
	_caught = true
	_fall_top = minf(climber.fall_from, climber.global_position.y)
	_fall_from_stamina = climber.stamina.value
	return true


## Where a fall held by the rope stops: as far below the last piton as you
## were above it, plus the stretch, on the rock of the cleft; never below
## the foot of the pitch.
func landing() -> Vector2:
	var p := current()
	var pin: Vector2i = p["pitons"][last_clip()]["cell"]
	var hang := Terrain.feet(pin + Vector2i(0, 1))
	var above := maxf(0.0, hang.y - _fall_top)
	var land_y := hang.y + above + SLACK
	var base: Vector2 = p["base"]
	if land_y >= base.y - T:
		return base
	var row := Terrain.cell_of(Vector2(0, land_y)).y
	var col := int(floor(float(p["x"])))
	for dy in range(0, maxi(1, row - pin.y + 1)):
		for dx in [0, -1, 1, 2]:
			var c := Vector2i(col + dx, row - dy)
			if level.terrain.is_climbable(c) and level.terrain.is_climbable(c + Vector2i.UP):
				return Terrain.feet(c)
	return hang


## The slip is over: the climb level asks whether the rope had it.
func caught_now() -> bool:
	return _caught


## Hang on the rope where the fall stopped (called instead of going back to
## the cairn). The knock comes off what you had, never below a quarter.
func hang() -> void:
	_caught = false
	var land := landing()
	var hit := maxf(climber.bruise, ROPE_KNOCK) * climber.hurt_scale
	climber.bruise = 0.0
	climber.hang_at(land)
	climber.stamina.value = maxf(climber.stamina.max_value * 0.25, _fall_from_stamina - hit)
	climber.hurt_total += hit
	# Hanging on the rope after a fall: a fresh rest bar to try again.
	rope_left = ROPE_REST * climber.stamina.max_value
	level.hud.flash("The rope holds! %s catches you below the piton. Tap REST to hang on the rope and get your breath back." % partner_name if partner else "The rope holds. Tap REST to hang on it and get your breath back.", 3.0)


## Back at a cairn after a slip the rope did not hold (or a resume): the
## pitches behind you are done; the one ahead is led again from its foot.
func reset_to(feet: Vector2) -> void:
	_caught = false
	resting = false
	climber.on_rope = false
	if belaying:
		belaying = false
	for p in pitches:
		if not p["done"] and p["anchor"].x <= feet.x + 1.0:
			_finish_pitch(p)
	for p in pitches:
		if not p["done"]:
			for pt in p["pitons"]:
				pt["clipped"] = false
	lead = 0
	while lead < pitches.size() and pitches[lead]["done"]:
		lead += 1
	if partner:
		partner.helped()
		partner.catch_up(feet)
	_refresh()


## Every physics frame, before the level's own taps: true when `tap` (the
## ACT button) was taken here.
func step(tap: bool) -> bool:
	if partner and partner.state == Companion.State.FOLLOWING and not belaying:
		partner.record(climber.global_position, climber.sprite.animation, climber.sprite.flip_h)
	var p := current()
	if p.is_empty() or climber.state == Climber.State.SLIP:
		_draw()
		return false
	if belaying:
		level.action_word = "PULL"
		level.prompt = "Pull %s up (%d of %d)" % [partner_name, pulls, PULLS]
		if tap:
			_pull()
		_draw()
		return tap
	# The partner stops at the foot to belay once you start up the pitch.
	if partner and partner.state == Companion.State.FOLLOWING and climber.is_climbing() and on_pitch():
		partner.state = Companion.State.CAMP
		partner.global_position = p["base"] + Vector2(-T * 1.2, 0)
		partner.reset_physics_interpolation()
		partner.sprite.play("idle")
		partner.sprite.flip_h = false
	# At the anchor: clip in and bring the partner up.
	if climber.state == Climber.State.GROUND and climber.global_position.distance_to(p["anchor"]) < ANCHOR_REACH:
		_at_anchor()
		_draw()
		return false
	_find_clip()
	_rest_on_rope()
	_draw()
	if clip_target >= 0:
		level.action_word = "CLIP"
		level.prompt = "Clip the piton"
		if tap:
			_clip()
			return true
	elif resting:
		level.prompt = "Resting on the rope"
	elif clipped() > 0 and on_pitch() and climber.state == Climber.State.CLIMB and climber.stamina.fraction() < 0.5 and rope_left > 0.0:
		level.prompt = "Tap REST to hang on the rope"
	return false


func _find_clip() -> void:
	clip_target = -1
	if climber.state != Climber.State.CLIMB or resting:
		return
	var chest := climber.global_position - Vector2(0, Climber.SIZE.y * 0.5)
	var pts: Array = current()["pitons"]
	for i in pts.size():
		if pts[i]["clipped"]:
			continue
		var at := Vector2(pts[i]["cell"]) * T + Vector2.ONE * T / 2.0
		if absf(at.x - chest.x) < CLIP_REACH.x and absf(at.y - chest.y) < CLIP_REACH.y:
			clip_target = i


func _clip() -> void:
	var pt: Dictionary = current()["pitons"][clip_target]
	pt["clipped"] = true
	clips_made += 1
	climber.stamina.value = maxf(0.0, climber.stamina.value - CLIP_COST)
	rope_left = ROPE_REST * climber.stamina.max_value
	level.engage("clip")
	Haptics.tap(28)
	Audio.play("clip", -2.0, 0.06, false)
	var n := clipped()
	level.hud.flash("Clipped: piton %d of %d. A fall now stops on the rope. Tap REST to hang on it." % [n, current()["pitons"].size()], 2.2)
	clip_target = -1
	_refresh()


## REST on the rock, once clipped: sit back on the rope. Moving, or REST
## again, climbs on; the rope's share runs out until the next clip.
func _rest_on_rope() -> void:
	if climber.state != Climber.State.CLIMB:
		resting = false
		climber.on_rope = false
		return
	var pressed := GameInput.pressed_now("rest")
	var dt := get_physics_process_delta_time()
	if GameInput.move() != Vector2.ZERO:
		_still = 0.0
	if resting:
		var give := minf(ROPE_RATE * climber.stamina.max_value * dt, rope_left)
		climber.stamina.value = minf(climber.stamina.max_value, climber.stamina.value + give)
		rope_left -= give
		if pressed or GameInput.move() != Vector2.ZERO or rope_left <= 0.0 or climber.stamina.value >= climber.stamina.max_value - 0.01:
			resting = false
			if rope_left <= 0.0:
				level.hud.flash("That's all the rope gives here: clip the next piton for more.", 2.0)
	elif clipped() > 0 and on_pitch() and not pressed and GameInput.move() == Vector2.ZERO and rope_left > 0.0 \
			and climber.stamina.value < climber.stamina.max_value - 0.5:
		# Holding still once clipped: you hang on the rope and the arms come
		# back on their own (no need to know the REST button).
		_still += dt
		if _still >= HANG_STILL:
			resting = true
			level.engage("rope_rest")
			if not _hang_said:
				_hang_said = true
				level.hud.flash("Clipped in: hold still and you hang on the rope, and your arms come back.", 2.6)
	elif pressed and clipped() > 0 and on_pitch():
		if rope_left > 0.0:
			resting = true
			level.engage("rope_rest")
			level.hud.flash("You sit back on the rope and shake your arms out.", 1.6)
		else:
			level.hud.flash("Nothing more from the rope here: clip the next piton.", 1.8)
	climber.on_rope = resting


func _at_anchor() -> void:
	var p := current()
	resting = false
	climber.on_rope = false
	clip_target = -1
	if partner == null:
		level.hud.flash("At the anchor. Nobody to bring up: you fix the rope and climb on alone.", 2.4)
		_finish_pitch(p)
		lead += 1
		return
	belaying = true
	pulls = 0
	climber.lock(true)
	level.engage("anchor")
	Audio.play("clip", -4.0, 0.06, false)
	level.hud.flash("Anchor! Clip in and bring %s up: tap PULL." % partner_name, 2.6)


func _pull() -> void:
	var p := current()
	pulls += 1
	climber.stamina.value = maxf(0.0, climber.stamina.value - PULL_COST)
	Haptics.tap(14)
	Audio.play("grip", -10.0, 0.1)
	var t := float(pulls) / float(PULLS)
	var col := float(p["x"]) * T
	var from: Vector2 = Vector2(col, p["base"].y)
	var to: Vector2 = Vector2(col, float(p["top"]) * T)
	partner.global_position = from.lerp(to, t)
	partner.sprite.play("climb")
	if pulls % 3 == 0:
		level.engage("pull")
	if pulls >= PULLS:
		hauls += 1
		belaying = false
		_finish_pitch(p)
		lead += 1
		partner.helped()
		partner.catch_up(climber.global_position)
		climber.lock(false)
		level.engage("haul")
		Audio.play("chime", -10.0)
		level.hud.flash("%s is up. They clean the pitons on the way: on to the next pitch." % partner_name if lead < pitches.size() else "%s is up. That was the last pitch." % partner_name, 2.4)
		_refresh()


func _finish_pitch(p: Dictionary) -> void:
	p["done"] = true
	# The second takes the gear out on the way up.
	for pt in p["pitons"]:
		pt["clipped"] = false
		pt["node"].visible = false


func _refresh() -> void:
	for i in pitches.size():
		for pt in pitches[i]["pitons"]:
			pt["node"].texture.region = Rect2(48 if pt["clipped"] else 0, 0, 48, 88)


## The rope: from the partner, up through the clipped pitons, to you.
func _draw() -> void:
	var p := current()
	var pts := PackedVector2Array()
	if partner and not p.is_empty() and (belaying or clipped() > 0 or (partner.state == Companion.State.CAMP and on_pitch())):
		pts.append(partner.global_position - Vector2(0, 12))
		if not belaying:
			var pins: Array = p["pitons"].filter(func(x: Dictionary) -> bool: return x["clipped"])
			pins.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["cell"].y > b["cell"].y)
			for pin in pins:
				pts.append(Vector2(pin["cell"]) * T + Vector2(4, 19))
		pts.append(climber.global_position - Vector2(0, 11))
	_rope.points = pts
	for pt in p.get("pitons", []):
		pt["node"].modulate = Color.WHITE
	if clip_target >= 0:
		var node: Sprite2D = p["pitons"][clip_target]["node"]
		node.modulate = Color(1, 1, 0.6) if Settings.reduced_motion or fmod(climber.clock * 3.0, 1.0) < 0.6 else Color.WHITE
