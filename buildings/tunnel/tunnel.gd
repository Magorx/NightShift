class_name TunnelLogic
extends Node

const ItemBuffer = preload("res://buildings/shared/item_buffer.gd")
const TILE_SIZE := 32
const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const SURFACE_VISIBLE_FRACTION := 0.75 # items vanish at 0.75 of entry cell, appear at 0.25 of exit

## Maximum number of cells between input and output (exclusive).
var max_tunnel_gap: int = 4

var grid_pos: Vector2i # position of THIS end (input or output)
var direction: int = 0 # 0=right, 1=down, 2=left, 3=up
var is_input: bool = true # true = input end, false = output end

## Reference to the paired tunnel end (set after both are placed).
var partner: TunnelLogic = null

## Tunnel length — Manhattan distance between input and output cells.
## Total travel distance in cells = tunnel_length + 1 (includes both endpoint cells).
var tunnel_length: int = 1

## Item buffer — items traveling through the tunnel (only stored on the INPUT end).
var buffer = ItemBuffer.new(1)

## Capacity scales with tunnel length (items per cell).
var items_per_cell: int = 1
var surface_time_per_cell: float = 1.0 # seconds per cell at entry/exit (matches conveyor)
var underground_time_per_cell: float = 0.5 # seconds per cell underground

var _surface_speed: float = 1.0 # progress/sec in entry/exit zones
var _underground_speed: float = 2.0 # progress/sec in underground zone

func _ready() -> void:
	set_physics_process(is_input)
	update_sprites()

func update_sprites() -> void:
	var parent = get_parent()
	var bottom: AnimatedSprite2D = parent.get_node_or_null("SpriteBottom")
	var top: AnimatedSprite2D = parent.get_node_or_null("SpriteTop")
	if bottom:
		bottom.play(&"default")
	if top:
		top.play(&"default")

func setup_pair(p_partner: TunnelLogic, p_length: int) -> void:
	partner = p_partner
	tunnel_length = p_length
	var total_cells: int = tunnel_length + 1
	var capacity := total_cells * items_per_cell
	if capacity < 1:
		capacity = 1
	buffer.set_capacity(capacity)
	var cell_progress: float = 1.0 / total_cells
	_surface_speed = cell_progress / surface_time_per_cell
	_underground_speed = cell_progress / underground_time_per_cell

func _physics_process(delta: float) -> void:
	if not is_input:
		return
	_advance_items(delta)
	_try_pull_input()

func _advance_items(delta: float) -> void:
	var total_cells: int = tunnel_length + 1
	var entry_end: float = SURFACE_VISIBLE_FRACTION / total_cells
	var exit_start: float = 1.0 - entry_end
	for i in range(buffer.size()):
		var item = buffer.items[i]
		var speed: float
		if item.progress < entry_end or item.progress >= exit_start:
			speed = _surface_speed
		else:
			speed = _underground_speed
		var max_progress := 1.0
		if i > 0:
			max_progress = buffer.items[i - 1].progress - buffer.item_gap
		item.progress = minf(item.progress + speed * delta, max_progress)
		_update_item_visual(item)

func _try_pull_input() -> void:
	if not can_accept():
		return
	var back_dir_idx: int = (direction + 2) % 4
	var result = GameManager.pull_item(grid_pos, back_dir_idx)
	if result.is_empty():
		return
	var item: Dictionary = buffer.add_item(result.id)
	_update_item_visual(item)

func can_accept() -> bool:
	if partner == null:
		return false
	return buffer.can_accept()

# ── Item visuals ─────────────────────────────────────────────────────────

func _update_item_visual(item: Dictionary) -> void:
	if not item.has("visual") or item.visual == null:
		return
	var p: float = item.progress
	var total_cells: int = tunnel_length + 1
	var entry_end: float = SURFACE_VISIBLE_FRACTION / total_cells
	var exit_start: float = 1.0 - entry_end

	if p <= entry_end:
		# Visible in input cell: back edge → 0.75 of cell
		item.visual.visible = true
		var local_t: float = p / entry_end
		var dir_vec := Vector2(DIRECTION_VECTORS[direction])
		var center := Vector2(grid_pos) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
		var back_edge := center - dir_vec * TILE_SIZE * 0.5
		var vanish_point := center + dir_vec * TILE_SIZE * (SURFACE_VISIBLE_FRACTION - 0.5)
		item.visual.position = back_edge.lerp(vanish_point, local_t)
	elif partner and p >= exit_start:
		# Visible in output cell: 0.25 of cell → front edge
		item.visual.visible = true
		var local_t: float = (p - exit_start) / entry_end
		var dir_vec := Vector2(DIRECTION_VECTORS[partner.direction])
		var center := Vector2(partner.grid_pos) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
		var appear_point := center - dir_vec * TILE_SIZE * (SURFACE_VISIBLE_FRACTION - 0.5)
		var front_edge := center + dir_vec * TILE_SIZE * 0.5
		item.visual.position = appear_point.lerp(front_edge, local_t)
	else:
		# Underground — hide
		item.visual.visible = false

## Recreate visuals for buffer items after save/load.
func restore_visuals() -> void:
	for item in buffer.items:
		if not item.has("visual") or item.visual == null:
			item.visual = buffer.create_visual(item.id)
			_update_item_visual(item)

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
	if not partner.buffer.is_empty() and partner.buffer.items[0].progress >= 1.0:
		return true
	return false

func peek_output_for(target_pos: Vector2i) -> StringName:
	if is_input or partner == null:
		return &""
	if grid_pos + DIRECTION_VECTORS[direction] != target_pos:
		return &""
	if not partner.buffer.is_empty() and partner.buffer.items[0].progress >= 1.0:
		return partner.buffer.items[0].id
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	if is_input or partner == null:
		return &""
	if grid_pos + DIRECTION_VECTORS[direction] != target_pos:
		return &""
	if not partner.buffer.is_empty() and partner.buffer.items[0].progress >= 1.0:
		var item = partner.buffer.pop_front()
		return item.id
	return &""

func cleanup_visuals() -> void:
	buffer.cleanup()
