extends Node

## Grid coordinate utilities for 3D world space.
## Grid coords map to world XZ plane (Y = 0 ground), 1 unit per tile.
## Grid X -> world +X, Grid Y -> world +Z.

## Size of one grid tile in 3D world units.
const TILE_SIZE := 1.0

## Convert grid coordinates to 3D world position on the ground plane (Y=0).
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * TILE_SIZE, 0.0, grid_pos.y * TILE_SIZE)

## Convert grid coordinates to 3D world position at terrain elevation.
func grid_to_world_elevated(grid_pos: Vector2i) -> Vector3:
	var h: float = GameManager.get_terrain_height(grid_pos)
	return Vector3(grid_pos.x * TILE_SIZE, h, grid_pos.y * TILE_SIZE)

## Alias -- center of a tile in 3D (same as grid_to_world).
func grid_to_center(grid_pos: Vector2i) -> Vector3:
	return grid_to_world(grid_pos)

## Convert 3D world position to grid coordinates (projects onto XZ plane).
func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / TILE_SIZE + 0.5),
		floori(world_pos.z / TILE_SIZE + 0.5)
	)

## Offset from grid cell center along a grid direction in 3D.
## fraction=0.5 gives tile edge.
func grid_offset(grid_pos: Vector2i, direction: Vector2, fraction: float) -> Vector3:
	var center := grid_to_world(grid_pos)
	return center + Vector3(direction.x, 0.0, direction.y) * TILE_SIZE * fraction

## Convert a grid-space direction to a 3D world direction (normalized, on XZ plane).
func grid_dir_to_world(grid_dir: Vector2) -> Vector3:
	return Vector3(grid_dir.x, 0.0, grid_dir.y).normalized()

## Transform3D that places a unit-sized object at a grid position.
## The transform scales by TILE_SIZE and positions on the ground plane.
func tile_transform(grid_pos: Vector2i) -> Transform3D:
	var origin := grid_to_world(grid_pos)
	return Transform3D(
		Basis.IDENTITY.scaled(Vector3(TILE_SIZE, TILE_SIZE, TILE_SIZE)),
		origin
	)

## Map world bounds for an NxN grid in 3D (AABB on XZ plane).
func map_world_size(map_tiles: int) -> Vector3:
	return Vector3(map_tiles * TILE_SIZE, 0.0, map_tiles * TILE_SIZE)

## The origin corner (min X, Y=0, min Z) of the map in 3D.
func map_origin(_map_tiles: int) -> Vector3:
	return Vector3.ZERO

## Raycast from a camera through the mouse position to find the terrain grid cell.
## Uses physics raycast against the terrain HeightMapShape3D (ground layer, mask 4).
## Falls back to Y=0 plane intersection if no terrain collision exists.
func raycast_mouse_to_grid(viewport: Viewport) -> Vector2i:
	var camera := viewport.get_camera_3d()
	if not camera:
		return Vector2i.ZERO
	var mouse_pos := viewport.get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	# Raycast against terrain collision (ground layer, bit 3 = mask 4)
	var space := viewport.get_world_3d().direct_space_state
	if space:
		var ray_end := ray_origin + ray_dir * 200.0
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 4)
		var result := space.intersect_ray(query)
		if result:
			return world_to_grid(result.position)

	# Fallback: intersect with Y=0 ground plane
	if absf(ray_dir.y) < 0.0001:
		return Vector2i.ZERO
	var t := -ray_origin.y / ray_dir.y
	var hit := ray_origin + ray_dir * t
	return world_to_grid(hit)

## Raycast from a camera through the mouse position, returning the 3D world hit point.
## Falls back to Y=0 plane intersection if no terrain collision exists.
func raycast_mouse_to_world(viewport: Viewport) -> Vector3:
	var camera := viewport.get_camera_3d()
	if not camera:
		return Vector3.ZERO
	var mouse_pos := viewport.get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	var space := viewport.get_world_3d().direct_space_state
	if space:
		var ray_end := ray_origin + ray_dir * 200.0
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 4)
		var result := space.intersect_ray(query)
		if result:
			return result.position

	if absf(ray_dir.y) < 0.0001:
		return Vector3.ZERO
	var t := -ray_origin.y / ray_dir.y
	return ray_origin + ray_dir * t
