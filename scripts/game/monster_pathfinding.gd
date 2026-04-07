class_name MonsterPathfinding
extends RefCounted

## Façade over one or more NavLayers. Exposes the monster-facing query API
## (sample_factory_flow, sample_chase_flow) plus the legacy A* API that test
## scenarios depend on (get_path, get_path_world, find_attack_cell).
##
## Architecture (see scripts/game/nav/):
##
##   MonsterPathfinding
##     ├── ground: GroundNavLayer    — walkable = not wall, not building
##     ├── jumping: (future)         — GroundNavLayer + ignores small elevation
##     └── flying:  (future)         — separate walkable profile entirely
##
## Each NavLayer owns its own sector grid, portal graph, per-sector flow
## fields, and dirty tracking, so adding a new movement type is just a new
## subclass of NavLayer registered here — the sector/portal/BFS machinery is
## shared.
##
## Goals are named destinations, shared across all agents:
##   GOAL_FACTORY — all cells adjacent to any building (multi-sector target).
##                  Re-registered when a building is placed or destroyed.
##   GOAL_CHASE   — the player's current sub-cell (single-sector target).
##                  Re-registered on the façade side whenever the player
##                  crosses a sub-cell boundary; otherwise reuses the cached
##                  next-hop + per-sector flow fields across all chasers.
##
## Scaling behaviour:
##   - Sector flow field compute = O(SECTOR_SUB_SIZE²) ≈ 1024 ops (vs. the
##     previous whole-map BFS of ~65k cells on a 128-tile map).
##   - Per-sector fields are cached; N monsters in the same sector → 1 compute.
##   - Sectors without any monsters never generate fields at all.
##   - Building changes mark only their sector + neighbours dirty; lazy
##     rebuild coalesces multiple changes into one update on the next query.

const SUB_CELL := 2

const GOAL_FACTORY := &"factory"
const GOAL_CHASE := &"chase"

# ── Nav layers ──────────────────────────────────────────────────────────────
var ground: GroundNavLayer

# Chase goal cache: only re-register when the player crosses sub-cells.
var _chase_player_sub: Vector2i = Vector2i(-9999, -9999)

# ── Legacy A* (test compatibility) ──────────────────────────────────────────
# Kept alongside the NavLayer system because a couple of scenarios still call
# get_path / get_path_world / find_attack_cell directly. The NavLayer is
# authoritative for live gameplay queries.
var _astar := AStar2D.new()
var _legacy_sub_grid_size: int = 0

func _init() -> void:
	ground = GroundNavLayer.new()

# ────────────────────────────────────────────────────────────────────────────
# Full rebuild
# ────────────────────────────────────────────────────────────────────────────

func rebuild() -> void:
	ground.rebuild()
	_rebuild_legacy_astar()
	_register_factory_goal()
	# Invalidate chase cache so the next chase sample re-registers
	_chase_player_sub = Vector2i(-9999, -9999)

## Invalidate the factory flow field. Call when buildings are placed or
## destroyed mid-fight. Marks the affected sector dirty and re-registers
## the goal so the per-sector flow fields regenerate on demand.
func invalidate_factory_flow() -> void:
	_register_factory_goal()

## Mark a specific grid cell as dirty in the ground nav layer (e.g. wall
## added/removed). Building changes already go through invalidate_factory_flow.
func mark_cell_dirty(grid_pos: Vector2i) -> void:
	ground.mark_cell_dirty(grid_pos)

# ────────────────────────────────────────────────────────────────────────────
# Flow field sampling (used by MonsterBase)
# ────────────────────────────────────────────────────────────────────────────

## Sample the factory flow field for ground monsters. Returns a normalised
## (x, z) direction, or Vector2.ZERO if no path / no buildings.
func sample_factory_flow(world_pos: Vector3) -> Vector2:
	var _perf_t0: int = Time.get_ticks_usec() if MonsterPerf.enabled else 0
	var r := ground.sample_flow(world_pos, GOAL_FACTORY)
	if MonsterPerf.enabled:
		MonsterPerf.sample_factory_calls += 1
		MonsterPerf.sample_factory_usec += Time.get_ticks_usec() - _perf_t0
	return r

## Sample the chase flow field for ground monsters. Re-registers the chase
## goal if the player has crossed a sub-cell boundary since the last call.
func sample_chase_flow(from_world: Vector3, player_world: Vector3) -> Vector2:
	_maybe_update_chase_goal(player_world)
	return ground.sample_flow(from_world, GOAL_CHASE)

func _maybe_update_chase_goal(player_world: Vector3) -> void:
	var sub := Vector2i(
		roundi(player_world.x * SUB_CELL),
		roundi(player_world.z * SUB_CELL)
	)
	if sub == _chase_player_sub and ground.goals.has(GOAL_CHASE):
		return
	_chase_player_sub = sub
	var cells := PackedVector2Array([Vector2(sub.x, sub.y)])
	ground.set_goal(GOAL_CHASE, cells)

