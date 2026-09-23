extends Control
## Results — VICTORY / DEFEAT screen with stats. Original layout.
signal replay_requested
signal menu_requested

@onready var _title: Label = $Dim/Center/VBox/Title
@onready var _stats: Label = $Dim/Center/VBox/Stats

func _ready() -> void:
	$Dim/Center/VBox/Buttons/Again.pressed.connect(func() -> void: emit_signal("replay_requested"))
	$Dim/Center/VBox/Buttons/Menu.pressed.connect(func() -> void: emit_signal("menu_requested"))

func show_result(r: Dictionary) -> void:
	visible = true
	if bool(r.get("victory", false)):
		_title.text = "VICTORY  #1"
		_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
	else:
		_title.text = "DEFEAT  #%d" % int(r.get("placement", 12))
		_title.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3))
	_stats.text = "Kills: %d\nSurvived: %s\nCombatants left: %d" % [
		int(r.get("kills", 0)), str(r.get("time", "00:00")), int(r.get("alive", 0))]
