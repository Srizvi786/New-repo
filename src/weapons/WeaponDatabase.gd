extends RefCounted
## WeaponDatabase — the 5 launch weapons (original names/stats, tunable).
class_name WeaponDatabase

const WR := preload("res://src/weapons/WeaponResource.gd")

static func all() -> Array:
	var out: Array = []
	out.append(_make("ar", "DS-AR Jackal", 24.0, 1.8, 9.0, 30, 90, 2.2, true, 0.004, 0.003, 1.6, 120.0))
	out.append(_make("smg", "DS-SMG Wasp", 16.0, 1.6, 13.0, 32, 96, 1.9, true, 0.003, 0.003, 2.4, 60.0))
	out.append(_make("shotgun", "DS-SG Mauler", 9.0 * 1.0, 1.5, 1.2, 6, 24, 2.6, false, 0.02, 0.012, 5.0, 30.0))
	out.append(_make("sniper", "DS-SR Longspur", 80.0, 2.0, 0.8, 5, 15, 3.2, false, 0.02, 0.01, 0.25, 300.0))
	out.append(_make("pistol", "DS-P9 Sidewinder", 18.0, 1.7, 4.5, 12, 48, 1.6, false, 0.005, 0.004, 1.2, 60.0))
	return out

static func by_id(wid: String) -> Resource:
	for w in all():
		if w.get("id") == wid:
			return w
	return all()[0]

static func _make(id: String, nm: String, dmg: float, hs: float, rate: float, mag: int, res: int, rel: float, auto: bool, rp: float, ry: float, sp: float, rng: float) -> Resource:
	var w = WR.new()
	w.set("id", id)
	w.set("display_name", nm)
	w.set("damage", dmg)
	w.set("headshot_mult", hs)
	w.set("fire_rate", rate)
	w.set("mag_size", mag)
	w.set("reserve_start", res)
	w.set("reload_time", rel)
	w.set("automatic", auto)
	w.set("recoil_pitch", rp)
	w.set("recoil_yaw", ry)
	w.set("spread_deg", sp)
	w.set("range_m", rng)
	return w
