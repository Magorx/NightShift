class_name PipelineLogic
extends UndergroundTransportLogic

## Pipeline: long-range underground item transport, max 9 cell gap.

func configure(def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	max_tunnel_gap = 9
	super.configure(def, p_grid_pos, rotation)

func _is_input_category(category: String) -> bool:
	return category == "pipeline"
