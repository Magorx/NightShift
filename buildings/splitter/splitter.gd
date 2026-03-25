class_name SplitterLogic
extends BuildingLogic



var traverse_time: float = 1.3 # seconds for an item to cross the splitter

var buffer = ItemBuffer.new(2)

var _input_rr: RoundRobin = RoundRobin.new()
var _output_rr: RoundRobin = RoundRobin.new()

# Per-direction item count: how many buffer items target each output direction.
# Avoids O(n) scans in _find_free_output and _is_output_backed_up.
var _dir_count: Array[int] = [0, 0, 0, 0]

func configure(_def: BuildingDef, p_grid_pos: Vector2i, _rotation: int) -> void:
	super.configure(_def, p_grid_pos, _rotation)

func _physics_process(delta: float) -> void:
	_validate_outputs()
	_advance_items(delta)
	_try_pull_inputs()

func _advance_items(delta: float) -> void:
	var speed := 1.0 / traverse_time
	buffer.advance_clamped(delta, speed)
	for item in buffer.items:
		_position_item(item)

# Re-check assigned outputs each tick — if the target was removed or
# now points at us, pick another valid output from the current position.
# Also reroute completed items stuck at congested outputs to free ones.
func _validate_outputs() -> void:
	# Rebuild direction counts from scratch (buffer is tiny, this is O(capacity))
	_dir_count = [0, 0, 0, 0]
	for item in buffer.items:
		if item.output_dir_idx >= 0 and _is_valid_output(item.output_dir_idx):
			_dir_count[item.output_dir_idx] += 1
			continue
		item.output_dir_idx = _find_any_valid_output(item.from_dir_idx)
		if item.output_dir_idx >= 0:
			_dir_count[item.output_dir_idx] += 1
	# Reroute: if a completed item is stuck and a valid output has no items
	# heading to it, redirect the stuck item there.
	for item in buffer.items:
		if item.progress < 1.0 or item.output_dir_idx < 0:
			continue
		var free_dir := _find_free_output(item)
		if free_dir >= 0:
			_dir_count[item.output_dir_idx] -= 1
			item.output_dir_idx = free_dir
			_dir_count[free_dir] += 1

func _try_pull_inputs() -> void:
	if buffer.is_full():
		return
	# Entry gap: don't pull if the newest item is still too close to the entry.
	for item in buffer.items:
		if item.progress < buffer.item_gap:
			return

	var start: int = _input_rr.index % 4
	for i in range(4):
		if buffer.is_full():
			break
		var dir_idx: int = (start + i) % 4
		# Don't pull if every valid output is backed up.
		if not _has_available_output(dir_idx):
			continue
		var result = GameManager.pull_item(grid_pos, dir_idx)
		if result.is_empty():
			continue
		var output_dir := _assign_output(dir_idx)
		var item: Dictionary = buffer.add_item(result.id, {
			from_dir_idx = dir_idx,
			output_dir_idx = output_dir,
		})
		if output_dir >= 0:
			_dir_count[output_dir] += 1
		_position_item(item)
		_input_rr.advance_past(dir_idx)

# Assign output via round-robin, excluding the input direction and backed-up outputs.
func _assign_output(from_dir_idx: int) -> int:
	var start: int = _output_rr.index % 4
	for i in range(4):
		var dir_idx: int = (start + i) % 4
		if dir_idx == from_dir_idx:
			continue
		if _is_valid_output(dir_idx) and not _is_output_backed_up(dir_idx):
			_output_rr.advance_past(dir_idx)
			return dir_idx
	return -1

# Check whether pulling is allowed: block only when valid outputs exist but are ALL
# backed up.  When no outputs exist at all, allow the pull so items buffer internally
# and get routed once outputs appear.
func _has_available_output(from_dir_idx: int) -> bool:
	var any_valid := false
	var start: int = _output_rr.index % 4
	for i in range(4):
		var dir_idx: int = (start + i) % 4
		if dir_idx == from_dir_idx:
			continue
		if _is_valid_output(dir_idx):
			any_valid = true
			if not _is_output_backed_up(dir_idx):
				return true
	return not any_valid

# An output is backed up when a completed item is still waiting to be pulled from it.
func _is_output_backed_up(dir_idx: int) -> bool:
	for item in buffer.items:
		if item.output_dir_idx == dir_idx and item.progress >= 1.0:
			return true
	return false

