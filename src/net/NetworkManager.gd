extends Node
## NetworkManager (M11 baseline) — ENet LAN/loopback multiplayer, offline default.
## Server-authoritative: damage validated on server (rate + sanity caps),
## 10 Hz snapshots drive client proxies, host/client combat HUD stays in sync.
## No public backend, no fake UI: menu shows OFFLINE until host/join succeeds.
class_name NetworkManager

signal status_changed(text: String)
signal feed_received(msg: String)
signal client_ready

const PORT := 7777
const BotScript := preload("res://src/bots/Bot.gd")

var mode: String = "OFFLINE" # OFFLINE | HOST | CLIENT
var peer = null
var status_text: String = "OFFLINE — bots only"
var world: Node3D = null
var rate: Dictionary = {} # attacker -> [count, window_start_msec]
var _snap_t: float = 0.0
var _send_t: float = 0.0
var my_peer_id: int = 0

func _ready() -> void:
	add_to_group("network_manager")

func is_active() -> bool:
	return mode == "HOST" or mode == "CLIENT"

func is_server() -> bool:
	return mode == "HOST" or (is_active() and multiplayer.is_server())

func host_game(w: Node3D) -> bool:
	leave()
	world = w
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_server(PORT, 12)
	if err != OK:
		status_text = "Host failed (port busy?)"
		emit_signal("status_changed", status_text)
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	mode = "HOST"
	status_text = "HOSTING on port %d" % PORT
	emit_signal("status_changed", status_text)
	return true

func join_game(ip: String, w: Node3D) -> void:
	leave()
	world = w
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		status_text = "Join failed (bad address?)"
		emit_signal("status_changed", status_text)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_conn_failed)
	mode = "CLIENT"
	my_peer_id = multiplayer.get_unique_id()
	status_text = "Connecting to %s..." % ip
	emit_signal("status_changed", status_text)

func leave() -> void:
	if peer:
		peer.close()
		peer = null
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	mode = "OFFLINE"
	status_text = "OFFLINE — bots only"
	rate.clear()
	emit_signal("status_changed", status_text)

# ------------------------------------------------------------ server side
func _on_peer_connected(pid: int) -> void:
	if mode != "HOST" or world == null:
		return
	_spawn_proxy(pid)
	rpc_id(pid, "sync_world")

func _on_peer_disconnected(pid: int) -> void:
	var p := world.get_node_or_null("NETP_%d" % pid)
	if p:
		p.queue_free()
	_relay_feed("Guest_%d left" % pid)

func _spawn_proxy(pid: int) -> void:
	if world.get_node_or_null("NETP_%d" % pid):
		return
	var b = BotScript.new()
	b.name = "NETP_%d" % pid
	b.set("ai_enabled", false)
	world.add_child(b)
	var spawn := Vector3(0, 1.5, -40.0 - float(pid % 5) * 4.0)
	b.call("setup", "Guest_%d" % pid, spawn, 0.0)
	b.set("bot_name", "Guest_%d" % pid)

func _process(delta: float) -> void:
	if mode == "HOST":
		_snap_t += delta
		if _snap_t >= 0.1:
			_snap_t = 0.0
			_broadcast_snapshot()

func _snapshot_entries() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("bots"):
		if not is_instance_valid(n):
			continue
		var tag := "host"
		if String((n as Node).name).begins_with("NETP_"):
			tag = "net:" + String((n as Node).name).trim_prefix("NETP_")
		elif (n as Node).is_in_group("bots") and not String((n as Node).name).begins_with("NETP_"):
			tag = "bot:" + String((n as Node).name)
		out.append({"tag": tag, "pos": (n as Node3D).global_position,
			"yaw": (n as Node3D).rotation.y, "hp": float(n.get("health")),
			"anim": str(n.get("anim_state")), "alive": bool(n.get("alive"))})
	return out

func _broadcast_snapshot() -> void:
	var entries := _snapshot_entries()
	var zone = get_tree().get_first_node_in_group("zone_manager")
	if zone:
		entries.append({"tag": "zone", "center": zone.get("center"), "radius": float(zone.get("radius"))})
	var mm = get_tree().get_first_node_in_group("match_manager")
	if mm:
		entries.append({"tag": "match", "time": float(mm.get("match_time")), "alive": int(mm.call("alive_count"))})
	rpc("apply_snapshot", entries)

@rpc("authority", "call_remote", "unreliable_ordered")
func apply_snapshot(entries: Array) -> void:
	if mode != "CLIENT":
		return
	for e in entries:
		_apply_entry(e)

