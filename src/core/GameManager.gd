extends Node
## GameManager (autoload) — boot + state machine. Offline-first, network-ready stubs.
## States: BOOT -> MENU -> LOADING -> PLAYING -> RESULTS

enum State { BOOT, MENU, LOADING, PLAYING, RESULTS }

var state: int = State.BOOT
var arena_path: String = "res://src/environment/BattleMap.tscn"
var skirmish_path: String = "res://src/environment/TestArena.tscn" # dev quick-test scene
var last_result: Dictionary = {}

signal state_changed(new_state: int)

func _ready() -> void:
	state = State.MENU

func goto_menu() -> void:
	state = State.MENU
	emit_signal("state_changed", state)

func start_play(world_root: Node3D) -> void:
	if world_root == null:
		push_warning("GameManager.start_play: world_root is null")
		return
	state = State.LOADING
	emit_signal("state_changed", state)
	for c in world_root.get_children():
		c.queue_free()
	await get_tree().process_frame
	var packed: PackedScene = load(arena_path)
	if packed == null:
		push_error("GameManager: cannot load arena " + arena_path)
		state = State.MENU
		emit_signal("state_changed", state)
		return
	var arena := packed.instantiate()
	world_root.add_child(arena)
	state = State.PLAYING
	emit_signal("state_changed", state)

func end_match(winner_name: String, placement: int, kills: int) -> void:
	last_result = {"winner": winner_name, "placement": placement, "kills": kills}
	state = State.RESULTS
	emit_signal("state_changed", state)
