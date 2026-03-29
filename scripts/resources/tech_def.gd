class_name TechDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var description: String = ""
@export var ring: int = 0  # tech ring (0=free, 1=red, 2=red+green, 3=all)
@export var cost: Array[ItemStack] = []  # science packs required
@export var unlocks: Array[StringName] = []  # building IDs unlocked
