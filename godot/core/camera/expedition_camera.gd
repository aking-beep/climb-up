class_name ExpeditionCamera
extends Camera2D
## A camera that composes the mountain rather than pinning the climber to
## the centre: it leads in the direction of travel, looks up on a face (the
## next hold matters more than the last), pulls back at vistas, stays inside
## the level, and shakes only on slips and gusts (never with reduced motion).

var target: Climber
var bounds := Rect2()
## [{at: Vector2, radius: float, zoom: float, lift: float}]
var reveals: Array = []
## When set, the camera looks here instead of at the climber (reading a
## route before climbing it). Vector2.INF: follow the climber.
var look := Vector2.INF

const LEAD_X := 56.0
const LOOK_UP := 46.0
const FOLLOW := 3.2

var _lead := Vector2.ZERO
var _shake := 0.0
var _zoom_target := 1.0


func _init() -> void:
	# Physics interpolation is on: the camera follows in the physics step
	# (Godot would switch it anyway, with a warning).
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func _ready() -> void:
	enabled = true
	# Moved in physics frames, drawn interpolated between them.
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	_apply_limits()


func _apply_limits() -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y) - 200
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


func snap() -> void:
	if target == null:
		return
	_lead = _wanted_lead()
	global_position = target.global_position + _lead + Vector2(0, -24)
	reset_smoothing()
	reset_physics_interpolation()


func kick(strength: float) -> void:
	if Settings.reduced_motion:
		return
	_shake = maxf(_shake, strength)


func _wanted_lead() -> Vector2:
	var lead := Vector2(target.facing * LEAD_X, 0.0)
	if target.is_climbing():
		lead = Vector2(target.facing * 18.0, -LOOK_UP)
	elif absf(target.velocity.x) < 4.0:
		lead.x *= 0.45
	return lead


func _physics_process(delta: float) -> void:
	if look != Vector2.INF:
		global_position = global_position.lerp(look, 1.0 if Settings.reduced_motion else clampf(4.0 * delta, 0.0, 1.0))
		offset = Vector2.ZERO
		return
	if target == null:
		return
	var want_lead := _wanted_lead()
	_zoom_target = 1.0
	var lift := 0.0
	for r in reveals:
		var d: float = target.global_position.distance_to(r["at"])
		if d < r["radius"]:
			var k := 1.0 - d / float(r["radius"])
			_zoom_target = lerpf(1.0, r["zoom"], k)
			lift = r["lift"] * k
	var rate := 1.0 if Settings.reduced_motion else clampf(FOLLOW * delta, 0.0, 1.0)
	_lead = _lead.lerp(want_lead, clampf(1.6 * delta, 0.0, 1.0) if not Settings.reduced_motion else 1.0)
	var goal := target.global_position + _lead + Vector2(0, -24 + lift)
	global_position = global_position.lerp(goal, rate)
	var z := lerpf(zoom.x, _zoom_target, clampf(1.2 * delta, 0.0, 1.0))
	zoom = Vector2(z, z)
	if _shake > 0.0:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 4.0
		_shake = maxf(0.0, _shake - delta * 2.5)
	else:
		offset = Vector2.ZERO
