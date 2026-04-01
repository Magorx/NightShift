class_name ClusterDrainManager
extends RefCounted

## Manages BFS-based drain ordering for deposit extraction.
## Multiple extractors can mine the same cluster of any deposit type.
## The most distant tiles (from any extractor) are drained first.
## Cache is rebuilt when an extractor is placed or removed.
##
## Generic: works with any deposit type that has finite stocks.
## Buildings register by implementing get_covered_deposit_cells() -> Array[Vector2i]
## and get_deposit_item_id() -> StringName.

const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var _cache_dirty: bool = true
## Per-extractor drain order: extractor_grid_pos -> Array[Vector2i] sorted most-distant-first
var _drain_order_cache: Dictionary = {}

func invalidate_cache() -> void:
	_cache_dirty = true
	_drain_order_cache.clear()

## Get the next tile to drain for a given extractor (most distant with stock > 0).
## deposit_id: the item_id of the deposit this extractor mines (for BFS traversal).
func get_next_drain_tile(extractor_pos: Vector2i, _deposit_id: StringName) -> Vector2i:
	if _cache_dirty:
		_rebuild_drain_order()
	var order: Array = _drain_order_cache.get(extractor_pos, [])
	for tile_pos: Vector2i in order:
		var stock: int = GameManager.deposit_stocks.get(tile_pos, 0)
		if stock > 0 or stock == -1:
			return tile_pos
	return Vector2i(-1, -1)

func _rebuild_drain_order() -> void:
	_drain_order_cache.clear()
	_cache_dirty = false

	# Collect all buildings that participate in cluster draining
	# Group by deposit type so BFS only traverses matching tiles
	var by_deposit: Dictionary = {}  # deposit_id -> Array[{pos, cells}]
	for building in GameManager.unique_buildings:
		if not is_instance_valid(building) or not building.logic:
			continue
		if not building.logic.has_method("get_covered_deposit_cells"):
			continue
		if not building.logic.has_method("get_deposit_item_id"):
			continue
		var cells: Array = building.logic.get_covered_deposit_cells()
		if cells.is_empty():
			continue
		var dep_id: StringName = building.logic.get_deposit_item_id()
		if not by_deposit.has(dep_id):
			by_deposit[dep_id] = []
		by_deposit[dep_id].append({pos = building.grid_pos, cells = cells})

	# Run separate BFS per deposit type
	for dep_id: StringName in by_deposit:
		var extractor_data: Array = by_deposit[dep_id]
		_rebuild_for_deposit(dep_id, extractor_data)

func _rebuild_for_deposit(deposit_id: StringName, extractor_data: Array) -> void:
	# Multi-source BFS from ALL extractor cells simultaneously
	var distance: Dictionary = {}
	var queue: Array[Vector2i] = []

	for data in extractor_data:
		for cell: Vector2i in data.cells:
			if not distance.has(cell):
				distance[cell] = 0
				queue.append(cell)

	# BFS over matching deposit tiles only (forming natural clusters)
	var head := 0
	while head < queue.size():
		var pos: Vector2i = queue[head]
		head += 1
		var d: int = distance[pos]
		for dir: Vector2i in DIRECTIONS:
			var next: Vector2i = pos + dir
			if distance.has(next):
				continue
			if GameManager.deposits.get(next, &"") != deposit_id:
				continue
			distance[next] = d + 1
			queue.append(next)

	# For each extractor, build its drain order (all reachable tiles, most distant first)
	for data in extractor_data:
		var reachable: Array = []
		for pos: Vector2i in distance:
			if GameManager.deposits.get(pos, &"") != deposit_id:
				continue
			reachable.append({pos = pos, dist = distance[pos]})
		reachable.sort_custom(func(a, b): return a.dist > b.dist)
		var ordered: Array = []
		for entry in reachable:
			ordered.append(entry.pos)
		_drain_order_cache[data.pos] = ordered
