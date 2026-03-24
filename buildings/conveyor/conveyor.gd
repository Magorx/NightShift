class_name ConveyorBelt
extends Node2D

const ItemBuffer = preload("res://buildings/shared/item_buffer.gd")
const TILE_SIZE := 32
const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var grid_pos: Vector2i
var direction: int = 0 # 0=right, 1=down, 2=left, 3=up
var traverse_time: float = 1.0 # seconds for an item to cross this conveyor

var buffer = ItemBuffer.new(2)

func get_direction_vector() -> Vector2i:
	return DIRECTION_VECTORS[direction]

func get_next_pos() -> Vector2i:
	return grid_pos + get_direction_vector()

func has_item() -> bool:
	return not buffer.is_empty()

func is_full() -> bool:
	return buffer.is_full()

func can_accept() -> bool:
	return buffer.can_accept()

# Place item with entry direction tracking for smooth visuals
# entry_from: the direction FROM which the item entered (e.g. LEFT if item came from the left)
func place_item(item_id: StringName, entry_from: Vector2i = Vector2i.ZERO) -> bool:
	if not buffer.can_accept():
		return false
	# Default entry: upstream edge (opposite of conveyor direction)
	if entry_from == Vector2i.ZERO:
		entry_from = -get_direction_vector()
	var item: Dictionary = buffer.add_item(item_id, {entry_from = entry_from})
	_position_item(item)
	return true

# Remove and return the frontmost item (highest progress)
func pop_front_item() -> Dictionary:
	return buffer.pop_front()

func get_front_item() -> Dictionary:
	return buffer.peek_front()

# Called by conveyor_system each tick
func update_items(delta: float, speed: float) -> void:
	buffer.advance_clamped(delta, speed)
	for item in buffer.items:
		_position_item(item)

func _position_item(item_data: Dictionary) -> void:
	if not item_data.visual:
		return
	var center := Vector2(grid_pos) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	var exit_dir := Vector2(get_direction_vector())
	var entry_dir := Vector2(item_data.entry_from)

	# Entry edge: where the item enters the tile
	var entry_point := center + entry_dir * 0.5 * TILE_SIZE
	# Exit edge: where the item leaves the tile
	var exit_point := center + exit_dir * 0.5 * TILE_SIZE

	# Quadratic bezier: entry -> center -> exit for a curved path on side entries
	var t: float = item_data.progress
	var p0 := entry_point
	var p1 := center
	var p2 := exit_point
	item_data.visual.position = p0 * (1 - t) * (1 - t) + p1 * 2 * (1 - t) * t + p2 * t * t

func cleanup_visuals() -> void:
	buffer.cleanup()
