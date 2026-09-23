extends Node
## Health — network-ready damage sink. Armor absorbs first, then HP.
## Knockdown skipped by design (no team mode): lethal damage kills outright.
class_name Health

signal damaged(amount: float, is_head: bool, attacker: String)
signal died(attacker: String, is_head: bool)
signal changed

@export var max_health: float = 100.0
var current: float = 100.0
## 0..100 vest points. Absorbs `absorb_frac` of each hit until depleted.
var armor: float = 0.0
var absorb_frac: float = 0.5
var alive: bool = true
var last_attacker: String = ""

func _ready() -> void:
	current = max_health

func take_damage(amount: float, is_head: bool = false, attacker: String = "") -> float:
	if not alive or amount <= 0.0:
		return 0.0
	last_attacker = attacker
	var left := amount
	if armor > 0.0:
		var absorbed: float = minf(armor, left * absorb_frac)
		armor -= absorbed
		left -= absorbed
	current = maxf(0.0, current - left)
	emit_signal("changed")
	emit_signal("damaged", left, is_head, attacker)
	if current <= 0.0:
		alive = false
		emit_signal("died", attacker, is_head)
	return left

func heal(amount: float) -> float:
	if not alive:
		return 0.0
	var before := current
	current = minf(max_health, current + amount)
	emit_signal("changed")
	return current - before

func add_armor(amount: float) -> void:
	armor = minf(100.0, armor + amount)
	emit_signal("changed")

func reset_full() -> void:
	current = max_health
	armor = 0.0
	alive = true
	emit_signal("changed")
