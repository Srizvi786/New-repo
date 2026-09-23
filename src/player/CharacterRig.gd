extends Node3D
## CharacterRig — M2 animation-ready soldier pipeline.
## Honest procedural placeholder (articulated PBR body, no copied assets) behind
## the SAME interface a real .glb rig will use (see tools/import_character.py).
## Covers: idle, walk, run, sprint, jump, fall, land, crouch, crouch_walk, aim,
## shoot, reload, weapon_switch, hit_reaction, death. Plus LOD0/1/2 + markers.

const ANIM_STATES := ["idle", "walk", "run", "sprint", "jump", "fall",
	"crouch", "crouch_walk", "aim"]

var anim_state: String = "idle"
var _speed: float = 0.0
var _firing: bool = false
var _aiming: bool = false

var _phase: float = 0.0
var _reload_t: float = 0.0
var _reload_dur: float = 1.0
var _shoot_t: float = 0.0
var _hit_t: float = 0.0
var _land_t: float = 0.0
var _dead: bool = false
var _death_t: float = 0.0

var _lod: int = 0
var _lod_timer: float = 0.0

var _hips: Node3D
var _torso: Node3D
var _head_pivot: Node3D
var _shoulder_l: Node3D
var _shoulder_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D

var _lod_mesh: MeshInstance3D
var _parts: Array[MeshInstance3D] = []
var _details: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []

var head_marker: Marker3D
var weapon_mount: Marker3D
var back_mount: Marker3D
var sidearm_mount: Marker3D

func _ready() -> void:
	_build()
	set_lod(0)

# ---------------------------------------------------------------- API
func set_state(state: String, speed: float, firing: bool, aiming: bool) -> void:
	if _dead:
		return
	if state in ANIM_STATES:
		anim_state = state
	_speed = speed
	_firing = firing
	_aiming = aiming

func play_shoot() -> void:
	_shoot_t = 0.12

func play_jump() -> void:
	_phase += 0.6

func play_land() -> void:
	if not _dead:
		_land_t = 0.3

func play_reload(duration: float = 2.0) -> void:
	if not _dead:
		_reload_t = duration
		_reload_dur = maxf(0.2, duration)

func play_weapon_switch() -> void:
	if not _dead:
		_reload_t = maxf(_reload_t, 0.45)
		_reload_dur = maxf(_reload_dur, 0.45)

func play_hit() -> void:
	if not _dead:
		_hit_t = 0.28

func play_death() -> void:
	if not _dead:
		_dead = true
		_death_t = 0.0

func revive() -> void:
	_dead = false
	rotation.x = 0.0
	position.y = 0.0

func set_lod(level: int) -> void:
	_lod = clampi(level, 0, 2)
	var show_full := _lod < 2
	for p in _parts:
		p.visible = show_full
	if _lod == 1:
		for d in _details:
			d.visible = false
	elif _lod == 0:
		for d in _details:
			d.visible = true
	_lod_mesh.visible = not show_full

func get_weapon_mount() -> Marker3D:
	return weapon_mount

func get_head_marker() -> Marker3D:
	return head_marker

# ------------------------------------------------------------ runtime
func _process(delta: float) -> void:
	_tick_timers(delta)
	_tick_lod(delta)
	if _dead:
		_tick_death(delta)
		return
	_phase += _speed * delta * 1.7
	_apply_pose(delta)

func _tick_timers(delta: float) -> void:
	_reload_t = maxf(0.0, _reload_t - delta)
	_shoot_t = maxf(0.0, _shoot_t - delta)
	_hit_t = maxf(0.0, _hit_t - delta)
	_land_t = maxf(0.0, _land_t - delta)
	for m in _mats:
		m.emission_enabled = _hit_t > 0.0
		if _hit_t > 0.0:
			m.emission = Color(1.0, 0.15, 0.1)
			m.emission_energy_multiplier = 1.5

