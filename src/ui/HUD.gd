extends Control
## HUD — health/ammo/crosshair/state. Touch-friendly, anchor-based.

@onready var _hp: ProgressBar = $TopLeft/HP
@onready var _armor: ProgressBar = $TopLeft/Armor
@onready var _ammo: Label = $BottomRight/Ammo
@onready var _slots: Label = $BottomRight/Slots
@onready var _state: Label = $TopRight/StateLabel
@onready var _cross: CenterContainer = $Crosshair
@onready var _hitmark: Label = $Crosshair/Hitmark
@onready var _prompt: Label = $InteractPrompt
@onready var _alive: Label = $TopCenter/AliveLabel
@onready var _timer: Label = $TopCenter/TimerLabel
@onready var _zone: Label = $TopCenter/ZoneLabel
@onready var _feed: VBoxContainer = $TopCenter/FeedBox

var match_mgr: Node = null
@onready var _panel: PanelContainer = $InvPanel
@onready var _cap: Label = $InvPanel/Margin/InvBox/CapLabel
@onready var _items_box: VBoxContainer = $InvPanel/Margin/InvBox/ItemsBox
@onready var _pause: PanelContainer = $PausePanel

var player: Node = null
var weapon: Node = null
var loot_mgr: Node = null
var _hit_t: float = 0.0
var _msg_t: float = 0.0

func _ready() -> void:
	visible = false

func bind(p: Node, w: Node) -> void:
	player = p
	weapon = w
	visible = true
	_hit_t = 0.0
	_panel.visible = false
	_pause.visible = false
	_connect_pause_buttons()
	loot_mgr = get_tree().get_first_node_in_group("loot_manager")
	if weapon and weapon.has_signal("hit_confirmed"):
		if not weapon.is_connected("hit_confirmed", _on_hit_confirmed):
			weapon.connect("hit_confirmed", _on_hit_confirmed)
	if player and player.get("inventory"):
		var inv = player.get("inventory")
		if inv.has_signal("changed") and not inv.is_connected("changed", _rebuild_list):
			inv.connect("changed", _rebuild_list)

func bind_match(m: Node) -> void:
	match_mgr = m
	if match_mgr and match_mgr.has_signal("killfeed"):
		if not match_mgr.is_connected("killfeed", push_kill):
			match_mgr.connect("killfeed", push_kill)

func push_kill(msg: String) -> void:
	var lab := Label.new()
	lab.text = msg
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 14)
	_feed.add_child(lab)
	while _feed.get_child_count() > 4:
		_feed.get_child(0).queue_free()
	await get_tree().create_timer(6.0).timeout
	if is_instance_valid(lab):
		lab.queue_free()

func set_prompt(t: String) -> void:
	if _msg_t <= 0.0:
		_prompt.text = t

func flash_message(t: String) -> void:
	_prompt.text = t
	_msg_t = 2.0

func toggle_inventory() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_rebuild_list()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not DisplayServer.is_touchscreen_available():
		pass # Main decides capture; leave as-is to avoid fighting Player

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
	if _msg_t > 0.0:
		_msg_t -= _delta
	if _hit_t > 0.0:
		_hit_t -= _delta
		if _hit_t <= 0.0:
			_hitmark.visible = false
	if player and "health" in player:
		_hp.value = float(player.get("health"))
	if player and "armor" in player:
		_armor.value = float(player.get("armor"))
	if match_mgr:
		_alive.text = "ALIVE %d" % int(match_mgr.call("alive_count"))
		_timer.text = str(match_mgr.call("time_str"))
	var zone = get_tree().get_first_node_in_group("zone_manager")
	if zone and player:
		_zone.text = str(zone.call("status_str", (player as Node3D).position))
	else:
		_zone.text = ""
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
	# heal channel indicator
	if player and player.has_method("heal_progress"):
		var hp: float = player.call("heal_progress")
		if hp >= 0.0:
			_state.text = "Healing... %d%%" % int(hp * 100.0)

func _input(event: InputEvent) -> void:
	if not visible or player == null:
		return
	if event.is_action_pressed("pause") and bool(player.get("alive")):
		toggle_pause()
		return
	if get_tree().paused:
		return
	if event.is_action_pressed("inventory"):
		toggle_inventory()
	elif event.is_action_pressed("heal"):
		_quick_heal()

func toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_pause.visible = p
	_panel.visible = false
	if p:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _connect_pause_buttons() -> void:
	var rb: Button = $PausePanel/Margin/VBox/ResumeBtn
	var mb: Button = $PausePanel/Margin/VBox/MenuBtn
	if not rb.is_connected("pressed", toggle_pause):
		rb.pressed.connect(toggle_pause)
	if not mb.is_connected("pressed", _on_quit_menu):
		mb.pressed.connect(_on_quit_menu)

func _on_quit_menu() -> void:
	get_tree().paused = false
	var m = get_tree().get_first_node_in_group("main")
	if m:
		m.call("_to_menu")

func _quick_heal() -> void:
	# First bandage/medkit stack found.
	var inv = player.get("inventory")
	if inv == null:
		return
	for i in range(inv.stacks.size()):
		var res = inv.peek(i)
		if res and str(res.get("kind")) == "heal":
			if player.call("use_item", i):
				flash_message("Using " + str(res.get("display_name")) + "...")
			else:
				flash_message("Health already full")
			return
	flash_message("No heals in backpack")

func _rebuild_list() -> void:
	if not _panel.visible or player == null:
		return
	for c in _items_box.get_children():
		c.queue_free()
	var inv = player.get("inventory")
	if inv == null:
		return
	_cap.text = "BACKPACK  %d/8" % inv.slots_used()
	if inv.stacks.is_empty():
		var empty := Label.new()
		empty.text = "(empty — walk over glowing loot, press E / USE)"
		_items_box.add_child(empty)
		return
	for i in range(inv.stacks.size()):
		var res = inv.peek(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lab := Label.new()
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.text = "%s x%d" % [str(res.get("display_name")), int(inv.stacks[i]["count"])]
		row.add_child(lab)
		var kind := str(res.get("kind"))
		if kind == "heal" or kind == "armor":
			var use_b := Button.new()
			use_b.text = "Use"
			use_b.pressed.connect(_on_use_item.bind(i))
			row.add_child(use_b)
		var drop_b := Button.new()
		drop_b.text = "Drop"
		drop_b.pressed.connect(_on_drop_item.bind(i))
		row.add_child(drop_b)
		_items_box.add_child(row)

func _on_use_item(i: int) -> void:
	if player.call("use_item", i):
		flash_message("Used item")
		_rebuild_list()
	else:
		flash_message("Cannot use now")

func _on_drop_item(i: int) -> void:
	if loot_mgr == null:
		loot_mgr = get_tree().get_first_node_in_group("loot_manager")
	if loot_mgr and player:
		var res = player.get("inventory").call("drop", i)
		if res:
			loot_mgr.call("drop_at", res, (player as Node3D).position)
			_rebuild_list()
