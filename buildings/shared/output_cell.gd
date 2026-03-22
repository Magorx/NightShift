class_name OutputCell
extends ColorRect

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

## Directional mask — which directions are valid for a receiver at this cell.
## Defined in the building's default orientation (facing right).
## Rotated automatically when the building is placed with rotation.
@export var allow_right: bool = true
@export var allow_down: bool = true
@export var allow_left: bool = true
@export var allow_up: bool = true

func get_mask() -> Array:
	return [allow_right, allow_down, allow_left, allow_up]
