class_name Companion
extends Node2D
## A teammate on the mountain. The foundation for people rather than stat
## modifiers: a state (waiting for help, climbing with you, left for Lena,
## or at camp), a condition, and how they regard you. Only Marco's problem
## on the wall uses it so far.
##
## A helped companion follows the climber's own path a moment behind, so
## they walk, scramble and climb exactly where the player did.

enum State { CAMP, WAITING, FOLLOWING, LEFT }

const DELAY_FRAMES := 42

@export var person := "marco"
var state: int = State.CAMP
## 0–100, the start of a relationship model: trust grows when you stop for
## someone and falls when you leave them.
var trust := 60
var condition := 70
var idle_anim := "idle"
var sprite: AnimatedSprite2D
var _trail: Array = []


func _ready() -> void:
	sprite = Sheet.sprite("res://assets/characters/%s.png" % person)
	add_child(sprite)
	sprite.play(idle_anim)


func set_waiting() -> void:
	state = State.WAITING
	idle_anim = "hang"
	sprite.play("hang")


func helped() -> void:
	state = State.FOLLOWING
	trust = mini(100, trust + 15)
	_trail.clear()


func left_behind() -> void:
	state = State.LEFT
	trust = maxi(0, trust - 20)
	sprite.play("rest")


## Called every physics frame with where the climber is and what they do.
func record(feet: Vector2, anim: String, flip: bool) -> void:
	if state != State.FOLLOWING:
		return
	_trail.append([feet, anim, flip])
	if _trail.size() > DELAY_FRAMES:
		var step: Array = _trail.pop_front()
		global_position = step[0] + Vector2(-6.0 if not step[2] else 6.0, 0.0)
		var anim_name: String = step[1]
		if anim_name == "slip" or anim_name == "mantle":
			anim_name = "climb"
		if sprite.animation != anim_name:
			sprite.play(anim_name)
		sprite.flip_h = step[2]


func catch_up(feet: Vector2) -> void:
	_trail.clear()
	global_position = feet + Vector2(-10, 0)
	reset_physics_interpolation()
