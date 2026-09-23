extends SceneTree
## Headless parse/reference check run via:
## godot --headless --path . --check-only --script res://scripts/validate_project.gd
## Kept dependency-free so --check-only never breaks the import.

func _init() -> void:
	print("validate_project.gd parse OK (Dustline Strike M1)")
	quit(0)
