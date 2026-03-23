class_name ConveyorBelt
extends Node2D

const TILE_SIZE := 32
const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var grid_pos: Vector2i
var direction: int = 0 # 0=right, 1=down, 2=left, 3=up

# Array of items on this conveyor, sorted by progress (highest first)
# Each entry: {id: StringName, progress: float, entry_from: Vector2i, visual: Node2D}
var items: Array = []

var max_items: int = 2 # capacity, increase for faster belts later
var item_gap: float = 1.0 / max_items # exact spacing between items

func get_direction_vector() -> Vector2i:
	return DIRECTION_VECTORS[direction]

func get_next_pos() -> Vector2i:
	return grid_pos + get_direction_vector()

func has_item() -> bool:
	return items.size() > 0

func is_full() -> bool:
	return items.size() >= max_items

func can_accept() -> bool:
	if is_full():
		return false
	# Check if there's room at the entry (no item too close to progress 0)
	if items.size() > 0:
		var last_item = items[items.size() - 1]
		if last_item.progress < item_gap:
			return false
	return true

# Place item with entry direction tracking for smooth visuals
# entry_from: the direction FROM which the item entered (e.g. LEFT if item came from the left)
func place_item(item_id: StringName, entry_from: Vector2i = Vector2i.ZERO) -> bool:
	if not can_accept():
		return false
	# Default entry: upstream edge (opposite of conveyor direction)
	if entry_from == Vector2i.ZERO:
		entry_from = -get_direction_vector()
	var visual = _create_item_visual(item_id)
	var item_data = {id = item_id, progress = 0.0, entry_from = entry_from, visual = visual}
	items.append(item_data)
	_position_item(item_data)
	return true

# Remove and return the frontmost item (highest progress)
func pop_front_item() -> Dictionary:
	if items.size() == 0:
		return {}
	var item_data = items[0]
	if item_data.visual:
		item_data.visual.queue_free()
	items.remove_at(0)
	return item_data

func get_front_item() -> Dictionary:
	if items.size() == 0:
		return {}
	return items[0]

# Called by conveyor_system each tick
func update_items(delta: float, speed: float) -> void:
	for i in range(items.size()):
		var item = items[i]
		# Calculate max progress (can't pass the item ahead)
		var max_progress := 1.0
		if i > 0:
			max_progress = items[i - 1].progress - item_gap
		item.progress = minf(item.progress + speed * delta, max_progress)
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

	item_data.visual.position = entry_point.lerp(exit_point, item_data.progress)

func _create_item_visual(item_id: StringName) -> Node2D:
	var visual := Node2D.new()
	var item_def = _get_item_def(item_id)
	var color := Color.WHITE
	if item_def:
		color = item_def.color
	visual.set_meta("color", color)
	visual.set_script(load("res://buildings/shared/item_visual.gd"))
	GameManager.item_layer.add_child(visual)
	return visual

func cleanup_visuals() -> void:
	for item in items:
		if item.visual:
			item.visual.queue_free()
	items.clear()

func _get_item_def(item_id: StringName):
	var path := "res://resources/items/%s.tres" % str(item_id)
	if ResourceLoader.exists(path):
		return load(path)
	return null