func _tick_lod(delta: float) -> void:
	_lod_timer += delta
	if _lod_timer < 0.25:
		return
	_lod_timer = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dist: float = global_position.distance_to(cam.global_position)
	var want := 0
	if dist > 60.0:
		want = 2
	elif dist > 25.0:
		want = 1
	if has_node("/root/QualityManager"):
		var qm := get_node("/root/QualityManager")
		if int(qm.get("current")) == 0 and dist > 15.0:
			want = maxi(want, 1)
	if want != _lod:
		set_lod(want)

func _tick_death(delta: float) -> void:
	_death_t += delta
	var k: float = minf(1.0, _death_t * 2.5)
	rotation.x = lerpf(rotation.x, -PI * 0.5, minf(1.0, delta * 6.0))
	position.y = lerpf(position.y, -0.55 * k, minf(1.0, delta * 6.0))

func _lerp_rot(n: Node3D, target: Vector3, w: float) -> void:
	n.rotation = n.rotation.lerp(target, clampf(w, 0.0, 1.0))

func _apply_pose(delta: float) -> void:
	var w: float = minf(1.0, delta * 10.0)
	var s := _phase
	var spd: float = clampf(_speed, 0.0, 8.0)
	var run_k: float = clampf(spd / 6.0, 0.0, 1.0)
	# defaults
	var hips_y := 0.0
	var torso_rx := 0.02 * sin(s * 0.5)
	var thigh_amp := 0.0
	var arm_amp := 0.0
	match anim_state:
		"walk":
			thigh_amp = 0.5
			arm_amp = 0.4
		"run":
			thigh_amp = 0.75
			arm_amp = 0.6
			torso_rx = -0.12
		"sprint":
			thigh_amp = 0.9
			arm_amp = 0.7
			torso_rx = -0.22
		"crouch", "crouch_walk":
			hips_y = -0.34
			torso_rx = 0.3
			thigh_amp = 0.3 if anim_state == "crouch_walk" else 0.0
			arm_amp = 0.2 if anim_state == "crouch_walk" else 0.0
		"jump":
			thigh_amp = 0.0
		"fall":
			thigh_amp = 0.0
		"aim":
			thigh_amp = 0.12 * minf(1.0, spd)
			arm_amp = 0.1 * minf(1.0, spd)
	if _land_t > 0.0:
		hips_y -= 0.18 * (_land_t / 0.3)
	_hips.position.y = 0.95 + hips_y
	# legs
	if anim_state == "jump":
		_lerp_rot(_hip_l, Vector3(-0.55, 0, -0.08), w)
		_lerp_rot(_hip_r, Vector3(0.35, 0, 0.08), w)
		_lerp_rot(_knee_l, Vector3(0.9, 0, 0), w)
		_lerp_rot(_knee_r, Vector3(0.4, 0, 0), w)
	elif anim_state == "fall":
		_lerp_rot(_hip_l, Vector3(-0.25, 0, -0.15), w)
		_lerp_rot(_hip_r, Vector3(-0.25, 0, 0.15), w)
		_lerp_rot(_knee_l, Vector3(0.35, 0, 0), w)
		_lerp_rot(_knee_r, Vector3(0.35, 0, 0), w)
	elif anim_state == "crouch" and thigh_amp == 0.0:
		_lerp_rot(_hip_l, Vector3(-1.15, 0, -0.06), w)
		_lerp_rot(_hip_r, Vector3(-1.15, 0, 0.06), w)
		_lerp_rot(_knee_l, Vector3(1.5, 0, 0), w)
		_lerp_rot(_knee_r, Vector3(1.5, 0, 0), w)
	else:
		var sw := sin(s * 4.5) * thigh_amp
		_lerp_rot(_hip_l, Vector3(sw, 0, -0.03), w)
		_lerp_rot(_hip_r, Vector3(-sw, 0, 0.03), w)
		var bend_l: float = maxf(0.0, -sin(s * 4.5)) * (0.5 + run_k * 0.6) + (0.25 if anim_state.begins_with("crouch") else 0.06)
		var bend_r: float = maxf(0.0, sin(s * 4.5)) * (0.5 + run_k * 0.6) + (0.25 if anim_state.begins_with("crouch") else 0.06)
		_lerp_rot(_knee_l, Vector3(bend_l, 0, 0), w)
		_lerp_rot(_knee_r, Vector3(bend_r, 0, 0), w)
	# torso (hit jerk overrides lean)
	var jerk := 0.0
	if _hit_t > 0.0:
		jerk = 0.35 * (_hit_t / 0.28)
	_lerp_rot(_torso, Vector3(torso_rx + jerk, 0, 0.02 * sin(s * 2.0)), w)
	# arms: aim / reload / shoot poses override swing
	if _reload_t > 0.0:
		var dip: float = 0.6 * (_reload_t / _reload_dur) + 0.25
		_lerp_rot(_shoulder_l, Vector3(-0.5 + dip * 0.4, 0, -0.25), w)
		_lerp_rot(_shoulder_r, Vector3(-0.5 + dip * 0.4, 0, 0.25), w)
		_lerp_rot(_elbow_l, Vector3(-1.3, 0, 0), w)
		_lerp_rot(_elbow_r, Vector3(-1.3, 0, 0), w)
		_lerp_rot(_head_pivot, Vector3(0.3, 0, 0), w)
	elif _aiming or anim_state == "aim":
		var kick := 0.0
		if _shoot_t > 0.0 or _firing:
			kick = 0.09
		_lerp_rot(_shoulder_l, Vector3(-1.25 + kick, 0, -0.12), w)
		_lerp_rot(_shoulder_r, Vector3(-1.25 + kick, 0, 0.12), w)
		_lerp_rot(_elbow_l, Vector3(-0.35, -0.25, 0), w)
		_lerp_rot(_elbow_r, Vector3(-0.25, 0.25, 0), w)
		_lerp_rot(_head_pivot, Vector3(0.05, 0, 0), w)
	else:
		var asw := sin(s * 4.5) * arm_amp
		var bend: float = 0.25 + run_k * 0.9
		_lerp_rot(_shoulder_l, Vector3(-asw, 0, -0.07), w)
		_lerp_rot(_shoulder_r, Vector3(asw, 0, 0.07), w)
		_lerp_rot(_elbow_l, Vector3(-bend, 0, 0), w)
		_lerp_rot(_elbow_r, Vector3(-bend, 0, 0), w)
		_lerp_rot(_head_pivot, Vector3(-0.05 * sin(s), 0, 0), w)