# Find any valid output (for reassignment when original disappears).
func _find_any_valid_output(from_dir_idx: int) -> int:
	for dir_idx in range(4):
		if dir_idx == from_dir_idx:
			continue
		if _is_valid_output(dir_idx):
			return dir_idx
	return -1

# Find a valid output that no buffer item is heading to AND whose downstream can accept.
func _find_free_output(stuck_item: Dictionary) -> int:
	for dir_idx in range(4):
		if dir_idx == stuck_item.from_dir_idx:
			continue
		if dir_idx == stuck_item.output_dir_idx:
			continue
		if not _is_valid_output(dir_idx):
			continue
		if _dir_count[dir_idx] > 0:
			continue
		if not _can_downstream_accept(dir_idx):
			continue
		return dir_idx
	return -1

# Check if the building at the given output direction has room to accept an item.
# Uses the common BuildingLogic.can_accept_from() interface — no type checks needed.
func _can_downstream_accept(dir_idx: int) -> bool:
	var neighbor_pos: Vector2i = grid_pos + DIRECTION_VECTORS[dir_idx]
	var building = GameManager.buildings.get(neighbor_pos)
	if not building or not building.logic:
		return false
	var from_dir: int = (dir_idx + 2) % 4
	return building.logic.can_accept_from(from_dir)

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

# Items report availability based on their assigned output direction.
# The reroute logic in _validate_outputs handles redirecting stuck items to free outputs.
func can_provide_to(target_pos: Vector2i) -> bool:
	for item in buffer.items:
		if item.progress >= 1.0 and item.output_dir_idx >= 0:
			if grid_pos + DIRECTION_VECTORS[item.output_dir_idx] == target_pos:
				return true
	return false

func peek_output_for(target_pos: Vector2i) -> StringName:
	for item in buffer.items:
		if item.progress >= 1.0 and item.output_dir_idx >= 0:
			if grid_pos + DIRECTION_VECTORS[item.output_dir_idx] == target_pos:
				return item.id
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	for i in range(buffer.items.size()):
		var item = buffer.items[i]
		if item.progress >= 1.0 and item.output_dir_idx >= 0:
			if grid_pos + DIRECTION_VECTORS[item.output_dir_idx] == target_pos:
				_dir_count[item.output_dir_idx] -= 1
				buffer.free_visual(item)
				var item_id: StringName = item.id
				buffer.items.remove_at(i)
				return item_id
	return &""

func can_accept_from(_from_dir_idx: int) -> bool:
	return not buffer.is_full()

# ── Visuals ──────────────────────────────────────────────────────────────────

# Quadratic bezier: entry edge -> center -> exit edge (same curve as conveyor).
# Falls back to linear entry->center when no output is assigned yet.
func _position_item(item: Dictionary) -> void:
	if not item.visual:
		return
	var center := Vector2(grid_pos) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	var entry_dir := Vector2(DIRECTION_VECTORS[item.from_dir_idx])
	var entry_point := center + entry_dir * 0.5 * TILE_SIZE
	var t: float = item.progress

	if item.output_dir_idx >= 0:
		var exit_dir := Vector2(DIRECTION_VECTORS[item.output_dir_idx])
		var exit_point := center + exit_dir * 0.5 * TILE_SIZE
		item.visual.position = entry_point * (1-t)*(1-t) + center * 2*(1-t)*t + exit_point * t*t
	else:
		item.visual.position = entry_point.lerp(center, t)

func cleanup_visuals() -> void:
	buffer.cleanup()
	_dir_count = [0, 0, 0, 0]

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var buffer_data: Array = []
	for item in buffer.items:
		buffer_data.append({
			"id": str(item.id),
			"from_dir_idx": item.from_dir_idx,
			"output_dir_idx": item.output_dir_idx,
			"progress": item.progress,
		})
	return {"buffer": buffer_data}

func deserialize_state(state: Dictionary) -> void:
	if not state.has("buffer"):
		return
	for item_data in state["buffer"]:
		var item: Dictionary = buffer.add_item(StringName(item_data["id"]), {
			from_dir_idx = int(item_data["from_dir_idx"]),
			output_dir_idx = int(item_data.get("output_dir_idx", -1)),
		})
		item.progress = float(item_data.get("progress", 0.0))
		_position_item(item)

# ── Info panel ─────────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	return [
		{type = "stat", text = "Items: %d/%d" % [buffer.size(), buffer.capacity]},
	]
