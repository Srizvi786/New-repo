extends Node
## Main — boot + world loader. Menu -> arena -> player+weapon+hud+touch wiring.

const PLAYER_SCENE := "res://src/player/Player.tscn"
const MENU_SCENE := "res://src/ui/MainMenu.tscn"
const HUD_SCENE := "res://src/ui/HUD.tscn"
const TOUCH_SCENE := "res://src/input/TouchControls.tscn"

@onready var world_root: Node3D = $WorldRoot
@onready var ui_root: CanvasLayer = $UIRoot

var input_mgr: Node = null
var audio_mgr: Node = null
var menu: Control = null
var hud: Control = null
var touch: Control = null
var player: CharacterBody3D = null
var weapon: Node3D = null
var loot_mgr: Node = null
var bot_mgr: Node = null
var match_mgr: Node = null
var zone_mgr: Node = null
var results: Control = null

const LOOT_SCRIPT := "res://src/items/LootManager.gd"
const BOTMGR_SCRIPT := "res://src/bots/BotManager.gd"
const MATCH_SCRIPT := "res://src/match/MatchManager.gd"
const ZONE_SCRIPT := "res://src/match/ZoneManager.gd"
const TFX := preload("res://src/weapons/TracerFX.gd")
const RESULTS_SCENE := "res://src/ui/Results.tscn"

func _ready() -> void:
	# Runtime helpers (kept out of the .tscn so Main.tscn stays trivial/robust).
	var im_script: Script = load("res://src/input/InputManager.gd")
	input_mgr = Node.new()
	input_mgr.set_script(im_script)
	input_mgr.name = "InputManager"
	add_child(input_mgr)
	var am_script: Script = load("res://src/audio/AudioManager.gd")
	audio_mgr = Node.new()
	audio_mgr.set_script(am_script)
	audio_mgr.name = "AudioManager"
	add_child(audio_mgr)
	_show_menu()

func _show_menu() -> void:
	_clear_world()
	if hud:
		hud.visible = false
	if touch:
		touch.visible = false
		if DisplayServer.is_touchscreen_available():
			touch.visible = false # menu has its own touch buttons
	var packed: PackedScene = load(MENU_SCENE)
	menu = packed.instantiate() as Control
	ui_root.add_child(menu)
	menu.connect("play_requested", _on_play)

func _on_play() -> void:
	if menu:
		menu.queue_free()
		menu = null
	if results:
		results.queue_free()
		results = null
	await get_tree().process_frame
	await _deploy()

func _deploy() -> void:
	# Full match deploy: arena -> loot -> player -> bots -> match wiring.
	if hud:
		hud.queue_free()
		hud = null
	TFX.clear_pool()
	var gm := get_node("/root/GameManager")
	await gm.call("start_play", world_root)
	_ensure_loot()
	_spawn_player()
	_ensure_bots()
	_ensure_zone()
	_start_match()

func _ensure_zone() -> void:
	if zone_mgr == null:
		var zs: Script = load(ZONE_SCRIPT)
		zone_mgr = Node3D.new()
		zone_mgr.set_script(zs)
		zone_mgr.name = "ZoneManager"
		add_child(zone_mgr)
		await get_tree().process_frame
	var arena := world_root.get_child(world_root.get_child_count() - 1)
	if arena and arena.has_method("get_map_bounds"):
		zone_mgr.call("reset_match", arena.call("get_map_bounds"))
	elif arena:
		zone_mgr.call("reset_match", Rect2(-60, -60, 120, 120))

func _ensure_bots() -> void:
	if bot_mgr == null:
		var bs: Script = load(BOTMGR_SCRIPT)
		bot_mgr = Node.new()
		bot_mgr.set_script(bs)
		bot_mgr.name = "BotManager"
		add_child(bot_mgr)
		await get_tree().process_frame
	var arena := world_root.get_child(world_root.get_child_count() - 1)
	bot_mgr.call("spawn_bots", arena, 11)

func _ensure_loot() -> void:
	if loot_mgr == null:
		var ls: Script = load(LOOT_SCRIPT)
		loot_mgr = Node.new()
		loot_mgr.set_script(ls)
		loot_mgr.name = "LootManager"
		add_child(loot_mgr)
		await get_tree().process_frame
	var arena := world_root.get_child(world_root.get_child_count() - 1)
	if arena and arena.has_method("get_loot_points"):
		loot_mgr.call("spawn_loot", arena.call("get_loot_points"))