# ------------------------------------------------------------ build
func _mat(albedo: Color, rough: float = 0.82, metal: float = 0.08) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	_mats.append(m)
	return m

func _pivot(parent: Node3D, pos: Vector3, nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	parent.add_child(n)
	return n

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, detail: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
	_parts.append(mi)
	if detail:
		_details.append(mi)
	return mi

func _capsule(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	cm.material = mat
	mi.mesh = cm
	mi.position = pos
	parent.add_child(mi)
	_parts.append(mi)
	return mi

func _build() -> void:
	var uniform := _mat(Color(0.32, 0.33, 0.26))
	var vest_m := _mat(Color(0.23, 0.22, 0.18), 0.9)
	var skin := _mat(Color(0.55, 0.42, 0.33), 0.65)
	var helmet_m := _mat(Color(0.25, 0.26, 0.22), 0.7, 0.25)
	var pack_m := _mat(Color(0.28, 0.27, 0.2), 0.9)
	var gun_m := _mat(Color(0.12, 0.12, 0.13), 0.45, 0.75)
	var boot_m := _mat(Color(0.16, 0.14, 0.11), 0.9)
	_hips = _pivot(self, Vector3(0, 0.95, 0), "Hips")
	_box(_hips, Vector3(0, 0.02, 0), Vector3(0.4, 0.25, 0.28), uniform)
	_torso = _pivot(_hips, Vector3(0, 0.12, 0), "Torso")
	_box(_torso, Vector3(0, 0.35, 0), Vector3(0.52, 0.6, 0.32), uniform)
	_box(_torso, Vector3(0, 0.37, 0.1), Vector3(0.44, 0.4, 0.36), vest_m, true)
	_box(_torso, Vector3(0, 0.35, -0.24), Vector3(0.4, 0.5, 0.16), pack_m, true)
	_head_pivot = _pivot(_torso, Vector3(0, 0.72, 0), "HeadPivot")
	_capsule(_head_pivot, Vector3(0, 0.12, 0), 0.14, 0.3, skin)
	_capsule(_head_pivot, Vector3(0, 0.2, -0.02), 0.17, 0.22, helmet_m)
	head_marker = Marker3D.new()
	head_marker.name = "HeadMarker"
	head_marker.position = Vector3(0, 0.18, 0)
	_head_pivot.add_child(head_marker)
	_shoulder_l = _pivot(_torso, Vector3(-0.34, 0.55, 0), "ShoulderL")
	_box(_shoulder_l, Vector3(0, -0.2, 0), Vector3(0.16, 0.42, 0.2), uniform)
	_elbow_l = _pivot(_shoulder_l, Vector3(0, -0.42, 0), "ElbowL")
	_box(_elbow_l, Vector3(0, -0.2, 0), Vector3(0.14, 0.4, 0.17), uniform)
	_box(_elbow_l, Vector3(0, -0.42, 0.02), Vector3(0.12, 0.12, 0.14), skin, true)
	_shoulder_r = _pivot(_torso, Vector3(0.34, 0.55, 0), "ShoulderR")
	_box(_shoulder_r, Vector3(0, -0.2, 0), Vector3(0.16, 0.42, 0.2), uniform)
	_elbow_r = _pivot(_shoulder_r, Vector3(0, -0.42, 0), "ElbowR")
	_box(_elbow_r, Vector3(0, -0.2, 0), Vector3(0.14, 0.4, 0.17), uniform)
	_box(_elbow_r, Vector3(0, -0.42, 0.02), Vector3(0.12, 0.12, 0.14), skin, true)
	# gun placeholder rides the right hand (M3 swaps the world model here)
	_box(_elbow_r, Vector3(0.02, -0.42, 0.35), Vector3(0.09, 0.12, 0.8), gun_m)
	weapon_mount = Marker3D.new()
	weapon_mount.name = "WeaponMount"
	weapon_mount.position = Vector3(0.02, -0.42, 0.4)
	_elbow_r.add_child(weapon_mount)
	back_mount = Marker3D.new()
	back_mount.name = "BackMount"
	back_mount.position = Vector3(0, 0.4, -0.35)
	_torso.add_child(back_mount)
	sidearm_mount = Marker3D.new()
	sidearm_mount.name = "SidearmMount"
	sidearm_mount.position = Vector3(0.28, 0.05, 0.1)
	_torso.add_child(sidearm_mount)
	_hip_l = _pivot(_hips, Vector3(-0.13, -0.05, 0), "HipL")
	_box(_hip_l, Vector3(0, -0.22, 0), Vector3(0.2, 0.45, 0.24), uniform)
	_knee_l = _pivot(_hip_l, Vector3(0, -0.45, 0), "KneeL")
	_box(_knee_l, Vector3(0, -0.2, 0), Vector3(0.17, 0.4, 0.2), uniform)
	_box(_knee_l, Vector3(0, -0.44, 0.05), Vector3(0.18, 0.12, 0.3), boot_m, true)
	_hip_r = _pivot(_hips, Vector3(0.13, -0.05, 0), "HipR")
	_box(_hip_r, Vector3(0, -0.22, 0), Vector3(0.2, 0.45, 0.24), uniform)
	_knee_r = _pivot(_hip_r, Vector3(0, -0.45, 0), "KneeR")
	_box(_knee_r, Vector3(0, -0.2, 0), Vector3(0.17, 0.4, 0.2), uniform)
	_box(_knee_r, Vector3(0, -0.44, 0.05), Vector3(0.18, 0.12, 0.3), boot_m, true)
	# LOD2 impostor: single capsule, hidden unless far away / LOW preset
	_lod_mesh = MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.38
	cm.height = 1.7
	cm.material = uniform
	_lod_mesh.mesh = cm
	_lod_mesh.position = Vector3(0, 0.9, 0)
	_lod_mesh.visible = false
	add_child(_lod_mesh)
