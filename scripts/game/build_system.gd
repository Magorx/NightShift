extends Node2D

const TILE_SIZE := 32
const MAP_SIZE := 64
const GHOST_COLOR := Color(0.4, 0.6, 1.0, 0.4)
const GHOST_INVALID_COLOR := Color(1.0, 0.3, 0.3, 0.4)
const BLUEPRINT_COLOR := Color(0.3, 0.7, 1.0, 0.35)
const BLUEPRINT_INVALID_COLOR := Color(1.0, 0.3, 0.3, 0.25)
const ARROW_COLOR := Color(1, 1, 1, 0.6)

var cursor_grid_pos := Vector2i.ZERO
var selected_building: StringName = &"drill"
var current_rotation: int = 0 # 0=right, 1=down, 2=left, 3=up

# Drag state
var _dragging: bool = false
var _drag_start_pos := Vector2i.ZERO
var _drag_axis: int = -1 # -1=undecided, 0=horizontal, 1=vertical
var _drag_rotation: int = 0
var _blueprints: Array = [] # Array of Vector2i positions

func _process(_delta: float) -> void:
	cursor_grid_pos = _get_grid_pos_under_mouse()
	if _dragging:
		_update_blueprints()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(cursor_grid_pos)
			else:
				_commit_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _dragging:
				_cancel_drag()
			else:
				_try_remove(cursor_grid_pos)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and not _dragging:
			current_rotation = (current_rotation + 1) % 4
		elif event.keycode == KEY_T:
			_debug_spawn_item(cursor_grid_pos)

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

func _commit_drag() -> void:
	if not _dragging:
		return
	# Place all valid blueprints as real buildings
	for pos in _blueprints:
		if GameManager.can_place_building(selected_building, pos, MAP_SIZE):
			GameManager.place_building(selected_building, pos, _drag_rotation)
	_dragging = false
	_drag_axis = -1
	_blueprints.clear()
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
				_drag_rotation = 0 if diff.x > 0 else 2
			else:
				_drag_axis = 1
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
		# Allow R rotation while on single tile
		_drag_rotation = current_rotation
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

	# If dragged back to 1 tile, unlock axis so direction can change
	# but keep the rotation that was already set by the drag
	if _blueprints.size() <= 1:
		_drag_axis = -1
		_blueprints = [_drag_start_pos]
		current_rotation = _drag_rotation

func _draw() -> void:
	var def = GameManager.get_building_def(selected_building)
	if not def:
		return
	var cell_size := Vector2(TILE_SIZE, TILE_SIZE)
	var bbox_px := Vector2(def.shape_size) * TILE_SIZE

	if _dragging:
		# Draw all blueprint tiles
		for pos in _blueprints:
			var can_place = GameManager.can_place_building(selected_building, pos, MAP_SIZE)
			var color := BLUEPRINT_COLOR if can_place else BLUEPRINT_INVALID_COLOR
			var origin := Vector2(pos) * TILE_SIZE
			for cell in def.shape:
				draw_rect(Rect2(origin + Vector2(cell) * TILE_SIZE, cell_size), color)
			_draw_direction_arrow(origin, bbox_px, _drag_rotation)
	else:
		# Single ghost cursor
		var can_place = GameManager.can_place_building(selected_building, cursor_grid_pos, MAP_SIZE)
		var color := GHOST_COLOR if can_place else GHOST_INVALID_COLOR
		var origin := Vector2(cursor_grid_pos) * TILE_SIZE
		for cell in def.shape:
			draw_rect(Rect2(origin + Vector2(cell) * TILE_SIZE, cell_size), color)
		_draw_direction_arrow(origin, bbox_px, current_rotation)

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

func _get_grid_pos_under_mouse() -> Vector2i:
	var mouse_world := get_global_mouse_position()
	var gx := floori(mouse_world.x / TILE_SIZE)
	var gy := floori(mouse_world.y / TILE_SIZE)
	return Vector2i(gx, gy)

func select_building(id: StringName) -> void:
	selected_building = id
	current_rotation = 0

func _try_remove(pos: Vector2i) -> void:
	GameManager.remove_building(pos)

func _debug_spawn_item(pos: Vector2i) -> void:
	var conv = GameManager.get_conveyor_at(pos)
	if conv and conv.can_accept():
		conv.place_item(&"iron_ore")
