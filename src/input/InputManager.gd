extends Node
## InputManager — owns InputMap actions + merges keyboard/mouse, touch, gyro stubs.
## All gameplay reads input through here so touch/desktop stay in sync.
class_name InputManager

signal fire_pressed
signal reload_pressed
signal jump_pressed

var touch_move: Vector2 = Vector2.ZERO      # set by VirtualJoystick (-1..1)
var touch_look_delta: Vector2 = Vector2.ZERO # accumulated by TouchControls look area
var touch_fire_held: bool = false
var touch_aim_held: bool = false
var touch_sprint_held: bool = false

var look_sensitivity: float = 1.0

func _ready() -> void:
	ensure_actions()
	if has_node("/root/SaveSystem"):
		look_sensitivity = float(get_node("/root/SaveSystem").get("sensitivity"))

func ensure_actions() -> void:
	_add_key("move_forward", [KEY_W, KEY_UP])
	_add_key("move_back", [KEY_S, KEY_DOWN])
	_add_key("move_left", [KEY_A, KEY_LEFT])
	_add_key("move_right", [KEY_D, KEY_RIGHT])
	_add_key("jump", [KEY_SPACE])
	_add_key("crouch", [KEY_C, KEY_CTRL])
	_add_key("sprint", [KEY_SHIFT])
	_add_key("reload", [KEY_R])
	_add_key("interact", [KEY_E, KEY_F])
	_add_key("inventory", [KEY_I, KEY_TAB])
	_add_key("map", [KEY_M])
	_add_key("heal", [KEY_H])
	_add_mouse("fire", MOUSE_BUTTON_LEFT)
	_add_mouse("aim", MOUSE_BUTTON_RIGHT)
	_add_key("pause", [KEY_ESCAPE, KEY_P])
	_add_joy("jump", JOY_BUTTON_A)
	_add_joy("crouch", JOY_BUTTON_B)
	_add_joy("reload", JOY_BUTTON_X)
	_add_joy("interact", JOY_BUTTON_Y)

func _add_key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var exists := false
		for e in InputMap.action_get_events(action):
			if e is InputEventKey and (e as InputEventKey).physical_keycode == k:
				exists = true
		if not exists:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for e in InputMap.action_get_events(action):
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == button:
			return
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _add_joy(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func get_move_vector() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	v += touch_move
	return v.limit_length(1.0)

func is_sprinting() -> bool:
	return Input.is_action_pressed("sprint") or touch_sprint_held

func is_aiming() -> bool:
	return Input.is_action_pressed("aim") or touch_aim_held

func is_firing() -> bool:
	return Input.is_action_pressed("fire") or touch_fire_held

func consume_look_delta() -> Vector2:
	# Mouse motion is fed directly by Player via _input; this drains touch remainder.
	var d := touch_look_delta
	touch_look_delta = Vector2.ZERO
	return d

func add_touch_look(delta_px: Vector2) -> void:
	touch_look_delta += delta_px
