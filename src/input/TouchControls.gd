extends Control
## TouchControls — mobile buttons + look-drag + joystick wiring.
## Anchor-based layout (see .tscn). Desktop hides this; touch shows it.

@onready var joystick: Control = $Joystick
@onready var look_area: Control = $LookArea

var input_mgr: Node = null
var _look_touch: int = -1
var _look_last: Vector2 = Vector2.ZERO

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if look_area:
		look_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Joystick -> InputManager
	if joystick and joystick.has_signal("changed"):
		joystick.connect("changed", _on_joy_changed)
	_wire_button($BtnFire, "fire")
	_wire_button($BtnAim, "aim")
	_wire_button($BtnJump, "jump")
	_wire_button($BtnCrouch, "crouch")
	_wire_button($BtnSprint, "sprint")
	_wire_button($BtnReload, "reload")
	_wire_button($BtnSwap, "slot_next")
	# Auto-show on real touch devices
	if DisplayServer.is_touchscreen_available():
		visible = true

func bind_manager(mgr: Node) -> void:
	input_mgr = mgr
	if input_mgr and "look_sensitivity" in input_mgr and has_node("/root/SaveSystem"):
		input_mgr.set("look_sensitivity", float(get_node("/root/SaveSystem").get("sensitivity")))
	if joystick and joystick.has_method("set_size_scale") and has_node("/root/SaveSystem"):
		joystick.call("set_size_scale", float(get_node("/root/SaveSystem").get("joystick_size")))

func _wire_button(btn: Button, action: String) -> void:
	if btn == null:
		return
	btn.button_down.connect(_on_btn_down.bind(action))
	btn.button_up.connect(_on_btn_up.bind(action))

func _on_joy_changed(v: Vector2) -> void:
	if input_mgr:
		# Joystick up (negative y) = forward. InputManager expects x right, y back(+).
		input_mgr.set("touch_move", v)

func _on_btn_down(action: String) -> void:
	if input_mgr == null:
		return
	match action:
		"fire":
			input_mgr.set("touch_fire_held", true)
		"aim":
			input_mgr.set("touch_aim_held", true)
		"sprint":
			input_mgr.set("touch_sprint_held", true)
		"jump", "crouch", "reload", "slot_next":
			Input.action_press(action)

func _on_btn_up(action: String) -> void:
	if input_mgr == null:
		return
	match action:
		"fire":
			input_mgr.set("touch_fire_held", false)
		"aim":
			input_mgr.set("touch_aim_held", false)
		"sprint":
			input_mgr.set("touch_sprint_held", false)
		"jump", "crouch", "reload", "slot_next":
			Input.action_release(action)

func _input(event: InputEvent) -> void:
	if not visible or input_mgr == null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _look_touch == -1 and t.position.x > get_viewport_rect().size.x * 0.4:
			# Ignore presses that started on buttons (they handle themselves).
			_look_touch = t.index
			_look_last = t.position
		elif not t.pressed and t.index == _look_touch:
			_look_touch = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _look_touch:
			var delta := d.position - _look_last
			_look_last = d.position
			var sens: float = float(input_mgr.get("look_sensitivity"))
			input_mgr.call("add_touch_look", delta * sens)
	elif event is InputEventMouseMotion and Input.is_action_pressed("aim") == false:
		# Desktop look is handled by Player capture; nothing here.
		pass
