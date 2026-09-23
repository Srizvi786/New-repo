extends Control
## MainMenu — original UI. No copied layouts. Play + quality + sensitivity.

signal play_requested

@onready var _status: Label = $Panel/VBox/StatusLabel
@onready var _quality: OptionButton = $Panel/VBox/QualityRow/QualityOption
@onready var _sens: HSlider = $Panel/VBox/SensRow/SensSlider

func _ready() -> void:
	_quality.clear()
	_quality.add_item("Auto", 0)
	_quality.add_item("Low", 1)
	_quality.add_item("Medium", 2)
	_quality.add_item("High", 3)
	var preset := "auto"
	var sens := 1.0
	if has_node("/root/SaveSystem"):
		preset = str(get_node("/root/SaveSystem").get("graphics_preset"))
		sens = float(get_node("/root/SaveSystem").get("sensitivity"))
	_quality.select({"auto": 0, "low": 1, "medium": 2, "high": 3}.get(preset, 0))
	_sens.value = sens
	_status.text = "OFFLINE BUILD M1 — bots/match arrive in M7/M8"
	$Panel/VBox/PlayButton.pressed.connect(_on_play)
	_quality.item_selected.connect(_on_quality)
	_sens.value_changed.connect(_on_sens)

func _on_play() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").call("play_ui")
	emit_signal("play_requested")

func _on_quality(idx: int) -> void:
	if not has_node("/root/SaveSystem"):
		return
	var sv := get_node("/root/SaveSystem")
	sv.set("graphics_preset", ["auto", "low", "medium", "high"][idx])
	sv.call("save_settings")
	if has_node("/root/QualityManager"):
		var qm := get_node("/root/QualityManager")
		if idx == 0:
			qm.call("apply_preset", qm.call("auto_detect"))
		else:
			qm.call("apply_preset", idx - 1)

func _on_sens(v: float) -> void:
	if has_node("/root/SaveSystem"):
		var sv := get_node("/root/SaveSystem")
		sv.set("sensitivity", v)
		sv.call("save_settings")
