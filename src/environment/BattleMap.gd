extends Node3D
## BattleMap — M6 original 400x400m battleground.
## Districts: town (houses), industrial (warehouses/crates/tanks),
## compound (walled base), fields + forest. Shared materials, box collision,
## MultiMesh vegetation, loot/spawn points, bounds for zone (M9).

const SIZE := 400.0
const HALF := 200.0

var loot_points: Array = []
var spawn_points: Array = []
var _mats: Dictionary = {}

func _ready() -> void:
	_make_mats()
	_build_sky()
	_build_ground()
	_build_roads()
	_build_town()
	_build_industrial()
	_build_compound()
	_build_vegetation()
	_build_perimeter()
	_build_spawns()
	if has_node("/root/QualityManager"):
		get_node("/root/QualityManager").call("apply_to_light", $Sun)
		var qm := get_node("/root/QualityManager")
		if int(qm.get("current")) == 0 and has_node("Veg/Grass"):
			$Veg/Grass.visible = false

func get_loot_points() -> Array:
	return loot_points

func get_spawn_points() -> Array:
	return spawn_points

func get_spawn_transform() -> Transform3D:
	if spawn_points.is_empty():
		return Transform3D(Basis(), Vector3(0, 1.2, 6))
	var p: Vector3 = spawn_points[randi() % spawn_points.size()]
	return Transform3D(Basis(), p + Vector3(0, 1.2, 0))

func get_map_bounds() -> Rect2:
	return Rect2(-HALF, -HALF, SIZE, SIZE)

# ------------------------------------------------------------- materials
func _make_mats() -> void:
	_mats["ground"] = _mat(Color(0.55, 0.48, 0.36), 0.95)
	_mats["road"] = _mat(Color(0.22, 0.22, 0.23), 0.95)
	_mats["wall"] = _mat(Color(0.62, 0.58, 0.5), 0.9)
	_mats["wall2"] = _mat(Color(0.5, 0.42, 0.32), 0.9)
	_mats["roof"] = _mat(Color(0.35, 0.28, 0.22), 0.85)
	_mats["metal"] = _mat(Color(0.4, 0.45, 0.5), 0.5, 0.6)
	_mats["crate"] = _mat(Color(0.4, 0.34, 0.22), 0.85)
	_mats["dark"] = _mat(Color(0.12, 0.13, 0.15), 0.8)
	_mats["tank"] = _mat(Color(0.55, 0.3, 0.2), 0.6, 0.3)
	_mats["trunk"] = _mat(Color(0.3, 0.22, 0.15), 0.95)
	_mats["leaf"] = _mat(Color(0.25, 0.42, 0.22), 0.9)
	_mats["rock"] = _mat(Color(0.45, 0.43, 0.4), 0.95)
	_mats["grass"] = _mat(Color(0.45, 0.55, 0.3), 0.9)

func _mat(c: Color, r: float = 0.9, m: float = 0.0) -> StandardMaterial3D:
	var mm := StandardMaterial3D.new()
	mm.albedo_color = c
	mm.roughness = r
	mm.metallic = m
	return mm

# ------------------------------------------------------------- helpers
func _solid(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot_y: float = 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation.y = rot_y
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	b.add_child(mi)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	b.add_child(col)
	parent.add_child(b)
	return b

func _deco_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
	return mi

# ------------------------------------------------------------- sky/ground
func _build_sky() -> void:
	var we := $WorldEnvironment as WorldEnvironment
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.35, 0.52, 0.72)
	mat.sky_horizon_color = Color(0.78, 0.72, 0.6)
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
	env.fog_density = 0.004
	env.fog_sky_affect = 0.4
	we.environment = env
	var sun := $Sun as DirectionalLight3D
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.95, 0.87)
	sun.shadow_enabled = true

func _build_ground() -> void:
	var g := StaticBody3D.new()
	g.name = "Ground"
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE, SIZE)
	pm.material = _mats["ground"]
	mi.mesh = pm
	g.add_child(mi)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(SIZE, 1, SIZE)
	col.shape = bs
	col.position.y = -0.5
	g.add_child(col)
	add_child(g)

func _build_roads() -> void:
	var r := Node3D.new()
	r.name = "Roads"
	add_child(r)
	_deco_box(r, Vector3(0, 0.02, 0), Vector3(10, 0.05, SIZE), _mats["road"])
	_deco_box(r, Vector3(0, 0.02, 0), Vector3(SIZE, 0.05, 10), _mats["road"])

