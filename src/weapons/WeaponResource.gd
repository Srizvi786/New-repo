extends Resource
## WeaponResource — data-driven weapon definition. No hardcoded stats in Player.
class_name WeaponResource

@export var id: String = "ar"
@export var display_name: String = "DS-AR Jackal"
## Damage per body hit at close range (per pellet).
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
## Base spread in degrees (hip) — aiming multiplies by ads_spread_mult.
@export var spread_deg: float = 1.6
@export var ads_spread_mult: float = 0.35
## Extra spread per m/s of movement.
@export var move_spread_deg: float = 0.25
@export var range_m: float = 120.0
## Pellets per shot (shotgun = 8).
@export var pellets: int = 1
## Ammo pool key: light | medium | shells | heavy.
@export var caliber: String = "medium"
## Seconds to bring up after switching.
@export var switch_time: float = 0.35
## Attached mods: slot name -> AttachmentData. Applied in effective stats.
var attachments: Dictionary = {}

func eff_damage() -> float:
	var m := 1.0
	for a in attachments.values():
		m *= float(a.get("damage_mult"))
	return damage * m

func eff_spread(aiming: bool) -> float:
	var s := spread_deg * (ads_spread_mult if aiming else 1.0)
	for a in attachments.values():
		s *= float(a.get("spread_mult"))
	return s

func eff_recoil() -> Vector2:
	var m := 1.0
	for a in attachments.values():
		m *= float(a.get("recoil_mult"))
	return Vector2(recoil_yaw * m, recoil_pitch * m)

func eff_reload() -> float:
	var m := 1.0
	for a in attachments.values():
		m *= float(a.get("reload_mult"))
	return reload_time * m

func eff_mag() -> int:
	var bonus := 0
	for a in attachments.values():
		bonus += int(a.get("mag_bonus"))
	return mag_size + bonus
