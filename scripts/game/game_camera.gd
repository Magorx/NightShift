class_name GameCamera
extends Camera2D

const TILE_SIZE := 32

# ── Zoom ────────────────────────────────────────────────────────────────────
const ZOOM_SPEED := 0.1
const MIN_ZOOM := 0.25
const MAX_ZOOM := 3.0
const ZOOM_SMOOTH_SPEED := 8.0

# ── Follow ──────────────────────────────────────────────────────────────────
const FOLLOW_SPEED := 8.0
const CURSOR_DEADZONE := 0.8       # fraction of window — cursor inside this = no offset
const CURSOR_WEIGHT := 0.2          # max offset strength when cursor is at window edge

var target_node: Node2D              # the node to follow (player)
var _target_zoom: float = 1.0

func _ready() -> void:
	_target_zoom = zoom.x

func snap_to(pos: Vector2) -> void:
	position = pos

func set_target_zoom(z: float) -> void:
	_target_zoom = z

func update_camera(real_delta: float) -> void:
	_follow(real_delta)
	_smooth_zoom(real_delta)

func handle_zoom_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			_target_zoom = clampf(_target_zoom + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
			_target_zoom = clampf(_target_zoom - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
	elif event is InputEventPanGesture:
		_target_zoom = clampf(_target_zoom - event.delta.y * ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)

# ── Follow ──────────────────────────────────────────────────────────────────

func _follow(real_delta: float) -> void:
	if not target_node or not is_instance_valid(target_node):
		return
	var viewport_size := get_viewport_rect().size
	var mouse_screen := get_viewport().get_mouse_position()
	# Offset from screen center in normalized [-1, 1] range per axis
	var screen_offset := (mouse_screen - viewport_size / 2.0) / (viewport_size / 2.0)
	# Apply dead zone: no offset while cursor is within the inner third of the window
	var cursor_offset := Vector2.ZERO
	for i in 2:
		var axis: float = screen_offset[i]
		var sign_v: float = signf(axis)
		var abs_v: float = absf(axis)
		if abs_v > CURSOR_DEADZONE:
			cursor_offset[i] = sign_v * (abs_v - CURSOR_DEADZONE) / (1.0 - CURSOR_DEADZONE)
	# Convert normalized offset to world-space shift
	var world_shift := cursor_offset * (viewport_size / 2.0) / zoom.x * CURSOR_WEIGHT
	var target: Vector2 = target_node.position + world_shift
	# Clamp to world bounds
	var bounds := _get_bounds()
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.y = clampf(target.y, bounds.position.y, bounds.end.y)
	position = position.lerp(target, 1.0 - exp(-FOLLOW_SPEED * real_delta))

# ── Zoom ────────────────────────────────────────────────────────────────────

func _smooth_zoom(real_delta: float) -> void:
	if is_equal_approx(zoom.x, _target_zoom):
		return
	var new_zoom := lerpf(zoom.x, _target_zoom, 1.0 - exp(-ZOOM_SMOOTH_SPEED * real_delta))
	if absf(new_zoom - _target_zoom) < 0.001:
		new_zoom = _target_zoom
	var mouse_screen := get_viewport().get_mouse_position()
	var viewport_size := get_viewport_rect().size
	var mouse_offset := mouse_screen - viewport_size / 2.0
	var world_before := position + mouse_offset / zoom.x
	zoom = Vector2(new_zoom, new_zoom)
	var world_after := position + mouse_offset / zoom.x
	position += world_before - world_after

# ── Bounds ──────────────────────────────────────────────────────────────────

func _get_bounds() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var half_view := viewport_size / (2.0 * zoom.x)
	var world_size := float(GameManager.map_size * TILE_SIZE)
	var min_pos := half_view
	var max_pos := Vector2(world_size, world_size) - half_view
	if min_pos.x > max_pos.x:
		min_pos.x = world_size / 2.0
		max_pos.x = world_size / 2.0
	if min_pos.y > max_pos.y:
		min_pos.y = world_size / 2.0
		max_pos.y = world_size / 2.0
	return Rect2(min_pos, max_pos - min_pos)
