extends Node3D
## ZoneManager (M9) — shrinking safe zone. Wait -> shrink phases, DPS outside,
## world ring visuals, HUD status. Bots steer via is_inside()/get_center().
class_name ZoneManager

const PHASES := [
	{"wait": 20.0, "shrink": 25.0, "mult": 0.62, "dps": 2.0},
	{"wait": 15.0, "shrink": 20.0, "mult": 0.55, "dps": 5.0},
	{"wait": 12.0, "shrink": 15.0, "mult": 0.5, "dps": 8.0},
	{"wait": 10.0, "shrink": 12.0, "mult": 0.45, "dps": 12.0},
	{"wait": 8.0, "shrink": 10.0, "mult": 0.3, "dps": 16.0},
]

var center: Vector3 = Vector3.ZERO
var radius: float = 190.0
var target_center: Vector3 = Vector3.ZERO
var target_radius: float = 190.0
var phase_idx: int = 0
var mode: String = "WAIT" # WAIT | SHRINK | DONE
var timer: float = 0.0
var dps: float = 2.0
var active: bool = false

var _dmg_tick: float = 0.0
var _ring: MeshInstance3D
var _next_ring: MeshInstance3D
var _from_center: Vector3 = Vector3.ZERO
var _from_radius: float = 190.0

func _ready() -> void:
	add_to_group("zone_manager")
	_ring = _make_ring(Color(1, 1, 1, 0.5))
	_next_ring = _make_ring(Color(0.3, 1, 0.4, 0.6))

func reset_match(bounds: Rect2) -> void:
	var cx: float = bounds.position.x + bounds.size.x * 0.5
	var cz: float = bounds.position.y + bounds.size.y * 0.5
	center = Vector3(cx + randf_range(-40, 40), 0, cz + randf_range(-40, 40))
	radius = minf(bounds.size.x, bounds.size.y) * 0.48
	_pick_next()
	phase_idx = 0
	mode = "WAIT"
	timer = float(PHASES[0]["wait"])
	dps = float(PHASES[0]["dps"])
	active = true
	_update_rings()

func _pick_next() -> void:
	if phase_idx >= PHASES.size():
		return
	var mult: float = float(PHASES[phase_idx]["mult"])
	target_radius = maxf(8.0, radius * mult)
	var max_off: float = maxf(0.0, (radius - target_radius) * 0.6)
	target_center = center + Vector3(randf_range(-max_off, max_off), 0, randf_range(-max_off, max_off))

func _process(delta: float) -> void:
	if not active:
		return
	if _net_client():
		return # server drives; snapshots set center/radius
	timer -= delta
	if mode == "WAIT" and timer <= 0.0:
		mode = "SHRINK"
		_from_center = center
		_from_radius = radius
		timer = float(PHASES[mini(phase_idx, PHASES.size() - 1)]["shrink"])
	elif mode == "SHRINK":
		var dur: float = float(PHASES[mini(phase_idx, PHASES.size() - 1)]["shrink"])
		var k: float = clampf(1.0 - timer / dur, 0.0, 1.0)
		center = _from_center.lerp(target_center, k)
		radius = lerpf(_from_radius, target_radius, k)
		_update_rings()
		if timer <= 0.0:
			phase_idx += 1
			if phase_idx >= PHASES.size():
				mode = "DONE"
			else:
				mode = "WAIT"
				timer = float(PHASES[phase_idx]["wait"])
				dps = float(PHASES[phase_idx]["dps"])
				_pick_next()
				_update_rings()
	_dmg_tick += delta
	if _dmg_tick >= 1.0:
		_dmg_tick = 0.0
		_apply_dot()

func _apply_dot() -> void:
	if _net_client():
		return # server-authoritative damage (M11)
	for n in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(n) and bool(n.get("alive")) and not is_inside((n as Node3D).global_position):
			n.call("take_damage", dps, false, "Zone", (n as Node3D).global_position)
	for n in get_tree().get_nodes_in_group("bots"):
		if is_instance_valid(n) and bool(n.get("alive")) and not is_inside((n as Node3D).global_position):
			n.call("take_damage", dps, false, "Zone", (n as Node3D).global_position)

func is_inside(pos: Vector3) -> bool:
	var d := Vector2(pos.x - center.x, pos.z - center.z).length()
	return d <= radius

func get_center() -> Vector3:
	return target_center if mode != "DONE" else center

func status_str(player_pos: Vector3) -> String:
	if not active:
		return ""
	var inside := is_inside(player_pos)
	if mode == "WAIT":
		return "Zone shrinks in %ds%s" % [int(timer), "" if inside else " — GET TO ZONE!"]
	elif mode == "SHRINK":
		return "ZONE SHRINKING%s" % ("" if inside else " — RUN!")
	return "FINAL ZONE" if inside else "FINAL ZONE — RUN!"

func apply_net_state(c: Vector3, r: float) -> void:
	active = true
	center = c
	radius = r
	_update_rings()

func _net_client() -> bool:
	var n = get_tree().get_first_node_in_group("network_manager")
	return n != null and bool(n.call("is_active")) and not bool(n.call("is_server"))

func _make_ring(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = false
	mi.material_override = m
	add_child(mi)
	return mi

func _update_rings() -> void:
	_fit_ring(_ring, center, radius)
	_fit_ring(_next_ring, target_center, target_radius)

func _fit_ring(mi: MeshInstance3D, c: Vector3, r: float) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(0.1, r - 0.6)
	tm.outer_radius = r + 0.6
	tm.rings = 64
	tm.ring_segments = 6
	mi.mesh = tm
	mi.position = Vector3(c.x, 0.4, c.z)
