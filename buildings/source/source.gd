class_name ItemSource
extends Node

const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var grid_pos: Vector2i
var direction: int = 0
var item_id: StringName = &"iron_ore"
var produce_interval: float = 1.0
var _timer: float = 0.0
var _has_ready_item: bool = false

func _physics_process(delta: float) -> void:
	if not _has_ready_item:
		_timer += delta
		if _timer >= produce_interval:
			_has_ready_item = true
			_timer = 0.0

func get_output_cell() -> Vector2i:
	return grid_pos + DIRECTION_VECTORS[direction]

func can_provide_to(target_pos: Vector2i) -> bool:
	return _has_ready_item and target_pos == get_output_cell()

func take_item() -> StringName:
	_has_ready_item = false
	return item_id

# ── Pull interface ─────────────────────────────────────────────────────────────

func has_output_toward(target_pos: Vector2i) -> bool:
	return target_pos == get_output_cell()

func peek_output_for(target_pos: Vector2i) -> StringName:
	if can_provide_to(target_pos):
		return item_id
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	if can_provide_to(target_pos):
		return take_item()
	return &""

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return false

func cleanup_visuals() -> void:
	pass
