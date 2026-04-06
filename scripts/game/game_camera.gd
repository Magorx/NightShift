class_name GameCamera
extends Camera3D

# ── Zoom ────────────────────────────────────────────────────────────────────
const ZOOM_SPEED := 1.0
const MIN_SIZE := 5.0
const MAX_SIZE := 80.0
const ZOOM_SMOOTH_SPEED := 8.0

# ── Follow ──────────────────────────────────────────────────────────────────
const FOLLOW_SPEED := 8.0

## Isometric camera angles (true isometric: atan(sin(45°)) ≈ 35.264°)
const ISO_ROTATION_X := -0.6155  # -35.264 degrees in radians
const ISO_ROTATION_Y := PI / 4.0 # 45 degrees

## Height above the ground plane the camera orbits at
const CAMERA_HEIGHT_RATIO := 1.1547  # 1/cos(35.264°) ≈ distance multiplier

# ── Rotation ────────────────────────────────────────────────────────────────
const ROTATE_SENSITIVITY := 0.005  # radians per pixel of mouse movement
const ROTATE_SMOOTH_SPEED := 10.0

var target_node: Node  # the node to follow (player)
var _target_size: float = 40.0
var _current_yaw: float = ISO_ROTATION_Y
var _target_yaw: float = ISO_ROTATION_Y
var _is_rotating: bool = false
var _ground_target: Vector3  # the point on the ground the camera orbits around

func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	_target_size = size
	_current_yaw = ISO_ROTATION_Y
	_target_yaw = ISO_ROTATION_Y
	_apply_rotation(_current_yaw)

func snap_to_3d(pos: Vector3) -> void:
	_ground_target = pos
	global_position = _ground_target + _camera_offset()

## Backward-compatible snap for 2D position (maps to XZ plane).
func snap_to(pos) -> void:
	if pos is Vector3:
		snap_to_3d(pos)
	elif pos is Vector2:
		snap_to_3d(Vector3(pos.x, 0.0, pos.y))

func set_target_zoom(z: float) -> void:
	_target_size = clampf(z, MIN_SIZE, MAX_SIZE)

func update_camera(real_delta: float) -> void:
	_smooth_rotate(real_delta)
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

func handle_rotate_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_rotate"):
		_is_rotating = true
	elif event.is_action_released("camera_rotate"):
		_is_rotating = false
	elif event is InputEventMouseMotion and _is_rotating:
		var delta_x: float = event.relative.x
		_target_yaw -= delta_x * ROTATE_SENSITIVITY

# ── Follow ──────────────────────────────────────────────────────────────────

func _follow(real_delta: float) -> void:
	if not target_node or not is_instance_valid(target_node):
		return
	if not target_node is Node3D:
		return
	var target_pos: Vector3 = target_node.global_position

	# Clamp to world bounds
	var bounds := _get_bounds()
	target_pos.x = clampf(target_pos.x, bounds.position.x, bounds.end.x)
	target_pos.z = clampf(target_pos.z, bounds.position.y, bounds.end.y)

	_ground_target = _ground_target.lerp(target_pos, 1.0 - exp(-FOLLOW_SPEED * real_delta))
	global_position = _ground_target + _camera_offset()

# ── Rotation ────────────────────────────────────────────────────────────────

func _smooth_rotate(real_delta: float) -> void:
	if is_equal_approx(_current_yaw, _target_yaw):
		return
	_current_yaw = lerpf(_current_yaw, _target_yaw, 1.0 - exp(-ROTATE_SMOOTH_SPEED * real_delta))
	if absf(_current_yaw - _target_yaw) < 0.001:
		_current_yaw = _target_yaw
	_apply_rotation(_current_yaw)

# ── Zoom ────────────────────────────────────────────────────────────────────

func _smooth_zoom(real_delta: float) -> void:
	if is_equal_approx(size, _target_size):
		return
	var new_size := lerpf(size, _target_size, 1.0 - exp(-ZOOM_SMOOTH_SPEED * real_delta))
	if absf(new_size - _target_size) < 0.01:
		new_size = _target_size
	size = new_size

# ── Helpers ─────────────────────────────────────────────────────────────────

## Build camera basis from yaw + fixed iso pitch. Avoids Euler decomposition issues.
func _apply_rotation(yaw: float) -> void:
	global_transform.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, ISO_ROTATION_X)

## Camera offset from the ground-plane target point, computed from current yaw.
func _camera_offset() -> Vector3:
	var dist := 100.0
	var cam_basis := Basis(Vector3.UP, _current_yaw) * Basis(Vector3.RIGHT, ISO_ROTATION_X)
	return cam_basis.z * dist

func _get_bounds() -> Rect2:
	var n := MapManager.map_size
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
