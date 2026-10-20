class_name Climber
extends CharacterBody2D
## The player on the mountain. A small state machine over Godot's character
## physics: walk (with slopes), scramble, climb and traverse faces, mantle
## onto ledges, rest (also how you sit out a gust), slip, and help a teammate.
##
## No jumping. The vocabulary is mountaineering: WALK, SCRAMBLE, CLIMB,
## TRAVERSE, BALANCE (exposed ground), REST, HELP, RETREAT (pause menu).
## Context decides what an input does: UP on a face grabs it; UP at the top
## of a face mantles; UP on open ground does nothing.

signal slipped(caught: bool, reason: String)
signal slip_finished
signal grabbed
signal mantled
signal footstep(surface: String)
signal wind_struck
signal jumped
signal dynoed
signal hurt_taken(amount: float, reason: String)
## A hand moved to the next hold on the rock (every MOVE_LENGTH climbed):
## what kind of hold it took.
signal moved(hold: int)

enum State { GROUND, AIR, CLIMB, MANTLE, REST, SLIP, HELP, LOCKED, DONE }

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
## Multiplies climbing speed on the rock: the shoes (crag mode).
var pace := 1.0
## Seconds the arms hang on once stamina runs out on a face, before they
## let go (0: at once, as at the crag, where running out is the pump fall).
## While hanging on you can only go down or sideways, slowly.
var arms_grace := 0.0
## The cold: multiplies how fast you walk (Climate.pace).
var chill := 1.0
var _arms_out := 0.0
## True while hanging on with nothing left (for the HUD and the level).
var arms_failing := false
const SCRAMBLE_SPEED := 48.0
const FATIGUE_SLOW := 0.7
## A drop longer than this (4 tiles) is a slip, not a step down.
const SAFE_FALL := 4.0 * T
const SLIP_TIME := 1.0
const MANTLE_TIME := 0.45
const HELP_TIME := 1.2
## Standing in a gust: a nudge along the ledge, never a fall, and breath.
const GUST_PUSH := 10.0
const GUST_FIGHT := 6.0  # stamina per second, standing (not resting) in a gust
## Walking into a gust: you stagger, and it costs this much stamina. Only a
## stagger you have no stamina left for is a fall (back to the cairn).
const GUST_STAGGER := 10.0
## A hop: about two tiles up and two across at a walk. Not a leap; it is how
## you get over a boulder, a stream cut or a crack in the ice. It costs
## breath like a hard step, more in thin air.
const JUMP_SPEED := 265.0
const JUMP_COST := 2.0
const AIR_CONTROL := 260.0
## A dyno (the crag): a jump from the rock to a hold out of reach, across
## blank wall. Up about three tiles; costs a hard move's breath.
const DYNO_SPEED := 300.0
const DYNO_SIDE := 80.0
const DYNO_COST := 8.0

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
var jumps := 0
var last_activity := "still"
var spotter_caught_last := false
var helper_cost := 15.0
## Standing on ice: little grip, and the edge guard cannot hold you.
var on_ice := false
## Gear found on this attempt (the level sets these). Crampons: ice holds
## like rock and costs less. Wind shell (goggles and a buff): a gust pushes
## and costs less, and sitting on windy ground gives some breath back.
var crampons := false
var wind_shell := false
## A helmet: a falling stone costs stamina (Hazards.HELMET_HIT) instead of
## knocking you off.
var helmet := false
## Asked once per sit, the first moment it would refill you: true when this
## rest may (the expedition counts rests between cairns and then eats camp
## food). Not set (the crag): every rest refills.
var rest_gate: Callable
## The most one sit gives back (the fastest way: the starting quarter of
## the bar, ClimbLevel). Once it has, you stand up: sit again for more, and
## that is another rest. INF: no limit.
var rest_cap := INF
## True for a frame when a sit ran out at rest_cap (the level says so).
var rest_capped := false
var _sit_gain := 0.0
var _sit_refills := true
var _sit_asked := false
const ICE_ACCEL := 150.0
const ICE_DECEL := 70.0

