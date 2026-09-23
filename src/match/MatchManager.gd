extends Node
## MatchManager stub (M8). Local/offline phases only. Server-authoritative later (M11).
class_name MatchManager

enum Phase { LOBBY, DROP, LOOT, COMBAT, ZONE, END }

var phase: int = Phase.LOBBY
var alive: int = 1
var kills: int = 0
var timer_s: float = 0.0

func start_match(player_count: int) -> void:
	phase = Phase.DROP
	alive = player_count
	kills = 0
	timer_s = 0.0

func to_results() -> Dictionary:
	return {"winner": "You", "placement": 1, "kills": kills}
