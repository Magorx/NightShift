class_name ExtractorLogic
extends Node

const Inventory = preload("res://scripts/inventory.gd")
const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var grid_pos: Vector2i
var direction: int = 0
var item_id: StringName = &"iron_ore":
	set(value):
		item_id = value
		inventory = Inventory.new()
		inventory.set_capacity(item_id, 5)
var produce_interval: float = 2.0  # 1 item every 2 seconds
var _timer: float = 0.0
var inventory: Inventory = Inventory.new()

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= produce_interval and inventory.has_space(item_id):
		inventory.add(item_id)
		_timer = 0.0
	elif _timer >= produce_interval:
		_timer = produce_interval  # cap timer while full

func get_output_cell() -> Vector2i:
	return grid_pos + DIRECTION_VECTORS[direction]

func can_provide_to(target_pos: Vector2i) -> bool:
	return not inventory.is_empty() and target_pos == get_output_cell()

func take_item() -> StringName:
	inventory.remove(item_id)
	return item_id

## Returns production progress as 0.0–1.0 for the progress bar.
func get_progress() -> float:
	return clampf(_timer / produce_interval, 0.0, 1.0)
