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
const DESTROY_STRIPE_COLOR := Color(1.0, 0.1, 0.08, 0.2)
const OUTLINE_WIDTH := 2.0
const STRIPE_SPACING := 12.0
const STRIPE_WIDTH := 5.0

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

# Drag state (build mode)
var _dragging: bool = false
var _drag_start_pos := Vector2i.ZERO
var _drag_axis: int = -1 # -1=undecided, 0=horizontal, 1=vertical
var _drag_rotation: int = 0
var _blueprints: Array = [] # Array of Vector2i positions (all candidates)
var _placeable_blueprints: Array = [] # subset that don't overlap each other

func _process(_delta: float) -> void:
	cursor_grid_pos = _get_grid_pos_under_mouse()
	if _dragging:
		_update_blueprints()
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
				if _dragging:
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
		else:
			# R toggles destroy mode when not in build mode
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
	selected_building = building_id
	building_mode = true
	GameManager.last_selected_building = building_id

func exit_building_mode() -> void:
	building_mode = false
	if _dragging:
		_cancel_drag()

func enter_destroy_mode() -> void:
	if building_mode:
		exit_building_mode()
	destroy_mode = true

func exit_destroy_mode() -> void:
	destroy_mode = false
	_destroy_dragging = false

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
	for pos in _blueprints:
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

	# Collect unique buildings in the area
	var to_remove: Array = []
	var seen: Dictionary = {}
	for x in range(min_pos.x, max_pos.x + 1):
		for y in range(min_pos.y, max_pos.y + 1):
			var building = GameManager.get_building_at(Vector2i(x, y))
			if building and is_instance_valid(building):
				var nid: int = building.get_instance_id()
				if not seen.has(nid):
					seen[nid] = true
					to_remove.append(building.grid_pos)

	for pos in to_remove:
		GameManager.remove_building(pos)

	_destroy_dragging = false

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
		for pos in _placeable_blueprints:
			var can_place = GameManager.can_place_building(selected_building, pos, MAP_SIZE, _drag_rotation)
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
		var can_place = GameManager.can_place_building(selected_building, cursor_grid_pos, MAP_SIZE, current_rotation)
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
		# Highlight buildings inside the area with stripes + outline
		var seen: Dictionary = {}
		for x in range(min_pos.x, max_pos.x + 1):
			for y in range(min_pos.y, max_pos.y + 1):
				var building = GameManager.get_building_at(Vector2i(x, y))
				if building and is_instance_valid(building):
					var nid: int = building.get_instance_id()
					if not seen.has(nid):
						seen[nid] = true
						_draw_building_destroy_highlight(building)
	else:
		# Hover: highlight building under cursor or just the cursor tile
		var building = GameManager.get_building_at(cursor_grid_pos)
		if building and is_instance_valid(building):
			_draw_building_destroy_highlight(building)
		else:
			draw_rect(Rect2(Vector2(cursor_grid_pos) * TILE_SIZE, cell_size), DESTROY_CURSOR_COLOR)

func _draw_building_destroy_highlight(building: Node2D) -> void:
	var cells := _get_building_visual_cells(building)
	var s := float(TILE_SIZE)
	# Diagonal stripes per cell
	for cell in cells:
		_draw_cell_stripes(Vector2(cell) * s, s)
	# Outline around the combined shape
	_draw_shape_outline(cells)

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
		# Fallback: use def shape
		var def = GameManager.get_building_def(building.building_id)
		if def:
			for cell in GameManager.get_rotated_shape(def, building.rotation_index):
				cells.append(building.grid_pos + cell)
		else:
			cells.append(building.grid_pos)
	return cells

## Draw world-aligned diagonal stripes within a single cell.
func _draw_cell_stripes(cell_pos: Vector2, s: float) -> void:
	var ox := cell_pos.x
	var oy := cell_pos.y
	# Stripes along x + y = k (top-left to bottom-right direction)
	var k_min := ox + oy
	var k_max := k_min + 2.0 * s
	# Align to world grid so stripes connect across cells
	var k := ceilf(k_min / STRIPE_SPACING) * STRIPE_SPACING
	while k <= k_max:
		# Clip line x + y = k to rect [ox, ox+s] x [oy, oy+s]
		var x1 := maxf(ox, k - oy - s)
		var x2 := minf(ox + s, k - oy)
		if x1 < x2:
			draw_line(Vector2(x1, k - x1), Vector2(x2, k - x2), DESTROY_STRIPE_COLOR, STRIPE_WIDTH)
		k += STRIPE_SPACING

## Draw outline around outer edges of a cell set.
func _draw_shape_outline(cells: Array) -> void:
	var cell_set: Dictionary = {}
	for cell in cells:
		cell_set[cell] = true
	var s := float(TILE_SIZE)
	for cell in cells:
		var wp := Vector2(cell) * s
		# Right edge
		if not cell_set.has(cell + Vector2i(1, 0)):
			draw_line(Vector2(wp.x + s, wp.y), Vector2(wp.x + s, wp.y + s), DESTROY_OUTLINE_COLOR, OUTLINE_WIDTH)
		# Bottom edge
		if not cell_set.has(cell + Vector2i(0, 1)):
			draw_line(Vector2(wp.x, wp.y + s), Vector2(wp.x + s, wp.y + s), DESTROY_OUTLINE_COLOR, OUTLINE_WIDTH)
		# Left edge
		if not cell_set.has(cell + Vector2i(-1, 0)):
			draw_line(Vector2(wp.x, wp.y), Vector2(wp.x, wp.y + s), DESTROY_OUTLINE_COLOR, OUTLINE_WIDTH)
		# Top edge
		if not cell_set.has(cell + Vector2i(0, -1)):
			draw_line(Vector2(wp.x, wp.y), Vector2(wp.x + s, wp.y), DESTROY_OUTLINE_COLOR, OUTLINE_WIDTH)

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

# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_grid_pos_under_mouse() -> Vector2i:
	var mouse_world := get_global_mouse_position()
	var gx := floori(mouse_world.x / TILE_SIZE)
	var gy := floori(mouse_world.y / TILE_SIZE)
	return Vector2i(gx, gy)

func _try_remove(pos: Vector2i) -> void:
	GameManager.remove_building(pos)

func _debug_spawn_item(pos: Vector2i) -> void:
	var conv = GameManager.get_conveyor_at(pos)
	if conv and conv.can_accept():
		conv.place_item(&"iron_ore")
