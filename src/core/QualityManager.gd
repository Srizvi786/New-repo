extends Node
## QualityManager (autoload) — LOW / MEDIUM / HIGH + auto-detect.
## Android-first: Compatibility renderer, cheap fog, capped shadows.

enum Preset { LOW, MEDIUM, HIGH }

var current: int = Preset.MEDIUM
var applied_scale: float = 0.85

signal preset_applied(preset: int)

func _ready() -> void:
	var want := "auto"
	if has_node("/root/SaveSystem"):
		want = str(get_node("/root/SaveSystem").get("graphics_preset"))
	if want == "low":
		apply_preset(Preset.LOW)
	elif want == "high":
		apply_preset(Preset.HIGH)
	elif want == "medium":
		apply_preset(Preset.MEDIUM)
	else:
		apply_preset(auto_detect())

func auto_detect() -> int:
	# Heuristic, free and offline. Never promises FPS.
	var cores: int = OS.get_processor_count()
	var mem_mb: float = 2048.0
	var mi := OS.get_memory_info()
	if mi.has("physical"):
		mem_mb = float(mi["physical"]) / 1048576.0
	elif mi.has("free"):
		mem_mb = float(mi["free"]) / 1048576.0 + 1024.0
	var model := OS.get_model_name().to_lower()
	var low_hints := ["mali-t", "adreno 5", "adreno 6", "helio", "exynos 7", "2gb", "3gb"]
	for h in low_hints:
		if h in model:
			return Preset.LOW
	if mem_mb < 3000.0 or cores <= 4:
		return Preset.LOW
	if mem_mb < 5000.0 or cores <= 6:
		return Preset.MEDIUM
	return Preset.HIGH

func apply_preset(p: int) -> void:
	current = p
	var vp := get_viewport()
	match p:
		Preset.LOW:
			applied_scale = 0.7
			if vp:
				vp.scaling_3d_scale = 0.7
				vp.msaa_3d = Viewport.MSAA_DISABLED
		Preset.MEDIUM:
			applied_scale = 0.85
			if vp:
				vp.scaling_3d_scale = 0.85
				vp.msaa_3d = Viewport.MSAA_2X
		Preset.HIGH:
			applied_scale = 1.0
			if vp:
				vp.scaling_3d_scale = 1.0
				vp.msaa_3d = Viewport.MSAA_2X
	emit_signal("preset_applied", current)

func apply_to_camera(cam: Camera3D) -> void:
	if cam == null:
		return
	match current:
		Preset.LOW:
			cam.far = 150.0
		Preset.MEDIUM:
			cam.far = 250.0
		Preset.HIGH:
			cam.far = 400.0

func apply_to_light(sun: DirectionalLight3D) -> void:
	if sun == null:
		return
	match current:
		Preset.LOW:
			sun.shadow_enabled = false
			sun.directional_shadow_max_distance = 30.0
		Preset.MEDIUM:
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 60.0
			sun.shadow_blur = 1.0
		Preset.HIGH:
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 100.0
			sun.shadow_blur = 2.0
