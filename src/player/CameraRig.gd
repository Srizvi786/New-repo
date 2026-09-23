extends Node3D
## CameraRig — third-person orbit + collision + aim zoom + recoil.
## First-person toggle is architected (offset -> head) but TP is default for mobile.
class_name CameraRig

@export var normal_distance: float = 4.2
@export var aim_distance: float = 2.2
@export var first_person_offset: Vector3 = Vector3(0, 1.62, 0.15)
@export var shoulder_offset: Vector3 = Vector3(0.55, 0.25, 0.0)
@export var min_pitch: float = -1.2
@export var max_pitch: float = 1.2

var yaw: float = 0.0
var pitch: float = -0.15
var aiming: bool = false
var first_person: bool = false
var recoil: Vector2 = Vector2.ZERO

@onready var arm: SpringArm3D = $SpringArm3D
@onready var cam: Camera3D = $SpringArm3D/Camera3D

func _ready() -> void:
	if arm:
		arm.spring_length = normal_distance
		arm.margin = 0.3
	if cam:
		cam.current = true
		cam.fov = 70.0
		if has_node("/root/QualityManager"):
			get_node("/root/QualityManager").call("apply_to_camera", cam)

func apply_look(delta: Vector2) -> void:
	yaw -= delta.x
	pitch = clampf(pitch - delta.y, min_pitch, max_pitch)
	_apply_transform()

func add_recoil(kick: Vector2) -> void:
	recoil += kick

func set_aiming(a: bool) -> void:
	aiming = a

func set_first_person(fp: bool) -> void:
	first_person = fp
	_apply_transform()

func _process(delta: float) -> void:
	# Decay recoil smoothly (frame-rate independent).
	if recoil.length() > 0.0001:
		var step: Vector2 = recoil * minf(1.0, delta * 10.0)
		yaw += step.x
		pitch = clampf(pitch + step.y, min_pitch, max_pitch)
		recoil -= step
		_apply_transform()
	# Smooth zoom toward aim/normal distance.
	if arm and not first_person:
		var target := aim_distance if aiming else normal_distance
		arm.spring_length = lerpf(arm.spring_length, target, minf(1.0, delta * 8.0))
	if cam:
		var target_fov := 55.0 if (aiming and not first_person) else 70.0
		cam.fov = lerpf(cam.fov, target_fov, minf(1.0, delta * 8.0))

func _apply_transform() -> void:
	rotation = Vector3(0, yaw, 0)
	if first_person:
		if arm:
			arm.spring_length = 0.15
		position = first_person_offset
		if cam:
			cam.rotation = Vector3(pitch, 0, 0)
	else:
		position = Vector3(0, 1.55, 0)
		if arm:
			arm.rotation = Vector3(pitch, 0, 0)
			# Shoulder offset via arm position (cheap over-shoulder feel).
			arm.position = shoulder_offset if aiming else Vector3.ZERO

func get_camera() -> Camera3D:
	return cam

func get_muzzle_hint() -> Vector3:
	if cam:
		return cam.global_transform.origin
	return global_transform.origin
