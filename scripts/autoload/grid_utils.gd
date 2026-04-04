extends Node

## Isometric tile dimensions (screen footprint of one diamond tile).
## Change TILE_WIDTH:TILE_HEIGHT to adjust diamond angle.
## 64:32 = classic 2:1 dimetric. 64:48 = steeper. 64:24 = flatter.
## Change ROTATION (radians) to rotate the entire grid on screen.
static var TILE_WIDTH := 64
static var TILE_HEIGHT := 32
## Default rotation: grid axes align with 45° screen diagonals so
## player diagonal movement (W+D, W+A) follows grid axes exactly.
## Formula: PI/4 - atan2(TILE_HEIGHT, TILE_WIDTH)
static var ROTATION := PI / 4.0 - atan2(32.0, 64.0)  # ≈ 0.3217 rad ≈ 18.4°

## Derived basis vectors: where grid +X and +Y point on screen.
## Recomputed by recalculate(). All coordinate math uses these.
static var HALF_W := TILE_WIDTH / 2.0
static var HALF_H := TILE_HEIGHT / 2.0
static var _basis_x := Vector2(HALF_W, HALF_H)
static var _basis_y := Vector2(-HALF_W, HALF_H)
## Inverse basis (for world_to_grid), precomputed for speed.
static var _inv_det := 1.0 / (_basis_x.x * _basis_y.y - _basis_x.y * _basis_y.x)

## Recompute derived values on startup (static var initializers don't include ROTATION).
func _ready() -> void:
	recalculate()

## Call after changing TILE_WIDTH, TILE_HEIGHT, or ROTATION.
static func recalculate() -> void:
	HALF_W = TILE_WIDTH / 2.0
	HALF_H = TILE_HEIGHT / 2.0
	_basis_x = Vector2(HALF_W, HALF_H).rotated(ROTATION)
	_basis_y = Vector2(-HALF_W, HALF_H).rotated(ROTATION)
	var det := _basis_x.x * _basis_y.y - _basis_x.y * _basis_y.x
	_inv_det = 1.0 / det if det != 0.0 else 1.0

## Convert grid coordinates to world-space (isometric tile center).
static func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return _basis_x * grid_pos.x + _basis_y * grid_pos.y

## Alias -- in isometric, grid_to_world already returns the center.
static func grid_to_center(grid_pos: Vector2i) -> Vector2:
	return grid_to_world(grid_pos)

## Convert world position to grid coordinates (isometric diamond picking).
static func world_to_grid(world_pos: Vector2) -> Vector2i:
	var gx := (_basis_y.y * world_pos.x - _basis_y.x * world_pos.y) * _inv_det
	var gy := (_basis_x.x * world_pos.y - _basis_x.y * world_pos.x) * _inv_det
	return Vector2i(floori(gx + 0.5), floori(gy + 0.5))

## Get a point offset from grid cell center along a GRID direction.
## fraction=0.5 gives tile edge.
static func grid_offset(grid_pos: Vector2i, direction: Vector2, fraction: float) -> Vector2:
	var screen_dir := _basis_x * direction.x + _basis_y * direction.y
	return grid_to_center(grid_pos) + screen_dir * fraction

## Map world bounds for an NxN grid (axis-aligned bounding rect of the diamond).
static func map_world_size(map_tiles: int) -> Vector2:
	# Compute the 4 extreme grid corners and find the AABB
	var corners := [
		grid_to_world(Vector2i(0, 0)),
		grid_to_world(Vector2i(map_tiles, 0)),
		grid_to_world(Vector2i(0, map_tiles)),
		grid_to_world(Vector2i(map_tiles, map_tiles)),
	]
	var min_v: Vector2 = corners[0]
	var max_v: Vector2 = corners[0]
	for c in corners:
		min_v.x = minf(min_v.x, c.x)
		min_v.y = minf(min_v.y, c.y)
		max_v.x = maxf(max_v.x, c.x)
		max_v.y = maxf(max_v.y, c.y)
	return max_v - min_v

## The top-left corner of the map's bounding box in world coordinates.
static func map_origin(map_tiles: int) -> Vector2:
	var corners := [
		grid_to_world(Vector2i(0, 0)),
		grid_to_world(Vector2i(map_tiles, 0)),
		grid_to_world(Vector2i(0, map_tiles)),
		grid_to_world(Vector2i(map_tiles, map_tiles)),
	]
	var min_v: Vector2 = corners[0]
	for c in corners:
		min_v.x = minf(min_v.x, c.x)
		min_v.y = minf(min_v.y, c.y)
	return min_v

## World size of one tile as Vector2 (screen footprint bounding box).
static func tile_size_vec() -> Vector2:
	return Vector2(TILE_WIDTH, TILE_HEIGHT)

## Transform2D that maps a unit quad (-0.5..0.5) to a tile at grid_pos.
## Used for MultiMesh instances so art stretches/rotates to match the grid.
static func tile_transform(grid_pos: Vector2i) -> Transform2D:
	return Transform2D(
		Vector2(TILE_WIDTH, 0).rotated(ROTATION),
		Vector2(0, TILE_HEIGHT).rotated(ROTATION),
		grid_to_center(grid_pos)
	)

## Convert a grid-space direction to screen-space direction (normalized).
static func grid_dir_to_screen(grid_dir: Vector2) -> Vector2:
	return (_basis_x * grid_dir.x + _basis_y * grid_dir.y).normalized()

## Diamond vertex offsets relative to tile center (top, right, bottom, left).
## Use: `var points = center + GridUtils.diamond_top()` etc.
static func diamond_top() -> Vector2:
	return (_basis_x + _basis_y) * -0.5  # midpoint of top two edges, negated

static func diamond_right() -> Vector2:
	return (_basis_x - _basis_y) * 0.5

static func diamond_bottom() -> Vector2:
	return (_basis_x + _basis_y) * 0.5

static func diamond_left() -> Vector2:
	return (_basis_y - _basis_x) * 0.5

## PackedVector2Array of 4 diamond vertices around a center point.
static func get_diamond_points(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + diamond_top(),
		center + diamond_right(),
		center + diamond_bottom(),
		center + diamond_left(),
	])
