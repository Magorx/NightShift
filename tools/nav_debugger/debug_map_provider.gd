## Provides walkable/elevation data to GroundNavLayer from a debug grid.
## Replaces MapManager + BuildingRegistry when injected as map_provider.
##
## API contract expected by GroundNavLayer:
##   map_size: int
##   is_walkable(x, y) -> bool
##   get_height(x, y) -> float
class_name DebugMapProvider
extends RefCounted

enum CellType { EMPTY = 0, WALL = 1 }

var map_size: int = 20

## Vector2i → [type: int, height: int]
var _cells: Dictionary = {}


func is_walkable(x: int, y: int) -> bool:
	var data: Variant = _cells.get(Vector2i(x, y))
	if data == null:
		return true
	return (data as Array)[0] == CellType.EMPTY


func get_height(x: int, y: int) -> float:
	var data: Variant = _cells.get(Vector2i(x, y))
	if data == null:
		return 0.0
	return float((data as Array)[1])


func set_cell(v: Vector2i, type: int, height: int) -> void:
	if type == CellType.EMPTY and height == 0:
		_cells.erase(v)
	else:
		_cells[v] = [type, height]


func get_cell_type(v: Vector2i) -> int:
	var data: Variant = _cells.get(v)
	if data == null:
		return CellType.EMPTY
	return (data as Array)[0]


func get_cell_height(v: Vector2i) -> int:
	var data: Variant = _cells.get(v)
	if data == null:
		return 0
	return (data as Array)[1]


func clear_all() -> void:
	_cells.clear()
