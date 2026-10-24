class_name Companion
extends Node2D
## A teammate on the mountain. The foundation for people rather than stat
## modifiers: a state (waiting for help, climbing with you, left for Lena,
## or at camp), a condition, and how they regard you. Only Marco's problem
## on the wall uses it so far.
##
## A helped companion follows the climber's own path a moment behind, so
## they walk, scramble and climb exactly where the player did.

enum State { CAMP, WAITING, FOLLOWING, LEFT, WINDED }

const DELAY_FRAMES := 42

@export var person := "marco"
var state: int = State.CAMP
## 0–100, the start of a relationship model: trust grows when you stop for
## someone and falls when you leave them.
var trust := 60
var condition := 70
var idle_anim := "idle"
var sprite: AnimatedSprite2D
## Drawn with your rig (FeatureFlags.hero_in_climbs); the sprite runs
## unseen and this follows it.
var hero: Hero
var _trail: Array = []


func _ready() -> void:
	sprite = Sheet.sprite("res://assets/characters/%s.png" % person)
	# A dark outline so people read against rock of any colour (the HD
	# sheets draw their own).
	if not Sheet.is_hd(Sheet.best(sprite.sprite_frames.get_frame_texture("idle", 0).atlas.resource_path)):
		var outline := ShaderMaterial.new()
		outline.shader = preload("res://core/world/outline.gdshader")
		sprite.material = outline
	add_child(sprite)
	sprite.play(idle_anim)
	if FeatureFlags.hero_in_climbs and not TeamLooks.look(person).is_empty():
		hero = Hero.new()
		hero.height = Climber.HERO_HEIGHT
		hero.set_look(TeamLooks.look(person))
		hero.phase = float(person.length())
		add_child(hero)
		sprite.visible = false


func _process(_delta: float) -> void:
	if hero:
		hero.follow(sprite)


func set_waiting() -> void:
	state = State.WAITING
	idle_anim = "hang"
	sprite.play("hang")


func helped() -> void:
	state = State.FOLLOWING
	trust = mini(100, trust + 15)
	_trail.clear()


## Out of breath: sits where they are until you come back and rest with them.
func winded() -> void:
	state = State.WINDED
	_trail.clear()
	sprite.play("rest")


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
