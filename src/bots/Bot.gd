extends CharacterBody3D
## Bot — lightweight offline opponent. State machine: LOOT / SEEK / ENGAGE / ZONE.
## Staggered thinking, burst fire with reaction delay, wall-blocked steering.
## Cap: 11 per match. Corpses drop their gun + ammo, then despawn.
class_name Bot

signal died(bot: Node)

const CRig := preload("res://src/player/CharacterRig.gd")
const HealthScript := preload("res://src/combat/Health.gd")
const WDB := preload("res://src/weapons/WeaponDatabase.gd")
const Items := preload("res://src/items/ItemDatabase.gd")
const PickupScript := preload("res://src/items/LootPickup.gd")
const TFx := preload("res://src/weapons/TracerFX.gd")

var bot_name: String = "Rook"
var alive: bool = true
var anim_state: String = "idle"
var health: float = 100.0
var armor: float = 0.0

var character_rig = null
var health_node = null
var weapon = null
var mag: int = 30
var cooldown: float = 0.0
var reload_t: float = 0.0
var burst_left: int = 0
var burst_cd: float = 0.0
var reaction_t: float = 0.0

var state: String = "LOOT"
var target_pos: Vector3 = Vector3.ZERO
var enemy = null
var strafe_dir: float = 1.0
var strafe_t: float = 0.0
var think_t: float = 0.0
var think_interval: float = 0.25
var speed: float = 4.2
var corpse_t: float = 0.0
var ai_enabled: bool = true # false for network proxies (M11): state applied remotely

func setup(nm: String, spawn: Vector3, stagger: float) -> void:
	bot_name = nm
	position = spawn + Vector3(0, 1.0, 0)
	think_t = stagger

func _ready() -> void:
	add_to_group("bots")
	add_to_group("damageable")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	character_rig = CRig.new()
	character_rig.name = "CharacterRig"
	add_child(character_rig)
	health_node = HealthScript.new()
	add_child(health_node)
	health_node.connect("died", _on_died)
	var wid: String = ["smg", "smg", "ar", "ar", "shotgun", "pistol"].pick_random()
	weapon = WDB.by_id(wid)
	mag = int(weapon.get("eff_mag"))
	target_pos = position

func _physics_process(delta: float) -> void:
	if not alive:
		corpse_t += delta
		if corpse_t > 20.0:
			queue_free()
		return
	cooldown = maxf(0.0, cooldown - delta)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			mag = int(weapon.get("eff_mag"))
	burst_cd = maxf(0.0, burst_cd - delta)
	think_t -= delta
	if think_t <= 0.0:
		think_t = think_interval
		if ai_enabled:
			_think()
	if ai_enabled:
		_steer(delta)
	else:
		_proxy_drift(delta)
	_update_rig()

func _think() -> void:
	if not alive:
		return
	_scan_enemy()
	var zone = get_tree().get_first_node_in_group("zone_manager")
	if zone and not bool(zone.call("is_inside", global_position)):
		state = "ZONE"
		target_pos = zone.call("get_center")
		return
	if enemy and is_instance_valid(enemy):
		state = "ENGAGE"
		return
	var loot = get_tree().get_first_node_in_group("loot_manager")
	var pk = null
	if loot:
		pk = loot.call("nearest_unclaimed", global_position, 45.0)
	if pk:
		state = "LOOT"
		target_pos = (pk as Node3D).position
		_grab_nearby()
	else:
		state = "SEEK"
		target_pos = global_position + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))

func _scan_enemy() -> void:
	var best = null
	var best_d := 60.0
	var cands: Array = []
	cands.append_array(get_tree().get_nodes_in_group("player"))
	cands.append_array(get_tree().get_nodes_in_group("bots"))
	for c in cands:
		if c == self or not is_instance_valid(c):
			continue
		if not bool(c.get("alive")):
			continue
		var d: float = global_position.distance_to((c as Node3D).global_position)
		if d < best_d and _has_los(c):
			best_d = d
			best = c
	if best != enemy and best != null:
		reaction_t = randf_range(0.35, 0.8)
		burst_left = 0
	enemy = best

func _has_los(c: Node) -> bool:
	var from: Vector3 = global_position + Vector3(0, 1.5, 0)
	var to: Vector3 = (c as Node3D).global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	return (hit["collider"] as Node) == c

