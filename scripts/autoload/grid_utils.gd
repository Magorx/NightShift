extends Node

## Single source of truth for tile dimensions.
## In ISO.2 these become 64x32 and the conversion functions use TileMap APIs.
const TILE_WIDTH := 32
const TILE_HEIGHT := 32
const HALF_W := TILE_WIDTH / 2.0
const HALF_H := TILE_HEIGHT / 2.0

## Convert grid coordinates to world-space top-left corner
static func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_WIDTH, grid_pos.y * TILE_HEIGHT)

## Convert grid coordinates to world-space center of the tile
static func grid_to_center(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_WIDTH + HALF_W, grid_pos.y * TILE_HEIGHT + HALF_H)

## Convert world position to grid coordinates
static func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE_WIDTH), floori(world_pos.y / TILE_HEIGHT))

## Get a point offset from grid cell center along a direction.
## fraction=0.5 gives edge, fraction=0.0 gives center.
static func grid_offset(grid_pos: Vector2i, direction: Vector2, fraction: float) -> Vector2:
	return grid_to_center(grid_pos) + direction * Vector2(HALF_W, HALF_H) * 2.0 * fraction

## Map size in pixels (world units)
static func map_world_size(map_tiles: int) -> Vector2:
	return Vector2(map_tiles * TILE_WIDTH, map_tiles * TILE_HEIGHT)

## World size of one tile as Vector2
static func tile_size_vec() -> Vector2:
	return Vector2(TILE_WIDTH, TILE_HEIGHT)
