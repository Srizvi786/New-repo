extends Node3D
## WeaponView — M1 placeholder hitscan gun (proves fire/aim/reload wiring).
## Full modular system (attachments, ballistics, pooling) lands in M3.
class_name WeaponView

const WDB := preload("res://src/weapons/WeaponDatabase.gd")

var weapon = null
var camera: Camera3D = null
var owner_body: CollisionObject3D = null

var ammo_in_mag: int = 30
var reserve: int = 90
var _cooldown: float = 0.0
var _reloading: float = 0.0
var _flash_t: float = 0.0

var _flash: OmniLight3D
var _flash_mesh: MeshInstance3D
var _tracers: Array[Dictionary] = []

func _ready() -> void:
	weapon = WDB.by_id("ar")
	ammo_in_mag = int(weapon.get("mag_size"))
	reserve = int(weapon.get("reserve_start"))
	_flash = OmniLight3D.new()
	_flash.light_energy = 0.0
	_flash.omni_range = 6.0
	_flash.light_color = Color(1.0, 0.8, 0.5)
	add_child(_flash)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 0.08, 0.3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.75, 0.3)
	bm.material = m
	_flash_mesh = MeshInstance3D.new()
	_flash_mesh.mesh = bm
	_flash_mesh.visible = false
	add_child(_flash_mesh)
	# View model sits slightly below camera; world position updated in _process.
	top_level = true

func setup(cam: Camera3D, body: CollisionObject3D) -> void:
	camera = cam
	owner_body = body

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _reloading > 0.0:
		_reloading -= delta
		if _reloading <= 0.0 and weapon != null:
			var need: int = int(weapon.get("mag_size")) - ammo_in_mag
			var take: int = mini(need, reserve)
			ammo_in_mag += take
			reserve -= take
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.light_energy = 0.0
			_flash_mesh.visible = false
	# Keep muzzle near camera (cheap view-model feel for M1).
	if camera:
		var t: Transform3D = camera.global_transform
		global_transform = Transform3D(t.basis, t.origin + (-t.basis.y * 0.25 + t.basis.z * 0.15 + t.basis.x * 0.25))
		_flash.position = Vector3(0.1, 0.0, -1.0)
		_flash_mesh.position = Vector3(0.1, 0.0, -1.1)
	# Fade tracers.
	for i in range(_tracers.size() - 1, -1, -1):
		_tracers[i]["life"] = float(_tracers[i]["life"]) - delta
		if float(_tracers[i]["life"]) <= 0.0:
			(_tracers[i]["node"] as Node).queue_free()
			_tracers.remove_at(i)

func try_fire(aiming: bool) -> bool:
	if weapon == null or _cooldown > 0.0 or _reloading > 0.0:
		return false
	if ammo_in_mag <= 0:
		start_reload()
		return false
	_cooldown = 1.0 / maxf(0.5, float(weapon.get("fire_rate")))
	ammo_in_mag -= 1
	_fire_hitscan(aiming)
	_flash.light_energy = 2.5
	_flash_mesh.visible = true
	_flash_t = 0.05
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").call("play_gunshot")
	return true

func start_reload() -> void:
	if weapon == null or _reloading > 0.0 or reserve <= 0:
		return
	if ammo_in_mag >= int(weapon.get("mag_size")):
		return
	_reloading = float(weapon.get("reload_time"))
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").call("play_reload")

func _fire_hitscan(aiming: bool) -> void:
	if camera == null or weapon == null:
		return
	var base_spread: float = float(weapon.get("spread_deg"))
	var spread: float = deg_to_rad(base_spread / 3.0 if aiming else base_spread)
	var basis_t: Basis = camera.global_transform.basis
	var dir: Vector3 = (-basis_t.z + basis_t.x * randf_range(-spread, spread) + basis_t.y * randf_range(-spread, spread)).normalized()
	var from: Vector3 = camera.global_transform.origin
	var rng: float = float(weapon.get("range_m"))
	var to: Vector3 = from + dir * rng
	var q := PhysicsRayQueryParameters3D.create(from, to)
	if owner_body:
		q.exclude = [owner_body.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = to
	if not hit.is_empty():
		end = hit["position"]
	_spawn_tracer(from + dir * 1.0, end)

func _spawn_tracer(a: Vector3, b: Vector3) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.4, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	get_tree().current_scene.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	# Store world-space line: ImmediateMesh verts are local, so bake transform.
	_tracers.append({"node": mi, "life": 0.08})

func get_state_dict() -> Dictionary:
	var wid := "ar"
	if weapon != null:
		wid = str(weapon.get("id"))
	return {"id": wid, "mag": ammo_in_mag, "reserve": reserve}