func _house(parent: Node3D, x: float, z: float, rot: float) -> void:
	var h := Node3D.new()
	h.position = Vector3(x, 0, z)
	h.rotation.y = rot
	parent.add_child(h)
	var w: Material = _mats["wall"]
	# floor + roof
	_solid(h, Vector3(0, 0.1, 0), Vector3(10, 0.2, 8), _mats["wall2"])
	_solid(h, Vector3(0, 3.6, 0), Vector3(10.6, 0.3, 8.6), _mats["roof"])
	# back + sides
	_solid(h, Vector3(0, 1.8, -4), Vector3(10, 3.4, 0.4), w)
	_solid(h, Vector3(-5, 1.8, 0), Vector3(0.4, 3.4, 8), w)
	_solid(h, Vector3(5, 1.8, 0), Vector3(0.4, 3.4, 8), w)
	# front with door gap (two segments + lintel)
	_solid(h, Vector3(-3.2, 1.8, 4), Vector3(3.6, 3.4, 0.4), w)
	_solid(h, Vector3(3.2, 1.8, 4), Vector3(3.6, 3.4, 0.4), w)
	_solid(h, Vector3(0, 3.0, 4), Vector3(2.8, 0.8, 0.4), w)
	# window trims (detail, no collision)
	_deco_box(h, Vector3(-5.25, 2.0, 0), Vector3(0.1, 1.0, 1.6), _mats["dark"])
	_deco_box(h, Vector3(5.25, 2.0, 0), Vector3(0.1, 1.0, 1.6), _mats["dark"])
	loot_points.append(h.position + Vector3(0, 0, 5.5))
	loot_points.append(h.position + Vector3(2.5, 0, -2.0))

func _build_town() -> void:
	var t := Node3D.new()
	t.name = "Town"
	add_child(t)
	var n := 0
	for gx in range(-1, 2):
		for gz in range(-1, 1):
			_house(t, -120.0 + float(gx) * 28.0, -120.0 + float(gz) * 26.0, 0.0 if n % 2 == 0 else 3.14159)
			n += 1

func _warehouse(parent: Node3D, x: float, z: float) -> void:
	var h := Node3D.new()
	h.position = Vector3(x, 0, z)
	parent.add_child(h)
	_solid(h, Vector3(0, 0.1, 0), Vector3(24, 0.2, 16), _mats["wall2"])
	_solid(h, Vector3(0, 3.0, -8), Vector3(24, 6, 0.5), _mats["metal"])
	_solid(h, Vector3(0, 3.0, 8), Vector3(24, 6, 0.5), _mats["metal"])
	_solid(h, Vector3(-12, 3.0, 0), Vector3(0.5, 6, 16), _mats["metal"])
	_solid(h, Vector3(12, 3.0, 0), Vector3(0.5, 6, 16), _mats["metal"])
	_solid(h, Vector3(0, 6.4, 0), Vector3(25, 0.4, 17), _mats["roof"])
	loot_points.append(h.position + Vector3(-6, 0, 0))
	loot_points.append(h.position + Vector3(6, 0, 0))
	loot_points.append(h.position + Vector3(0, 0, 10))

func _build_industrial() -> void:
	var t := Node3D.new()
	t.name = "Industrial"
	add_child(t)
	_warehouse(t, 110, -110)
	_warehouse(t, 150, -80)
	# fuel tanks
	for i in range(3):
		var tank := StaticBody3D.new()
		tank.position = Vector3(90.0 + float(i) * 12.0, 2.5, -140)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 3.0
		cm.bottom_radius = 3.0
		cm.height = 5.0
		cm.material = _mats["tank"]
		mi.mesh = cm
		tank.add_child(mi)
		var col := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 3.0
		cs.height = 5.0
		col.shape = cs
		tank.add_child(col)
		t.add_child(tank)
	# crate rows
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in range(16):
		var p := Vector3(rng.randf_range(80, 170), 0.6, rng.randf_range(-140, -60))
		_solid(t, p, Vector3(2.4, 1.2, 1.2), _mats["crate"], rng.randf() * 3.14)
		if i % 2 == 0:
			loot_points.append(p + Vector3(2.0, 0, 0))

