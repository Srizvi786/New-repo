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
	await get_tree().process_frame
	var gm := get_node("/root/GameManager")
	await gm.call("start_play", world_root)
	_spawn_player()

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
	# HUD
	var hpacked: PackedScene = load(HUD_SCENE)
	hud = hpacked.instantiate() as Control
	ui_root.add_child(hud)
	hud.call("bind", player, weapon)
	# Touch controls (visible only on touch devices).
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
	# Show touch layer the moment any touch arrives (covers ChromeOS hybrids).
	if touch and not touch.visible and DisplayServer.is_touchscreen_available():
		touch.visible = true
