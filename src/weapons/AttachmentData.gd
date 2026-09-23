extends Resource
## AttachmentData — weapon mod. Multipliers stack multiplicatively.
class_name AttachmentData

@export var id: String = "suppressor"
@export var display_name: String = "Suppressor"
## Slot: muzzle | grip | mag | sight
@export var slot: String = "muzzle"
@export var damage_mult: float = 1.0
@export var spread_mult: float = 1.0
@export var recoil_mult: float = 1.0
@export var reload_mult: float = 1.0
@export var mag_bonus: int = 0
