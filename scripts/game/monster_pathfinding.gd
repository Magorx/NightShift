class_name MonsterPathfinding
extends RefCounted

## Shared A* pathfinding grid for monsters during the fight phase.
## Uses a 2x sub-cell grid for smoother navigation (each game tile = 2x2 sub-cells).
## Rebuilt once at fight start and when buildings are destroyed.
## Monsters query get_path() with game-grid coords; conversion is internal.

const SUB_CELL := 2  # sub-cells per game tile (2x resolution)

var _astar := AStar2D.new()
var _sub_grid_size: int = 0  # total sub-cells per axis

func rebuild() -> void:
	_astar.clear()
	_sub_grid_size = MapManager.map_size * SUB_CELL

	for sy in _sub_grid_size:
		for sx in _sub_grid_size:
			if _is_sub_walkable(sx, sy):
				_astar.add_point(_sub_to_id(sx, sy), Vector2(sx, sy))

	# Connect 8-directional neighbors (cardinal + diagonal)
	for sy in _sub_grid_size:
		for sx in _sub_grid_size:
			var id := _sub_to_id(sx, sy)
			if not _astar.has_point(id):
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := sx + dx
					var ny := sy + dy
					if nx < 0 or ny < 0 or nx >= _sub_grid_size or ny >= _sub_grid_size:
						continue
					var nid := _sub_to_id(nx, ny)
					if _astar.has_point(nid):
						_astar.connect_points(id, nid, false)

	print("[PATHFINDING] Sub-grid rebuilt: %dx%d (SUB_CELL=%d), %d walkable" % [
		_sub_grid_size, _sub_grid_size, SUB_CELL, _astar.get_point_count()])

## Get a path between two game-grid positions. Returns world-unit coordinates.
func get_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	var from_sub := _grid_to_sub(from)
	var to_sub := _grid_to_sub(to)
	var from_id := _sub_to_id(from_sub.x, from_sub.y)
	var to_id := _sub_to_id(to_sub.x, to_sub.y)
	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return PackedVector2Array()
	var sub_path := _astar.get_point_path(from_id, to_id)
	# Convert sub-cell coords to world-unit coords
	var world_path := PackedVector2Array()
	world_path.resize(sub_path.size())
	for i in sub_path.size():
		world_path[i] = sub_path[i] / float(SUB_CELL)
	return world_path

## Get a path between two world positions (not grid-snapped).
func get_path_world(from_world: Vector3, to_world: Vector3) -> PackedVector2Array:
	var from_sub := _world_to_sub(from_world)
	var to_sub := _world_to_sub(to_world)
	var from_id := _sub_to_id(from_sub.x, from_sub.y)
	var to_id := _sub_to_id(to_sub.x, to_sub.y)
	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return PackedVector2Array()
	var sub_path := _astar.get_point_path(from_id, to_id)
	var world_path := PackedVector2Array()
	world_path.resize(sub_path.size())
	for i in sub_path.size():
		world_path[i] = sub_path[i] / float(SUB_CELL)
	return world_path

## Find the best adjacent cell to a building that this monster can path to.
func find_attack_cell(from: Vector2i, building_pos: Vector2i) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_dist := INF

	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var adj: Vector2i = building_pos + dir
		var adj_sub := _grid_to_sub(adj)
		var adj_id := _sub_to_id(adj_sub.x, adj_sub.y)
		if not _astar.has_point(adj_id):
			continue
		var dist: float = from.distance_squared_to(adj)
		if dist < best_dist:
			best_dist = dist
			best_cell = adj

	return best_cell

# ── Sub-cell helpers ────────────────────────────────────────────────────────

func _grid_to_sub(grid_pos: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	return grid_pos * SUB_CELL + Vector2i(SUB_CELL / 2, SUB_CELL / 2)

func _world_to_sub(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		roundi(world_pos.x * SUB_CELL),
		roundi(world_pos.z * SUB_CELL)
	)

func _is_sub_walkable(sx: int, sy: int) -> bool:
	if sx < 0 or sy < 0 or sx >= _sub_grid_size or sy >= _sub_grid_size:
		return false
	@warning_ignore("integer_division")
	var grid_pos := Vector2i(sx / SUB_CELL, sy / SUB_CELL)
	if MapManager.walls.has(grid_pos):
		return false
	if BuildingRegistry.get_building_at(grid_pos) != null:
		return false
	return true

func _sub_to_id(sx: int, sy: int) -> int:
	return sy * _sub_grid_size + sx
