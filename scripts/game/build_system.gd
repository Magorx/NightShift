extends Node2D

signal building_clicked(building: Node2D)

const TILE_SIZE := 32
const MAP_SIZE := 64
const GHOST_COLOR := Color(0.4, 0.6, 1.0, 0.4)
const GHOST_INVALID_COLOR := Color(1.0, 0.3, 0.3, 0.4)
const BLUEPRINT_COLOR := Color(0.3, 0.7, 1.0, 0.35)
const BLUEPRINT_INVALID_COLOR := Color(1.0, 0.3, 0.3, 0.25)
const ARROW_COLOR := Color(1, 1, 1, 0.6)
const DESTROY_AREA_COLOR := Color(1.0, 0.2, 0.2, 0.15)
const DESTROY_CURSOR_COLOR := Color(1.0, 0.2, 0.2, 0.25)
const DESTROY_OUTLINE_COLOR := Color(1.0, 0.2, 0.15, 0.85)
const OUTLINE_WIDTH := 2.0

var _destroy_shader: Shader = preload("res://buildings/shared/destroy_highlight.gdshader")

var cursor_grid_pos := Vector2i.ZERO
var selected_building: StringName = &"conveyor"
var current_rotation: int = 0 # 0=right, 1=down, 2=left, 3=up
var rotation_locked: bool = false # when true, drag doesn't auto-set rotation

# Building mode: when false, player is in inspect mode
var building_mode: bool = false

# Destroy mode
var destroy_mode: bool = false
var _destroy_dragging: bool = false
var _destroy_drag_start := Vector2i.ZERO
# Shader highlight tracking: instance_id -> Array of {node, original}
var _highlighted_buildings: Dictionary = {}

# Drag state (build mode)
var _dragging: bool = false
var _drag_start_pos := Vector2i.ZERO
var _drag_axis: int = -1 # -1=undecided, 0=horizontal, 1=vertical
var _drag_rotation: int = 0
var _blueprints: Array = [] # Array of Vector2i positions (all candidates)
var _placeable_blueprints: Array = [] # subset that don't overlap each other

# Multi-phase placement state (for buildings like tunnels that need 2+ clicks)
var _phase_index: int = -1 # -1 = normal single-phase, 0+ = current phase
var _phase_config: Dictionary = {} # placement_phases entry for current building
var _phase_placements: Array = [] # Array of Arrays of {pos: Vector2i, rotation: int}

