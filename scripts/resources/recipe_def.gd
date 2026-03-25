class_name RecipeDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var converter_type: String # "smelter", "assembler", etc.
@export var inputs: Array[ItemStack]
@export var outputs: Array[ItemStack]
@export var craft_time: float = 5.0
@export var energy_cost: float = 0.0  # energy consumed when craft starts (0 = free)
