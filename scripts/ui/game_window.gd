class_name GameWindow
extends PanelContainer
## Base class for draggable, resizable in-game windows.
## Windows consume all mouse input that lands on them (scroll, click, hover).

# ── Drag state ──────────────────────────────────────────────────────────────
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# ── Resize state ────────────────────────────────────────────────────────────
var _resizing: bool = false
var _resize_edge: int = 0 # bitmask: 1=left, 2=right, 4=top, 8=bottom
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_pos: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
const RESIZE_MARGIN := 6.0
const MIN_PANEL_SIZE := Vector2(320, 200)

# ── Snap-back interpolation ────────────────────────────────────────────────
var _snapping_back: bool = false
var _snap_target: Vector2 = Vector2.ZERO
const SNAP_SPEED := 12.0

func _ready() -> void:
	# Windows consume all mouse input — nothing passes through to the game world
	mouse_filter = Control.MOUSE_FILTER_STOP
	var close_btn = get_node_or_null("%CloseButton")
	if close_btn:
		close_btn.pressed.connect(func(): visible = false)

func _process(delta: float) -> void:
	if _snapping_back:
		global_position = global_position.lerp(_snap_target, SNAP_SPEED * delta)
		if global_position.distance_to(_snap_target) < 1.0:
			global_position = _snap_target
			_snapping_back = false

func move_to_center() -> void:
	var vp_size := get_viewport_rect().size
	_snap_target = (vp_size - size) * 0.5
	_snapping_back = true

func _is_out_of_bounds() -> bool:
	var vp_size := get_viewport_rect().size
	var margin := 40.0
	return (global_position.x + size.x < margin
		or global_position.x > vp_size.x - margin
		or global_position.y + size.y < margin
		or global_position.y > vp_size.y - margin)

# ── Dragging & Resizing ─────────────────────────────────────────────────────

func _get_resize_edge(local_pos: Vector2) -> int:
	var edge := 0
	if local_pos.x < RESIZE_MARGIN:
		edge |= 1 # left
	elif local_pos.x > size.x - RESIZE_MARGIN:
		edge |= 2 # right
	if local_pos.y < RESIZE_MARGIN:
		edge |= 4 # top
	elif local_pos.y > size.y - RESIZE_MARGIN:
		edge |= 8 # bottom
	return edge

func _gui_input(event: InputEvent) -> void:
	# Consume scroll wheel events so they don't reach the game camera
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_pos: Vector2 = event.position
			var edge := _get_resize_edge(local_pos)
			if edge != 0:
				# Start resize
				_resizing = true
				_resize_edge = edge
				_resize_start_mouse = get_global_mouse_position()
				_resize_start_pos = global_position
				_resize_start_size = size
				_snapping_back = false
				accept_event()
			else:
				# Start drag — works from any non-interactive area (title bar, margins, separators).
				# Buttons and other MOUSE_FILTER_STOP children consume clicks before reaching here.
				_dragging = true
				_snapping_back = false
				_drag_offset = global_position - get_global_mouse_position()
				accept_event()
		else:
			if _resizing:
				_resizing = false
			elif _dragging:
				_dragging = false
				if _is_out_of_bounds():
					move_to_center()
	elif event is InputEventMouseMotion:
		if _resizing:
			_apply_resize()
			accept_event()
		elif _dragging:
			global_position = get_global_mouse_position() + _drag_offset
			accept_event()
		else:
			# Update cursor shape based on edge
			var edge := _get_resize_edge(event.position)
			_update_cursor(edge)

func _apply_resize() -> void:
	var mouse := get_global_mouse_position()
	var delta := mouse - _resize_start_mouse
	var new_pos := _resize_start_pos
	var new_size := _resize_start_size

	if _resize_edge & 1: # left
		new_pos.x = _resize_start_pos.x + delta.x
		new_size.x = _resize_start_size.x - delta.x
	if _resize_edge & 2: # right
		new_size.x = _resize_start_size.x + delta.x
	if _resize_edge & 4: # top
		new_pos.y = _resize_start_pos.y + delta.y
		new_size.y = _resize_start_size.y - delta.y
	if _resize_edge & 8: # bottom
		new_size.y = _resize_start_size.y + delta.y

	# Clamp to minimum
	if new_size.x < MIN_PANEL_SIZE.x:
		if _resize_edge & 1:
			new_pos.x -= MIN_PANEL_SIZE.x - new_size.x
		new_size.x = MIN_PANEL_SIZE.x
	if new_size.y < MIN_PANEL_SIZE.y:
		if _resize_edge & 4:
			new_pos.y -= MIN_PANEL_SIZE.y - new_size.y
		new_size.y = MIN_PANEL_SIZE.y

	global_position = new_pos
	custom_minimum_size = new_size
	size = new_size

func _update_cursor(edge: int) -> void:
	if edge == 0:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	elif edge == 1 or edge == 2:
		mouse_default_cursor_shape = Control.CURSOR_HSIZE
	elif edge == 4 or edge == 8:
		mouse_default_cursor_shape = Control.CURSOR_VSIZE
	elif edge == 5 or edge == 10: # top-left or bottom-right
		mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	elif edge == 6 or edge == 9: # top-right or bottom-left
		mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE

# ── Close on RMB outside ────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		visible = false
		get_viewport().set_input_as_handled()
