class_name JunctionLogic
extends Node

const ItemBuffer = preload("res://buildings/shared/item_buffer.gd")
const RoundRobin = preload("res://scripts/round_robin.gd")
const TILE_SIZE := 32
const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var grid_pos: Vector2i
var traverse_time: float = 1.3

# Per-axis buffers: 0 = horizontal (right/left), 1 = vertical (down/up).
var buffers: Array = [ItemBuffer.new(2), ItemBuffer.new(2)]

var _input_rr: RoundRobin = RoundRobin.new()

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
		buffers[axis].advance_unclamped(delta, speed)
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

# ── Pull-compatible output interface ─────────────────────────────────────────

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

# ── Visuals ──────────────────────────────────────────────────────────────────

# Straight-line interpolation from entry edge to exit edge (opposite sides).
func _position_item(item: Dictionary) -> void:
	if not item.visual:
		return
	var center := Vector2(grid_pos) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	var entry_dir := Vector2(DIRECTION_VECTORS[item.from_dir_idx])
	var entry_point := center + entry_dir * 0.5 * TILE_SIZE
	var exit_dir := Vector2(DIRECTION_VECTORS[item.output_dir_idx])
	var exit_point := center + exit_dir * 0.5 * TILE_SIZE
	item.visual.position = entry_point.lerp(exit_point, item.progress)

func cleanup_visuals() -> void:
	for axis in 2:
		buffers[axis].cleanup()