## Stamina lost to thorns, bites and beaks on this climb.
var hurt_total := 0.0
## A moment after a hit when nothing else can hurt you.
const HURT_GUARD := 1.0
## Every hit is scaled by the route (Trek.hurt_factor): the long way's
## knocks hurt half as much.
var hurt_scale := 1.0
const HIT_MAX := 0.4
## What being knocked off costs, on top of the slip: taken off the bar you
## get back at the cairn (respawn).
const KNOCK := {"rock": 8.0, "fall": 8.0, "hole": 6.0, "slab": 6.0, "wind": 4.0}
var bruise := 0.0
var _hurt_cool := 0.0
## Being unwell, from the trek: a dizzy spell (half speed, the feet wander)
## or a cramp (doubled over: no walking, no hopping), seconds left of each.
var dizzy := 0.0
var cramp := 0.0
## The crag turns dynos on. In the air after one, the hands catch the first
## hold they reach.
var can_dyno := false
## Resting on the rope after a clip (the crag): holding still costs nothing.
var on_rope := false
## Asked when you come off (the fastest way's alpine pitches): true when a
## clipped piton holds the fall. A fall the rope holds is no slip, but the
## knock still hurts (the bruise), and you hang below the piton
## (Alpine.landing), not back at the cairn.
var rope_catch: Callable
var rope_falls := 0
## The slip under way is one the rope holds.
var on_belay_fall := false
var dynos := 0
## Hand moves made on the rock this climb.
var moves := 0
var _dyno_from := INF

var _timer := 0.0
var _mantle_from := Vector2.ZERO
var _mantle_to := Vector2.ZERO
var _step_distance := 0.0
var _move_distance := 0.0
## Each kind of hold has its own sound as a hand takes it.
const HOLD_SOUND := {Terrain.Kind.SLOPER: "sloper", Terrain.Kind.POCKET: "pocket", Terrain.Kind.JUG: "jug"}
## How far the hands travel between holds.
const MOVE_LENGTH := 9.0
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
	# A dark outline so people read against rock of any colour (the HD
	# sheets draw their own).
	if not Sheet.is_hd(Sheet.best(sprite.sprite_frames.get_frame_texture("idle", 0).atlas.resource_path)):
		var outline := ShaderMaterial.new()
		outline.shader = preload("res://core/world/outline.gdshader")
		sprite.material = outline
	add_child(sprite)
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 6.0
	floor_constant_speed = true
	safe_margin = 0.05


