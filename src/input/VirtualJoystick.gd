extends Control
## TouchStick (VirtualJoystick.gd) — left-half movement stick. Mouse + touch. Anchor-based, scalable.
class_name TouchStick

signal changed(value: Vector2)

@export var radius: float = 110.0
var value: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _mouse_active: bool = false
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO

var _base: Control
var _knob_ctrl: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base = Control.new()
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_base)
	_knob_ctrl = Control.new()
	_knob_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_knob_ctrl)
	set_process(true)

func set_size_scale(s: float) -> void:
	radius = 110.0 * s
	queue_redraw()

func _gui_input(_event: InputEvent) -> void:
	pass

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var half := get_viewport_rect().size.x * 0.45
		if t.pressed and _touch_index == -1 and t.position.x < half and t.position.y > get_viewport_rect().size.y * 0.35:
			_touch_index = t.index
			_center = t.position
			_knob = t.position
			_update_value()
			get_viewport().set_input_as_handled()
		elif not t.pressed and t.index == _touch_index:
			_touch_index = -1
			value = Vector2.ZERO
			emit_signal("changed", value)
			queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			_knob = d.position
			_update_value()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var half := get_viewport_rect().size.x * 0.45
			if mb.pressed and not _mouse_active and mb.position.x < half and mb.position.y > get_viewport_rect().size.y * 0.35 and _touch_index == -1:
				# Only capture mouse joystick when touch emulation is likely (editor test).
				# Desktop WASD remains primary; this is a fallback for testing.
				_mouse_active = true
				_center = mb.position
				_knob = mb.position
				_update_value()
			elif not mb.pressed and _mouse_active:
				_mouse_active = false
				value = Vector2.ZERO
				emit_signal("changed", value)
				queue_redraw()
	elif event is InputEventMouseMotion:
		if _mouse_active:
			_knob = (event as InputEventMouseMotion).position
			_update_value()

func _update_value() -> void:
	var d := _knob - _center
	if d.length() > radius:
		d = d.normalized() * radius
		_knob = _center + d
	value = Vector2(d.x / radius, d.y / radius)
	# Screen up = forward (-y). Keep as-is; Player maps y->forward.
	emit_signal("changed", value)
	queue_redraw()

func _screen_to_local(p: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * p

func _draw() -> void:
	if _touch_index == -1 and not _mouse_active:
		return
	draw_circle(_screen_to_local(_center), radius, Color(1, 1, 1, 0.10))
	draw_arc(_screen_to_local(_center), radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(_screen_to_local(_knob), radius * 0.35, Color(1, 1, 1, 0.35))
