class_name Sheet
extends RefCounted
## SpriteFrames from a party sheet written by tools/art/characters.py:
## 32 × 40 frames, 8 columns, feet at (16, 40). The clip table matches
## CLIMBER_CLIPS in src/features/climbing/sprites.ts, so both engines show
## the same frames for the same pose.

const FRAME := Vector2i(32, 40)
const COLUMNS := 8

## name: [frames, frames per second, loops]
const CLIPS := {
	"idle": [[0, 1], 1.7, true],
	"walk": [[2, 3, 4, 5], 8.3, true],
	"tired": [[23, 24, 25, 26], 5.3, true],
	"climb": [[6, 7, 8, 9], 5.9, true],
	"scramble": [[6, 7, 8, 9], 9.0, true],
	"mantle": [[7, 8, 9, 21], 9.0, false],
	"hang": [[10, 11], 1.9, true],
	"fall": [[12, 13], 11.0, true],
	"slip": [[12, 13, 14, 15, 15, 15], 6.0, false],
	"rest": [[16, 17], 1.3, true],
	"brace": [[18], 1.0, true],
	"help": [[19, 20], 3.8, true],
	"celebrate": [[21, 22], 3.3, true],
}

static var _cache: Dictionary = {}


static func frames(path: String) -> SpriteFrames:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = load(path)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for name in CLIPS:
		var clip: Array = CLIPS[name]
		sf.add_animation(name)
		sf.set_animation_speed(name, clip[1])
		sf.set_animation_loop(name, clip[2])
		for index in clip[0]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2((index % COLUMNS) * FRAME.x, (index / COLUMNS) * FRAME.y, FRAME.x, FRAME.y)
			sf.add_frame(name, a)
	_cache[path] = sf
	return sf


## An AnimatedSprite2D whose origin is the figure's feet.
static func sprite(path: String) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(path)
	s.centered = true
	s.offset = Vector2(0, -FRAME.y / 2.0)
	s.animation = "idle"
	s.play()
	return s