func _start_match() -> void:
	if match_mgr == null:
		var ms: Script = load(MATCH_SCRIPT)
		match_mgr = Node.new()
		match_mgr.set_script(ms)
		match_mgr.name = "MatchManager"
		add_child(match_mgr)
		match_mgr.connect("match_ended", _on_match_ended)
	match_mgr.call("start_match", player, bot_mgr.get("bots"))
	if hud:
		hud.call("bind_match", match_mgr)

func _on_match_ended(result: Dictionary) -> void:
	# Freeze the battlefield behind the results screen.
	if player:
		player.set_physics_process(false)
	if bot_mgr:
		for b in bot_mgr.get("bots"):
			if is_instance_valid(b):
				b.set_physics_process(false)
	var packed: PackedScene = load(RESULTS_SCENE)
	results = packed.instantiate() as Control
	ui_root.add_child(results)
	results.call("show_result", result)
	results.connect("replay_requested", _on_replay)
	results.connect("menu_requested", _to_menu)

func _on_replay() -> void:
	if results:
		results.queue_free()
		results = null
	await get_tree().process_frame
	await _deploy()

func _to_menu() -> void:
	if results:
		results.queue_free()
		results = null
	if bot_mgr:
		bot_mgr.call("clear")
	if loot_mgr:
		loot_mgr.call("clear")
	var gm := get_node("/root/GameManager")
	gm.call("goto_menu")
	_show_menu()

func _clear_world() -> void:
	for c in world_root.get_children():
		c.queue_free()
	player = null
	weapon = null

func _spawn_player() -> void:
	var arena := world_root.get_child(world_root.get_child_count() - 1)
	var spawn := Transform3D(Basis(), Vector3(0, 1.2, 6))
	if arena and arena.has_method("get_spawn_transform"):
		spawn = arena.call("get_spawn_transform")
	var packed: PackedScene = load(PLAYER_SCENE)
	player = packed.instantiate() as CharacterBody3D
	world_root.add_child(player)
	player.global_transform = spawn
	# Weapon view (hitscan placeholder, M3 expands it).
	var wv_script: Script = load("res://src/weapons/WeaponView.gd")
	weapon = Node3D.new()
	weapon.set_script(wv_script)
	weapon.name = "WeaponView"
	get_tree().current_scene.add_child.call_deferred(weapon)
	await get_tree().process_frame
	var rig = player.get_node("CameraRig")
	var cam := rig.call("get_camera") as Camera3D
	weapon.call("setup", cam, player)
	player.call("bind", input_mgr, weapon)
	# Deaths are owned by MatchManager (M8); no direct connect here.
	# HUD (rebuilt per life; touch controls persist across respawns).
	var hpacked: PackedScene = load(HUD_SCENE)
	hud = hpacked.instantiate() as Control
	ui_root.add_child(hud)
	hud.call("bind", player, weapon)
	if touch == null:
		var tpacked: PackedScene = load(TOUCH_SCENE)
		touch = tpacked.instantiate() as Control
		ui_root.add_child(touch)
		touch.call("bind_manager", input_mgr)
	if DisplayServer.is_touchscreen_available():
		touch.visible = true
	else:
		touch.visible = false

func _process(_delta: float) -> void:
	if weapon and Input.is_action_just_pressed("reload"):
		weapon.call("start_reload")
	if player and loot_mgr and hud and bool(player.get("alive")):
		var near = loot_mgr.call("nearest", (player as Node3D).position)
		if near:
			hud.call("set_prompt", "Pick up %s  [E / USE]" % str(near.get("item").get("display_name")))
			if Input.is_action_just_pressed("interact"):
				var msg: String = loot_mgr.call("apply_pickup", near, player, weapon)
				if msg != "":
					hud.call("flash_message", msg)
		else:
			hud.call("set_prompt", "")
	# Show touch layer the moment any touch arrives (covers ChromeOS hybrids).
	if touch and not touch.visible and DisplayServer.is_touchscreen_available():
		touch.visible = true