func _steer(delta: float) -> void:
	var dir := Vector3.ZERO
	if state == "ENGAGE" and enemy and is_instance_valid(enemy):
		var epos: Vector3 = (enemy as Node3D).global_position
		var to: Vector3 = epos - global_position
		to.y = 0
		var dist: float = to.length()
		rotation.y = atan2(-to.x, -to.z)
		strafe_t -= delta
		if strafe_t <= 0.0:
			strafe_t = randf_range(0.8, 1.6)
			strafe_dir = [-1.0, 1.0].pick_random()
		if dist > 25.0:
			dir = to.normalized()
		elif dist < 8.0:
			dir = -to.normalized()
		else:
			dir = to.normalized().rotated(Vector3.UP, strafe_dir * 1.2)
		_try_fire(epos, dist, delta)
	else:
		var to2: Vector3 = target_pos - global_position
		to2.y = 0
		if to2.length() > 2.0:
			dir = to2.normalized()
			rotation.y = atan2(-dir.x, -dir.z)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	var want: Vector3 = dir * speed
	# cheap obstacle response: veer when blocked
	if is_on_wall() and dir.length() > 0.1:
		want = dir.rotated(Vector3.UP, 0.9) * speed
	velocity.x = want.x
	velocity.z = want.z
	move_and_slide()
	anim_state = "run" if dir.length() > 0.1 else "idle"
	if state == "ENGAGE":
		anim_state = "aim"

func _try_fire(epos: Vector3, dist: float, _delta: float) -> void:
	if reaction_t > 0.0:
		reaction_t -= _delta
		return
	if cooldown > 0.0 or reload_t > 0.0 or weapon == null:
		return
	if burst_cd <= 0.0:
		burst_left = 3 + randi() % 3
		burst_cd = randf_range(0.7, 1.4)
	if burst_left <= 0:
		return
	if mag <= 0:
		reload_t = float(weapon.get("reload_time"))
		return
	cooldown = 1.0 / maxf(0.5, float(weapon.get("fire_rate")))
	burst_left -= 1
	mag -= 1
	var from: Vector3 = global_position + Vector3(0, 1.4, 0)
	var aim: Vector3 = epos + Vector3(0, 1.0, 0)
	var spread := 0.035 + dist * 0.0012
	var hit_chance: float = clampf(1.1 - dist / 45.0, 0.15, 0.85)
	if randf() < hit_chance:
		var dmg: float = float(weapon.get("damage")) * (1.0 - 0.5 * clampf(dist / float(weapon.get("range_m")), 0.0, 1.0))
		if enemy and enemy.has_method("take_damage"):
			enemy.call("take_damage", dmg, false, bot_name, from)
		TFx.spawn(get_tree().current_scene, from, aim)
	else:
		var miss: Vector3 = aim + Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)) * (0.5 + dist * 0.05)
		TFx.spawn(get_tree().current_scene, from, miss, Color(1.0, 0.6, 0.3, 0.7))
	if character_rig:
		character_rig.play_shoot()

func _grab_nearby() -> void:
	var loot = get_tree().get_first_node_in_group("loot_manager")
	if loot == null:
		return
	var pk = loot.call("nearest", global_position, 2.4)
	if pk:
		loot.call("apply_bot_pickup", pk, self)

func _proxy_drift(delta: float) -> void:
	# Network proxy: no AI, just gravity + network-driven transform.
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()

func apply_net_state(pos: Vector3, yaw: float, hp: float, anim: String, is_alive: bool) -> void:
	global_position = pos
	rotation.y = yaw
	anim_state = anim
	if health_node and absf(float(health_node.get("current")) - hp) > 0.5:
		health_node.set("current", clampf(hp, 0.0, float(health_node.get("max_health"))))
		health = hp
	if not is_alive and alive:
		alive = false
		if character_rig:
			character_rig.play_death()

func _update_rig() -> void:
	if character_rig == null:
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	character_rig.set_state(anim_state, spd, burst_left > 0, state == "ENGAGE")

# --- damage interface (same as Player) ---
func take_damage(amount: float, is_head: bool, attacker: String, _from: Vector3 = Vector3.ZERO) -> void:
	if not alive or health_node == null:
		return
	if _net_client():
		return # server-authoritative (M11)
	health_node.take_damage(amount, is_head, attacker)
	health = float(health_node.get("current"))
	if alive and character_rig:
		character_rig.play_hit()

func is_head_hit(pos: Vector3) -> bool:
	if character_rig and character_rig.get_head_marker():
		return pos.y > character_rig.get_head_marker().global_position.y - 0.12
	return pos.y > global_position.y + 1.45

func _on_died(_attacker: String) -> void:
	alive = false
	velocity = Vector3.ZERO
	if character_rig:
		character_rig.play_death()
	collision_layer = 0
	_drop_loot()
	emit_signal("died", self)

func _drop_loot() -> void:
	var loot = get_tree().get_first_node_in_group("loot_manager")
	if loot == null or weapon == null:
		return
	for it in Items.all():
		if it.get("kind") == "weapon" and str(it.get("weapon_id")) == str(weapon.get("id")):
			loot.call("drop_at", it, global_position)
			break

func get_state_dict() -> Dictionary:
	return {"pos": global_position, "yaw": rotation.y, "alive": alive,
		"health": health, "anim": anim_state, "name": bot_name}

func _net_client() -> bool:
	var n = get_tree().get_first_node_in_group("network_manager")
	if n == null:
		return false
	return bool(n.call("is_active")) and not bool(n.call("is_server"))
