extends Node
## Input abstraction (autoload `GameInput`). Gameplay reads actions only,
## never raw keys, so keyboard, gamepad and the touch overlay are
## interchangeable. Actions are registered here in code, which keeps the
## bindings readable and in one place.

const ACTIONS := {
	"move_left": [KEY_LEFT, KEY_A],
	"move_right": [KEY_RIGHT, KEY_D],
	"climb_up": [KEY_UP, KEY_W],
	"climb_down": [KEY_DOWN, KEY_S],
	"interact": [KEY_E, KEY_SPACE, KEY_ENTER],
	"brace": [KEY_SHIFT, KEY_B],
	"rest": [KEY_R],
	"pause": [KEY_ESCAPE, KEY_P],
}

const PAD := {
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"climb_up": [JOY_BUTTON_DPAD_UP],
	"climb_down": [JOY_BUTTON_DPAD_DOWN],
	"interact": [JOY_BUTTON_A],
	"brace": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER],
	"rest": [JOY_BUTTON_Y],
	"pause": [JOY_BUTTON_START],
}

const STICK := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"climb_up": [JOY_AXIS_LEFT_Y, -1.0],
	"climb_down": [JOY_AXIS_LEFT_Y, 1.0],
}

## Set by tests and the replay tool: when not empty, these override devices.
var scripted: Dictionary = {}
## The touch stick, -1 … 1 on both axes (up is +y). Analog: a small push
## walks slowly.
var touch_move := Vector2.ZERO


func _enter_tree() -> void:
	register()


static func register() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		InputMap.action_erase_events(action)
		for key in ACTIONS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)
		for button in PAD.get(action, []):
			var b := InputEventJoypadButton.new()
			b.button_index = button
			InputMap.action_add_event(action, b)
		if STICK.has(action):
			var m := InputEventJoypadMotion.new()
			m.axis = STICK[action][0]
			m.axis_value = STICK[action][1]
			InputMap.action_add_event(action, m)


func held(action: String) -> bool:
	if not scripted.is_empty():
		return scripted.get(action, false)
	return Input.is_action_pressed(action)


## -1 … 1 across, -1 (down) … 1 (up).
func move() -> Vector2:
	var x := (1.0 if held("move_right") else 0.0) - (1.0 if held("move_left") else 0.0)
	var y := (1.0 if held("climb_up") else 0.0) - (1.0 if held("climb_down") else 0.0)
	if scripted.is_empty() and touch_move != Vector2.ZERO and x == 0.0 and y == 0.0:
		return touch_move
	return Vector2(x, y)


## Edge-triggered press, for menus and one-off actions.
var _was: Dictionary = {}


func pressed_now(action: String) -> bool:
	var now := held(action)
	var before: bool = _was.get(action, false)
	_was[action] = now
	return now and not before
