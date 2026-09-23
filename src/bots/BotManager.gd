extends Node
## BotManager stub (M7). Interface only — no expensive AI in M1.
class_name BotManager

var bot_count: int = 0

func spawn_bots(_arena: Node3D, _count: int) -> void:
	bot_count = 0

func active_bots() -> int:
	return bot_count