func _process(_delta: float) -> void:
	cursor_grid_pos = _get_grid_pos_under_mouse()
	if _dragging:
		_update_blueprints()
	if destroy_mode:
		_update_destroy_highlights()
	elif not _highlighted_buildings.is_empty():
		_clear_all_highlights()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if building_mode:
				if event.pressed:
					_start_drag(cursor_grid_pos)
				else:
					_commit_drag()
			elif destroy_mode:
				if event.pressed:
					_destroy_dragging = true
					_destroy_drag_start = cursor_grid_pos
				else:
					_commit_destroy()
			else:
				# Inspect mode
				if event.pressed:
					_try_inspect(cursor_grid_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if building_mode:
				if _phase_index > 0:
					# In a later phase — cancel everything (remove prior placements)
					if _dragging:
						_cancel_drag()
					_cancel_multiphase()
					exit_building_mode()
				elif _dragging:
					_cancel_drag()
				else:
					exit_building_mode()
			elif destroy_mode:
				if _destroy_dragging:
					_destroy_dragging = false
				else:
					exit_destroy_mode()
	elif event.is_action_pressed(&"rotate_building"):
		if building_mode:
			current_rotation = (current_rotation + 1) % 4
			if _dragging:
				_drag_rotation = current_rotation
	elif event.is_action_pressed(&"destroy_mode_toggle"):
		if destroy_mode:
			exit_destroy_mode()
		else:
			enter_destroy_mode()
	elif event.is_action_pressed(&"lock_rotation"):
		rotation_locked = not rotation_locked
	elif event.is_action_pressed(&"debug_spawn_item"):
		_debug_spawn_item(cursor_grid_pos)
	elif event.is_action_pressed(&"build_mode_toggle"):
		if building_mode:
			exit_building_mode()
		else:
			if destroy_mode:
				exit_destroy_mode()
			enter_building_mode(GameManager.last_selected_building)

# ── Mode management ──────────────────────────────────────────────────────────

func enter_building_mode(building_id: StringName) -> void:
	if destroy_mode:
		exit_destroy_mode()
	_cancel_multiphase()
	selected_building = building_id
	building_mode = true
	GameManager.last_selected_building = building_id
	# Check for multi-phase placement config
	if GameManager.placement_phases.has(building_id):
		_phase_config = GameManager.placement_phases[building_id]
		_phase_index = 0
		_phase_placements.clear()
		selected_building = _phase_config.phases[0].building_id
	else:
		_phase_index = -1
		_phase_config = {}

func exit_building_mode() -> void:
	building_mode = false
	if _dragging:
		_cancel_drag()
	_cancel_multiphase()

func enter_destroy_mode() -> void:
	if building_mode:
		exit_building_mode()
	destroy_mode = true

func exit_destroy_mode() -> void:
	destroy_mode = false
	_destroy_dragging = false
	_clear_all_highlights()

func select_building(id: StringName) -> void:
	enter_building_mode(id)

# ── Inspect ──────────────────────────────────────────────────────────────────

func _try_inspect(pos: Vector2i) -> void:
	var building = GameManager.get_building_at(pos)
	if building and is_instance_valid(building):
		building_clicked.emit(building)
	else:
		# Clicked empty space — dismiss info panel
		building_clicked.emit(null)

# ── Build drag ───────────────────────────────────────────────────────────────

func _start_drag(pos: Vector2i) -> void:
	_dragging = true
	_drag_start_pos = pos
	_drag_axis = -1
	_drag_rotation = current_rotation
	_blueprints = [pos]

func _cancel_drag() -> void:
	_dragging = false
	_drag_axis = -1
	_blueprints.clear()
	_placeable_blueprints.clear()

func _commit_drag() -> void:
	if not _dragging:
		return
	if _phase_index >= 0:
		_commit_phase_drag()
		return
	# Place only non-overlapping blueprints that pass validation
	for pos in _placeable_blueprints:
		if GameManager.can_place_building(selected_building, pos, MAP_SIZE, _drag_rotation):
			GameManager.place_building(selected_building, pos, _drag_rotation)
	_dragging = false
	_drag_axis = -1
	_blueprints.clear()
	_placeable_blueprints.clear()
	# Keep the drag rotation as the current rotation for convenience
	current_rotation = _drag_rotation

# ── Multi-phase placement ─────────────────────────────────────────────────

func _commit_phase_drag() -> void:
	var phase_def: Dictionary = _phase_config.phases[_phase_index]
	var bid: StringName = phase_def.building_id
	var placed: Array = []

	for pos in _placeable_blueprints:
		if _can_place_phase(pos, _drag_rotation, placed.size()):
			GameManager.place_building(bid, pos, _drag_rotation)
			placed.append({pos = pos, rotation = _drag_rotation})

	_dragging = false
	_drag_axis = -1
	_blueprints.clear()
	_placeable_blueprints.clear()
	current_rotation = _drag_rotation

	if placed.is_empty():
		return

	_phase_placements.append(placed)
	_phase_index += 1

	if _phase_index >= _phase_config.phases.size():
		_complete_multiphase()
	else:
		# Advance to next phase's building
		selected_building = _phase_config.phases[_phase_index].building_id

## Check if a building can be placed in the current phase at pos with index.
func _can_place_phase(pos: Vector2i, rot: int, index: int) -> bool:
	var phase_def: Dictionary = _phase_config.phases[_phase_index]
	var bid: StringName = phase_def.building_id
	if not GameManager.can_place_building(bid, pos, MAP_SIZE, rot):
		return false
	if _phase_index == 0:
		return true
	var prev_placements: Array = _phase_placements[_phase_placements.size() - 1]
	# Count match: don't allow more placements than prior phase
	if phase_def.get("count_match", false):
		if index >= prev_placements.size():
			return false
	# Max distance: check against corresponding prior placement
	var max_dist: int = phase_def.get("max_distance", 0)
	if max_dist > 0 and index < prev_placements.size():
		var prev_pos: Vector2i = prev_placements[index].pos
		var dist := absi(pos.x - prev_pos.x) + absi(pos.y - prev_pos.y)
		if dist > max_dist:
			return false
	return true

func _complete_multiphase() -> void:
	if _phase_config.has("link_fn"):
		GameManager.call(_phase_config.link_fn, _phase_placements)
	# Restart at phase 0 so the player can keep building more of the same
	_phase_index = 0
	_phase_placements.clear()
	selected_building = _phase_config.phases[0].building_id

## Cancel multi-phase placement, removing buildings placed in prior phases.
func _cancel_multiphase() -> void:
	if _phase_index <= 0:
		_phase_index = -1
		_phase_config = {}
		_phase_placements.clear()
		return
	for phase_placed in _phase_placements:
		for entry in phase_placed:
			GameManager.remove_building(entry.pos)
	_phase_index = -1
	_phase_config = {}
	_phase_placements.clear()

func _update_blueprints() -> void:
	var raw_pos := _get_grid_pos_under_mouse()

	# Determine axis once mouse moves to a different tile
	if _drag_axis == -1:
		if raw_pos != _drag_start_pos:
			var diff := raw_pos - _drag_start_pos
			if abs(diff.x) >= abs(diff.y):
				_drag_axis = 0
				if not rotation_locked:
					_drag_rotation = 0 if diff.x > 0 else 2
			else:
				_drag_axis = 1
				if not rotation_locked:
					_drag_rotation = 1 if diff.y > 0 else 3

	# Build the line of positions from start to cursor, locked to axis
	var end_pos := raw_pos
	if _drag_axis == 0:
		end_pos.y = _drag_start_pos.y
	elif _drag_axis == 1:
		end_pos.x = _drag_start_pos.x

	cursor_grid_pos = end_pos

	# Generate positions along the line
	_blueprints.clear()
	if _drag_axis == -1:
		# Still undecided — just the start tile
		_blueprints = [_drag_start_pos]
		_drag_rotation = current_rotation
		_filter_placeable_blueprints()
		return

	var start := _drag_start_pos
	var step: Vector2i
	var count: int
	if _drag_axis == 0:
		var dx := end_pos.x - start.x
		step = Vector2i(signi(dx), 0)
		count = absi(dx) + 1
	else:
		var dy := end_pos.y - start.y
		step = Vector2i(0, signi(dy))
		count = absi(dy) + 1

	for i in range(count):
		_blueprints.append(start + step * i)

	_filter_placeable_blueprints()

	# If only one blueprint is visible, unlock axis so direction can change
	if _placeable_blueprints.size() <= 1:
		_drag_axis = -1
		_blueprints = [_drag_start_pos]
		current_rotation = _drag_rotation
		_filter_placeable_blueprints()

## Filter blueprints to only include those that don't overlap earlier ones.
func _filter_placeable_blueprints() -> void:
	_placeable_blueprints.clear()
	var def = GameManager.get_building_def(selected_building)
	if not def:
		return
	var rotated_shape = GameManager.get_rotated_shape(def, _drag_rotation)
	var claimed_cells: Dictionary = {} # Vector2i -> true
	# Multi-phase count limit: don't show more blueprints than prior phase placed
	var max_count := 999999
	if _phase_index > 0:
		var phase_def: Dictionary = _phase_config.phases[_phase_index]
		if phase_def.get("count_match", false) and _phase_placements.size() > 0:
			max_count = _phase_placements[_phase_placements.size() - 1].size()
	for pos in _blueprints:
		if _placeable_blueprints.size() >= max_count:
			break
		# Check if any cell of this blueprint overlaps a cell claimed by a prior blueprint
		var overlaps := false
		var cells: Array = []
		for cell in rotated_shape:
			var world_cell: Vector2i = pos + cell
			cells.append(world_cell)
			if claimed_cells.has(world_cell):
				overlaps = true
				break
		if not overlaps:
			_placeable_blueprints.append(pos)
			for c in cells:
				claimed_cells[c] = true

# ── Destroy ──────────────────────────────────────────────────────────────────

func _commit_destroy() -> void:
	if not _destroy_dragging:
		return

	var min_pos := Vector2i(
		mini(_destroy_drag_start.x, cursor_grid_pos.x),
		mini(_destroy_drag_start.y, cursor_grid_pos.y))
	var max_pos := Vector2i(
		maxi(_destroy_drag_start.x, cursor_grid_pos.x),
		maxi(_destroy_drag_start.y, cursor_grid_pos.y))

	# Collect unique buildings in the area, including linked buildings
	var to_remove: Array = []
	var seen: Dictionary = {}
	for x in range(min_pos.x, max_pos.x + 1):
		for y in range(min_pos.y, max_pos.y + 1):
			var building = GameManager.get_building_at(Vector2i(x, y))
			if building and is_instance_valid(building):
				_collect_building_and_linked(building, seen, to_remove)

	_clear_all_highlights()

	for pos in to_remove:
		GameManager.remove_building(pos)

	_destroy_dragging = false

# ── Destroy shader highlights ────────────────────────────────────────────────

func _update_destroy_highlights() -> void:
	# Compute which buildings should be highlighted
	var new_set: Dictionary = {} # instance_id -> Node2D
	if _destroy_dragging:
		var min_pos := Vector2i(
			mini(_destroy_drag_start.x, cursor_grid_pos.x),
			mini(_destroy_drag_start.y, cursor_grid_pos.y))
		var max_pos := Vector2i(
			maxi(_destroy_drag_start.x, cursor_grid_pos.x),
			maxi(_destroy_drag_start.y, cursor_grid_pos.y))
		for x in range(min_pos.x, max_pos.x + 1):
			for y in range(min_pos.y, max_pos.y + 1):
				var building = GameManager.get_building_at(Vector2i(x, y))
				if building and is_instance_valid(building):
					new_set[building.get_instance_id()] = building
	else:
		var building = GameManager.get_building_at(cursor_grid_pos)
		if building and is_instance_valid(building):
			new_set[building.get_instance_id()] = building

	# Include linked buildings (e.g. tunnel partner) in the highlight set
	var linked_set: Dictionary = {}
	for nid in new_set:
		for linked_pos in GameManager.get_linked_buildings(new_set[nid]):
			var linked = GameManager.buildings.get(linked_pos)
			if linked and is_instance_valid(linked):
				linked_set[linked.get_instance_id()] = linked
	for nid in linked_set:
		if not new_set.has(nid):
			new_set[nid] = linked_set[nid]

	# Remove highlights no longer needed
	for nid in _highlighted_buildings.keys():
		if not new_set.has(nid):
			_remove_highlight(nid)

	# Add new highlights
	for nid in new_set:
		if not _highlighted_buildings.has(nid):
			_apply_highlight(new_set[nid])

	# Update frame UV bounds for animated sprites (frame changes each tick)
	for nid in _highlighted_buildings:
		var entries: Array = _highlighted_buildings[nid]
		for entry in entries:
			if is_instance_valid(entry.node) and entry.node is AnimatedSprite2D:
				var bounds := _get_frame_uv_bounds(entry.node)
				entry.node.material.set_shader_parameter("frame_uv_min", bounds.position)
				entry.node.material.set_shader_parameter("frame_uv_max", bounds.position + bounds.size)

func _apply_highlight(building: Node2D) -> void:
	var entries: Array = []
	for node in _get_visual_nodes(building):
		var orig = node.material
		var mat := ShaderMaterial.new()
		mat.shader = _destroy_shader
		mat.set_shader_parameter("enabled", true)
		var bounds := _get_frame_uv_bounds(node)
		mat.set_shader_parameter("frame_uv_min", bounds.position)
		mat.set_shader_parameter("frame_uv_max", bounds.position + bounds.size)
		node.material = mat
		entries.append({node = node, original = orig})
	_highlighted_buildings[building.get_instance_id()] = entries

## Get the UV bounds of the current frame within the atlas texture.
func _get_frame_uv_bounds(node: CanvasItem) -> Rect2:
	if node is AnimatedSprite2D:
		var frame_tex = node.sprite_frames.get_frame_texture(node.animation, node.frame)
		if frame_tex is AtlasTexture:
			var atlas_size: Vector2 = frame_tex.atlas.get_size()
			var region: Rect2 = frame_tex.region
			return Rect2(region.position / atlas_size, region.size / atlas_size)
	elif node is Sprite2D and node.region_enabled:
		var tex_size: Vector2 = node.texture.get_size()
		return Rect2(node.region_rect.position / tex_size, node.region_rect.size / tex_size)
	return Rect2(0, 0, 1, 1)

func _remove_highlight(nid: int) -> void:
	if not _highlighted_buildings.has(nid):
		return
	var entries: Array = _highlighted_buildings[nid]
	for entry in entries:
		if is_instance_valid(entry.node):
			entry.node.material = entry.original
	_highlighted_buildings.erase(nid)

func _clear_all_highlights() -> void:
	for nid in _highlighted_buildings.keys():
		_remove_highlight(nid)

## Find visual children of a building to apply the destroy shader to.
func _get_visual_nodes(building: Node2D) -> Array:
	var result: Array = []
	# Shape ColorRects
	var shape_node = building.find_child("Shape", false, false)
	if shape_node:
		for child in shape_node.get_children():
			if child is ColorRect:
				result.append(child)
	# Sprite2D and AnimatedSprite2D (direct children)
	for child in building.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			result.append(child)
	return result

# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var cell_size := Vector2(TILE_SIZE, TILE_SIZE)

	if destroy_mode:
		_draw_destroy(cell_size)
		return

	if not building_mode:
		return

	var def = GameManager.get_building_def(selected_building)
	if not def:
		return

	if _dragging:
		# Draw only placeable blueprints (non-overlapping)
		var rotated_shape = GameManager.get_rotated_shape(def, _drag_rotation)
		var bbox = GameManager.get_rotated_shape_bbox(def, _drag_rotation)
		var bbox_px := Vector2(bbox.size) * TILE_SIZE
		var bbox_offset := Vector2(bbox.min_cell) * TILE_SIZE
		for idx in range(_placeable_blueprints.size()):
			var pos: Vector2i = _placeable_blueprints[idx]
			var can_place: bool
			if _phase_index >= 0:
				can_place = _can_place_phase(pos, _drag_rotation, idx)
			else:
				can_place = GameManager.can_place_building(selected_building, pos, MAP_SIZE, _drag_rotation)
			var color := BLUEPRINT_COLOR if can_place else BLUEPRINT_INVALID_COLOR
			var anchor_px := Vector2(pos) * TILE_SIZE
			for cell in rotated_shape:
				draw_rect(Rect2(anchor_px + Vector2(cell) * TILE_SIZE, cell_size), color)
			_draw_direction_arrow(anchor_px + bbox_offset, bbox_px, _drag_rotation)
	else:
		# Single ghost cursor
		var rotated_shape = GameManager.get_rotated_shape(def, current_rotation)
		var bbox = GameManager.get_rotated_shape_bbox(def, current_rotation)
		var bbox_px := Vector2(bbox.size) * TILE_SIZE
		var bbox_offset := Vector2(bbox.min_cell) * TILE_SIZE
		var can_place: bool
		if _phase_index >= 0:
			can_place = _can_place_phase(cursor_grid_pos, current_rotation, 0)
		else:
			can_place = GameManager.can_place_building(selected_building, cursor_grid_pos, MAP_SIZE, current_rotation)
		var color := GHOST_COLOR if can_place else GHOST_INVALID_COLOR
		var anchor_px := Vector2(cursor_grid_pos) * TILE_SIZE
		for cell in rotated_shape:
			draw_rect(Rect2(anchor_px + Vector2(cell) * TILE_SIZE, cell_size), color)
		_draw_direction_arrow(anchor_px + bbox_offset, bbox_px, current_rotation)

func _draw_destroy(cell_size: Vector2) -> void:
	if _destroy_dragging:
		# Draw transparent red over the entire drag rectangle
		var min_pos := Vector2i(
			mini(_destroy_drag_start.x, cursor_grid_pos.x),
			mini(_destroy_drag_start.y, cursor_grid_pos.y))
		var max_pos := Vector2i(
			maxi(_destroy_drag_start.x, cursor_grid_pos.x),
			maxi(_destroy_drag_start.y, cursor_grid_pos.y))
		var rect_pos := Vector2(min_pos) * TILE_SIZE
		var rect_size := Vector2(max_pos - min_pos + Vector2i.ONE) * TILE_SIZE
		draw_rect(Rect2(rect_pos, rect_size), DESTROY_AREA_COLOR)
	else:
		# No building under cursor — show cursor indicator
		var building = GameManager.get_building_at(cursor_grid_pos)
		if not building or not is_instance_valid(building):
			draw_rect(Rect2(Vector2(cursor_grid_pos) * TILE_SIZE, cell_size), DESTROY_CURSOR_COLOR)


func _draw_direction_arrow(origin: Vector2, size_px: Vector2, rot: int) -> void:
	var center := origin + size_px * 0.5
	var arrow_len: float = min(size_px.x, size_px.y) * 0.3
	var dir: Vector2
	match rot:
		0: dir = Vector2.RIGHT
		1: dir = Vector2.DOWN
		2: dir = Vector2.LEFT
		3: dir = Vector2.UP
	var tip: Vector2 = center + dir * arrow_len
	var base: Vector2 = center - dir * arrow_len
	draw_line(base, tip, ARROW_COLOR, 2.0)
	var perp := Vector2(-dir.y, dir.x)
	draw_line(tip, tip - dir * 6 + perp * 4, ARROW_COLOR, 2.0)
	draw_line(tip, tip - dir * 6 - perp * 4, ARROW_COLOR, 2.0)

## Read actual Shape ColorRect positions from the placed building node.
func _get_building_visual_cells(building: Node2D) -> Array:
	var cells: Array = []
	var bx := floori(building.position.x / TILE_SIZE)
	var by := floori(building.position.y / TILE_SIZE)
	var shape_node = building.find_child("Shape", false, false)
	if shape_node:
		for child in shape_node.get_children():
			if child is ColorRect:
				var gx := floori(child.offset_left / TILE_SIZE)
				var gy := floori(child.offset_top / TILE_SIZE)
				cells.append(Vector2i(bx + gx, by + gy))
	if cells.is_empty():
		var def = GameManager.get_building_def(building.building_id)
		if def:
			for cell in GameManager.get_rotated_shape(def, building.rotation_index):
				cells.append(building.grid_pos + cell)
		else:
			cells.append(building.grid_pos)
	return cells

## Draw outline around outer edges of a cell set.
func _draw_shape_outline(cells: Array) -> void:
	var cell_set: Dictionary = {}
	for cell in cells:
		cell_set[cell] = true
	var s := float(TILE_SIZE)
	for cell in cells:
		var wp := Vector2(cell) * s
		if not cell_set.has(cell + Vector2i(1, 0)):
			draw_line(Vector2(wp.x + s, wp.y), Vector2(wp.x + s, wp.y + s), DESTROY_OUTLINE_COLOR, OUTLINE_WIDTH)
		if not cell_set.has(cell + Vector2i(0, 1)):
			draw_line(Vector2(wp.x, wp.y + s), Vector2(wp.x + s, wp.y + s), DESTROY_OUTLINE_COLOR, OUTLINE_WIDTH)
		if not cell_set.has(cell + Vector2i(-1, 0)):
			draw_line(Vector2(wp.x, wp.y), Vector2(wp.x, wp.y + s), DESTROY_OUTLINE_COLOR, OUTLINE_WIDTH)
		if not cell_set.has(cell + Vector2i(0, -1)):
			draw_line(Vector2(wp.x, wp.y), Vector2(wp.x + s, wp.y), DESTROY_OUTLINE_COLOR, OUTLINE_WIDTH)

# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_grid_pos_under_mouse() -> Vector2i:
	var mouse_world := get_global_mouse_position()
	var gx := floori(mouse_world.x / TILE_SIZE)
	var gy := floori(mouse_world.y / TILE_SIZE)
	return Vector2i(gx, gy)

func _try_remove(pos: Vector2i) -> void:
	GameManager.remove_building(pos)

## Collect a building and all its linked buildings into to_remove, deduplicating by instance id.
func _collect_building_and_linked(building: Node2D, seen: Dictionary, to_remove: Array) -> void:
	var nid: int = building.get_instance_id()
	if seen.has(nid):
		return
	seen[nid] = true
	to_remove.append(building.grid_pos)
	for linked_pos in GameManager.get_linked_buildings(building):
		var linked = GameManager.get_building_at(linked_pos)
		if linked and is_instance_valid(linked):
			_collect_building_and_linked(linked, seen, to_remove)

func _debug_spawn_item(pos: Vector2i) -> void:
	var conv = GameManager.get_conveyor_at(pos)
	if conv and conv.can_accept():
		conv.place_item(&"iron_ore")
