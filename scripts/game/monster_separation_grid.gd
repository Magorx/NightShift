class_name MonsterSeparationGrid
extends RefCounted

## Spatial hash for monster-vs-monster boid separation queries.
##
## The previous implementation called `get_tree().get_nodes_in_group("monsters")`
## inside `_apply_separation` per monster per frame, which was O(N²) and
## dominated baseline frame time at large monster counts (~13% of avg frame
## time at 42 monsters, ~quadratic from there).
##
## This grid is rebuilt once per physics frame from the spawner's
## `alive_monsters` array (cheap O(N) bucket assignment) and then queried by
## each monster's `_apply_separation` to get only the monsters within its
## immediate neighborhood — typically 3×3 cells at the SEPARATION_RADIUS scale.
##
## The cell size is set slightly larger than the separation radius so a query
## from any point in a cell is guaranteed to hit all neighbors within radius
## by checking the 3×3 cell window centered on the query point's cell.

const CELL_SIZE := 1.5  # world units; > MonsterBase.SEPARATION_RADIUS (1.1)

## key = Vector2i (cell coords) -> Array[MonsterBase]
var _cells: Dictionary = {}
## Frame number this grid was built for. Lets the spawner skip rebuilding twice
## in the same frame if needed (defensive).
var _frame: int = -1

## Rebuild the grid from a list of live monsters. O(N).
func rebuild(alive: Array) -> void:
	var f := Engine.get_physics_frames()
	if f == _frame:
		return
	_frame = f
	_cells.clear()
	for m in alive:
		if not is_instance_valid(m):
			continue
		if (m as Node).is_queued_for_deletion():
			continue
		var pos: Vector3 = (m as Node3D).global_position
		var cell := _cell_of(pos)
		var bucket: Array = _cells.get(cell, [])
		if bucket.is_empty():
			_cells[cell] = bucket
		bucket.append(m)

## Append all monsters within the 3×3 cell window centered on `world_pos` into
## `out` (caller-provided to avoid per-call array allocation in the hot loop).
## Pass the querying monster as `exclude` so it isn't returned as its own
## neighbor.
func gather_neighbors(world_pos: Vector3, out: Array, exclude: Object = null) -> void:
	var cell := _cell_of(world_pos)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := Vector2i(cell.x + dx, cell.y + dy)
			var bucket: Array = _cells.get(key, [])
			for m in bucket:
				if m == exclude:
					continue
				out.append(m)

func _cell_of(world_pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / CELL_SIZE)), int(floor(world_pos.z / CELL_SIZE)))