func body_rect(at: Vector2 = global_position) -> Rect2:
	return Rect2(at + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


## True when the floor under any part of the feet is `k`.
func _on_kind(k: int) -> bool:
	var feet := global_position + Vector2(0, 2)
	for dx in [-SIZE.x / 2.0 + 1.0, 0.0, SIZE.x / 2.0 - 1.0]:
		if terrain.kind(Terrain.cell_of(feet + Vector2(dx, 0))) == k:
			return true
	return false


func on_ground_cell() -> bool:
	var feet := global_position + Vector2(0, 2)
	for dx in [-SIZE.x / 2.0 + 1.0, 0.0, SIZE.x / 2.0 - 1.0]:
		if terrain.is_solid(Terrain.cell_of(feet + Vector2(dx, 0))):
			return true
	return false


func is_climbing() -> bool:
	return state == State.CLIMB or state == State.MANTLE


## Stops the climber for a panel. On the rock they stay on the rock: they
## hang where they are and are still holding on when it closes.
## In the middle of a move (falling, a slip, a mantle, helping) the moment
## is frozen instead, and carries on from where it was when the panel
## closes: a pause never cancels a fall or skips the walk back to a cairn.
func lock(on: bool) -> void:
	if on:
		if state != State.DONE and state != State.LOCKED:
			_before_lock = state
			_held_velocity = velocity
		if state != State.DONE:
			state = State.LOCKED
		if not _frozen():
			velocity.x = 0.0
	elif state == State.LOCKED:
		if _frozen():
			state = _before_lock
			velocity = _held_velocity
		else:
			state = State.CLIMB if _before_lock == State.CLIMB and terrain.touches_climbable(body_rect()) else State.GROUND
		_before_lock = State.GROUND


## Locked mid-move: held still, to carry on after.
func _frozen() -> bool:
	return state == State.LOCKED and _before_lock in [State.AIR, State.SLIP, State.MANTLE, State.HELP]


var _held_velocity := Vector2.ZERO


var _before_lock: int = State.GROUND


## Back at a cairn after a slip. A caught slip leaves more in the arms.
func respawn(feet: Vector2) -> void:
	arms_failing = false
	_arms_out = 0.0
	global_position = feet
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	state = State.GROUND
	fall_from = feet.y
	stamina.refill(0.75 if spotter_caught_last else 0.5)
	# Knocked off by a stone or a fall, it hurts: the bruise comes off what
	# you get back (never below a quarter of the bar).
	if bruise > 0.0:
		var hit := bruise * hurt_scale
		stamina.value = maxf(stamina.max_value * 0.25, stamina.value - hit)
		hurt_total += hit
		bruise = 0.0
	dizzy = 0.0
	cramp = 0.0
	spotter_caught_last = false


func _physics_process(delta: float) -> void:
	if terrain == null:
		return
	if state != State.LOCKED and state != State.DONE:
		clock += delta
		dizzy = maxf(0.0, dizzy - delta)
		cramp = maxf(0.0, cramp - delta)
	if _hurt_cool > 0.0:
		_hurt_cool = maxf(0.0, _hurt_cool - delta)
		sprite.modulate = Color(1, 0.55, 0.5) if fmod(_hurt_cool, 0.2) > 0.1 else Color.WHITE
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
		State.SLIP:
			_slip(delta)
		State.HELP:
			_help(delta)
		State.LOCKED, State.DONE:
			if state == State.LOCKED and (_before_lock == State.CLIMB or _frozen()):
				velocity = Vector2.ZERO
			else:
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
	if GameInput.pressed_now("rest"):
		state = State.REST
		_sit_asked = false
		_sit_gain = 0.0
		_sit_refills = true
		velocity.x = 0.0
		return
	if GameInput.pressed_now("jump") and cramp <= 0.0 and _jump():
		return
	on_ice = _on_kind(Terrain.Kind.ICE)
	# Crampons bite: ice is just steep snow, no sliding.
	var slick := on_ice and not crampons
	var limit := (EXPOSED_WALK if exposed else (TIRED_WALK if stamina.is_tired() else WALK)) * chill
	var target := input.x * limit
	# Standing in a gust: the wind walks you along slowly (the edge guard
	# below still holds you at a drop).
	if exposed and gust == WindSchedule.Phase.BLOW and absf(input.x) <= 0.2:
		target = GUST_PUSH * (0.4 if wind_shell else 1.0)
	if cramp > 0.0:
		target = 0.0
	elif dizzy > 0.0:
		target = target * 0.5 + sin(clock * 7.0) * 16.0
	var rate := ACCEL if absf(target) > absf(velocity.x) else DECEL
	if slick:
		rate = ICE_ACCEL if absf(target) > absf(velocity.x) and signf(target) == signf(velocity.x) else ICE_DECEL
		if velocity.x == 0.0 and target != 0.0:
			rate = ICE_ACCEL
	velocity.x = move_toward(velocity.x, target, rate * delta)
	# The edge guard: walking never carries you off a drop that would be a
	# slip. Going down is a choice (DOWN onto the rock), not a stumble.
	# Walking off a ledge onto a face grabs the face instead. On ice there
	# is no stopping at the edge: you slide.
	if absf(velocity.x) > 0.0 and drop_ahead(int(signf(velocity.x))):
		if _face_ahead(int(signf(velocity.x))):
			_grab()
			return
		if not slick:
			velocity.x = 0.0
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var before := global_position
	move_and_slide()
	var moving := absf(velocity.x) > 6.0
	last_activity = "still"
	if moving:
		last_activity = "ice" if on_ice else ("walk_up" if global_position.y < before.y - 0.15 else "walk")
	stamina.tick(delta, last_activity)
	_steps(before, delta)
	_weather(delta, input)
	if state != State.GROUND:
		return
	if not is_on_floor():
		state = State.AIR
		fall_from = global_position.y


## Hops, if there is breath for it. A hop on open ground in a gust is a slip.
func _jump() -> bool:
	# Hops come often; thin air makes them cost more, but not as much as walking.
	var cost := JUMP_COST * stamina.drain * (0.5 + 0.5 * stamina.thin_air)
	if stamina.value < cost:
		return false
	stamina.value -= cost
	if exposed and gust == WindSchedule.Phase.BLOW:
		wind_strikes += 1
		wind_struck.emit()
		slip("wind")
		return true
	velocity.y = -JUMP_SPEED
	# A hop from a standstill still goes the way you are pushing.
	# A hop has a little forward spring in it.
	var push := GameInput.move().x
	if absf(push) > 0.2:
		velocity.x = signf(push) * maxf(absf(velocity.x), (EXPOSED_WALK if exposed else WALK) * 1.15)
	state = State.AIR
	fall_from = global_position.y
	jumps += 1
	Audio.play("grip", -8.0)
	jumped.emit()
	return true


func _air(delta: float, input: Vector2) -> void:
	# Some steering in the air, as a walker leans; no speed is gained.
	var limit := (EXPOSED_WALK if exposed else WALK) * 1.15
	velocity.x = move_toward(velocity.x, input.x * limit, AIR_CONTROL * delta) if absf(input.x) > 0.2 else move_toward(velocity.x, 0.0, 120.0 * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	# A fall is measured from where the feet left the ground (a hop up and
	# down to the same level is no fall at all).
	# After a dyno the hands catch the first hold they reach, once clear of
	# the one they left (or on the way back down to it).
	if _dyno_from < INF:
		var risen := global_position.y < _dyno_from - 1.5 * T
		if (risen or velocity.y > 0.0) and terrain.hold_at(body_rect()) != Terrain.Kind.AIR:
			_dyno_from = INF
			_grab()
			return
	# Catching the rock on the way down: only from a short fall.
	_no_regrab = maxf(0.0, _no_regrab - delta)
	if _no_regrab <= 0.0 and input.y > 0.5 and terrain.touches_climbable(body_rect()) and global_position.y - fall_from < SAFE_FALL * 0.5 and not stamina.is_empty():
		_grab()
		return
	move_and_slide()
	if is_on_floor():
		_dyno_from = INF
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
	if _supported(at):
		return false
	# Overhanging an edge already (landed on a lip): stepping toward the
	# rock under the leading foot is stepping onto ground, not off it.
	var toe := Vector2i(Terrain.cell_of(Vector2(global_position.x + dir * SIZE.x / 2.0, 0)).x, at.y)
	return not _supported(toe)


func _supported(at: Vector2i) -> bool:
	for k in int(SAFE_FALL / T) + 1:
		if terrain.is_solid(at + Vector2i(0, k)):
			return true
	return false


## The climbable column under the hands nearest the body's centre, or -1.
## The rock above the hands in this column: rows to the top of the face,
## and how many of them are loose.
func face_above() -> Vector2i:
	var col := _hold_column()
	if col < 0:
		col = Terrain.cell_of(global_position).x
	var row := Terrain.cell_of(global_position + Vector2(0, -SIZE.y * 0.75)).y
	var rows := 0
	var loose := 0
	while row - rows >= 0 and terrain.is_climbable(Vector2i(col, row - rows)):
		if terrain.kind(Vector2i(col, row - rows)) == Terrain.Kind.LOOSE:
			loose += 1
		rows += 1
	return Vector2i(rows, loose)


func _hold_column() -> int:
	var hands := global_position + Vector2(0, -SIZE.y * 0.75)
	var here := Terrain.cell_of(hands)
	for dx in [0, 1, -1]:
		if terrain.is_climbable(here + Vector2i(dx, 0)):
			# The middle column of the face, when the face is wide.
			var c: int = here.x + dx
			if terrain.is_climbable(Vector2i(c - 1, here.y)) and terrain.is_climbable(Vector2i(c + 1, here.y)):
				return c
			if terrain.is_climbable(Vector2i(c + 1, here.y)) and not terrain.is_climbable(Vector2i(c - 1, here.y)):
				return c + 1
			if terrain.is_climbable(Vector2i(c - 1, here.y)) and not terrain.is_climbable(Vector2i(c + 1, here.y)):
				return c - 1
			return c
	return -1


## A boulder or step a hop clears: rock at the feet a step ahead, with room
## above it.
func hurdle_ahead(dir: int) -> bool:
	var feet := global_position + Vector2(dir * (SIZE.x / 2.0 + 2.0), -4.0)
	var c := Terrain.cell_of(feet)
	return terrain.is_solid(c) and not terrain.is_solid(c + Vector2i.UP) and not terrain.is_solid(c + Vector2i(0, -2))


## A gap a hop clears: a drop a step ahead, and floor again within reach.
func gap_ahead(dir: int, lead: float = 6.0) -> bool:
	var at := Vector2i(Terrain.cell_of(Vector2(global_position.x + dir * lead, 0)).x, Terrain.cell_of(global_position + Vector2(0, 2)).y)
	for k in int(SAFE_FALL / T) + 1:
		if terrain.is_solid(at + Vector2i(0, k)):
			return false
	for k in range(1, 4):
		if terrain.is_solid(at + Vector2i(dir * k, 0)) and not terrain.is_solid(at + Vector2i(dir * k, -1)):
			return true
	return false


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
	var speed_up := SCRAMBLE_SPEED if scrambling else CLIMB_UP * pace
	var speed_side := SCRAMBLE_SPEED * 0.8 if scrambling else CLIMB_SIDE * pace
	if stamina.is_tired():
		speed_up *= FATIGUE_SLOW
		speed_side *= FATIGUE_SLOW
	# The cold slows walking, not climbing: on a face the arms are the clock,
	# and a slower climb would cost more stamina than a bar can hold.
	if can_dyno and GameInput.pressed_now("jump") and stamina.value >= DYNO_COST:
		_dyno(input)
		return
	if arms_failing:
		# Nothing left: no pulling up; down, or slowly along.
		speed_side *= 0.5
	var want := Vector2(input.x * speed_side, -input.y * speed_up)
	if arms_failing and want.y < 0.0:
		want.y = 0.0
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
	# Snagged on a lip overhead at the edge of a face: ease toward the middle
	# of the rock, as hands find the next hold.
	if want.y < 0.0 and want.x == 0.0 and absf(global_position.y - before.y) < absf(want.y * delta) * 0.3:
		var col := _hold_column()
		if col >= 0:
			var mid := col * T + T / 2.0
			global_position.x = move_toward(global_position.x, mid, CLIMB_SIDE * delta)
	var moving := global_position.distance_to(before) > 0.05
	# Hold to hold: each reach is a move, with its own sound by the hold.
	_move_distance += global_position.distance_to(before)
	if _move_distance >= MOVE_LENGTH:
		_move_distance = 0.0
		moves += 1
		if not scrambling:
			var vol := {Terrain.Kind.CRIMP: -13.0, Terrain.Kind.JUG: -10.0, Terrain.Kind.SLOPER: -12.0, Terrain.Kind.POCKET: -12.0}.get(hold, -16.0) as float
			Audio.play(HOLD_SOUND.get(hold, "grip"), vol, 0.15)
		moved.emit(hold)
	var loose := terrain.kinds_in(body_rect()).has(Terrain.Kind.LOOSE)
	if loose:
		loose_seconds += delta
		if moving and randf() < delta * 0.8:
			Audio.play("rockfall", -14.0)
	if scrambling:
		last_activity = "scramble" if moving else "hang"
	elif hold == Terrain.Kind.CRIMP:
		last_activity = "crimp" if moving else "crimp_hang"
	elif hold == Terrain.Kind.SLOPER:
		last_activity = "sloper" if moving else "sloper_hang"
	elif hold == Terrain.Kind.POCKET and not moving:
		last_activity = "pocket"
	elif hold == Terrain.Kind.JUG and not moving:
		last_activity = "jug"
	elif moving and absf(want.x) > absf(want.y):
		last_activity = "traverse"
	else:
		last_activity = "climb" if moving else "hang"
	# Sitting back on the rope (the crag): the arms are off the rock.
	if not on_rope:
		stamina.tick(delta, last_activity, loose)
	_breathing(delta)
	if stamina.is_empty() and not on_rope:
		_arms_out += delta
		arms_failing = true
		if _arms_out >= arms_grace:
			arms_failing = false
			_arms_out = 0.0
			if arms_grace > 0.0 and not on_ground_cell():
				# The arms gave out: that is the fall, and it says why.
				_let_go()
				slip("arms")
				return
			_let_go()
			return
	else:
		_arms_out = 0.0
		arms_failing = false
	if not terrain.touches_climbable(body_rect()):
		_let_go()
		return
	if input.y < -0.5 and on_ground_cell():
		state = State.GROUND


func _dyno(input: Vector2) -> void:
	stamina.value -= DYNO_COST
	velocity = Vector2(signf(input.x) * DYNO_SIDE if absf(input.x) > 0.3 else 0.0, -DYNO_SPEED)
	state = State.AIR
	fall_from = global_position.y
	_dyno_from = global_position.y
	dynos += 1
	Audio.play("grip", -4.0)
	dynoed.emit()


## Hands off the rock (the crag: grip gone, or a dyno not stuck). They
## cannot snatch the rock again for a moment: a peel is a fall.
func peel_off() -> void:
	if is_climbing():
		_dyno_from = INF
		state = State.AIR
		fall_from = global_position.y
		velocity = Vector2.ZERO
		_no_regrab = PEEL_GUARD


const PEEL_GUARD := 0.35
var _no_regrab := 0.0


## Hanging on the rope at a bolt after a fall (the crag): back on the rock
## if there is rock to hold there.
func hang_at(feet: Vector2) -> void:
	respawn(feet)
	_dyno_from = INF
	if terrain.touches_climbable(body_rect()):
		state = State.CLIMB


func _let_go() -> void:
	arms_failing = false
	_arms_out = 0.0
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
	if not is_on_floor():
		state = State.AIR
		fall_from = global_position.y
		return
	rest_seconds += delta
	if _rest_stone:
		# A rest stone is shelter: always a full rest, and it never counts.
		last_activity = "rest_stone"
	elif exposed:
		# Hunkered down on windy ground: safe from gusts and free, never
		# moved, but the wind gives no breath back (a little with the
		# goggles and buff), and a gust costs a little while it blows.
		if wind_shell:
			last_activity = "rest_gust"
		elif gust == WindSchedule.Phase.BLOW:
			last_activity = "sit_gust"
		else:
			last_activity = "sit"
	else:
		if not _sit_asked and stamina.value < stamina.max_value:
			_sit_asked = true
			_sit_refills = rest_gate.call() if rest_gate.is_valid() else true
		last_activity = "rest" if _sit_refills else "sit"
	var had := stamina.value
	stamina.tick(delta, last_activity)
	_sit_gain += maxf(0.0, stamina.value - had)
	if _sit_gain >= rest_cap:
		# All one sit gives on this route: up you get.
		stamina.value -= _sit_gain - rest_cap
		_sit_gain = 0.0
		rest_capped = true
		state = State.GROUND
		return
	_weather(delta, Vector2.ZERO)
	if state == State.REST and (input.length() > 0.3 or GameInput.pressed_now("rest")):
		state = State.GROUND
	elif state == State.REST and GameInput.pressed_now("jump"):
		# Up and over in one go: a stone rolling at you while you sit.
		state = State.GROUND
		_jump()


func _weather(delta: float, input: Vector2) -> void:
	# Resting (REST) is how you sit out a gust: low and still, it cannot
	# take you.
	if not exposed or gust != WindSchedule.Phase.BLOW or state == State.REST:
		return
	var shell := 0.4 if wind_shell else 1.0
	# Only the player's own step counts as moving: a slide on ice, or the
	# wind's own nudge, is never held against you.
	if absf(input.x) > 0.2:
		if _hurt_cool <= 0.0:
			wind_strikes += 1
			wind_struck.emit()
		# A stagger: it stops you and costs breath; a fall only if that was
		# the last of it.
		velocity.x = 0.0
		hurt(GUST_STAGGER * shell, "wind")
		return
	# Standing in it: the nudge is in _ground (a slow drift the edge guard
	# still stops), and it costs breath.
	stamina.value = maxf(0.0, stamina.value - GUST_FIGHT * shell * delta)


## Something hurt you: it takes stamina, the one bar. Returns false when it
## could not (just hit, falling, done). A hit you have no stamina left for
## is a collapse, and that is a slip. The route scales every hit
## (hurt_scale: the long way's knocks hurt half as much).
func hurt(amount: float, reason: String) -> bool:
	if _hurt_cool > 0.0 or state in [State.SLIP, State.DONE, State.LOCKED]:
		return false
	_hurt_cool = HURT_GUARD
	# The route scales it; and no one hit takes more than HIT_MAX of the
	# bar, so the fastest way's quarter bar is never two nettles from empty.
	amount = minf(amount * hurt_scale, stamina.max_value * HIT_MAX)
	var spent := stamina.value <= amount
	stamina.value = maxf(0.0, stamina.value - amount)
	hurt_total += amount
	Audio.play("slip", -12.0)
	hurt_taken.emit(amount, reason)
	if spent:
		slip("wind" if reason == "wind" else "hurt")
	return true


## A slip: the next one is caught if a teammate is spotting you.
func slip(reason: String) -> void:
	if state == State.SLIP or state == State.DONE:
		return
	# Nobody can grab you out of a hole.
	var saved := spotter and reason != "hole"
	on_belay_fall = not saved and reason != "hole" and rope_catch.is_valid() and bool(rope_catch.call(reason))
	if on_belay_fall:
		rope_falls += 1
	elif saved:
		spotter = false
		caught += 1
		spotter_caught_last = true
	else:
		slips += 1
	bruise = float(KNOCK.get(reason, 0.0))
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
		_before_lock = State.GROUND
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
	# Under a quarter of the bar the breathing comes faster and carries
	# over the music: the arms are nearly gone.
	var f := stamina.fraction()
	var low := f < 0.25
	if _breath > (lerpf(0.9, 2.4, clampf(f / 0.25, 0.0, 1.0)) if low else 2.4):
		_breath = 0.0
		if low:
			Audio.play("breath", -16.0, 0.05, false)
		else:
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
			anim = "brace" if exposed and gust != WindSchedule.Phase.CALM else "rest"
		State.SLIP:
			anim = "slip"
		State.HELP:
			anim = "help"
		State.DONE:
			anim = "celebrate"
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = facing < 0