func _build_compound() -> void:
	var t := Node3D.new()
	t.name = "Compound"
	add_child(t)
	var cx := 0.0
	var cz := 90.0
	var s := 34.0
	_solid(t, Vector3(cx, 2, cz - s), Vector3(s * 2 + 2, 4, 1), _mats["wall2"])
	_solid(t, Vector3(cx, 2, cz + s), Vector3(s * 2 + 2, 4, 1), _mats["wall2"])
	_solid(t, Vector3(cx - s, 2, cz), Vector3(1, 4, s * 2), _mats["wall2"])
	_solid(t, Vector3(cx + s, 2, cz), Vector3(1, 4, s * 2), _mats["wall2"])
	# inner blocks + watch tower
	_solid(t, Vector3(cx - 10, 1.5, cz), Vector3(10, 3, 8), _mats["wall"])
	_solid(t, Vector3(cx + 12, 1.5, cz + 8), Vector3(8, 3, 10), _mats["wall"])
	_solid(t, Vector3(cx, 4, cz - 12), Vector3(6, 8, 6), _mats["metal"])
	_solid(t, Vector3(cx, 8.2, cz - 12), Vector3(8, 0.4, 8), _mats["roof"])
	for off in [Vector3(-10, 0, 6), Vector3(12, 0, -4), Vector3(0, 0, 12), Vector3(-16, 0, -10)]:
		loot_points.append(Vector3(cx, 0, cz) + off)

func _multimesh_box(parent: Node3D, nm: String, mesh: Mesh, count: int, positions: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in range(mini(count, positions.size())):
		mm.set_instance_transform(i, Transform3D(Basis(), positions[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	parent.add_child(mmi)
	return mmi

func _build_vegetation() -> void:
	var v := Node3D.new()
	v.name = "Veg"
	add_child(v)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var trunks: Array = []
	var canopies: Array = []
	for i in range(150):
		# forest in south-west quadrant + scattered
		var x := rng.randf_range(-HALF + 8, -20.0)
		var z := rng.randf_range(20.0, HALF - 8)
		if absf(x) < 9.0 or absf(z) < 9.0:
			continue # keep roads clear
		var sc: float = rng.randf_range(0.8, 1.4)
		trunks.append(Vector3(x, 1.5 * sc, z))
		canopies.append(Vector3(x, 4.2 * sc, z))
	var trunk_mesh := BoxMesh.new()
	trunk_mesh.size = Vector3(0.5, 3.0, 0.5)
	trunk_mesh.material = _mats["trunk"]
	_multimesh_box(v, "Trunks", trunk_mesh, trunks.size(), trunks)
	var can_mesh := BoxMesh.new()
	can_mesh.size = Vector3(2.6, 2.2, 2.6)
	can_mesh.material = _mats["leaf"]
	_multimesh_box(v, "Canopies", can_mesh, canopies.size(), canopies)
	var rocks: Array = []
	for i in range(80):
		rocks.append(Vector3(rng.randf_range(-HALF + 5, HALF - 5), 0.4, rng.randf_range(-HALF + 5, HALF - 5)))
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(1.4, 0.9, 1.2)
	rock_mesh.material = _mats["rock"]
	_multimesh_box(v, "Rocks", rock_mesh, rocks.size(), rocks)
	var grass: Array = []
	for i in range(400):
		grass.append(Vector3(rng.randf_range(-HALF + 5, HALF - 5), 0.15, rng.randf_range(-HALF + 5, HALF - 5)))
	var grass_mesh := BoxMesh.new()
	grass_mesh.size = Vector3(0.5, 0.3, 0.5)
	grass_mesh.material = _mats["grass"]
	_multimesh_box(v, "Grass", grass_mesh, grass.size(), grass)

func _build_perimeter() -> void:
	var p := Node3D.new()
	p.name = "Perimeter"
	add_child(p)
	_solid(p, Vector3(0, 3, -HALF), Vector3(SIZE + 20, 6, 2), _mats["rock"])
	_solid(p, Vector3(0, 3, HALF), Vector3(SIZE + 20, 6, 2), _mats["rock"])
	_solid(p, Vector3(-HALF, 3, 0), Vector3(2, 6, SIZE + 20), _mats["rock"])
	_solid(p, Vector3(HALF, 3, 0), Vector3(2, 6, SIZE + 20), _mats["rock"])

func _build_spawns() -> void:
	for i in range(12):
		var a: float = TAU * float(i) / 12.0
		spawn_points.append(Vector3(cos(a) * (HALF - 15.0), 0, sin(a) * (HALF - 15.0)))
