class_name GameCamera
extends Camera3D

# ── Zoom ────────────────────────────────────────────────────────────────────
const ZOOM_SPEED := 1.0
const MIN_SIZE := 10.0
const MAX_SIZE := 80.0
const ZOOM_SMOOTH_SPEED := 8.0

# ── Follow ──────────────────────────────────────────────────────────────────
const FOLLOW_SPEED := 8.0
const CURSOR_DEADZONE := 1.1
const CURSOR_WEIGHT := 0.2

## Isometric camera angles (true isometric: atan(sin(45°)) ≈ 35.264°)
const ISO_ROTATION_X := -0.6155  # -35.264 degrees in radians
const ISO_ROTATION_Y := PI / 4.0 # 45 degrees

## Height above the ground plane the camera orbits at
const CAMERA_HEIGHT_RATIO := 1.1547  # 1/cos(35.264°) ≈ distance multiplier

var target_node: Node  # the node to follow (player)
var _target_size: float = 40.0

func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	_target_size = size

func snap_to_3d(pos: Vector3) -> void:
	var offset := _camera_offset()
	global_position = pos + offset

## Backward-compatible snap for 2D position (maps to XZ plane).
func snap_to(pos) -> void:
	if pos is Vector3:
		snap_to_3d(pos)
	elif pos is Vector2:
		snap_to_3d(Vector3(pos.x, 0.0, pos.y))

func set_target_zoom(z: float) -> void:
	_target_size = clampf(z, MIN_SIZE, MAX_SIZE)

func update_camera(real_delta: float) -> void:
	_follow(real_delta)
	_smooth_zoom(real_delta)

func handle_zoom_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			_target_size = clampf(_target_size - ZOOM_SPEED, MIN_SIZE, MAX_SIZE)
		elif event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
			_target_size = clampf(_target_size + ZOOM_SPEED, MIN_SIZE, MAX_SIZE)
	elif event is InputEventPanGesture:
		_target_size = clampf(_target_size + event.delta.y * ZOOM_SPEED, MIN_SIZE, MAX_SIZE)

# ── Follow ──────────────────────────────────────────────────────────────────

func _follow(real_delta: float) -> void:
	if not target_node or not is_instance_valid(target_node):
		return
	var target_pos: Vector3
	if target_node is Node3D:
		target_pos = target_node.global_position
	elif target_node is Node2D:
		# Backward compat: map 2D position to XZ plane
		target_pos = Vector3(target_node.position.x, 0.0, target_node.position.y)
	else:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var mouse_screen := get_viewport().get_mouse_position()
	var screen_offset := (mouse_screen - viewport_size / 2.0) / (viewport_size / 2.0)
	var cursor_offset := Vector2.ZERO
	for i in 2:
		var axis: float = screen_offset[i]
		var sign_v: float = signf(axis)
		var abs_v: float = absf(axis)
		if abs_v > CURSOR_DEADZONE:
			cursor_offset[i] = sign_v * (abs_v - CURSOR_DEADZONE) / (1.0 - CURSOR_DEADZONE)

	# Convert screen offset to world XZ shift (approximate for ortho)
	var world_shift := Vector3(cursor_offset.x, 0.0, cursor_offset.y) * size * CURSOR_WEIGHT

	var follow_target := target_pos + world_shift
	# Clamp to world bounds
	var bounds := _get_bounds()
	follow_target.x = clampf(follow_target.x, bounds.position.x, bounds.end.x)
	follow_target.z = clampf(follow_target.z, bounds.position.y, bounds.end.y)

	# Current look-at point on the ground plane
	var current_ground := global_position - _camera_offset()
	var new_ground := current_ground.lerp(follow_target, 1.0 - exp(-FOLLOW_SPEED * real_delta))
	global_position = new_ground + _camera_offset()

# ── Zoom ────────────────────────────────────────────────────────────────────

func _smooth_zoom(real_delta: float) -> void:
	if is_equal_approx(size, _target_size):
		return
	var new_size := lerpf(size, _target_size, 1.0 - exp(-ZOOM_SMOOTH_SPEED * real_delta))
	if absf(new_size - _target_size) < 0.01:
		new_size = _target_size
	size = new_size

# ── Helpers ─────────────────────────────────────────────────────────────────

## Camera offset from the ground-plane target point.
## The camera looks down at ISO angle, so it sits above and behind.
func _camera_offset() -> Vector3:
	# Place camera along the isometric view direction, at a distance that
	# keeps the ground target centered. For orthographic this is arbitrary
	# distance, but needs to be far enough to not clip.
	var dist := 100.0
	# View direction: the -Z axis of the camera in world space
	var view_dir := -global_transform.basis.z
	return -view_dir * dist

func _get_bounds() -> Rect2:
	var n := GameManager.map_size
	var map_size_3d := GridUtils.map_world_size(n)
	var origin := GridUtils.map_origin(n)
	# Half-view in world units (ortho size is vertical extent)
	var half_view := size * 0.5
	var min_pos := Vector2(origin.x + half_view, origin.z + half_view)
	var max_pos := Vector2(origin.x + map_size_3d.x - half_view, origin.z + map_size_3d.z - half_view)
	if min_pos.x > max_pos.x:
		var mid := origin.x + map_size_3d.x * 0.5
		min_pos.x = mid
		max_pos.x = mid
	if min_pos.y > max_pos.y:
		var mid := origin.z + map_size_3d.z * 0.5
		min_pos.y = mid
		max_pos.y = mid
	return Rect2(min_pos, max_pos - min_pos)

## Project a 3D world position to screen coordinates (for UI positioning).
func world_to_screen(world_pos: Vector3) -> Vector2:
	return unproject_position(world_pos)
