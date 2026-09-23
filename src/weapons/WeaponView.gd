extends Node3D
## WeaponView — M3 modular hitscan system.
## Data-driven stats (WeaponResource), 3-slot inventory, attachments, pellets,
## semi-auto trigger discipline, movement spread, falloff, headshots, capped tracers.
class_name WeaponView

const WDB := preload("res://src/weapons/WeaponDatabase.gd")
const WInv := preload("res://src/weapons/WeaponInventory.gd")

signal hit_confirmed(hit: bool, head: bool)
signal recoil(kick: Vector2)
signal reload_started(duration: float)
signal weapon_changed

var weapon = null
var inv = null
var camera: Camera3D = null
var owner_body: CollisionObject3D = null
var attacker_name: String = "You"

var ammo_in_mag: int = 30
var reserve: int = 90
var _cooldown: float = 0.0
var _reloading: float = 0.0
var _flash_t: float = 0.0

var _flash: OmniLight3D
var _flash_mesh: MeshInstance3D
var _tracers: Array[Dictionary] = []

func _ready() -> void:
	inv = WInv.new()
	var ar = WDB.by_id("ar")
	inv.add_weapon(ar)
	var p9 = WDB.by_id("pistol")
	inv.slots[2] = p9
	inv.mags[2] = int(p9.get("eff_mag"))
	var cal := str(p9.get("caliber"))
	inv.ammo[cal] = int(inv.ammo.get(cal, 0)) + int(p9.get("reserve_start"))
	weapon = inv.current_weapon()
	top_level = true
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
	_sync_ammo()

func setup(cam: Camera3D, body: CollisionObject3D, attacker: String = "You") -> void:
	camera = cam
	owner_body = body
	attacker_name = attacker

func attach(att) -> bool:
	if weapon == null or att == null:
		return false
	weapon.get("attachments")[str(att.get("slot"))] = att
	emit_signal("weapon_changed")
	_sync_ammo()
	return true

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	inv.tick(delta)
	_poll_slots()
	if _reloading > 0.0:
		_reloading -= delta
		if _reloading <= 0.0:
			_finish_reload()
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.light_energy = 0.0
			_flash_mesh.visible = false
	if camera:
		var t: Transform3D = camera.global_transform
		global_transform = Transform3D(t.basis, t.origin + (-t.basis.y * 0.25 + t.basis.z * 0.15 + t.basis.x * 0.25))
		_flash.position = Vector3(0.1, 0.0, -1.0)
		_flash_mesh.position = Vector3(0.1, 0.0, -1.1)
	for i in range(_tracers.size() - 1, -1, -1):
		_tracers[i]["life"] = float(_tracers[i]["life"]) - delta
		if float(_tracers[i]["life"]) <= 0.0:
			(_tracers[i]["node"] as Node).queue_free()
			_tracers.remove_at(i)

func _poll_slots() -> void:
	var want := -1
	if Input.is_action_just_pressed("slot_1"):
		want = 0
	elif Input.is_action_just_pressed("slot_2"):
		want = 1
	elif Input.is_action_just_pressed("slot_3"):
		want = 2
	elif Input.is_action_just_pressed("slot_next"):
		inv.set_mag(inv.current, ammo_in_mag)
		if inv.switch_next():
			_equip_current()
		return
	if want >= 0:
		inv.set_mag(inv.current, ammo_in_mag)
		if inv.switch_to(want):
			_equip_current()

func _equip_current() -> void:
	weapon = inv.current_weapon()
	_reloading = 0.0
	_cooldown = 0.1
	_sync_ammo()
	emit_signal("weapon_changed")

func give_weapon(res):
	# Add or swap. Returns the replaced weapon (caller drops it) or null.
	inv.set_mag(inv.current, ammo_in_mag)
	var idx: int = inv.add_weapon(res)
	if idx >= 0:
		_equip_current()
		return null
	var old = inv.replace_current(res)
	_equip_current()
	return old

