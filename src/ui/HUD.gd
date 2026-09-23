extends Control
## HUD — health/ammo/crosshair/state. Touch-friendly, anchor-based.

@onready var _hp: ProgressBar = $TopLeft/HP
@onready var _armor: ProgressBar = $TopLeft/Armor
@onready var _ammo: Label = $BottomRight/Ammo
@onready var _slots: Label = $BottomRight/Slots
@onready var _state: Label = $TopRight/StateLabel
@onready var _cross: CenterContainer = $Crosshair
@onready var _hitmark: Label = $Crosshair/Hitmark

var player: Node = null
var weapon: Node = null
var _hit_t: float = 0.0

func _ready() -> void:
	visible = false

func bind(p: Node, w: Node) -> void:
	player = p
	weapon = w
	visible = true
	_hit_t = 0.0
	if weapon and weapon.has_signal("hit_confirmed"):
		if not weapon.is_connected("hit_confirmed", _on_hit_confirmed):
			weapon.connect("hit_confirmed", _on_hit_confirmed)

func show_hitmarker(killed: bool) -> void:
	_hit_t = 0.3 if killed else 0.15
	_hitmark.visible = true
	_hitmark.add_theme_color_override("font_color", Color(1, 0.1, 0.05, 1) if killed else Color(1, 0.9, 0.9, 1))

func _on_hit_confirmed(hit: bool, _head: bool) -> void:
	if hit:
		show_hitmarker(false)

func _process(_delta: float) -> void:
	if not visible:
		return
	if _hit_t > 0.0:
		_hit_t -= _delta
		if _hit_t <= 0.0:
			_hitmark.visible = false
	if player and "health" in player:
		_hp.value = float(player.get("health"))
	if player and "armor" in player:
		_armor.value = float(player.get("armor"))
	if player and "anim_state" in player:
		var st := str(player.get("anim"))
		_state.text = "M1  •  %s  •  OFFLINE" % str(player.get("anim_state"))
	if weapon and "ammo_in_mag" in weapon:
		var wname := "DS-AR Jackal"
		var wr = weapon.get("weapon")
		if wr:
			wname = str(wr.get("display_name"))
		_ammo.text = "%d / %d\n%s" % [int(weapon.get("ammo_in_mag")), int(weapon.get("reserve")), wname]
		var winv = weapon.get("inv")
		if winv:
			_slots.text = "  ".join(winv.call("summary"))
	var aiming := false
	if player and "aiming" in player:
		aiming = bool(player.get("aiming"))
	_cross.visible = aiming or Input.is_action_pressed("fire")
