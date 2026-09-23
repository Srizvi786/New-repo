extends Node
## SaveSystem (autoload) — persists user prefs only. Never stores secrets.
## File: user://dustline_save.cfg

const SAVE_PATH := "user://dustline_save.cfg"

var sensitivity: float = 1.0
var ads_sensitivity: float = 0.8
var graphics_preset: String = "auto" # auto | low | medium | high
var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.9
var joystick_size: float = 1.0
var gyro_enabled: bool = false

signal loaded
signal saved

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		emit_signal("loaded")
		return
	sensitivity = float(cfg.get_value("controls", "sensitivity", 1.0))
	ads_sensitivity = float(cfg.get_value("controls", "ads_sensitivity", 0.8))
	graphics_preset = str(cfg.get_value("graphics", "preset", "auto"))
	master_volume = float(cfg.get_value("audio", "master", 0.8))
	music_volume = float(cfg.get_value("audio", "music", 0.6))
	sfx_volume = float(cfg.get_value("audio", "sfx", 0.9))
	joystick_size = float(cfg.get_value("controls", "joystick_size", 1.0))
	gyro_enabled = bool(cfg.get_value("controls", "gyro", false))
	emit_signal("loaded")

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "sensitivity", sensitivity)
	cfg.set_value("controls", "ads_sensitivity", ads_sensitivity)
	cfg.set_value("controls", "joystick_size", joystick_size)
	cfg.set_value("controls", "gyro", gyro_enabled)
	cfg.set_value("graphics", "preset", graphics_preset)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SAVE_PATH)
	emit_signal("saved")
