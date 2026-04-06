class_name MonsterPathfinding
extends RefCounted

## Shared A* pathfinding grid for monsters during the fight phase.
## Rebuilt once at fight start and when buildings are destroyed.
## Monsters query get_path() for navigation between grid cells.

var _astar := AStar2D.new()
var _grid_size: int = 0

func rebuild() -> void:
	_astar.clear()
	_grid_size = MapManager.map_size

	for y in _grid_size:
		for x in _grid_size:
			var pos := Vector2i(x, y)
			if _is_walkable(pos):
				_astar.add_point(_pos_to_id(pos), Vector2(x, y))

	# Connect 4-directional neighbors
	for y in _grid_size:
		for x in _grid_size:
			var id := _pos_to_id(Vector2i(x, y))
			if not _astar.has_point(id):
				continue
			if x < _grid_size - 1:
				var right_id := _pos_to_id(Vector2i(x + 1, y))
				if _astar.has_point(right_id):
					_astar.connect_points(id, right_id)
			if y < _grid_size - 1:
				var down_id := _pos_to_id(Vector2i(x, y + 1))
				if _astar.has_point(down_id):
					_astar.connect_points(id, down_id)

	print("[PATHFINDING] Grid rebuilt: %dx%d, %d walkable" % [
		_grid_size, _grid_size, _astar.get_point_count()])

func get_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	var from_id := _pos_to_id(from)
	var to_id := _pos_to_id(to)
	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return PackedVector2Array()
	return _astar.get_point_path(from_id, to_id)

## Find the best adjacent cell to a building that this monster can path to.
func find_attack_cell(from: Vector2i, building_pos: Vector2i) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_dist := INF

	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var adj: Vector2i = building_pos + dir
		var adj_id := _pos_to_id(adj)
		if not _astar.has_point(adj_id):
			continue
		var dist: float = from.distance_squared_to(adj)
		if dist < best_dist:
			best_dist = dist
			best_cell = adj

	return best_cell

func _is_walkable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= _grid_size or pos.y >= _grid_size:
		return false
	if MapManager.walls.has(pos):
		return false
	if BuildingRegistry.get_building_at(pos) != null:
		return false
	return true

func _pos_to_id(pos: Vector2i) -> int:
	return pos.y * _grid_size + pos.x
