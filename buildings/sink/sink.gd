class_name ItemSink
extends Node

const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var grid_pos: Vector2i
var items_consumed: int = 0
var _pull_index: int = 0

func _physics_process(_delta: float) -> void:
	# Keep pulling until nothing is ready
	var keep_pulling := true
	while keep_pulling:
		keep_pulling = false
		for i in range(4):
			var dir_idx = (_pull_index + i) % 4
			var result = GameManager.pull_item(grid_pos, dir_idx)
			if not result.is_empty():
				items_consumed += 1
				var item_def = _get_item_def(result.id)
				var export_val: int = item_def.export_value if item_def else 1
				GameManager.record_delivery(result.id, export_val)
				_pull_index = (dir_idx + 1) % 4
				keep_pulling = true
				break

func _get_item_def(item_id: StringName):
	return GameManager.get_item_def(item_id)

# ── Pull interface ─────────────────────────────────────────────────────────────

func has_output_toward(_target_pos: Vector2i) -> bool:
	return false

func can_provide_to(_target_pos: Vector2i) -> bool:
	return false

func peek_output_for(_target_pos: Vector2i) -> StringName:
	return &""

func take_item_for(_target_pos: Vector2i) -> StringName:
	return &""

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return true

func cleanup_visuals() -> void:
	pass
