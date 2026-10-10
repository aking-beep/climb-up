class_name Climber
extends CharacterBody2D
## The player on the mountain. A small state machine over Godot's character
## physics: walk (with slopes), scramble, climb and traverse faces, mantle
## onto ledges, rest, brace against wind, slip, and help a teammate.
##
## No jumping. The vocabulary is mountaineering: WALK, SCRAMBLE, CLIMB,
## TRAVERSE, BALANCE (exposed ground), BRACE, REST, HELP, RETREAT (pause menu).
## Context decides what an input does: UP on a face grabs it; UP at the top
## of a face mantles; UP on open ground does nothing.

signal slipped(caught: bool, reason: String)
signal slip_finished
signal grabbed
signal mantled
signal footstep(surface: String)
signal wind_struck

enum State { GROUND, AIR, CLIMB, MANTLE, REST, BRACE, SLIP, HELP, LOCKED, DONE }

const T := Terrain.TILE
const SIZE := Vector2(10, 26)

# Movement, in pixels per second. One tile is 16 px.
const WALK := 64.0
const TIRED_WALK := 40.0
const EXPOSED_WALK := 28.0
const ACCEL := 720.0
const DECEL := 1100.0
const GRAVITY := 900.0
const MAX_FALL := 420.0
const CLIMB_UP := 34.0
const CLIMB_SIDE := 27.0
const SCRAMBLE_SPEED := 48.0
const FATIGUE_SLOW := 0.7
## A drop longer than this (4 tiles) is a slip, not a step down.
const SAFE_FALL := 4.0 * T
const SLIP_TIME := 1.0
const MANTLE_TIME := 0.45
const HELP_TIME := 1.2
const GUST_PUSH := 20.0
const GUST_FIGHT := 6.0  # stamina per second, standing unbraced in a gust

var terrain: Terrain
var wind: WindSchedule
var stamina: StaminaModel
var sheet_path := "res://assets/characters/you.png"

var state: int = State.GROUND
var facing := 1
var clock := 0.0              # seconds on the mountain, paused when locked
var fall_from := 0.0
var exposed := false
var gust: int = WindSchedule.Phase.CALM
## Set by a helped teammate: the next slip is caught.
var spotter := false
var slips := 0
var caught := 0
var wind_strikes := 0
var loose_seconds := 0.0
var rest_seconds := 0.0
var last_activity := "still"
var spotter_caught_last := false
var helper_cost := 15.0

var _timer := 0.0
var _mantle_from := Vector2.ZERO
var _mantle_to := Vector2.ZERO
var _step_distance := 0.0
var _breath := 0.0
var _rest_stone := false
var sprite: AnimatedSprite2D


func setup(t: Terrain, w: WindSchedule, s: StaminaModel) -> void:
	terrain = t
	wind = w
	stamina = s


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y / 2.0)
	add_child(shape)
	sprite = Sheet.sprite(sheet_path)
	add_child(sprite)
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 6.0
	floor_constant_speed = true
	safe_margin = 0.05


