class_name JunctionLogic
extends BuildingLogic



var traverse_time: float = 1.3

# Per-axis buffers: 0 = horizontal (right/left), 1 = vertical (down/up).
var buffers: Array = [ItemBuffer.new(2), ItemBuffer.new(2)]

var _input_rr: RoundRobin = RoundRobin.new()

func configure(_def: BuildingDef, p_grid_pos: Vector2i, _rotation: int) -> void:
	super.configure(_def, p_grid_pos, _rotation)

func try_insert_item(item_id: StringName, quantity: int = 1) -> int:
	var remaining := quantity
	while remaining > 0:
		var inserted := false
		for axis in 2:
			if not buffers[axis].is_full():
				buffers[axis].add_item(item_id, {from_dir_idx = -1, output_dir_idx = -1})
				inserted = true
				break
		if not inserted:
			break
		remaining -= 1
	return remaining

func _physics_process(delta: float) -> void:
	_reverse_stranded_items()
	_advance_items(delta)
	_try_pull_inputs()

# If an item's output was removed and the entry side is now a valid output,
# reverse it so it travels back the way it came.
func _reverse_stranded_items() -> void:
	for axis in 2:
		for item in buffers[axis].items:
			if _is_valid_output(item.output_dir_idx):
				continue
			if _is_valid_output(item.from_dir_idx):
				var old_from: int = item.from_dir_idx
				item.from_dir_idx = item.output_dir_idx
				item.output_dir_idx = old_from
				item.progress = 1.0 - item.progress

func _advance_items(delta: float) -> void:
	var speed := 1.0 / traverse_time
	for axis in 2:
		buffers[axis].advance_clamped(delta, speed)
		for item in buffers[axis].items:
			_position_item(item)

func _try_pull_inputs() -> void:
	var start: int = _input_rr.index % 4
	for i in range(4):
		var dir_idx: int = (start + i) % 4
		var axis: int = dir_idx % 2
		if buffers[axis].is_full():
			continue
		# Entry gap: don't pull if newest item on this axis is too close to entry.
		var gap_blocked := false
		for item in buffers[axis].items:
			if item.progress < buffers[axis].item_gap:
				gap_blocked = true
				break
		if gap_blocked:
			continue
		var opposite_idx: int = (dir_idx + 2) % 4
		# Only accept from this direction if opposite side has valid output
		if not _is_valid_output(opposite_idx):
			continue
		var result = GameManager.pull_item(grid_pos, dir_idx)
		if result.is_empty():
			continue
		var item: Dictionary = buffers[axis].add_item(result.id, {
			from_dir_idx = dir_idx,
			output_dir_idx = opposite_idx,
		})
		_position_item(item)
		_input_rr.advance_past(dir_idx)

func _is_valid_output(dir_idx: int) -> bool:
	var neighbor_pos: Vector2i = grid_pos + DIRECTION_VECTORS[dir_idx]
	var from_dir: int = (dir_idx + 2) % 4
	return GameManager.has_input_at(neighbor_pos, from_dir)

# ── Pull interface ─────────────────────────────────────────────────────────────

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return true

func get_output_visual_distance() -> float:
	return 0.5

func has_output_toward(target_pos: Vector2i) -> bool:
	var diff: Vector2i = target_pos - grid_pos
	return diff in DIRECTION_VECTORS

func can_provide_to(target_pos: Vector2i) -> bool:
	for axis in 2:
		for item in buffers[axis].items:
			if item.progress >= 1.0:
				if grid_pos + DIRECTION_VECTORS[item.output_dir_idx] == target_pos:
					return true
	return false

func peek_output_for(target_pos: Vector2i) -> StringName:
	for axis in 2:
		for item in buffers[axis].items:
			if item.progress >= 1.0:
				if grid_pos + DIRECTION_VECTORS[item.output_dir_idx] == target_pos:
					return item.id
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	for axis in 2:
		for i in range(buffers[axis].items.size()):
			var item = buffers[axis].items[i]
			if item.progress >= 1.0:
				if grid_pos + DIRECTION_VECTORS[item.output_dir_idx] == target_pos:
					buffers[axis].free_visual(item)
					var item_id: StringName = item.id
					buffers[axis].items.remove_at(i)
					return item_id
	return &""

func can_accept_from(from_dir_idx: int) -> bool:
	return not buffers[from_dir_idx % 2].is_full()

# ── Visuals ──────────────────────────────────────────────────────────────────

# Straight-line interpolation from entry edge to exit edge (opposite sides).
func _position_item(item: Dictionary) -> void:
	if not item.visual:
		return
	var entry_dir := Vector2(DIRECTION_VECTORS[item.from_dir_idx])
	var entry_point := GridUtils.grid_offset_3d(grid_pos, entry_dir, 0.5)
	var exit_dir := Vector2(DIRECTION_VECTORS[item.output_dir_idx])
	var exit_point := GridUtils.grid_offset_3d(grid_pos, exit_dir, 0.5)
	var pos := entry_point.lerp(exit_point, item.progress)
	pos.y = 0.05
	item.visual.position = pos

func cleanup_visuals() -> void:
	for axis in 2:
		buffers[axis].cleanup()

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var axes_data: Array = []
	for axis in 2:
		var buffer_data: Array = []
		for item in buffers[axis].items:
			buffer_data.append({
				"id": str(item.id),
				"from_dir_idx": item.from_dir_idx,
				"output_dir_idx": item.output_dir_idx,
				"progress": item.progress,
			})
		axes_data.append(buffer_data)
	return {"junction_buffers": axes_data}

func deserialize_state(state: Dictionary) -> void:
	if not state.has("junction_buffers"):
		return
	var axes_data: Array = state["junction_buffers"]
	for axis in mini(axes_data.size(), 2):
		for item_data in axes_data[axis]:
			var iid := StringName(item_data["id"])
			if not GameManager.is_valid_item_id(iid):
				GameLogger.warn("Junction at %s: skipped invalid item '%s'" % [grid_pos, iid])
				continue
			var item: Dictionary = buffers[axis].add_item(iid, {
				from_dir_idx = int(item_data["from_dir_idx"]),
				output_dir_idx = int(item_data["output_dir_idx"]),
			})
			item.progress = float(item_data.get("progress", 0.0))
			_position_item(item)

# ── Info panel ─────────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	var total_items: int = buffers[0].size() + buffers[1].size()
	var total_cap: int = buffers[0].capacity + buffers[1].capacity
	return [
		{type = "stat", text = "Items: %d/%d" % [total_items, total_cap]},
	]

func get_inventory_items() -> Array:
	var counts := {}
	for axis in 2:
		for id in buffers[axis].get_item_counts():
			counts[id] = counts.get(id, 0) + buffers[axis].get_item_counts()[id]
	var result: Array = []
	for id in counts:
		result.append({id = id, count = counts[id]})
	return result

func remove_inventory_item(item_id: StringName, count: int) -> int:
	var removed := 0
	for axis in 2:
		if removed >= count:
			break
		removed += buffers[axis].remove_items_by_id(item_id, count - removed)
	return removed
