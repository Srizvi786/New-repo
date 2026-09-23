extends CharacterBody3D
## Player — responsive Android CharacterBody3D controller (M1).
## Walk/run/sprint/jump/crouch/gravity/accel/decel + camera + aim + anim hooks.
## Placeholder soldier meshes are procedural PBR; real rig swaps in via MeshRoot (M2).
class_name Player

const CRig := preload("res://src/player/CharacterRig.gd")
const HealthScript := preload("res://src/combat/Health.gd")
const InvScript := preload("res://src/items/Inventory.gd")

signal died(attacker: String)

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
var health: float = 100.0 # synced from Health node; full combat in M4
var armor: float = 0.0
var alive: bool = true
var health_node = null
var inventory = null
var heal_t: float = 0.0
var heal_pending: float = 0.0

var character_rig: CRig = null
var _stand_height: float = 1.8
var _crouch_height: float = 1.2

@onready var _col: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")
	rig = $CameraRig
	health_node = HealthScript.new()
	health_node.name = "Health"
	add_child(health_node)
	health_node.connect("died", _on_died)
	inventory = InvScript.new()
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
	if weapon_view and weapon_view.has_signal("recoil") and rig and rig.has_method("add_recoil"):
		weapon_view.connect("recoil", rig.add_recoil)
	if weapon_view and weapon_view.has_signal("reload_started"):
		weapon_view.connect("reload_started", play_reload)
	if weapon_view and weapon_view.has_signal("weapon_changed"):
		weapon_view.connect("weapon_changed", _on_weapon_changed)

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
	if not alive:
		if not is_on_floor():
			velocity.y -= 22.0 * delta
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		move_and_slide()
		return
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
	# Heal channel: moving allowed, firing blocked.
	if heal_t > 0.0:
		heal_t -= delta
		if heal_t <= 0.0 and health_node:
			health_node.heal(heal_pending)
			heal_pending = 0.0
		firing = false
	_update_anim_state(iv, firing)
	if rig and rig.has_method("set_aiming"):
		rig.call("set_aiming", aiming)
	# placeholder fire -> weapon view (full ballistics M3)
	var move_speed := Vector2(velocity.x, velocity.z).length()
	var just_pressed := Input.is_action_just_pressed("fire")
	if input_mgr and bool(input_mgr.call("consume_touch_fire_edge")):
		just_pressed = true
	if firing and weapon_view and weapon_view.has_method("try_fire"):
		if weapon_view.call("try_fire", aiming, move_speed, just_pressed):
			emit_signal("fired")
	if health_node:
		health = float(health_node.get("current"))
		armor = float(health_node.get("armor"))

# --- M5 consumables ---
func start_heal(amount: float) -> bool:
	if not alive or heal_t > 0.0 or health_node == null:
		return false
	if float(health_node.get("current")) >= float(health_node.get("max_health")):
		return false
	heal_t = 2.5
	heal_pending = amount
	return true

func use_item(idx: int) -> bool:
	if inventory == null:
		return false
	var res = inventory.peek(idx)
	if res == null:
		return false
	if str(res.get("kind")) == "heal":
		if start_heal(float(res.get("heal_amount"))):
			inventory.consume(idx)
			return true
		return false
	if str(res.get("kind")) == "armor":
		if health_node:
			health_node.add_armor(float(res.get("armor_amount")))
			inventory.consume(idx)
			return true
	return false

func heal_progress() -> float:
	if heal_t <= 0.0:
		return -1.0
	return 1.0 - heal_t / 2.5

# --- M4 damage interface (WeaponView hits call this) ---
func take_damage(amount: float, is_head: bool, attacker: String, _from: Vector3 = Vector3.ZERO) -> void:
	if not alive or health_node == null:
		return
	if _net_client():
		return # server applies; snapshots sync HP back (M11)
	health_node.take_damage(amount, is_head, attacker)
	health = float(health_node.get("current"))
	armor = float(health_node.get("armor"))
	if alive:
		play_hit()
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").call("play_hit", is_head)

func is_head_hit(pos: Vector3) -> bool:
	if character_rig and character_rig.get_head_marker():
		return pos.y > character_rig.get_head_marker().global_position.y - 0.12
	return pos.y > global_position.y + 1.45

func _on_died(attacker: String) -> void:
	alive = false
	play_death()
	emit_signal("died", attacker)

func _net_client() -> bool:
	var n = get_tree().get_first_node_in_group("network_manager")
	if n == null:
		return false
	return bool(n.call("is_active")) and not bool(n.call("is_server"))

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

# --- M2/M3 animation hooks (CharacterRig implements these; real rig keeps the names) ---
func play_shoot() -> void:
	if character_rig:
		character_rig.play_shoot()

func play_reload(duration: float = 2.0) -> void:
	if character_rig:
		character_rig.play_reload(duration)

func play_weapon_switch() -> void:
	if character_rig:
		character_rig.play_weapon_switch()

func _on_weapon_changed() -> void:
	play_weapon_switch()

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
