extends Node
## BotManager — spawns/clears lightweight bots. 11 max + player = 12 combatants.
class_name BotManager

const BotScript := preload("res://src/bots/Bot.gd")

const NAMES := ["Rook", "Sable", "Flint", "Juno", "Moss", "Talon",
	"Bram", "Kestrel", "Dune", "Ash", "Vex", "Pike"]

var bots: Array = []

func spawn_bots(arena: Node3D, count: int = 11) -> void:
	clear()
	if arena == null or not arena.has_method("get_spawn_points"):
		return
	var pts: Array = arena.call("get_spawn_points")
	if pts.is_empty():
		return
	var n: int = mini(count, mini(pts.size() - 1, NAMES.size()))
	for i in range(n):
		var b = BotScript.new()
		var spawn: Vector3 = pts[(i + 1) % pts.size()]
		b.setup(NAMES[i % NAMES.size()], spawn, float(i) * 0.023)
		arena.get_parent().add_child(b)
		bots.append(b)

func active_bots() -> int:
	var n := 0
	for b in bots:
		if is_instance_valid(b) and bool(b.get("alive")):
			n += 1
	return n

func alive_names() -> Array:
	var out: Array = []
	for b in bots:
		if is_instance_valid(b) and bool(b.get("alive")):
			out.append(str(b.get("bot_name")))
	return out

func clear() -> void:
	for b in bots:
		if is_instance_valid(b):
			b.queue_free()
	bots.clear()
