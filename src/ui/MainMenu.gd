extends Control
## MainMenu — original UI. No copied layouts. Play + quality + sensitivity.

signal play_requested
signal host_requested
signal join_requested(ip: String)

@onready var _status: Label = $Panel/VBox/StatusLabel
@onready var _netstatus: Label = $Panel/VBox/NetStatus
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
	if has_node("/root/SaveSystem"):
		var sv0 := get_node("/root/SaveSystem")
		$Panel/VBox/MasterRow/MasterSlider.value = float(sv0.get("master_volume"))
		$Panel/VBox/SFXRow/SFXSlider.value = float(sv0.get("sfx_volume"))
	$Panel/VBox/MasterRow/MasterSlider.value_changed.connect(_on_vol.bind("master_volume", "master"))
	$Panel/VBox/SFXRow/SFXSlider.value_changed.connect(_on_vol.bind("sfx_volume", "sfx"))
	_status.text = "OFFLINE MATCH — 12 combatants, shrinking zone"
	$Panel/VBox/PlayButton.pressed.connect(_on_play)
	$Panel/VBox/NetRow/HostBtn.pressed.connect(func() -> void: emit_signal("host_requested"))
	$Panel/VBox/NetRow/JoinBtn.pressed.connect(_on_join)
	_refresh_net()
	_quality.item_selected.connect(_on_quality)
	_sens.value_changed.connect(_on_sens)

func _refresh_net() -> void:
	var n = get_tree().get_first_node_in_group("network_manager")
	if n:
		_netstatus.text = str(n.get("status_text"))
		if not n.is_connected("status_changed", _on_net_status):
			n.connect("status_changed", _on_net_status)

func _on_net_status(t: String) -> void:
	_netstatus.text = t

func _on_join() -> void:
	emit_signal("join_requested", $Panel/VBox/NetRow/IPEdit.text)

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

func _on_vol(v: float, key: String, _bus: String) -> void:
	if has_node("/root/SaveSystem"):
		var sv := get_node("/root/SaveSystem")
		sv.set(key, v)
		sv.call("save_settings")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").call("apply_volumes")
		get_node("/root/AudioManager").call("play_ui")
