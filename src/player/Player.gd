extends CharacterBody3D
## Player — responsive Android CharacterBody3D controller (M1).
## Walk/run/sprint/jump/crouch/gravity/accel/decel + camera + aim + anim hooks.
## Placeholder soldier meshes are procedural PBR; real rig swaps in via MeshRoot (M2).
class_name Player

signal fired
signal jumped
signal landed

@export var walk_speed: float = 4.2
@export var run_speed: float = 6.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.2
@export var jump_velocity: float = 4.8
@export var acceleration: float = 14.0
@export var deceleration: float = 16.0
@export var mouse_sensitivity: float = 0.0026
@export var touch_look_scale: float = 0.0042

var input_mgr: Node = null
var rig: Node3D = null
var weapon_view: Node3D = null

var yaw: float = 0.0
var pitch: float = -0.15
var crouching: bool = false
var aiming: bool = false
var sprinting: bool = false
var on_ground_last: bool = true
var anim_state: String = "idle" # idle|walk|run|sprint|jump|fall|crouch|crouch_walk|aim
var health: float = 100.0 # stub; full combat in M4

var _mesh_root: Node3D
var _body_parts: Array[MeshInstance3D] = []
var _bob_t: float = 0.0
var _stand_height: float = 1.8
var _crouch_height: float = 1.2

@onready var _col: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("player")
	rig = $CameraRig
	_build_placeholder_soldier()
	_apply_stance(false)
	# Desktop mouse capture (touch devices skip this).
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func bind(manager: Node, weapon: Node3D) -> void:
	input_mgr = manager
	weapon_view = weapon

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_rotate_look(mm.relative * mouse_sensitivity * _sens_mult())

func _sens_mult() -> float:
	var s := 1.0
	if has_node("/root/SaveSystem"):
		s = float(get_node("/root/SaveSystem").get("sensitivity"))
	if aiming and has_node("/root/SaveSystem"):
		s *= float(get_node("/root/SaveSystem").get("ads_sensitivity"))
	return s

