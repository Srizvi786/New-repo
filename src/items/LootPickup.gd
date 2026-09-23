extends Node3D
## LootPickup — world loot: colored mesh + floating label + bob. Pickup via interact.
class_name LootPickup

var item = null
var _t: float = 0.0
var _base_y: float = 0.6
var _mi: MeshInstance3D

func setup(res) -> void:
	item = res

func _ready() -> void:
	add_to_group("pickup")
	_base_y = position.y
	var tint := Color(0.9, 0.9, 0.9)
	var nm := "Loot"
	if item:
		tint = item.get("tint")
		nm = str(item.get("display_name"))
	_mi = MeshInstance3D.new()
	var kind := ""
	if item:
		kind = str(item.get("kind"))
	if kind == "weapon":
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 0.18, 1.0)
		_mi.mesh = bm
	elif kind == "ammo":
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.4, 0.25, 0.3)
		_mi.mesh = bm2
	else:
		var cm := CapsuleMesh.new()
		cm.radius = 0.22
		cm.height = 0.5
		_mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission = tint
	m.emission_energy_multiplier = 0.35
	_mi.mesh.material = m
	add_child(_mi)
	var label := Label3D.new()
	label.text = nm
	label.font_size = 48
	label.pixel_size = 0.008
	label.position = Vector3(0, 0.75, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 2.0) * 0.08
	_mi.rotation.y += delta * 0.8