func body_rect(at: Vector2 = global_position) -> Rect2:
	return Rect2(at + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


func on_ground_cell() -> bool:
	var feet := global_position + Vector2(0, 2)
	for dx in [-SIZE.x / 2.0 + 1.0, 0.0, SIZE.x / 2.0 - 1.0]:
		if terrain.is_solid(Terrain.cell_of(feet + Vector2(dx, 0))):
			return true
	return false


func is_climbing() -> bool:
	return state == State.CLIMB or state == State.MANTLE


func lock(on: bool) -> void:
	if on:
		if state != State.DONE:
			state = State.LOCKED
		velocity.x = 0.0
	elif state == State.LOCKED:
		state = State.GROUND


## Back at a cairn after a slip. A caught slip leaves more in the arms.
func respawn(feet: Vector2) -> void:
	global_position = feet
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	state = State.GROUND
	fall_from = feet.y
	stamina.refill(0.75 if spotter_caught_last else 0.5)
	spotter_caught_last = false


func _physics_process(delta: float) -> void:
	if terrain == null:
		return
	if state != State.LOCKED and state != State.DONE:
		clock += delta
	var input := GameInput.move()
	var kinds := terrain.kinds_in(body_rect())
	exposed = kinds.has(Terrain.Kind.EXPOSED)
	_rest_stone = kinds.has(Terrain.Kind.REST)
	gust = wind.phase_at(clock) if exposed else WindSchedule.Phase.CALM
	if input.x > 0.2:
		facing = 1
	elif input.x < -0.2:
		facing = -1

	match state:
		State.GROUND:
			_ground(delta, input)
		State.AIR:
			_air(delta, input)
		State.CLIMB:
			_climb(delta, input)
		State.MANTLE:
			_mantle(delta)
		State.REST:
			_rest(delta, input)
		State.BRACE:
			_brace(delta)
		State.SLIP:
			_slip(delta)
		State.HELP:
			_help(delta)
		State.LOCKED, State.DONE:
			velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
			velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
			move_and_slide()
	_animate(input)


# --- States -----------------------------------------------------------------

func _ground(delta: float, input: Vector2) -> void:
	if input.y > 0.5 and terrain.touches_climbable(body_rect()):
		_grab()
		return
	if input.y < -0.5 and _climb_down_from_top():
		return
	if GameInput.held("brace"):
		state = State.BRACE
		velocity.x = 0.0
		return
	if GameInput.pressed_now("rest"):
		state = State.REST
		velocity.x = 0.0
		return
	var limit := EXPOSED_WALK if exposed else (TIRED_WALK if stamina.is_tired() else WALK)
	var target := input.x * limit
	var rate := ACCEL if absf(target) > absf(velocity.x) else DECEL
	velocity.x = move_toward(velocity.x, target, rate * delta)
	# The edge guard: walking never carries you off a drop that would be a
	# slip. Going down is a choice (DOWN onto the rock), not a stumble.
	# Walking off a ledge onto a face grabs the face instead.
	if absf(velocity.x) > 0.0 and drop_ahead(int(signf(velocity.x))):
		if _face_ahead(int(signf(velocity.x))):
			_grab()
			return
		velocity.x = 0.0
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var before := global_position
	move_and_slide()
	var moving := absf(velocity.x) > 6.0
	last_activity = "walk" if moving else "still"
	stamina.tick(delta, last_activity)
	_steps(before, delta)
	_weather(delta, input)
	if state != State.GROUND:
		return
	if not is_on_floor():
		state = State.AIR
		fall_from = global_position.y


func _air(delta: float, input: Vector2) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	# Catching the rock on the way down: only from a short fall.
	if input.y > 0.5 and terrain.touches_climbable(body_rect()) and global_position.y - fall_from < SAFE_FALL * 0.5 and not stamina.is_empty():
		_grab()
		return
	move_and_slide()
	if is_on_floor():
		var drop := global_position.y - fall_from
		if drop > SAFE_FALL:
			slip("fall")
		else:
			state = State.GROUND
			if drop > T:
				Audio.play("step_dirt", -4.0)


## The floor row under the feet, and the column a step ahead in `dir`.
func _ahead(dir: int) -> Vector2i:
	return Vector2i(Terrain.cell_of(Vector2(global_position.x + dir * 3.0, 0)).x, Terrain.cell_of(global_position + Vector2(0, 2)).y)


## True when a step in `dir` would walk off a drop longer than a safe step.
func drop_ahead(dir: int) -> bool:
	var at := _ahead(dir)
	for k in int(SAFE_FALL / T) + 1:
		if terrain.is_solid(at + Vector2i(0, k)):
			return false
	return true


## Rock to hold at chest height a step ahead.
func _face_ahead(dir: int) -> bool:
	var chest := global_position + Vector2(dir * (SIZE.x / 2.0 + 1.0), -SIZE.y * 0.5)
	return terrain.is_climbable(Terrain.cell_of(chest))


## The climbable column under the feet or a step ahead, for climbing down
## from the top of a face. (-1, -1) when there is none.
func _rock_below() -> Vector2i:
	var row := Terrain.cell_of(global_position + Vector2(0, 2)).y
	for dir in [0, facing]:
		var col := Terrain.cell_of(Vector2(global_position.x + dir * 3.0, 0)).x
		if terrain.is_climbable(Vector2i(col, row)):
			return Vector2i(col, row)
	return Vector2i(-1, -1)


## What the context button would do on rock: grab it (or climb down onto it).
func can_grab() -> bool:
	if state != State.GROUND:
		return false
	return terrain.touches_climbable(body_rect()) or _rock_below().x >= 0


func grab_now() -> void:
	if state != State.GROUND:
		return
	if terrain.touches_climbable(body_rect()):
		_grab()
	else:
		_climb_down_from_top()


func _climb_down_from_top() -> bool:
	var cell := _rock_below()
	if cell.x < 0:
		return false
	global_position = Vector2(cell.x * T + T / 2.0, global_position.y + 6.0)
	_grab()
	return true


func _grab() -> void:
	state = State.CLIMB
	velocity = Vector2.ZERO
	Audio.play("grip", -8.0)
	grabbed.emit()


func _climb(delta: float, input: Vector2) -> void:
	var hold := terrain.hold_at(body_rect())
	if hold == Terrain.Kind.AIR and not terrain.touches_climbable(body_rect()):
		_let_go()
		return
	var scrambling := hold == Terrain.Kind.SCRAMBLE
	var speed_up := SCRAMBLE_SPEED if scrambling else CLIMB_UP
	var speed_side := SCRAMBLE_SPEED * 0.8 if scrambling else CLIMB_SIDE
	if stamina.is_tired():
		speed_up *= FATIGUE_SLOW
		speed_side *= FATIGUE_SLOW
	var want := Vector2(input.x * speed_side, -input.y * speed_up)
	# Hands must stay on rock: no climbing up past the top of the face.
	if want.y < 0.0:
		var next := body_rect(global_position + Vector2(0, want.y * delta))
		if terrain.hold_at(next) == Terrain.Kind.AIR:
			want.y = 0.0
			if input.y > 0.5 and _try_mantle(input):
				return
	velocity = want
	var before := global_position
	move_and_slide()
	# Small lips: when a sideways move is blocked, step up over a ledge edge.
	if absf(want.x) > 0.0 and absf(global_position.x - before.x) < absf(want.x * delta) * 0.5:
		_step_assist(int(signf(want.x)))
	var moving := global_position.distance_to(before) > 0.05
	var loose := terrain.kinds_in(body_rect()).has(Terrain.Kind.LOOSE)
	if loose:
		loose_seconds += delta
		if moving and randf() < delta * 0.8:
			Audio.play("rockfall", -14.0)
	if scrambling:
		last_activity = "scramble" if moving else "hang"
	elif moving and absf(want.x) > absf(want.y):
		last_activity = "traverse"
	else:
		last_activity = "climb" if moving else "hang"
	stamina.tick(delta, last_activity, loose)
	_breathing(delta)
	if stamina.is_empty():
		_let_go()
		return
	if not terrain.touches_climbable(body_rect()):
		_let_go()
		return
	if input.y < -0.5 and on_ground_cell():
		state = State.GROUND


func _let_go() -> void:
	if on_ground_cell():
		state = State.GROUND
		return
	state = State.AIR
	fall_from = global_position.y
	velocity = Vector2.ZERO


func _step_assist(dir: int) -> void:
	for up in [2.0, 4.0, 6.0, 8.0, 10.0]:
		var at := global_position + Vector2(dir * 2.0, -up)
		if _fits(at):
			global_position = at
			return


func _fits(feet: Vector2) -> bool:
	var r := body_rect(feet).grow(-0.5)
	var a := Terrain.cell_of(r.position)
	var b := Terrain.cell_of(r.end)
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			if terrain.is_solid(Vector2i(x, y)):
				return false
	return true


## At the top of a face: find the ledge to step onto, to either side.
func _try_mantle(input: Vector2) -> bool:
	var dirs: Array[int] = []
	if absf(input.x) > 0.2:
		dirs.append(int(signf(input.x)))
	for d in [facing, -facing]:
		if not dirs.has(d):
			dirs.append(d)
	for d in dirs:
		for reach in [0.9, 1.6, 2.3, 3.0]:
			if _mantle_to_side(d, reach):
				return true
	return false


## A ledge `reach` tiles to side `d`, no more than 2.5 tiles up, that the
## body fits on and can get to without passing through rock.
func _mantle_to_side(d: int, reach: float) -> bool:
	var x := global_position.x + d * (T * reach)
	var column := Terrain.cell_of(Vector2(x, 0)).x
	# Floors are tile tops: try each one from here up to 2.5 tiles higher.
	var lowest := Terrain.cell_of(global_position).y + 1
	var highest := Terrain.cell_of(global_position - Vector2(0, T * 2.5)).y
	for row in range(lowest, highest - 1, -1):
		var feet := Vector2(x, row * T)
		if feet.y > global_position.y + 1.0:
			continue
		if terrain.is_solid(Vector2i(column, row)) and _fits(feet) and _clear_between(global_position.x, x, feet.y - 8.0):
			_mantle_from = global_position
			_mantle_to = feet
			facing = d
			state = State.MANTLE
			_timer = 0.0
			velocity = Vector2.ZERO
			Audio.play("grip", -6.0)
			return true
	return false


func _clear_between(x0: float, x1: float, y: float) -> bool:
	var a := Terrain.cell_of(Vector2(minf(x0, x1), y)).x
	var b := Terrain.cell_of(Vector2(maxf(x0, x1), y)).x
	for cx in range(a, b + 1):
		if terrain.is_solid(Vector2i(cx, Terrain.cell_of(Vector2(0, y)).y)):
			return false
	return true


func _mantle(delta: float) -> void:
	_timer += delta
	var t := clampf(_timer / MANTLE_TIME, 0.0, 1.0)
	# Up first, then over: the body clears the lip before moving across.
	var up := clampf(t * 1.6, 0.0, 1.0)
	var over := clampf((t - 0.4) / 0.6, 0.0, 1.0)
	global_position = Vector2(lerpf(_mantle_from.x, _mantle_to.x, over), lerpf(_mantle_from.y, _mantle_to.y, up))
	stamina.tick(delta, "climb")
	if t >= 1.0:
		global_position = _mantle_to
		state = State.GROUND
		fall_from = global_position.y
		mantled.emit()


func _rest(delta: float, input: Vector2) -> void:
	velocity = Vector2(0.0, minf(velocity.y + GRAVITY * delta, MAX_FALL))
	move_and_slide()
	rest_seconds += delta
	last_activity = "rest_stone" if _rest_stone else "rest"
	stamina.tick(delta, last_activity)
	_weather(delta, Vector2.ZERO)
	if state == State.REST and (input.length() > 0.3 or GameInput.pressed_now("rest")):
		state = State.GROUND


func _brace(delta: float) -> void:
	velocity = Vector2(0.0, minf(velocity.y + GRAVITY * delta, MAX_FALL))
	move_and_slide()
	last_activity = "brace"
	stamina.tick(delta, "brace")
	if not GameInput.held("brace"):
		state = State.GROUND


func _weather(delta: float, input: Vector2) -> void:
	if not exposed or gust != WindSchedule.Phase.BLOW or state == State.BRACE:
		return
	if absf(input.x) > 0.2 or absf(velocity.x) > 8.0:
		wind_strikes += 1
		wind_struck.emit()
		slip("wind")
		return
	# Standing unbraced: the wind shoves you along the ledge and costs breath.
	velocity.x = GUST_PUSH
	stamina.value = maxf(0.0, stamina.value - GUST_FIGHT * delta)


## A slip: the next one is caught if a teammate is spotting you.
func slip(reason: String) -> void:
	if state == State.SLIP or state == State.DONE:
		return
	var saved := spotter
	if saved:
		spotter = false
		caught += 1
		spotter_caught_last = true
	else:
		slips += 1
	state = State.SLIP
	_timer = 0.0
	velocity = Vector2(0.0, velocity.y)
	Audio.play("slip", -2.0)
	slipped.emit(saved, reason)


func _slip(delta: float) -> void:
	_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	if _timer >= SLIP_TIME:
		slip_finished.emit()


## Starts helping a teammate up. False when the arms are not there for it.
func help(on_done: Callable) -> bool:
	if stamina.value < helper_cost:
		return false
	state = State.HELP
	_timer = 0.0
	_on_help = on_done
	return true


var _on_help: Callable


func _help(delta: float) -> void:
	_timer += delta
	velocity = Vector2(0.0, minf(velocity.y + GRAVITY * delta, MAX_FALL))
	move_and_slide()
	if _timer >= HELP_TIME:
		stamina.spend(helper_cost)
		spotter = true
		state = State.LOCKED
		if _on_help.is_valid():
			_on_help.call()


# --- Presentation -----------------------------------------------------------

func _steps(before: Vector2, delta: float) -> void:
	_step_distance += absf(global_position.x - before.x)
	if _step_distance > 11.0:
		_step_distance = 0.0
		var under := terrain.kind(Terrain.cell_of(global_position + Vector2(0, 2)))
		var surface := "step_rock" if exposed or under == Terrain.Kind.SLOPE_R or under == Terrain.Kind.SLOPE_L else "step_dirt"
		Audio.play(surface, -14.0)
		footstep.emit(surface)
	_breathing(delta)


func _breathing(delta: float) -> void:
	if not stamina.is_tired():
		_breath = 0.0
		return
	_breath += delta
	if _breath > 2.4:
		_breath = 0.0
		Audio.play("breath", -12.0, 0.05)


func _animate(input: Vector2) -> void:
	var anim := "idle"
	match state:
		State.GROUND:
			if absf(velocity.x) > 6.0:
				anim = "tired" if stamina.is_tired() or exposed else "walk"
			elif exposed and gust != WindSchedule.Phase.CALM:
				anim = "brace"
			else:
				anim = "idle"
		State.AIR:
			anim = "fall"
		State.CLIMB:
			var moving := input.length() > 0.3
			if terrain.hold_at(body_rect()) == Terrain.Kind.SCRAMBLE:
				anim = "scramble" if moving else "hang"
			else:
				anim = "climb" if moving else "hang"
		State.MANTLE:
			anim = "mantle"
		State.REST:
			anim = "rest"
		State.BRACE:
			anim = "brace"
		State.SLIP:
			anim = "slip"
		State.HELP:
			anim = "help"
		State.DONE:
			anim = "celebrate"
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = facing < 0
