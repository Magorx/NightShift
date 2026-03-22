class_name ExtractorLogic
extends Node

const TILE_SIZE := 32
const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var grid_pos: Vector2i
var direction: int = 0
var item_id: StringName = &"iron_ore"
var produce_interval: float = 2.0  # 1 item every 2 seconds
var _timer: float = 0.0

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= produce_interval:
		if _try_push():
			_timer = 0.0
		else:
			_timer = produce_interval  # retry next frame

func _try_push() -> bool:
	var output_pos = grid_pos + DIRECTION_VECTORS[direction]
	var conv = GameManager.get_conveyor_at(output_pos)
	if conv and conv.can_accept():
		var entry_from = grid_pos - output_pos
		conv.place_item(item_id, entry_from)
		return true
	return false

## Returns production progress as 0.0–1.0 for the progress bar.
func get_progress() -> float:
	return clampf(_timer / produce_interval, 0.0, 1.0)
