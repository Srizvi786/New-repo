extends Node
## MatchManager (M8) — offline BR match: spawn wiring, kill feed, alive count,
## timer, win/lose detection. Server-authoritative version lands in M11.
class_name MatchManager

enum Phase { LOBBY, DROP, COMBAT, END }

signal killfeed(msg: String)
signal match_ended(result: Dictionary)

var phase: int = Phase.LOBBY
var player = null
var player_name: String = "You"
var player_kills: int = 0
var match_time: float = 0.0
var result: Dictionary = {}

func _ready() -> void:
	add_to_group("match_manager")

func apply_net_state(time_s: float, alive_n: int) -> void:
	# Passive client mirror (server is authoritative).
	match_time = time_s

func start_match(p, bots: Array) -> void:
	player = p
	player_kills = 0
	match_time = 0.0
	result = {}
	phase = Phase.DROP
	if player and player.has_signal("died"):
		if not player.is_connected("died", _on_player_died):
			player.connect("died", _on_player_died)
	for b in bots:
		if is_instance_valid(b) and b.has_signal("died"):
			if not b.is_connected("died", _on_bot_died):
				b.connect("died", _on_bot_died)
	phase = Phase.COMBAT
	emit_signal("killfeed", "Match started — %d combatants" % alive_count())

func _process(delta: float) -> void:
	if phase == Phase.COMBAT:
		match_time += delta

func alive_bots() -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group("bots"):
		if is_instance_valid(b) and bool(b.get("alive")):
			n += 1
	return n

func player_alive() -> bool:
	return player and is_instance_valid(player) and bool(player.get("alive"))

func alive_count() -> int:
	return alive_bots() + (1 if player_alive() else 0)

func time_str() -> String:
	var s := int(match_time)
	return "%02d:%02d" % [s / 60, s % 60]

func _on_bot_died(bot) -> void:
	var attacker := ""
	if bot.get("health_node"):
		attacker = str(bot.get("health_node").get("last_attacker"))
	_register_kill(str(bot.get("bot_name")), attacker)
	if player_alive() and alive_bots() == 0:
		_finish(true, 1)

func _on_player_died(attacker: String) -> void:
	_register_kill(player_name, attacker)
	_finish(false, alive_count() + 1)

func _register_kill(victim: String, attacker: String) -> void:
	if attacker == "" or attacker == victim:
		emit_signal("killfeed", "%s went down" % victim)
	else:
		emit_signal("killfeed", "%s  ▸  %s" % [attacker, victim])
		if attacker == player_name:
			player_kills += 1

func _finish(victory: bool, placement: int) -> void:
	if phase == Phase.END:
		return
	phase = Phase.END
	result = {"victory": victory, "placement": placement,
		"kills": player_kills, "time": time_str(), "alive": alive_count()}
	emit_signal("match_ended", result)

func to_results() -> Dictionary:
	return result
