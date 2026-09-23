extends RefCounted
## PlayerInventory — heals / armor / attachments. Ammo lives in WeaponInventory.
class_name PlayerInventory

const MAX_SLOTS := 8

var stacks: Array = [] # [{res, count}]

signal changed

func slots_used() -> int:
	return stacks.size()

func add(res, count: int = 1) -> int:
	# Returns leftover that did NOT fit.
	var left := count
	for s in stacks:
		if s["res"].get("id") == res.get("id"):
			var room: int = int(res.get("max_stack")) - int(s["count"])
			var take: int = mini(room, left)
			s["count"] = int(s["count"]) + take
			left -= take
			if left <= 0:
				break
	while left > 0 and stacks.size() < MAX_SLOTS:
		var take: int = mini(int(res.get("max_stack")), left)
		stacks.append({"res": res, "count": take})
		left -= take
	emit_signal("changed")
	return left

func peek(idx: int):
	if idx < 0 or idx >= stacks.size():
		return null
	return stacks[idx]["res"]

func consume(idx: int) -> bool:
	if idx < 0 or idx >= stacks.size():
		return false
	stacks[idx]["count"] = int(stacks[idx]["count"]) - 1
	if int(stacks[idx]["count"]) <= 0:
		stacks.remove_at(idx)
	emit_signal("changed")
	return true

func drop(idx: int):
	if idx < 0 or idx >= stacks.size():
		return null
	var res = stacks[idx]["res"]
	consume(idx)
	return res

func count_of(iid: String) -> int:
	var n := 0
	for s in stacks:
		if s["res"].get("id") == iid:
			n += int(s["count"])
	return n
