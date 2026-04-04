class_name UndergroundTransportLogic
extends BuildingLogic

## Base class for underground transport buildings (tunnels, pipelines).
## Handles paired input/output ends, item buffering, underground speed zones,
## serialization, and pull interface. Subclasses only need to set class_name
## and override max_tunnel_gap if needed.

const SURFACE_VISIBLE_FRACTION := 0.75 # items vanish at 0.75 of entry cell, appear at 0.25 of exit

## Maximum number of cells between input and output (exclusive).
## Override in subclass or set in configure().
var max_tunnel_gap: int = 4

var direction: int = 0 # 0=right, 1=down, 2=left, 3=up
var is_input: bool = true # true = input end, false = output end

## Reference to the paired end (set after both are placed).
var partner: UndergroundTransportLogic = null

## Distance between input and output cells.
## Total travel distance in cells = tunnel_length + 1 (includes both endpoint cells).
var tunnel_length: int = 1

## Item buffer — items traveling through (only stored on the INPUT end).
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

func configure(def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(def, p_grid_pos, rotation)
	direction = rotation
	is_input = _is_input_category(def.category)
	set_physics_process(is_input)
	update_sprites()

## Override in subclass to match the input category name.
func _is_input_category(category: String) -> bool:
	return category == "tunnel"

func update_sprites() -> void:
	var parent = get_parent()
	var bottom: AnimatedSprite2D = parent.get_node_or_null("SpriteBottom")
	var top: AnimatedSprite2D = parent.get_node_or_null("SpriteTop")
	if bottom:
		bottom.play(&"default")
	if top:
		top.play(&"default")

func setup_pair(p_partner: UndergroundTransportLogic, p_length: int) -> void:
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
		# Visible in input cell: back edge -> 0.75 of cell
		item.visual.visible = true
		var local_t: float = p / entry_end
		var dir_vec := Vector2(DIRECTION_VECTORS[direction])
		var back_edge := GridUtils.grid_offset(grid_pos, -dir_vec, 0.5)
		var vanish_point := GridUtils.grid_offset(grid_pos, dir_vec, SURFACE_VISIBLE_FRACTION - 0.5)
		item.visual.position = back_edge.lerp(vanish_point, local_t)
	elif partner and p >= exit_start:
		# Visible in output cell: 0.25 of cell -> front edge
		item.visual.visible = true
		var local_t: float = (p - exit_start) / entry_end
		var dir_vec := Vector2(DIRECTION_VECTORS[partner.direction])
		var appear_point := GridUtils.grid_offset(partner.grid_pos, -dir_vec, SURFACE_VISIBLE_FRACTION - 0.5)
		var front_edge := GridUtils.grid_offset(partner.grid_pos, dir_vec, 0.5)
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

# ── Pull interface ─────────────────────────────────────────────────────────────

func has_input_from(_cell: Vector2i, from_dir_idx: int) -> bool:
	if not is_input or partner == null:
		return false
	var back_dir: int = (direction + 2) % 4
	return from_dir_idx == back_dir

func get_linked_positions() -> Array:
	if partner:
		return [partner.grid_pos]
	return []

func get_output_visual_distance() -> float:
	return 0.5

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

func can_accept_from(_from_dir_idx: int) -> bool:
	return can_accept()

func cleanup_visuals() -> void:
	buffer.cleanup()

func on_removing() -> void:
	if partner:
		partner.partner = null

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var state := {}
	state["tunnel_is_input"] = is_input
	state["tunnel_direction"] = direction
	state["tunnel_length"] = tunnel_length
	if partner:
		state["tunnel_partner_x"] = partner.grid_pos.x
		state["tunnel_partner_y"] = partner.grid_pos.y
	if is_input:
		var buffer_data: Array = []
		for item in buffer.items:
			buffer_data.append({
				"id": str(item.id),
				"progress": item.progress,
			})
		state["tunnel_buffer"] = buffer_data
	return state

func deserialize_state(state: Dictionary) -> void:
	if not state.has("tunnel_buffer"):
		return
	for item_data in state["tunnel_buffer"]:
		var iid := StringName(item_data["id"])
		if not GameManager.is_valid_item_id(iid):
			GameLogger.warn("Underground transport at %s: skipped invalid item '%s'" % [grid_pos, iid])
			continue
		var item: Dictionary = {
			id = iid,
			progress = float(item_data.get("progress", 0.0)),
		}
		buffer.items.append(item)

# ── Info panel ─────────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	var stats: Array = []
	if is_input:
		stats.append({type = "stat", text = "End: Input"})
	else:
		stats.append({type = "stat", text = "End: Output"})
	stats.append({type = "stat", text = "Length: %d" % tunnel_length})
	if partner:
		stats.append({type = "stat", text = "Partner: %s" % str(partner.grid_pos)})
	else:
		stats.append({type = "stat", text = "Partner: none"})
	return stats

func get_inventory_items() -> Array:
	if not is_input:
		return []
	var result: Array = []
	for id in buffer.get_item_counts():
		result.append({id = id, count = buffer.get_item_counts()[id]})
	return result

func remove_inventory_item(item_id: StringName, count: int) -> int:
	if not is_input:
		return 0
	return buffer.remove_items_by_id(item_id, count)
