class_name BuildingBase
extends Node2D

var grid_pos: Vector2i
var building_id: StringName
var rotation_index: int = 0 # 0=right, 1=down, 2=left, 3=up

## Reference to the building's logic node (ConveyorBelt, ExtractorLogic, etc.).
## All logic nodes implement the pull interface: has_output_toward(), can_provide_to(),
## peek_output_for(), take_item_for(), has_input_from(), cleanup_visuals().
var logic: Node = null

func init(p_id: StringName, p_grid_pos: Vector2i, p_rotation: int = 0) -> void:
	building_id = p_id
	grid_pos = p_grid_pos
	rotation_index = p_rotation