func _register_factory_goal() -> void:
	var _perf_t0: int = Time.get_ticks_usec() if MonsterPerf.enabled else 0
	var cells := PackedVector2Array()
	for building in BuildingRegistry.unique_buildings:
		if not is_instance_valid(building):
			continue
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var adj: Vector2i = building.grid_pos + dir
			@warning_ignore("integer_division")
			var sub_off: Vector2i = Vector2i(SUB_CELL / 2, SUB_CELL / 2)
			var sub: Vector2i = adj * SUB_CELL + sub_off
			cells.append(Vector2(sub.x, sub.y))
	ground.set_goal(GOAL_FACTORY, cells)
	if MonsterPerf.enabled:
		MonsterPerf.register_goal_calls += 1
		MonsterPerf.register_goal_usec += Time.get_ticks_usec() - _perf_t0

# ────────────────────────────────────────────────────────────────────────────
# Legacy A* API (get_path / get_path_world / find_attack_cell)
# ────────────────────────────────────────────────────────────────────────────

func _rebuild_legacy_astar() -> void:
	_astar.clear()
	_legacy_sub_grid_size = MapManager.map_size * SUB_CELL
	for sy in _legacy_sub_grid_size:
		for sx in _legacy_sub_grid_size:
			if ground.is_sub_walkable(sx, sy):
				_astar.add_point(_sub_to_id(sx, sy), Vector2(sx, sy))
	for sy in _legacy_sub_grid_size:
		for sx in _legacy_sub_grid_size:
			var id: int = _sub_to_id(sx, sy)
			if not _astar.has_point(id):
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx: int = sx + dx
					var ny: int = sy + dy
					if nx < 0 or ny < 0 or nx >= _legacy_sub_grid_size or ny >= _legacy_sub_grid_size:
						continue
					var nid: int = _sub_to_id(nx, ny)
					if _astar.has_point(nid):
						_astar.connect_points(id, nid, false)

## Get a path between two game-grid positions. Returns world-unit coordinates.
## Legacy — prefer sample_*_flow() for gameplay code.
func get_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	var from_sub: Vector2i = _grid_to_sub(from)
	var to_sub: Vector2i = _grid_to_sub(to)
	var from_id: int = _sub_to_id(from_sub.x, from_sub.y)
	var to_id: int = _sub_to_id(to_sub.x, to_sub.y)
	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return PackedVector2Array()
	var sub_path: PackedVector2Array = _astar.get_point_path(from_id, to_id)
	var world_path := PackedVector2Array()
	world_path.resize(sub_path.size())
	for i in sub_path.size():
		world_path[i] = sub_path[i] / float(SUB_CELL)
	return world_path

## Get a path between two world positions (not grid-snapped).
func get_path_world(from_world: Vector3, to_world: Vector3) -> PackedVector2Array:
	var from_sub: Vector2i = _world_to_sub(from_world)
	var to_sub: Vector2i = _world_to_sub(to_world)
	var from_id: int = _sub_to_id(from_sub.x, from_sub.y)
	var to_id: int = _sub_to_id(to_sub.x, to_sub.y)
	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return PackedVector2Array()
	var sub_path: PackedVector2Array = _astar.get_point_path(from_id, to_id)
	var world_path := PackedVector2Array()
	world_path.resize(sub_path.size())
	for i in sub_path.size():
		world_path[i] = sub_path[i] / float(SUB_CELL)
	return world_path

## Find the best adjacent walkable cell to a building.
func find_attack_cell(from: Vector2i, building_pos: Vector2i) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_dist := INF
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var adj: Vector2i = building_pos + dir
		var adj_sub: Vector2i = _grid_to_sub(adj)
		var adj_id: int = _sub_to_id(adj_sub.x, adj_sub.y)
		if not _astar.has_point(adj_id):
			continue
		var dist: float = from.distance_squared_to(adj)
		if dist < best_dist:
			best_dist = dist
			best_cell = adj
	return best_cell

## True if the given game-grid cell is walkable on the ground layer.
func is_cell_walkable(grid_pos: Vector2i) -> bool:
	return ground.is_grid_walkable(grid_pos)

# ────────────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────────────

func _grid_to_sub(grid_pos: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	return grid_pos * SUB_CELL + Vector2i(SUB_CELL / 2, SUB_CELL / 2)

func _world_to_sub(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		roundi(world_pos.x * SUB_CELL),
		roundi(world_pos.z * SUB_CELL)
	)

func _sub_to_id(sx: int, sy: int) -> int:
	return sy * _legacy_sub_grid_size + sx
