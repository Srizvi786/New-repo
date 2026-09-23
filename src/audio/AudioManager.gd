extends Node
## AudioManager — bus layout + hooks. Real clips land in M3/M6; M1 uses tiny synth blips.
## Buses: Master / SFX / UI / Ambience. Volumes persisted via SaveSystem.

var _sfx: AudioStreamPlayer
var _ui: AudioStreamPlayer
var _shot_noise: AudioStreamWAV

func _ready() -> void:
	_ensure_buses()
	_shot_noise = _noise_burst(0.12, 2200.0)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "SFX"
	_sfx.bus = "SFX"
	_sfx.stream = _shot_noise
	add_child(_sfx)
	_ui = AudioStreamPlayer.new()
	_ui.name = "UI"
	_ui.bus = "UI"
	_ui.stream = _blip(880.0, 0.07)
	add_child(_ui)
	apply_volumes()

func _ensure_buses() -> void:
	for b in ["SFX", "UI", "Ambience"]:
		if AudioServer.bus_count <= 4 or AudioServer.get_bus_index(b) == -1:
			if AudioServer.get_bus_index(b) == -1:
				AudioServer.add_bus()
				AudioServer.set_bus_name(AudioServer.bus_count - 1, b)

func apply_volumes() -> void:
	if not has_node("/root/SaveSystem"):
		return
	var sv := get_node("/root/SaveSystem")
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(sv.get("master_volume")), 0.01, 1.0)))
	var sfx_i := AudioServer.get_bus_index("SFX")
	if sfx_i != -1:
		AudioServer.set_bus_volume_db(sfx_i, linear_to_db(clampf(float(sv.get("sfx_volume")), 0.01, 1.0)))

func play_ui() -> void:
	if _ui and not _ui.playing:
		_ui.play()

func play_gunshot(pitch: float = 1.0) -> void:
	_sfx.stream = _shot_noise
	_sfx.pitch_scale = pitch * randf_range(0.97, 1.03)
	_sfx.play()

func play_reload() -> void:
	_sfx.stream = _blip(330.0, 0.12)
	_sfx.pitch_scale = 1.0
	_sfx.play()

func play_hit(head: bool = false) -> void:
	_sfx.stream = _blip(1200.0 if head else 700.0, 0.06)
	_sfx.pitch_scale = 1.0
	_sfx.play()

func play_footstep() -> void:
	pass # hooked by Player anim events in M2

func _blip(freq: float, dur: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var d := PackedByteArray()
	d.resize(n)
	for i in range(n):
		var t := float(i) / rate
		var v := sin(TAU * freq * t) * (1.0 - float(i) / n)
		d[i] = int(clampf(v * 60.0 + 128.0, 0, 255))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_8_BITS
	s.mix_rate = rate
	s.data = d
	return s

func _noise_burst(dur: float, cutoff: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var d := PackedByteArray()
	d.resize(n)
	var last := 0.0
	var alpha: float = clampf(cutoff / rate, 0.05, 1.0)
	for i in range(n):
		var w := randf_range(-1.0, 1.0)
		last = last + alpha * (w - last)
		var env := 1.0 - float(i) / n
		d[i] = int(clampf(last * 90.0 * env + 128.0, 0, 255))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_8_BITS
	s.mix_rate = rate
	s.data = d
	return s
