class_name ConveyorBelt
extends BuildingLogic



var direction: int = 0 # 0=right, 1=down, 2=left, 3=up
var traverse_time: float = 1.0 # seconds for an item to cross this conveyor
var push_speed: float = 1.0 # tiles/s — how fast the conveyor pushes the player

var buffer = ItemBuffer.new(2)

func configure(_def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(_def, p_grid_pos, rotation)
	direction = rotation
	# Speed tiers based on building type
	match _def.id:
		&"conveyor_mk2":
			traverse_time = 0.5
			push_speed = 2.0
			buffer.set_capacity(3)
		&"conveyor_mk3":
			traverse_time = 0.333
			push_speed = 3.0
			buffer.set_capacity(4)

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
func place_item(item_id: StringName, entry_from: Vector2i = Vector2i.ZERO, entry_dist: float = 0.5) -> bool:
	if not buffer.can_accept():
		return false
	# Default entry: upstream edge (opposite of conveyor direction)
	if entry_from == Vector2i.ZERO:
		entry_from = -get_direction_vector()
	var item: Dictionary = buffer.add_item(item_id, {entry_from = entry_from, entry_dist = entry_dist})
	_position_item(item)
	return true

func try_insert_item(item_id: StringName, quantity: int = 1) -> int:
	var remaining := quantity
	while remaining > 0 and place_item(item_id):
		remaining -= 1
	return remaining

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

	# Entry edge: where the item enters the tile (0.5 = tile edge, 1.0 = source center)
	var entry_dist: float = item_data.get("entry_dist", 0.5)
	var entry_point := center + entry_dir * entry_dist * TILE_SIZE
	# Exit edge: where the item leaves the tile
	var exit_point := center + exit_dir * 0.5 * TILE_SIZE

	# Quadratic bezier: entry -> center -> exit for a curved path on side entries
	var t: float = item_data.progress
	var p0 := entry_point
	var p1 := center
	var p2 := exit_point
	item_data.visual.position = p0 * (1 - t) * (1 - t) + p1 * 2 * (1 - t) * t + p2 * t * t

# ── Pull interface ─────────────────────────────────────────────────────────────

func get_output_visual_distance() -> float:
	return 0.5

func has_output_toward(target_pos: Vector2i) -> bool:
	return get_next_pos() == target_pos

func can_provide_to(target_pos: Vector2i) -> bool:
	if get_next_pos() != target_pos or buffer.is_empty():
		return false
	return buffer.peek_front().progress >= 1.0

func peek_output_for(target_pos: Vector2i) -> StringName:
	if get_next_pos() != target_pos or buffer.is_empty():
		return &""
	var front := buffer.peek_front()
	if front.progress >= 1.0:
		return front.id
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	if get_next_pos() != target_pos or buffer.is_empty():
		return &""
	var front := buffer.peek_front()
	if front.progress >= 1.0:
		var item := pop_front_item()
		return item.id
	return &""

func has_input_from(_cell: Vector2i, from_dir_idx: int) -> bool:
	return from_dir_idx != direction

func can_accept_from(_from_dir_idx: int) -> bool:
	return can_accept()

func cleanup_visuals() -> void:
	buffer.cleanup()

func on_removing() -> void:
	GameManager.conveyor_system.unregister_conveyor(grid_pos)

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var items_data: Array = []
	for item in buffer.items:
		items_data.append({
			"id": str(item.id),
			"progress": item.progress,
			"entry_from_x": item.entry_from.x,
			"entry_from_y": item.entry_from.y,
			"entry_dist": item.get("entry_dist", 0.5),
		})
	return {"items": items_data}

func deserialize_state(state: Dictionary) -> void:
	if not state.has("items"):
		return
	for item_data in state["items"]:
		var item_id := StringName(item_data["id"])
		if not GameManager.is_valid_item_id(item_id):
			GameLogger.warn("Conveyor at %s: skipped invalid item '%s'" % [grid_pos, item_id])
			continue
		var entry_from := Vector2i(int(item_data["entry_from_x"]), int(item_data["entry_from_y"]))
		var entry_dist: float = item_data.get("entry_dist", 0.5)
		if place_item(item_id, entry_from, entry_dist):
			var placed_item = buffer.items[buffer.size() - 1]
			placed_item.progress = item_data["progress"]
			_position_item(placed_item)

# ── Info panel ─────────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	var dirs := ["Right", "Down", "Left", "Up"]
	return [
		{type = "stat", text = "Items on belt: %d/%d" % [buffer.size(), buffer.capacity]},
		{type = "stat", text = "Direction: %s" % dirs[direction]},
	]

func get_inventory_items() -> Array:
	var result: Array = []
	for id in buffer.get_item_counts():
		result.append({id = id, count = buffer.get_item_counts()[id]})
	return result
