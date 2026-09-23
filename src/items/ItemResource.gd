extends Resource
## ItemResource — loot/inventory definition (heals, armor, ammo, weapons, mods).
class_name ItemResource

@export var id: String = "bandage"
@export var display_name: String = "Bandage"
## kind: heal | armor | ammo | weapon | attachment
@export var kind: String = "heal"
@export var weapon_id: String = ""
@export var caliber: String = ""
@export var amount: int = 1
@export var heal_amount: float = 25.0
@export var armor_amount: float = 50.0
@export var attachment_id: String = ""
@export var max_stack: int = 5
@export var tint: Color = Color(0.9, 0.9, 0.9)