func _physics_process(delta: float) -> void:
	# --- look ---
	var look := Vector2.ZERO
	if input_mgr:
		look += (input_mgr.call("consume_look_delta") as Vector2) * touch_look_scale * _sens_mult()
		# Right stick (joy) look.
		var jx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var jy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if absf(jx) > 0.15 or absf(jy) > 0.15:
			look += Vector2(jx, jy) * 2.4 * delta
	if look.length() > 0.0:
		_rotate_look(look)
	# --- stance toggles ---
	if Input.is_action_just_pressed("crouch"):
		_apply_stance(not crouching)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		emit_signal("jumped")
	# Click-to-capture on desktop for easy editor testing.
	if Input.is_action_just_pressed("fire") and not DisplayServer.is_touchscreen_available():
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	aiming = Input.is_action_pressed("aim") or (input_mgr and bool(input_mgr.get("touch_aim_held")))
	var want_sprint := Input.is_action_pressed("sprint") or (input_mgr and bool(input_mgr.get("touch_sprint_held")))

	# --- move ---
	var iv := Vector2.ZERO
	if input_mgr:
		iv = input_mgr.call("get_move_vector")
	else:
		iv = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := -iv.y
	sprinting = want_sprint and forward > 0.3 and not crouching and not aiming and iv.length() > 0.1
	var target_speed := walk_speed
	if crouching:
		target_speed = crouch_speed
	elif aiming:
		target_speed = walk_speed * 0.6
	elif sprinting:
		target_speed = sprint_speed
	elif iv.length() > 0.85:
		target_speed = run_speed
	var basis_y := Basis(Vector3.UP, yaw)
	var dir: Vector3 = basis_y * Vector3(iv.x, 0, iv.y)
	# iv.y is +back, so forward vector above is correct with z=iv.y.
	if dir.length() > 1.0:
		dir = dir.normalized()
	# gravity
	if not is_on_floor():
		velocity.y -= 22.0 * delta
		if velocity.y < -30.0:
			velocity.y = -30.0
	elif velocity.y < 0.0:
		velocity.y = -0.5
	# accel / decel
	var hv := Vector3(velocity.x, 0, velocity.z)
	var want := dir * target_speed
	var rate := acceleration if dir.length() > 0.05 else deceleration
	hv = hv.move_toward(want, rate * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()
	# landing event
	if is_on_floor() and not on_ground_last and velocity.y <= 0.5:
		emit_signal("landed")
	on_ground_last = is_on_floor()
	_update_anim_state(iv)
	if rig and rig.has_method("set_aiming"):
		rig.call("set_aiming", aiming)
	# placeholder fire -> weapon view (full ballistics M3)
	var firing := Input.is_action_pressed("fire") or (input_mgr and bool(input_mgr.get("touch_fire_held")))
	if firing and weapon_view and weapon_view.has_method("try_fire"):
		if weapon_view.call("try_fire", aiming):
			emit_signal("fired")
			if rig and rig.has_method("add_recoil"):
				rig.call("add_recoil", Vector2(0.003, 0.004))

func _rotate_look(d: Vector2) -> void:
	yaw -= d.x
	pitch = clampf(pitch - d.y, -1.2, 1.2)
	rotation.y = yaw
	if rig and rig.has_method("apply_look"):
		# Keep rig in sync without double-applying: set directly.
		rig.set("yaw", yaw)
		rig.set("pitch", pitch)
		rig.call("_apply_transform")

func _apply_stance(c: bool) -> void:
	crouching = c
	if _col and _col.shape is CapsuleShape3D:
		var cap := _col.shape as CapsuleShape3D
		cap.height = _crouch_height if c else _stand_height
		_col.position.y = (_crouch_height * 0.5) if c else (_stand_height * 0.5)

func _update_anim_state(iv: Vector2) -> void:
	# Hook-compatible state string for the M2 AnimationTree swap.
	var speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		anim_state = "jump" if velocity.y > 0.5 else "fall"
	elif crouching:
		anim_state = "crouch_walk" if speed > 0.5 else "crouch"
	elif aiming:
		anim_state = "aim"
	elif sprinting:
		anim_state = "sprint"
	elif speed > 5.0:
		anim_state = "run"
	elif speed > 0.5:
		anim_state = "walk"
	else:
		anim_state = "idle"
	# Cheap procedural motion: bob + lean (replaced by real anims in M2).
	_bob_t += delta_speed_factor(speed) * get_physics_process_delta_time()
	if _mesh_root:
		_mesh_root.position.y = absf(sin(_bob_t * 9.0)) * 0.035 * minf(1.0, speed / 6.0)
		_mesh_root.rotation.z = lerpf(_mesh_root.rotation.z, -iv.x * 0.06, 0.12)
		_mesh_root.rotation.x = lerpf(_mesh_root.rotation.x, -maxf(0.0, -iv.y) * 0.04 if not sprinting else -0.08, 0.1)

func delta_speed_factor(speed: float) -> float:
	return clampf(speed, 0.0, 8.0)

# --- M2 animation hook stubs (real rig connects these) ---
func play_shoot() -> void:
	pass

func play_reload() -> void:
	pass

func play_hit() -> void:
	pass

func play_death() -> void:
	pass

# --- network-ready state (M11) ---
func get_state_dict() -> Dictionary:
	return {
		"pos": global_position,
		"yaw": yaw,
		"pitch": pitch,
		"crouch": crouching,
		"aim": aiming,
		"health": health,
		"anim": anim_state,
	}

func apply_state_dict(s: Dictionary) -> void:
	if s.has("pos"):
		global_position = s["pos"]
	if s.has("yaw"):
		yaw = float(s["yaw"])
		rotation.y = yaw
	if s.has("pitch"):
		pitch = float(s["pitch"])
	if s.has("crouch"):
		_apply_stance(bool(s["crouch"]))
	if s.has("health"):
		health = float(s["health"])

# --- placeholder soldier (procedural PBR, honest stand-in) ---
func _pbr(albedo: Color, rough: float = 0.82, metal: float = 0.08) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
	_body_parts.append(mi)
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
	_body_parts.append(mi)
	return mi

func _build_placeholder_soldier() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "MeshRoot"
	add_child(_mesh_root)
	var uniform := _pbr(Color(0.32, 0.33, 0.26))      # olive drab
	var vest_m := _pbr(Color(0.23, 0.22, 0.18), 0.9)   # tactical vest
	var skin := _pbr(Color(0.55, 0.42, 0.33), 0.65)    # exposed skin placeholder
	var helmet_m := _pbr(Color(0.25, 0.26, 0.22), 0.7, 0.25)
	var pack_m := _pbr(Color(0.28, 0.27, 0.2), 0.9)
	var gun_m := _pbr(Color(0.12, 0.12, 0.13), 0.45, 0.75)
	# legs / torso / arms (human proportions, ~1.8m)
	_box(_mesh_root, Vector3(-0.13, 0.45, 0), Vector3(0.2, 0.9, 0.24), uniform) # leg L
	_box(_mesh_root, Vector3(0.13, 0.45, 0), Vector3(0.2, 0.9, 0.24), uniform)  # leg R
	_box(_mesh_root, Vector3(0, 1.12, 0), Vector3(0.52, 0.62, 0.32), uniform)   # torso
	_box(_mesh_root, Vector3(0, 1.14, -0.2), Vector3(0.4, 0.5, 0.16), pack_m)   # backpack
	_box(_mesh_root, Vector3(0, 1.16, 0.1), Vector3(0.44, 0.4, 0.36), vest_m)   # vest
	_box(_mesh_root, Vector3(-0.36, 1.12, 0.05), Vector3(0.16, 0.55, 0.2), uniform) # arm L
	_box(_mesh_root, Vector3(0.36, 1.12, 0.05), Vector3(0.16, 0.55, 0.2), uniform)  # arm R
	_capsule(_mesh_root, Vector3(0, 1.58, 0), 0.14, 0.3, skin)                  # head
	_capsule(_mesh_root, Vector3(0, 1.68, -0.02), 0.17, 0.22, helmet_m)         # helmet
	# weapon placeholder in hands (swapped by WeaponView world model in M3)
	_box(_mesh_root, Vector3(0.22, 1.15, 0.45), Vector3(0.09, 0.12, 0.85), gun_m)
	# attachment markers for M2/M3 real assets
	var head := Marker3D.new()
	head.name = "HeadMarker"
	head.position = Vector3(0, 1.7, 0)
	_mesh_root.add_child(head)
	var mount := Marker3D.new()
	mount.name = "WeaponMount"
	mount.position = Vector3(0.22, 1.15, 0.45)
	_mesh_root.add_child(mount)
