extends Node
## LootManager — spawns loot, answers nearest-pickup queries, applies pickups.
class_name LootManager

const PickupScript := preload("res://src/items/LootPickup.gd")
const Items := preload("res://src/items/ItemDatabase.gd")
const WDB := preload("res://src/weapons/WeaponDatabase.gd")

const AMMO_CAPS := {"light": 180, "medium": 180, "shells": 32, "heavy": 25}
const PICKUP_RADIUS := 2.6

var pickups: Array = []

func _ready() -> void:
	add_to_group("loot_manager")

func clear() -> void:
	for p in pickups:
		if is_instance_valid(p):
			p.queue_free()
	pickups.clear()

func spawn_loot(points: Array, count: int = 36, seed: int = 777) -> void:
	clear()
	if points.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var table: Array = Items.loot_table()
	var total := 0.0
	for row in table:
		total += float(row[1])
	var idxs: Array = range(points.size())
	# Fisher-Yates shuffle of indices.
	for i in range(idxs.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = idxs[i]
		idxs[i] = idxs[j]
		idxs[j] = tmp
	var n: int = mini(count, idxs.size())
	for k in range(n):
		var roll: float = rng.randf() * total
		var acc := 0.0
		var pick_id := "bandage"
		for row in table:
			acc += float(row[1])
			if roll <= acc:
				pick_id = str(row[0])
				break
		var res = Items.by_id(pick_id)
		if res == null:
			continue
		var pk = PickupScript.new()
		pk.setup(res)
		var pt: Vector3 = points[int(idxs[k])]
		pk.position = pt + Vector3(0, 0.6, 0)
		add_child(pk)
		pickups.append(pk)

func nearest(pos: Vector3, max_d: float = PICKUP_RADIUS):
	var best = null
	var best_d := max_d
	for p in pickups:
		if not is_instance_valid(p):
			continue
		var d: float = pos.distance_to((p as Node3D).position)
		if d < best_d:
			best_d = d
			best = p
	return best

func drop_at(res, pos: Vector3) -> void:
	var pk = PickupScript.new()
	pk.setup(res)
	pk.position = pos + Vector3(0, 0.6, 0)
	add_child(pk)
	pickups.append(pk)

func apply_pickup(pk, player, weapon_view) -> String:
	if not is_instance_valid(pk) or player == null:
		return ""
	var res = pk.get("item")
	if res == null:
		return ""
	var kind := str(res.get("kind"))
	var msg := ""
	if kind == "weapon":
		var wres = WDB.by_id(str(res.get("weapon_id")))
		var old = weapon_view.call("give_weapon", wres)
		if old != null:
			drop_at(_weapon_item_for(old), (player as Node3D).position)
		msg = "Picked up " + str(wres.get("display_name"))
	elif kind == "ammo":
		var cal := str(res.get("caliber"))
		var pool: int = int(weapon_view.get("inv").get("ammo").get(cal, 0))
		var space: int = int(AMMO_CAPS.get(cal, 999)) - pool
		var take: int = mini(int(res.get("amount")), maxi(0, space))
		weapon_view.get("inv").get("ammo")[cal] = pool + take
		weapon_view.call("_sync_ammo")
		msg = "Picked up %d %s" % [take, str(res.get("display_name"))]
	elif kind == "armor":
		player.get("health_node").call("add_armor", float(res.get("armor_amount")))
		msg = "Equipped vest (+%d armor)" % int(res.get("armor_amount"))
	elif kind == "heal":
		var left: int = player.get("inventory").call("add", res, 1)
		msg = "Picked up " + str(res.get("display_name")) if left == 0 else "Inventory full!"
	elif kind == "attachment":
		var att = WDB.attachment_by_id(str(res.get("attachment_id")))
		if att and weapon_view.call("attach", att):
			msg = "Attached " + str(att.get("display_name"))
		else:
			msg = "No weapon for attachment"
	pickups.erase(pk)
	pk.queue_free()
	return msg

func _weapon_item_for(wres):
	# Map a dropped weapon back to its loot item.
	for it in Items.all():
		if it.get("kind") == "weapon" and str(it.get("weapon_id")) == str(wres.get("id")):
			return it
	return Items.by_id("w_pistol")
