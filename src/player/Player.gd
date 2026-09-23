extends CharacterBody3D
## Player — responsive Android CharacterBody3D controller (M1).
## Walk/run/sprint/jump/crouch/gravity/accel/decel + camera + aim + anim hooks.
## Placeholder soldier meshes are procedural PBR; real rig swaps in via MeshRoot (M2).
class_name Player

const CRig := preload("res://src/player/CharacterRig.gd")

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

var character_rig: CRig = null
var _stand_height: float = 1.8
var _crouch_height: float = 1.2

@onready var _col: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("player")
	rig = $CameraRig
	character_rig = CRig.new()
	character_rig.name = "CharacterRig"
	add_child(character_rig)
	fired.connect(character_rig.play_shoot)
	jumped.connect(character_rig.play_jump)
	landed.connect(character_rig.play_land)
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
	var firing := Input.is_action_pressed("fire") or (input_mgr and bool(input_mgr.get("touch_fire_held")))
	_update_anim_state(iv, firing)
	if rig and rig.has_method("set_aiming"):
		rig.call("set_aiming", aiming)
	# placeholder fire -> weapon view (full ballistics M3)
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

func _update_anim_state(_iv: Vector2, firing: bool) -> void:
	# Hook-compatible state string for the M2 CharacterRig (real .glb swaps in later).
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
	if character_rig:
		character_rig.set_state(anim_state, speed, firing, aiming)

# --- M2 animation hooks (CharacterRig implements these; real rig keeps the names) ---
func play_shoot() -> void:
	if character_rig:
		character_rig.play_shoot()

func play_reload() -> void:
	if character_rig and weapon_view:
		character_rig.play_reload(float(weapon_view.get("weapon").get("reload_time")) if weapon_view.get("weapon") else 2.0)

func play_hit() -> void:
	if character_rig:
		character_rig.play_hit()

func play_death() -> void:
	if character_rig:
		character_rig.play_death()

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
