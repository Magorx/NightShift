class_name MonsterPathfinding
extends RefCounted

## Façade over one or more NavLayers. Exposes the monster-facing query API
## (sample_factory_flow, sample_chase_flow).
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
##   GOAL_FACTORY — all tiles adjacent to any building (multi-sector target).
##                  Re-registered when a building is placed or destroyed.
##   GOAL_CHASE   — the player's current tile (single-sector target).
##                  Re-registered on the façade side whenever the player
##                  crosses a tile boundary; otherwise reuses the cached
##                  next-hop + per-sector flow fields across all chasers.
##
## Scaling behaviour:
##   - Sector flow field compute = O(SECTOR_TILES²) ≈ 64 ops
##   - Per-sector fields are cached; N monsters in the same sector → 1 compute.
##   - Sectors without any monsters never generate fields at all.
##   - Building changes mark only their sector + neighbours dirty; lazy
##     rebuild coalesces multiple changes into one update on the next query.

const GOAL_FACTORY := &"factory"
const GOAL_CHASE := &"chase"

# ── Nav layers ──────────────────────────────────────────────────────────────
var ground: GroundNavLayer

# Chase goal cache: only re-register when the player crosses tile boundaries.
var _chase_player_tile: Vector2i = Vector2i(-9999, -9999)

func _init() -> void:
	ground = GroundNavLayer.new()

# ────────────────────────────────────────────────────────────────────────────
# Full rebuild
# ────────────────────────────────────────────────────────────────────────────

func rebuild() -> void:
	ground.rebuild()
	_register_factory_goal()
	# Invalidate chase cache so the next chase sample re-registers
	_chase_player_tile = Vector2i(-9999, -9999)

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
## goal if the player has crossed a tile boundary since the last call.
func sample_chase_flow(from_world: Vector3, player_world: Vector3) -> Vector2:
	_maybe_update_chase_goal(player_world)
	return ground.sample_flow(from_world, GOAL_CHASE)

func _maybe_update_chase_goal(player_world: Vector3) -> void:
	var tile := Vector2i(
		floori(player_world.x + 0.5),
		floori(player_world.z + 0.5)
	)
	if tile == _chase_player_tile and ground.goals.has(GOAL_CHASE):
		return
	_chase_player_tile = tile
	var cells := PackedVector2Array([Vector2(tile.x, tile.y)])
	ground.set_goal(GOAL_CHASE, cells)

func _register_factory_goal() -> void:
	var _perf_t0: int = Time.get_ticks_usec() if MonsterPerf.enabled else 0
	var cells := PackedVector2Array()
	for building in BuildingRegistry.unique_buildings:
		if not is_instance_valid(building):
			continue
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var adj: Vector2i = building.grid_pos + dir
			cells.append(Vector2(adj.x, adj.y))
	ground.set_goal(GOAL_FACTORY, cells)
	if MonsterPerf.enabled:
		MonsterPerf.register_goal_calls += 1
		MonsterPerf.register_goal_usec += Time.get_ticks_usec() - _perf_t0

## True if the given game-grid cell is walkable on the ground layer.
func is_cell_walkable(grid_pos: Vector2i) -> bool:
	return ground.is_grid_walkable(grid_pos)
