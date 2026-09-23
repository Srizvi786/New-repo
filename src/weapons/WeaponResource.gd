extends Resource
## WeaponResource — data-driven weapon definition. No hardcoded stats in Player.
class_name WeaponResource

@export var id: String = "ar"
@export var display_name: String = "DS-AR Jackal"
## Damage per body hit at close range.
@export var damage: float = 24.0
@export var headshot_mult: float = 1.8
## Shots per second.
@export var fire_rate: float = 9.0
@export var mag_size: int = 30
@export var reserve_start: int = 90
@export var reload_time: float = 2.2
@export var automatic: bool = true
## Recoil kick applied to CameraRig (radians).
@export var recoil_pitch: float = 0.004
@export var recoil_yaw: float = 0.003
## Base spread in degrees (hip) — aiming divides by ~3.
@export var spread_deg: float = 1.6
@export var range_m: float = 120.0