func try_fire(aiming: bool, move_speed: float, just_pressed: bool) -> bool:
	if weapon == null or _cooldown > 0.0 or _reloading > 0.0 or inv.switch_cd > 0.0:
		return false
	if not bool(weapon.get("automatic")) and not just_pressed:
		return false
	if ammo_in_mag <= 0:
		start_reload()
		return false
	_cooldown = 1.0 / maxf(0.5, float(weapon.get("fire_rate")))
	ammo_in_mag -= 1
	inv.set_mag(inv.current, ammo_in_mag)
	_fire_hitscan(aiming, move_speed)
	_flash.light_energy = 2.5
	_flash_mesh.visible = true
	_flash_t = 0.05
	if has_node("/root/AudioManager"):
		var pitch := 1.0
		match str(weapon.get("id")):
			"smg":
				pitch = 1.15
			"shotgun":
				pitch = 0.7
			"sniper":
				pitch = 0.6
			"pistol":
				pitch = 1.25
		get_node("/root/AudioManager").call("play_gunshot", pitch)
	emit_signal("recoil", weapon.call("eff_recoil"))
	return true

func start_reload() -> void:
	if weapon == null or _reloading > 0.0 or inv.switch_cd > 0.0:
		return
	if ammo_in_mag >= int(weapon.get("eff_mag")):
		return
	var cal := str(weapon.get("caliber"))
	if int(inv.ammo.get(cal, 0)) <= 0:
		return
	_reloading = float(weapon.call("eff_reload"))
	emit_signal("reload_started", _reloading)
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").call("play_reload")

func _finish_reload() -> void:
	if weapon == null:
		return
	var cal := str(weapon.get("caliber"))
	var pool: int = int(inv.ammo.get(cal, 0))
	var need: int = int(weapon.get("eff_mag")) - ammo_in_mag
	var take: int = mini(need, pool)
	ammo_in_mag += take
	inv.ammo[cal] = pool - take
	inv.set_mag(inv.current, ammo_in_mag)
	_sync_ammo()

func _sync_ammo() -> void:
	if weapon == null:
		ammo_in_mag = 0
		reserve = 0
		return
	ammo_in_mag = inv.mags[inv.current]
	reserve = int(inv.ammo.get(str(weapon.get("caliber")), 0))

func _fire_hitscan(aiming: bool, move_speed: float) -> void:
	if camera == null or weapon == null:
		return
	var spread: float = deg_to_rad(float(weapon.call("eff_spread", aiming)) + float(weapon.get("move_spread_deg")) * move_speed * 0.3)
	var basis_t: Basis = camera.global_transform.basis
	var from: Vector3 = camera.global_transform.origin
	var rng: float = float(weapon.get("range_m"))
	var pellets: int = maxi(1, int(weapon.get("pellets")))
	var any_hit := false
	var any_head := false
	for p in range(pellets):
		var dir: Vector3 = (-basis_t.z + basis_t.x * randf_range(-spread, spread) + basis_t.y * randf_range(-spread, spread)).normalized()
		var to: Vector3 = from + dir * rng
		var q := PhysicsRayQueryParameters3D.create(from, to)
		if owner_body:
			q.exclude = [owner_body.get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		var end: Vector3 = to
		if not hit.is_empty():
			end = hit["position"]
			var dist: float = from.distance_to(end)
			var fall: float = 1.0 - 0.5 * clampf(dist / rng, 0.0, 1.0)
			var head := _is_head(hit["collider"], end)
			var dmg: float = float(weapon.call("eff_damage")) * fall
			if head:
				dmg *= float(weapon.get("headshot_mult"))
				any_head = true
			_apply_hit(hit["collider"], end, dmg, head, from)
			any_hit = true
		_spawn_tracer(from + dir * 1.0, end)
	emit_signal("hit_confirmed", any_hit, any_head)

func _is_head(collider: Object, pos: Vector3) -> bool:
	if collider is Node and (collider as Node).has_method("is_head_hit"):
		return bool((collider as Node).call("is_head_hit", pos))
	return false

func _apply_hit(collider: Object, pos: Vector3, dmg: float, is_head: bool, from: Vector3) -> bool:
	if collider == null:
		return false
	if collider is Node and (collider as Node).has_method("take_damage"):
		(collider as Node).call("take_damage", dmg, is_head, attacker_name, from)
		return true
	return false

func _spawn_tracer(a: Vector3, b: Vector3) -> void:
	while _tracers.size() >= 24:
		var old: Dictionary = _tracers.pop_front()
		(old["node"] as Node).queue_free()
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
	_tracers.append({"node": mi, "life": 0.08})

func get_state_dict() -> Dictionary:
	var wid := "ar"
	if weapon != null:
		wid = str(weapon.get("id"))
	return {"id": wid, "mag": ammo_in_mag, "reserve": reserve}
