class_name SplitterLogic
extends Node

const RoundRobin = preload("res://scripts/round_robin.gd")
const TILE_SIZE := 32
const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var grid_pos: Vector2i
var traverse_time: float = 1.3 # seconds for an item to cross the splitter

# Buffer of items in transit through the splitter.
# Each entry: {id: StringName, from_dir_idx: int, output_dir_idx: int,
#              progress: float, visual: Node2D}
var _buffer: Array = []
var _buffer_capacity: int = 2
var item_gap: float = 1.0 / _buffer_capacity

var _input_rr: RoundRobin = RoundRobin.new()
var _output_rr: RoundRobin = RoundRobin.new()

func _physics_process(delta: float) -> void:
	_validate_outputs()
	_advance_items(delta)
	_try_pull_inputs()

func _advance_items(delta: float) -> void:
	var speed := 1.0 / traverse_time
	for item in _buffer:
		if item.progress < 1.0:
			item.progress = minf(item.progress + speed * delta, 1.0)
		_position_item(item)

# Re-check assigned outputs each tick — if the target was removed or
# now points at us, pick another valid output from the current position.
# Also reroute completed items stuck at congested outputs to free ones.
func _validate_outputs() -> void:
	for item in _buffer:
		if item.output_dir_idx >= 0 and _is_valid_output(item.output_dir_idx):
			continue
		item.output_dir_idx = _find_any_valid_output(item.from_dir_idx)
	# Reroute: if a completed item is stuck and a valid output has no items
	# heading to it, redirect the stuck item there.
	for item in _buffer:
		if item.progress < 1.0 or item.output_dir_idx < 0:
			continue
		var free_dir := _find_free_output(item)
		if free_dir >= 0:
			item.output_dir_idx = free_dir

func _try_pull_inputs() -> void:
	if _buffer.size() >= _buffer_capacity:
		return
	# Entry gap: don't pull if the newest item is still too close to the entry.
	for item in _buffer:
		if item.progress < item_gap:
			return

	var start: int = _input_rr.index % 4
	for i in range(4):
		if _buffer.size() >= _buffer_capacity:
			break
		var dir_idx: int = (start + i) % 4
		# Don't pull if every valid output is backed up.
		if not _has_available_output(dir_idx):
			continue
		var result = GameManager.pull_item(grid_pos, dir_idx)
		if result.is_empty():
			continue
		var output_dir := _assign_output(dir_idx)
		var visual = _create_item_visual(result.id)
		var entry := {
			id = result.id,
			from_dir_idx = dir_idx,
			output_dir_idx = output_dir,
			progress = 0.0,
			visual = visual,
		}
		_buffer.append(entry)
		_position_item(entry)
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
	for item in _buffer:
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
		var taken := false
		for other in _buffer:
			if other.output_dir_idx == dir_idx:
				taken = true
				break
		if taken:
			continue
		if not _can_downstream_accept(dir_idx):
			continue
		return dir_idx
	return -1

# Check if the building at the given output direction has room to accept an item.
func _can_downstream_accept(dir_idx: int) -> bool:
	var neighbor_pos: Vector2i = grid_pos + DIRECTION_VECTORS[dir_idx]
	var building = GameManager.buildings.get(neighbor_pos)
	if not building:
		return false
	if building.has_meta("conveyor"):
		return building.get_meta("conveyor").can_accept()
	if building.has_meta("splitter"):
		var spl = building.get_meta("splitter")
		return spl._buffer.size() < spl._buffer_capacity
	if building.has_meta("junction"):
		var jnc = building.get_meta("junction")
		var axis: int = dir_idx % 2
		return jnc._buffers[axis].size() < jnc._axis_capacity
	if building.has_meta("sink"):
		return true
	return false

func _is_valid_output(dir_idx: int) -> bool:
	var neighbor_pos: Vector2i = grid_pos + DIRECTION_VECTORS[dir_idx]
	var from_dir: int = (dir_idx + 2) % 4
	return GameManager.has_input_at(neighbor_pos, from_dir)

# ── Pull-compatible output interface ─────────────────────────────────────────

func has_output_toward(target_pos: Vector2i) -> bool:
	var diff: Vector2i = target_pos - grid_pos
	return diff in DIRECTION_VECTORS

# Any completed item can leave through any output — whichever downstream pulls first wins.
func can_provide_to(target_pos: Vector2i) -> bool:
	if not has_output_toward(target_pos):
		return false
	for item in _buffer:
		if item.progress >= 1.0:
			return true
	return false

func peek_output_for(target_pos: Vector2i) -> StringName:
	if not has_output_toward(target_pos):
		return &""
	for item in _buffer:
		if item.progress >= 1.0:
			return item.id
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	if not has_output_toward(target_pos):
		return &""
	for i in range(_buffer.size()):
		var item = _buffer[i]
		if item.progress >= 1.0:
			if item.visual:
				item.visual.queue_free()
			var item_id: StringName = item.id
			_buffer.remove_at(i)
			return item_id
	return &""

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
	for item in _buffer:
		if item.visual:
			item.visual.queue_free()
	_buffer.clear()

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

func _get_item_def(item_id: StringName):
	var path := "res://resources/items/%s.tres" % str(item_id)
	if ResourceLoader.exists(path):
		return load(path)
	return null
