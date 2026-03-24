class_name TunnelLogic
extends Node

const TILE_SIZE := 32
const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

## Maximum number of cells between input and output (exclusive).
var max_tunnel_gap: int = 4

var grid_pos: Vector2i # position of THIS end (input or output)
var direction: int = 0 # 0=right, 1=down, 2=left, 3=up
var is_input: bool = true # true = input end, false = output end

## Reference to the paired tunnel end (set after both are placed).
var partner: TunnelLogic = null

## Tunnel length in cells (distance between input and output, inclusive of both ends).
var tunnel_length: int = 1

## Item buffer — items traveling through the tunnel (only stored on the INPUT end).
## Each entry: {id: StringName, progress: float}
## progress 0.0 = just entered input, 1.0 = ready to exit at output.
var _buffer: Array = []

## Capacity scales with tunnel length (items per cell).
var items_per_cell: int = 1
var item_gap: float = 0.5 # minimum progress gap between items (computed on pair)
var traverse_time: float = 1.0 # seconds for item to traverse full tunnel (computed on pair)
var traverse_time_per_cell: float = 0.5 # seconds per cell of tunnel length

func _ready() -> void:
	set_physics_process(is_input)

func setup_pair(p_partner: TunnelLogic, p_length: int) -> void:
	partner = p_partner
	tunnel_length = p_length
	var capacity := tunnel_length * items_per_cell
	if capacity < 1:
		capacity = 1
	item_gap = 1.0 / capacity
	traverse_time = tunnel_length * traverse_time_per_cell

func _physics_process(delta: float) -> void:
	if not is_input:
		return
	_advance_items(delta)
	_try_pull_input()

func _advance_items(delta: float) -> void:
	var speed := 1.0 / traverse_time
	for i in range(_buffer.size()):
		var item = _buffer[i]
		var max_progress := 1.0
		if i > 0:
			max_progress = _buffer[i - 1].progress - item_gap
		item.progress = minf(item.progress + speed * delta, max_progress)

func _try_pull_input() -> void:
	if not can_accept():
		return
	# Pull from the input direction (opposite of tunnel direction)
	var from_dir_idx: int = direction # item comes FROM the direction we face away from
	# Actually: input accepts from the left side (opposite of direction).
	# The input's "back" side is opposite of direction.
	var back_dir_idx: int = (direction + 2) % 4
	var result = GameManager.pull_item(grid_pos, back_dir_idx)
	if result.is_empty():
		return
	_buffer.append({id = result.id, progress = 0.0})

func can_accept() -> bool:
	if partner == null:
		return false
	var capacity := tunnel_length * items_per_cell
	if _buffer.size() >= capacity:
		return false
	if _buffer.size() > 0:
		var last = _buffer[_buffer.size() - 1]
		if last.progress < item_gap:
			return false
	return true

# ── Pull-compatible output interface (called on the OUTPUT end) ──────────

func has_output_toward(target_pos: Vector2i) -> bool:
	if is_input:
		return false
	var out_dir: Vector2i = DIRECTION_VECTORS[direction]
	return grid_pos + out_dir == target_pos

func can_provide_to(target_pos: Vector2i) -> bool:
	if is_input or partner == null:
		return false
	if grid_pos + DIRECTION_VECTORS[direction] != target_pos:
		return false
	# Check the input end's buffer for a completed item
	if partner._buffer.size() > 0 and partner._buffer[0].progress >= 1.0:
		return true
	return false

func peek_output_for(target_pos: Vector2i) -> StringName:
	if is_input or partner == null:
		return &""
	if grid_pos + DIRECTION_VECTORS[direction] != target_pos:
		return &""
	if partner._buffer.size() > 0 and partner._buffer[0].progress >= 1.0:
		return partner._buffer[0].id
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	if is_input or partner == null:
		return &""
	if grid_pos + DIRECTION_VECTORS[direction] != target_pos:
		return &""
	if partner._buffer.size() > 0 and partner._buffer[0].progress >= 1.0:
		var item_id: StringName = partner._buffer[0].id
		partner._buffer.remove_at(0)
		return item_id
	return &""

func cleanup_visuals() -> void:
	_buffer.clear()
