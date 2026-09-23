extends RefCounted
## ItemDatabase — all loot items + weighted spawn table.
class_name ItemDatabase

const IR := preload("res://src/items/ItemResource.gd")

static func all() -> Array:
	var out: Array = []
	out.append(_make("bandage", "Bandage", "heal", "", "", 1, 25.0, 0.0, "", 5, Color(0.95, 0.95, 0.9)))
	out.append(_make("medkit", "Medkit", "heal", "", "", 1, 100.0, 0.0, "", 2, Color(0.9, 0.25, 0.2)))
	out.append(_make("vest", "Tactical Vest", "armor", "", "", 1, 0.0, 50.0, "", 1, Color(0.3, 0.35, 0.5)))
	out.append(_make("ammo_light", "9mm Rounds", "ammo", "", "light", 30, 0.0, 0.0, "", 99, Color(0.9, 0.8, 0.3)))
	out.append(_make("ammo_medium", "Rifle Rounds", "ammo", "", "medium", 30, 0.0, 0.0, "", 99, Color(0.9, 0.6, 0.2)))
	out.append(_make("ammo_shells", "12G Shells", "ammo", "", "shells", 8, 0.0, 0.0, "", 99, Color(0.8, 0.3, 0.15)))
	out.append(_make("ammo_heavy", "Long Rounds", "ammo", "", "heavy", 10, 0.0, 0.0, "", 99, Color(0.6, 0.8, 0.9)))
	out.append(_make("w_smg", "DS-SMG Wasp", "weapon", "smg", "", 1, 0.0, 0.0, "", 1, Color(0.2, 0.2, 0.22)))
	out.append(_make("w_shotgun", "DS-SG Mauler", "weapon", "shotgun", "", 1, 0.0, 0.0, "", 1, Color(0.25, 0.2, 0.15)))
	out.append(_make("w_sniper", "DS-SR Longspur", "weapon", "sniper", "", 1, 0.0, 0.0, "", 1, Color(0.15, 0.25, 0.15)))
	out.append(_make("w_pistol", "DS-P9 Sidewinder", "weapon", "pistol", "", 1, 0.0, 0.0, "", 1, Color(0.3, 0.3, 0.32)))
	out.append(_make("att_suppressor", "Suppressor", "attachment", "", "", 1, 0.0, 0.0, "suppressor", 1, Color(0.1, 0.1, 0.1)))
	out.append(_make("att_grip", "Vert Grip", "attachment", "", "", 1, 0.0, 0.0, "grip", 1, Color(0.4, 0.35, 0.25)))
	return out

static func by_id(iid: String):
	for it in all():
		if it.get("id") == iid:
			return it
	return null

## Weighted spawn table: [item_id, weight].
static func loot_table() -> Array:
	return [
		["bandage", 20], ["ammo_medium", 18], ["ammo_light", 16],
		["w_smg", 8], ["w_shotgun", 8], ["medkit", 8], ["vest", 7],
		["ammo_shells", 7], ["w_pistol", 5], ["w_sniper", 4],
		["ammo_heavy", 4], ["att_suppressor", 3], ["att_grip", 3],
	]

static func _make(id: String, nm: String, kind: String, wid: String, cal: String, amt: int, heal: float, arm: float, att: String, stack: int, tint: Color):
	var it = IR.new()
	it.set("id", id)
	it.set("display_name", nm)
	it.set("kind", kind)
	it.set("weapon_id", wid)
	it.set("caliber", cal)
	it.set("amount", amt)
	it.set("heal_amount", heal)
	it.set("armor_amount", arm)
	it.set("attachment_id", att)
	it.set("max_stack", stack)
	it.set("tint", tint)
	return it
