extends RefCounted
## TracerFX — pooled world tracers for bots/events (max 32 live, nodes reused).
## Player gun keeps its own capped pool (high fire rate).
class_name TracerFX

static var _pool: Array = []
static var _mat: StandardMaterial3D = null
const MAX_LIVE := 32

static func _get_mat() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.8)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _mat

static func spawn(host: Node, a: Vector3, b: Vector3, color: Color = Color(1.0, 0.85, 0.4, 0.8), life: float = 0.08) -> void:
	if host == null:
		return
	_prune(host)
	if _live_count() >= MAX_LIVE:
		return
	var mi: MeshInstance3D = null
	for n in _pool:
		if is_instance_valid(n) and not (n as MeshInstance3D).visible and (n as Node).get_parent() == host:
			mi = n
			break
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = _get_mat()
		host.add_child(mi)
		_pool.append(mi)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	mi.mesh = im
	mi.global_transform = Transform3D.IDENTITY
	mi.visible = true
	if color != Color(1.0, 0.85, 0.4, 0.8):
		var m := _get_mat().duplicate() as StandardMaterial3D
		m.albedo_color = color
		mi.material_override = m
	else:
		mi.material_override = _get_mat()
	await host.get_tree().create_timer(life).timeout
	if is_instance_valid(mi):
		mi.visible = false

static func _live_count() -> int:
	var n := 0
	for mi in _pool:
		if is_instance_valid(mi) and (mi as MeshInstance3D).visible:
			n += 1
	return n

static func _prune(host: Node) -> void:
	# Drop pooled nodes whose scene went away (match redeploy).
	for i in range(_pool.size() - 1, -1, -1):
		var mi = _pool[i]
		if not is_instance_valid(mi) or not mi.is_inside_tree():
			_pool.remove_at(i)
		elif host and mi.get_parent() != host and not (mi as MeshInstance3D).visible:
			(mi as Node).queue_free()
			_pool.remove_at(i)

static func clear_pool() -> void:
	for mi in _pool:
		if is_instance_valid(mi):
			(mi as Node).queue_free()
	_pool.clear()
