extends Node

## Isometric 2:1 dimetric tile dimensions (screen footprint of one diamond tile).
## Grid X axis goes down-right on screen, Grid Y axis goes down-left.
const TILE_WIDTH := 64
const TILE_HEIGHT := 32
const HALF_W := TILE_WIDTH / 2.0  # 32.0
const HALF_H := TILE_HEIGHT / 2.0  # 16.0

## Convert grid coordinates to world-space (isometric diamond center).
## In isometric, grid_to_world returns the tile CENTER (unlike orthogonal where it's top-left).
static func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		(grid_pos.x - grid_pos.y) * HALF_W,
		(grid_pos.x + grid_pos.y) * HALF_H
	)

## Convert grid coordinates to world-space center of the tile.
## In isometric projection, this is the same as grid_to_world.
static func grid_to_center(grid_pos: Vector2i) -> Vector2:
	return grid_to_world(grid_pos)

## Convert world position to grid coordinates (isometric diamond picking).
static func world_to_grid(world_pos: Vector2) -> Vector2i:
	var gx := (world_pos.x / HALF_W + world_pos.y / HALF_H) * 0.5
	var gy := (world_pos.y / HALF_H - world_pos.x / HALF_W) * 0.5
	return Vector2i(floori(gx), floori(gy))

## Get a point offset from grid cell center along a GRID direction.
## direction should be a grid-space direction like Vector2(1,0), Vector2(0,1), etc.
## This converts to screen-space offset. fraction=0.5 gives tile edge.
static func grid_offset(grid_pos: Vector2i, direction: Vector2, fraction: float) -> Vector2:
	# Convert grid direction to screen direction
	var screen_dir := Vector2(
		(direction.x - direction.y) * HALF_W,
		(direction.x + direction.y) * HALF_H
	)
	return grid_to_center(grid_pos) + screen_dir * fraction

## Map world bounds for an NxN grid in isometric projection.
## Returns the bounding rectangle size of the diamond-shaped map.
static func map_world_size(map_tiles: int) -> Vector2:
	# The diamond map for NxN tiles spans:
	# X: from grid(0, N-1) to grid(N-1, 0)  => width = 2 * N * HALF_W = N * TILE_WIDTH
	# Y: from grid(0, 0) to grid(N-1, N-1) => height = 2 * N * HALF_H = N * TILE_HEIGHT
	return Vector2(map_tiles * TILE_WIDTH, map_tiles * TILE_HEIGHT)

## The top-left corner of the map's bounding box in world coordinates.
## For isometric, the diamond is centered at screen x=0, with negative x values for y-axis tiles.
static func map_origin(map_tiles: int) -> Vector2:
	# grid(0, map_tiles-1) gives the leftmost point
	return Vector2(-(map_tiles - 1) * HALF_W, 0.0)

## World size of one tile as Vector2 (screen footprint)
static func tile_size_vec() -> Vector2:
	return Vector2(TILE_WIDTH, TILE_HEIGHT)

## Convert a grid-space direction vector to screen-space direction (normalized).
## E.g., grid direction (1,0) becomes screen direction pointing down-right.
static func grid_dir_to_screen(grid_dir: Vector2) -> Vector2:
	return Vector2(
		(grid_dir.x - grid_dir.y) * HALF_W,
		(grid_dir.x + grid_dir.y) * HALF_H
	).normalized()
