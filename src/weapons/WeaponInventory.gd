extends RefCounted
## WeaponInventory — 3 slots (primary/secondary/sidearm) + shared caliber pools.
class_name WeaponInventory

const SLOT_NAMES := ["Primary", "Secondary", "Sidearm"]

var slots: Array = [null, null, null]
var mags: Array = [0, 0, 0]
var current: int = 0
var switch_cd: float = 0.0
var ammo: Dictionary = {"light": 0, "medium": 0, "shells": 0, "heavy": 0}

signal changed

func tick(delta: float) -> void:
	switch_cd = maxf(0.0, switch_cd - delta)

func current_weapon():
	if current < 0 or current >= slots.size():
		return null
	return slots[current]

func add_weapon(res, mag: int = -1) -> int:
	# Returns slot index, or -1 if full (caller drops current first).
	var idx := _first_empty()
	if idx == -1:
		return -1
	slots[idx] = res
	mags[idx] = int(res.get("eff_mag")) if mag < 0 else mag
	var cal := str(res.get("caliber"))
	ammo[cal] = int(ammo.get(cal, 0)) + int(res.get("reserve_start"))
	if current_weapon() == null:
		current = idx
	emit_signal("changed")
	return idx

func replace_current(res) :
	# Swap current slot's weapon (old one is dropped by caller). Returns old weapon.
	var old = slots[current]
	slots[current] = res
	mags[current] = int(res.get("eff_mag"))
	var cal := str(res.get("caliber"))
	ammo[cal] = int(ammo.get(cal, 0)) + int(res.get("reserve_start"))
	switch_cd = float(res.get("switch_time"))
	emit_signal("changed")
	return old

func switch_to(i: int) -> bool:
	if i < 0 or i >= slots.size() or slots[i] == null:
		return false
	if i == current or switch_cd > 0.0:
		return false
	current = i
	switch_cd = float(slots[i].get("switch_time"))
	emit_signal("changed")
	return true

func switch_next() -> bool:
	for step in range(1, slots.size() + 1):
		var i: int = (current + step) % slots.size()
		if slots[i] != null and i != current and switch_cd <= 0.0:
			return switch_to(i)
	return false

func set_mag(i: int, v: int) -> void:
	mags[i] = maxi(0, v)

func summary() -> Array:
	var out: Array = []
	for i in range(slots.size()):
		if slots[i] == null:
			out.append("-")
		else:
			var mark := ">" if i == current else " "
			out.append("%s%d:%s(%d)" % [mark, i + 1, str(slots[i].get("display_name")), mags[i]])
	return out

func _first_empty() -> int:
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1
