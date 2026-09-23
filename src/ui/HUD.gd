extends Control
## HUD — health/ammo/crosshair/state. Touch-friendly, anchor-based.

@onready var _hp: ProgressBar = $TopLeft/HP
@onready var _ammo: Label = $BottomRight/Ammo
@onready var _state: Label = $TopRight/StateLabel
@onready var _cross: CenterContainer = $Crosshair

var player: Node = null
var weapon: Node = null

func _ready() -> void:
	visible = false

func bind(p: Node, w: Node) -> void:
	player = p
	weapon = w
	visible = true

func _process(_delta: float) -> void:
	if not visible:
		return
	if player and "health" in player:
		_hp.value = float(player.get("health"))
	if player and "anim_state" in player:
		var st := str(player.get("anim"))
		_state.text = "M1  •  %s  •  OFFLINE" % str(player.get("anim_state"))
	if weapon and "ammo_in_mag" in weapon:
		var wname := "DS-AR Jackal"
		var wr = weapon.get("weapon")
		if wr:
			wname = str(wr.get("display_name"))
		_ammo.text = "%d / %d\n%s" % [int(weapon.get("ammo_in_mag")), int(weapon.get("reserve")), wname]
	var aiming := false
	if player and "aiming" in player:
		aiming = bool(player.get("aiming"))
	_cross.visible = aiming or Input.is_action_pressed("fire")
