extends RefCounted
## TracerFX — one-shot world tracers for bots/events. Player gun keeps its
## own capped pool (high fire rate); everything else uses this (auto-frees).
class_name TracerFX

static func spawn(host: Node, a: Vector3, b: Vector3, color: Color = Color(1.0, 0.85, 0.4, 0.8), life: float = 0.08) -> void:
	if host == null:
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	host.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	await host.get_tree().create_timer(life).timeout
	if is_instance_valid(mi):
		mi.queue_free()
