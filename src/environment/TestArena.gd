extends Node3D
## TestArena — M1 procedural playground (100x100m). Real map lands in M6.
## PBR ground, scattered cover, sky/sun/fog tuned for Compatibility renderer.

func _ready() -> void:
	_build_sky()
	_build_ground()
	_build_cover()
	if has_node("/root/QualityManager"):
		var sun := $Sun as DirectionalLight3D
		get_node("/root/QualityManager").call("apply_to_light", sun)

func get_spawn_transform() -> Transform3D:
	var m := $SpawnPoint as Marker3D
	if m:
		return m.global_transform
	return Transform3D(Basis(), Vector3(0, 1.2, 6))

func _build_sky() -> void:
	var we := $WorldEnvironment as WorldEnvironment
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.35, 0.52, 0.72)
	mat.sky_horizon_color = Color(0.75, 0.72, 0.62) # dusty horizon fits "Dustline"
	mat.ground_bottom_color = Color(0.3, 0.26, 0.2)
	mat.ground_horizon_color = Color(0.65, 0.6, 0.5)
	mat.sun_angle_max = 12.0
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.68, 0.58)
	env.fog_density = 0.008
	env.fog_sky_affect = 0.4
	env.ssao_enabled = false # off on mobile for perf
	we.environment = env
	var sun := $Sun as DirectionalLight3D
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.95, 0.87)
	sun.shadow_enabled = true

func _ground_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.48, 0.36) # dry dust
	m.roughness = 0.95
	m.metallic = 0.0
	# Cheap procedural detail: UV-scaled noise would need a shader; M1 uses flat PBR + props.
	return m

func _concrete_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.52, 0.52, 0.5)
	m.roughness = 0.9
	return m

func _crate_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 0.34, 0.22)
	m.roughness = 0.85
	return m

func _build_ground() -> void:
	var body := $Ground as StaticBody3D
	var mi := $Ground/GroundMesh as MeshInstance3D
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	pm.material = _ground_mat()
	mi.mesh = pm
	var col := $Ground/GroundCol as CollisionShape3D
	var shape := BoxShape3D.new()
	shape.size = Vector3(120, 1, 120)
	col.shape = shape
	col.position.y = -0.5
	# Outer skirt walls (keep player in for M1).
	for i in range(4):
		var wall := StaticBody3D.new()
		var wmi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(120, 4, 1)
		bm.material = _concrete_mat()
		wmi.mesh = bm
		wall.add_child(wmi)
		var wc := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(120, 4, 1)
		wc.shape = bs
		wall.add_child(wc)
		add_child(wall)
		match i:
			0:
				wall.position = Vector3(0, 2, -60)
			1:
				wall.position = Vector3(0, 2, 60)
			2:
				wall.position = Vector3(-60, 2, 0)
				wall.rotation.y = PI / 2.0
			3:
				wall.position = Vector3(60, 2, 0)
				wall.rotation.y = PI / 2.0

func _build_cover() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345 # deterministic M1 layout
	var spots: Array[Vector3] = []
	for i in range(26):
		var x := rng.randf_range(-45.0, 45.0)
		var z := rng.randf_range(-45.0, 45.0)
		if Vector2(x, z).length() < 6.0:
			continue # keep spawn clear
		spots.append(Vector3(x, 0, z))
	for s in spots:
		_spawn_crate(s, rng.randf_range(0.0, TAU))

func _spawn_crate(pos: Vector3, rot_y: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, 0.6, 0)
	body.rotation.y = rot_y
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var sx: float = [1.2, 1.2, 2.4].pick_random()
	bm.size = Vector3(sx, 1.2, 1.2)
	bm.material = _crate_mat() if randf() > 0.4 else _concrete_mat()
	mi.mesh = bm
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	col.shape = bs
	body.add_child(col)
	add_child(body)
