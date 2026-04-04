extends Node

## Grid coordinate utilities for 3D world space.
## Grid coords map to world XZ plane (Y = 0 ground), 1 unit per tile.
## Grid X -> world +X, Grid Y -> world +Z.

## Size of one grid tile in 3D world units.
const TILE_SIZE := 1.0

## Convert grid coordinates to 3D world position on the ground plane.
static func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * TILE_SIZE, 0.0, grid_pos.y * TILE_SIZE)

## Alias -- center of a tile in 3D (same as grid_to_world).
static func grid_to_center(grid_pos: Vector2i) -> Vector3:
	return grid_to_world(grid_pos)

## Convert 3D world position to grid coordinates (projects onto XZ plane).
static func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / TILE_SIZE + 0.5),
		floori(world_pos.z / TILE_SIZE + 0.5)
	)

## Offset from grid cell center along a grid direction in 3D.
## fraction=0.5 gives tile edge.
static func grid_offset(grid_pos: Vector2i, direction: Vector2, fraction: float) -> Vector3:
	var center := grid_to_world(grid_pos)
	return center + Vector3(direction.x, 0.0, direction.y) * TILE_SIZE * fraction

## Convert a grid-space direction to a 3D world direction (normalized, on XZ plane).
static func grid_dir_to_world(grid_dir: Vector2) -> Vector3:
	return Vector3(grid_dir.x, 0.0, grid_dir.y).normalized()

## Transform3D that places a unit-sized object at a grid position.
## The transform scales by TILE_SIZE and positions on the ground plane.
static func tile_transform(grid_pos: Vector2i) -> Transform3D:
	var origin := grid_to_world(grid_pos)
	return Transform3D(
		Basis.IDENTITY.scaled(Vector3(TILE_SIZE, TILE_SIZE, TILE_SIZE)),
		origin
	)

## Map world bounds for an NxN grid in 3D (AABB on XZ plane).
static func map_world_size(map_tiles: int) -> Vector3:
	return Vector3(map_tiles * TILE_SIZE, 0.0, map_tiles * TILE_SIZE)

## The origin corner (min X, Y=0, min Z) of the map in 3D.
static func map_origin(map_tiles: int) -> Vector3:
	return Vector3.ZERO