func _apply_entry(e: Dictionary) -> void:
	var tag := str(e.get("tag", ""))
	if tag == "zone":
		var zone = get_tree().get_first_node_in_group("zone_manager")
		if zone and zone.has_method("apply_net_state"):
			zone.call("apply_net_state", e.get("center"), float(e.get("radius", 100.0)))
		return
	if tag == "match":
		var mm = get_tree().get_first_node_in_group("match_manager")
		if mm:
			mm.set("match_time", float(e.get("time", 0.0)))
		return
	if tag == "host":
		_ensure_proxy("HOST", "Host").call("apply_net_state", e["pos"], float(e["yaw"]), float(e["hp"]), str(e["anim"]), bool(e["alive"]))
	elif tag.begins_with("bot:"):
		var nm := tag.trim_prefix("bot:")
		_ensure_proxy("BOT_" + nm, nm).call("apply_net_state", e["pos"], float(e["yaw"]), float(e["hp"]), str(e["anim"]), bool(e["alive"]))
	elif tag.begins_with("net:"):
		var pid := tag.trim_prefix("net:")
		if pid == str(my_peer_id):
			_apply_self_hp(float(e["hp"]), bool(e["alive"]))
		else:
			_ensure_proxy("NETP_" + pid, "Guest_" + pid).call("apply_net_state", e["pos"], float(e["yaw"]), float(e["hp"]), str(e["anim"]), bool(e["alive"]))

func _ensure_proxy(nodename: String, display: String):
	if world == null:
		return null
	var p = world.get_node_or_null(nodename)
	if p == null:
		p = BotScript.new()
		p.name = nodename
		p.set("ai_enabled", false)
		world.add_child(p)
		p.call("setup", display, Vector3(0, 1.5, 0), 0.0)
	return p

func _apply_self_hp(hp: float, alive_now: bool) -> void:
	var me = get_tree().get_first_node_in_group("player")
	if me and me.get("health_node"):
		me.get("health_node").set("current", hp)
		me.set("health", hp)
		if not alive_now and bool(me.get("alive")):
			me.call("take_damage", 1000.0, false, "net", (me as Node3D).global_position)

# ------------------------------------------------- server damage authority
@rpc("any_peer", "call_remote", "reliable")
func request_damage(victim: String, dmg: float, head: bool, attacker: String, dist: float) -> void:
	if mode != "HOST" or not multiplayer.is_server():
		return
	var now: int = Time.get_ticks_msec()
	var r: Array = rate.get(attacker, [0, now])
	if now - int(r[1]) > 1000:
		r = [0, now]
	r[0] = int(r[0]) + 1
	rate[attacker] = r
	if int(r[0]) > 20 or dmg > 120.0 or dist > 350.0:
		return # rate / sanity reject
	var v = _find_combatant(victim)
	if v:
		v.call("take_damage", minf(dmg, 100.0), head, attacker, (v as Node3D).global_position)

func _find_combatant(nm: String):
	for n in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("bots"):
		if is_instance_valid(n) and (String((n as Node).name) == nm or str(n.get("bot_name")) == nm or (n.is_in_group("player") and nm == "You")):
			return n
	return null

func send_player_state(d: Dictionary) -> void:
	if mode == "CLIENT" and multiplayer.multiplayer_peer:
		rpc_id(1, "recv_player_state", d)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func recv_player_state(d: Dictionary) -> void:
	if mode != "HOST":
		return
	var pid: int = multiplayer.get_remote_sender_id()
	var p = world.get_node_or_null("NETP_%d" % pid) if world else null
	if p == null:
		return
	var want: Vector3 = d.get("pos", (p as Node3D).global_position)
	# anti-teleport: ignore jumps over 12 m per update
	if (p as Node3D).global_position.distance_to(want) > 12.0:
		return
	(p as Node3D).global_position = want
	(p as Node3D).rotation.y = float(d.get("yaw", 0.0))
	if p.get("character_rig"):
		p.get("character_rig").call("set_state", str(d.get("anim", "idle")), 4.0, false, false)

# ------------------------------------------------------------ client side
@rpc("authority", "call_remote", "reliable")
func sync_world() -> void:
	emit_signal("client_ready")

func _on_connected() -> void:
	my_peer_id = multiplayer.get_unique_id()
	status_text = "Connected! Syncing..."
	emit_signal("status_changed", status_text)

func _on_conn_failed() -> void:
	status_text = "Connection failed"
	emit_signal("status_changed", status_text)
	mode = "OFFLINE"

func _relay_feed(msg: String) -> void:
	rpc("client_feed", msg)

@rpc("authority", "call_remote", "reliable")
func client_feed(msg: String) -> void:
	emit_signal("feed_received", msg)
