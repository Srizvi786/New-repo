extends Node
## PerformanceMonitor — dev-only panel. Toggle with F3 or 3-finger touch hold.
## Shows FPS, frame ms, memory, draw calls, physics, objects.

var _layer: CanvasLayer
var _label: Label
var _visible_panel: bool = false
var _timer: float = 0.0
var _touch_points: Dictionary = {}
var _touch_hold: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 99
	add_child(_layer)
	_label = Label.new()
	_label.visible = false
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(8)
	_label.add_theme_stylebox_override("normal", bg)
	_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_label.position = Vector2(10, 10)
	_label.custom_minimum_size = Vector2(280, 0)
	_layer.add_child(_label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.physical_keycode == KEY_F3:
			toggle()
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_points[t.index] = true
		else:
			_touch_points.erase(t.index)
			_touch_hold = 0.0

func _process(delta: float) -> void:
	if _touch_points.size() >= 3:
		_touch_hold += delta
		if _touch_hold > 0.5:
			toggle()
			_touch_hold = 0.0
			_touch_points.clear()
	_timer += delta
	if _timer < 0.5 or not _label.visible:
		return
	_timer = 0.0
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var mem_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objs := Performance.get_monitor(Performance.OBJECT_COUNT)
	var bots := get_tree().get_nodes_in_group("bots").size()
	_label.text = "PERF (dev)\nFPS: %d\nframe: %.2f ms\nphys: %.2f ms\nmem: %.1f MB\ndraws: %d\nobjects: %d\nbots: %d" % [int(fps), proc_ms, phys_ms, mem_mb, int(draws), int(objs), bots]

func toggle() -> void:
	_visible_panel = not _visible_panel
	if _label:
		_label.visible = _visible_panel
