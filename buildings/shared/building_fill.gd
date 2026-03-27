class_name BuildingFill
extends Node2D

## Reusable fill indicator for buildings. Grows vertically from bottom to top.
##
## Usage: Add a Node2D child to Rotatable, assign this script, configure
## fill_size and fill_color via @export. Call set_fill(ratio) from your logic.
## Works with any building — battery charge, fuel gauge, progress bar, etc.
## Rotates properly with the building because it's a Node2D using _draw().

@export var fill_size: Vector2 = Vector2(22, 20)
@export var fill_color: Color = Color(0.298, 0.686, 0.314, 1.0)

var _ratio: float = 0.0

func set_fill(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if _ratio != ratio:
		_ratio = ratio
		queue_redraw()

func _draw() -> void:
	if _ratio <= 0.0:
		return
	var h := fill_size.y * _ratio
	var y := fill_size.y - h
	draw_rect(Rect2(0.0, y, fill_size.x, h), fill_color)
