class_name NavLayer
extends RefCounted

## Base class for one movement profile (ground / jumping / flying / ...).
## Subclasses override _compute_sub_walkable_raw() to plug in a walkability
## rule — everything else (sectors, portals, hierarchical BFS, flow field
## caching, dirty invalidation) is shared.
##
## Pipeline:
##   1. rebuild()           — build walkable grid, partition into sectors,
##                            detect portals on every shared edge, wire up
##                            sector-adjacency.
##   2. set_goal(key, cells)— register a named multi-cell destination.
##   3. sample_flow(pos, k) — find the monster's sector, lazily compute (or
##                            reuse) its per-sector flow field for the given
##                            goal, and return the gradient direction.
##   4. mark_cell_dirty()   — mark affected sector + neighbours for rebuild;
##                            processed lazily on the next query so many
##                            simultaneous changes coalesce into one update.
##
## Multi-layer scaling:
##   Every NavLayer has its own walkable mask and portal graph, so you can
##   add a JumpingNavLayer (ignores small elevation gaps) or FlyingNavLayer
##   (ignores ground obstacles entirely) by subclassing and overriding
##   _compute_sub_walkable_raw() — no changes here.

const SUB_CELL := 2                 ## sub-cells per game tile (must match MonsterPathfinding)
const SECTOR_SIZE := 8             ## game tiles per sector side
const SECTOR_SUB_SIZE := SECTOR_SIZE * SUB_CELL  ## sub-cells per sector side (= 32)
const UNREACHABLE := 1000000

var layer_id: StringName  ## "ground", "jumping", "flying", ...

# ── Dimensions ──────────────────────────────────────────────────────────────
var map_size: int = 0           ## game tiles per map side
var sub_grid_size: int = 0      ## sub-cells per map side
var sectors_per_axis: int = 0   ## sectors per side
var num_sectors: int = 0

# ── Sector & portal graph ───────────────────────────────────────────────────
var sectors: Array[NavSector] = []
var portals: Array[NavPortal] = []
var portals_by_sector: Array[PackedInt32Array] = []   ## sector idx -> portal ids
var sector_neighbors: Array[PackedInt32Array] = []    ## sector idx -> adjacent sector indices
## Sectors that became dirty and need rebuilding before the next query.
var _dirty_sectors: Dictionary = {}

# ── Goals and flow field cache ──────────────────────────────────────────────
var goals: Dictionary = {}            ## StringName -> NavGoal
## Flow field cache: key = "goal_key:sector_idx" -> FlowField. Public so the
## debug renderer can iterate it; gameplay code should go through sample_flow().
var flow_field_cache: Dictionary = {}

func _init(p_layer_id: StringName) -> void:
	layer_id = p_layer_id

# ────────────────────────────────────────────────────────────────────────────
# Virtual API: subclasses define walkability
# ────────────────────────────────────────────────────────────────────────────

## Called during walkable-grid construction. Return true if the given sub-cell
## is traversable for this layer. Override in subclass.
func _compute_sub_walkable_raw(_gx: int, _gy: int) -> bool:
	return true

## (Optional) Override to apply extra edge-based constraints, e.g. ground
## monsters refusing to step up onto terrain that's elevated above their
## current cell. Called by BFS when relaxing a neighbour; default = always ok.
func _can_traverse_edge(_from_gx: int, _from_gy: int, _to_gx: int, _to_gy: int) -> bool:
	return true

# ────────────────────────────────────────────────────────────────────────────
# Full rebuild
# ────────────────────────────────────────────────────────────────────────────

func rebuild() -> void:
	map_size = MapManager.map_size
	sub_grid_size = map_size * SUB_CELL
	@warning_ignore("integer_division")
	sectors_per_axis = map_size / SECTOR_SIZE
	if sectors_per_axis * SECTOR_SIZE != map_size:
		push_warning("[NAV %s] map_size %d is not divisible by SECTOR_SIZE %d — boundary sectors will be omitted" % [layer_id, map_size, SECTOR_SIZE])
	if sectors_per_axis <= 0:
		sectors_per_axis = 1
	num_sectors = sectors_per_axis * sectors_per_axis

	# Build sectors + local walkable masks
	sectors.clear()
	sectors.resize(num_sectors)
	for sy in sectors_per_axis:
		for sx in sectors_per_axis:
			var idx: int = sy * sectors_per_axis + sx
			var origin := Vector2i(sx * SECTOR_SUB_SIZE, sy * SECTOR_SUB_SIZE)
			sectors[idx] = NavSector.new(idx, sx, sy, origin, SECTOR_SUB_SIZE)
			_rebuild_sector_walkable(idx)

	# Build portal graph + sector adjacency
	_rebuild_portal_graph()

	# Drop caches
	goals.clear()
	flow_field_cache.clear()
	_dirty_sectors.clear()

	print("[NAV %s] rebuilt: %dx%d sectors (%d total), %d portals" % [
		layer_id, sectors_per_axis, sectors_per_axis, num_sectors, portals.size()
	])

func _rebuild_sector_walkable(sector_idx: int) -> void:
	var sector: NavSector = sectors[sector_idx]
	var origin: Vector2i = sector.sub_origin
	var size: int = sector.sub_size
	for ly in size:
		for lx in size:
			var gx: int = origin.x + lx
			var gy: int = origin.y + ly
			var walk: bool = (
				gx >= 0 and gy >= 0 and gx < sub_grid_size and gy < sub_grid_size
				and _compute_sub_walkable_raw(gx, gy)
			)
			sector.walkable[ly * size + lx] = 1 if walk else 0
	sector.dirty = false
	sector.last_walkable_rebuild_msec = Time.get_ticks_msec()

func _rebuild_portal_graph() -> void:
	portals.clear()
	portals_by_sector.clear()
	portals_by_sector.resize(num_sectors)
	for i in num_sectors:
		portals_by_sector[i] = PackedInt32Array()
	sector_neighbors.clear()
	sector_neighbors.resize(num_sectors)
	for i in num_sectors:
		sector_neighbors[i] = PackedInt32Array()

	# Scan right-neighbour and bottom-neighbour boundaries for each sector
	for sy in sectors_per_axis:
		for sx in sectors_per_axis:
			var idx: int = sy * sectors_per_axis + sx
			if sx + 1 < sectors_per_axis:
				_detect_portals_between(idx, idx + 1, Vector2i(1, 0))
			if sy + 1 < sectors_per_axis:
				_detect_portals_between(idx, idx + sectors_per_axis, Vector2i(0, 1))

	# Build sector_neighbors from the portal list
	for portal in portals:
		if portal.sector_a >= 0 and portal.sector_b >= 0:
			if not sector_neighbors[portal.sector_a].has(portal.sector_b):
				sector_neighbors[portal.sector_a].append(portal.sector_b)
			if not sector_neighbors[portal.sector_b].has(portal.sector_a):
				sector_neighbors[portal.sector_b].append(portal.sector_a)

func _detect_portals_between(a_idx: int, b_idx: int, dir: Vector2i) -> void:
	var a: NavSector = sectors[a_idx]
	var b: NavSector = sectors[b_idx]
	var size: int = a.sub_size
	var run_a: Array[int] = []
	var run_b: Array[int] = []

	for t in size:
		var a_local: Vector2i
		var b_local: Vector2i
		if dir.x == 1:
			# A's right edge vs. B's left edge
			a_local = Vector2i(size - 1, t)
			b_local = Vector2i(0, t)
		else:
			# A's bottom edge vs. B's top edge
			a_local = Vector2i(t, size - 1)
			b_local = Vector2i(t, 0)

		var a_idx_local: int = a_local.y * size + a_local.x
		var b_idx_local: int = b_local.y * size + b_local.x
		var both_walk: bool = (a.walkable[a_idx_local] == 1 and b.walkable[b_idx_local] == 1)

		# Also respect layer-specific edge constraints (e.g. ground monsters
		# refusing to traverse a cliff between sectors). Without this check,
		# the sector adjacency graph treats cliff-separated sectors as
		# neighbours and monsters try to path THROUGH the cliff before the
		# physics collider bounces them off.
		var edge_ok: bool = both_walk
		if edge_ok:
			var from_gx: int = a.sub_origin.x + a_local.x
			var from_gy: int = a.sub_origin.y + a_local.y
			var to_gx: int = b.sub_origin.x + b_local.x
			var to_gy: int = b.sub_origin.y + b_local.y
			edge_ok = _can_traverse_edge(from_gx, from_gy, to_gx, to_gy)

		if edge_ok:
			run_a.append(a_idx_local)
			run_b.append(b_idx_local)
		else:
			_flush_portal_run(a_idx, b_idx, run_a, run_b)
			run_a.clear()
			run_b.clear()
	_flush_portal_run(a_idx, b_idx, run_a, run_b)

func _flush_portal_run(a_idx: int, b_idx: int, run_a: Array, run_b: Array) -> void:
	if run_a.is_empty():
		return
	var portal := NavPortal.new()
	portal.sector_a = a_idx
	portal.sector_b = b_idx
	portal.cells_a = PackedInt32Array(run_a)
	portal.cells_b = PackedInt32Array(run_b)
	var mid: int = run_a.size() / 2
	portal.rep_a = run_a[mid]
	portal.rep_b = run_b[mid]
	portals.append(portal)
	var portal_id: int = portals.size() - 1
	portals_by_sector[a_idx].append(portal_id)
	portals_by_sector[b_idx].append(portal_id)

# ────────────────────────────────────────────────────────────────────────────
# Dirty sector handling
# ────────────────────────────────────────────────────────────────────────────

## Mark a world-grid tile as dirty. The sector containing it — and its current
## sector neighbours, since portals across the shared edge may change — will
## be rebuilt on the next query. Many dirty marks coalesce into a single
## rebuild, so mass building changes are cheap.
func mark_cell_dirty(grid_pos: Vector2i) -> void:
	var sector_idx: int = _grid_to_sector(grid_pos)
	if sector_idx < 0:
		return
	_dirty_sectors[sector_idx] = true
	for n in sector_neighbors[sector_idx]:
		_dirty_sectors[n] = true

func _flush_dirty_sectors() -> void:
	if _dirty_sectors.is_empty():
		return
	if MonsterPerf.enabled:
		MonsterPerf.flush_dirty_calls += 1
	for sector_idx in _dirty_sectors.keys():
		_rebuild_sector_walkable(sector_idx)
	# Rebuild the global portal graph — first-pass simplicity; cheap enough
	# (a few thousand edge scans for 64 sectors).
	_rebuild_portal_graph()
	# Invalidate caches since portals may have moved and next-hops too.
	flow_field_cache.clear()
	for goal_val in goals.values():
		(goal_val as NavGoal).invalidate()
	_dirty_sectors.clear()

# ────────────────────────────────────────────────────────────────────────────
# Goals
# ────────────────────────────────────────────────────────────────────────────

## Register or replace a named goal. target_sub_cells are GLOBAL sub-cell
## positions (Vector2i encoded as Vector2 for PackedVector2Array compatibility).
## Passing an empty array clears the goal.
func set_goal(key: StringName, target_sub_cells: PackedVector2Array) -> void:
	if target_sub_cells.is_empty():
		clear_goal(key)
		return

	var goal: NavGoal = goals.get(key, null) as NavGoal
	if goal == null:
		goal = NavGoal.new()
		goal.key = key
		goals[key] = goal

	goal.target_cells_global = PackedInt32Array()
	var seen_sectors: Dictionary = {}
	for p in target_sub_cells:
		var gx: int = int(p.x)
		var gy: int = int(p.y)
		if gx < 0 or gy < 0 or gx >= sub_grid_size or gy >= sub_grid_size:
			continue
		goal.target_cells_global.append(gy * sub_grid_size + gx)
		var sec_idx: int = _sub_to_sector(gx, gy)
		if sec_idx >= 0:
			seen_sectors[sec_idx] = true

	goal.target_sectors = PackedInt32Array(seen_sectors.keys())
	goal.invalidate()
	_invalidate_goal_cache(key)

func clear_goal(key: StringName) -> void:
	goals.erase(key)
	_invalidate_goal_cache(key)

func _invalidate_goal_cache(key: StringName) -> void:
	var prefix: String = String(key) + ":"
	var to_remove: Array[String] = []
	for k in flow_field_cache.keys():
		var s: String = k
		if s.begins_with(prefix):
			to_remove.append(s)
	for k in to_remove:
		flow_field_cache.erase(k)

# ────────────────────────────────────────────────────────────────────────────
# Sector-level BFS: compute nearest-goal next-hops
# ────────────────────────────────────────────────────────────────────────────

func _ensure_sector_next_hop(goal: NavGoal) -> void:
	if not goal.needs_recompute:
		return
	goal.sector_next_hop.resize(num_sectors)
	goal.sector_distance.resize(num_sectors)
	goal.sector_lower_neighbors.resize(num_sectors)
	for i in num_sectors:
		goal.sector_next_hop[i] = -1
		goal.sector_distance[i] = UNREACHABLE
		goal.sector_lower_neighbors[i] = PackedInt32Array()

	# Multi-source BFS from goal sectors outward along the portal graph
	var queue := PackedInt32Array()
	for gs in goal.target_sectors:
		if gs < 0 or gs >= num_sectors:
			continue
		goal.sector_next_hop[gs] = gs  # at goal: next hop is self
		goal.sector_distance[gs] = 0
		queue.append(gs)

	var head: int = 0
	while head < queue.size():
		var s: int = queue[head]
		head += 1
		var s_dist: int = goal.sector_distance[s]
		for n in sector_neighbors[s]:
			if goal.sector_distance[n] == UNREACHABLE:
				goal.sector_distance[n] = s_dist + 1
				# Head toward s — the neighbour that brought us closer to goal
				goal.sector_next_hop[n] = s
				queue.append(n)

	# Second pass: for each sector, record EVERY neighbour whose distance is
	# strictly lower. The per-sector flow field will seed from all of them so
	# monsters can choose the geometrically-nearest portal rather than being
	# funnelled through one arbitrary next-hop sector. This is what makes the
	# flow "vaguely head toward the factory" instead of zig-zagging.
	for s in num_sectors:
		var s_dist: int = goal.sector_distance[s]
		if s_dist == UNREACHABLE:
			continue
		var lower := PackedInt32Array()
		for n in sector_neighbors[s]:
			if goal.sector_distance[n] < s_dist:
				lower.append(n)
		goal.sector_lower_neighbors[s] = lower

	goal.needs_recompute = false

# ────────────────────────────────────────────────────────────────────────────
# Per-sector flow field generation (lazy + cached)
# ────────────────────────────────────────────────────────────────────────────

func _get_or_compute_flow_field(goal: NavGoal, from_sector: int) -> FlowField:
	var cache_key: String = String(goal.key) + ":" + str(from_sector)
	var cached: FlowField = flow_field_cache.get(cache_key, null) as FlowField
	if cached != null:
		return cached
	var _perf_t0: int = Time.get_ticks_usec() if MonsterPerf.enabled else 0

	var local_goal_cells: PackedInt32Array = PackedInt32Array()
	if goal.is_goal_sector(from_sector):
		# The real target cells that fall inside this sector
		var sector: NavSector = sectors[from_sector]
		for gcell in goal.target_cells_global:
			@warning_ignore("integer_division")
			var gy: int = gcell / sub_grid_size
			var gx: int = gcell - gy * sub_grid_size
			var lidx: int = sector.global_to_local_index(gx, gy)
			if lidx >= 0 and sector.walkable[lidx] == 1:
				local_goal_cells.append(lidx)
	else:
		# Intermediate sector: seed from portals leading to ANY strictly-closer
		# neighbour. Using the full set (not just one "primary" next-hop) lets
		# the local BFS gradient naturally pick whichever exit portal is
		# closest from the monster's position, giving flow lines that point
		# "vaguely toward the factory" instead of being funnelled through one
		# arbitrarily-chosen portal.
		var lower_neighbors: PackedInt32Array
		if from_sector >= 0 and from_sector < goal.sector_lower_neighbors.size():
			lower_neighbors = goal.sector_lower_neighbors[from_sector]
		if lower_neighbors.is_empty():
			return null  # unreachable from this sector
		for pid in portals_by_sector[from_sector]:
			var portal: NavPortal = portals[pid]
			var other: int = portal.other_sector(from_sector)
			var is_lower := false
			for ln in lower_neighbors:
				if ln == other:
					is_lower = true
					break
			if not is_lower:
				continue
			for c in portal.cells_for(from_sector):
				local_goal_cells.append(c)

	if local_goal_cells.is_empty():
		return null

	var ff: FlowField = _compute_sector_flow_field(from_sector, local_goal_cells)
	flow_field_cache[cache_key] = ff
	sectors[from_sector].last_flow_compute_msec = Time.get_ticks_msec()
	if MonsterPerf.enabled:
		MonsterPerf.ff_compute_calls += 1
		MonsterPerf.ff_compute_usec += Time.get_ticks_usec() - _perf_t0
	return ff

## 8-directional BFS (Chebyshev distance) within a single sector. Runs over
## ~1024 cells for SECTOR_SUB_SIZE=32 — several orders of magnitude cheaper
## than a whole-map BFS.
func _compute_sector_flow_field(sector_idx: int, local_goal_cells: PackedInt32Array) -> FlowField:
	var sector: NavSector = sectors[sector_idx]
	var sz: int = sector.sub_size
	var ff := FlowField.new(sz)

	var queue := PackedInt32Array()
	for c in local_goal_cells:
		if c < 0 or c >= sector.walkable.size():
			continue
		if sector.walkable[c] == 0:
			continue
		if ff.costs[c] == 0:
			continue  # duplicate seed
		ff.costs[c] = 0
		queue.append(c)

	if queue.is_empty():
		return ff

	var ndx := PackedInt32Array([1, -1, 0, 0, 1, 1, -1, -1])
	var ndy := PackedInt32Array([0, 0, 1, -1, 1, -1, 1, -1])
	var head: int = 0

	while head < queue.size():
		var idx: int = queue[head]
		head += 1
		var current_cost: int = ff.costs[idx]
		@warning_ignore("integer_division")
		var sy: int = idx / sz
		var sx: int = idx - sy * sz
		var next_cost: int = current_cost + 1

		for k in 8:
			var dx: int = ndx[k]
			var dy: int = ndy[k]
			var nx: int = sx + dx
			var ny: int = sy + dy
			if nx < 0 or ny < 0 or nx >= sz or ny >= sz:
				continue
			var nidx: int = ny * sz + nx
			if sector.walkable[nidx] == 0:
				continue
			if ff.costs[nidx] != FlowField.UNREACHABLE:
				continue
			# Optional edge constraint (elevation, etc.) for subclasses
			var from_gx: int = sector.sub_origin.x + sx
			var from_gy: int = sector.sub_origin.y + sy
			var to_gx: int = sector.sub_origin.x + nx
			var to_gy: int = sector.sub_origin.y + ny
			if not _can_traverse_edge(from_gx, from_gy, to_gx, to_gy):
				continue
			ff.costs[nidx] = next_cost
			# Direction at (nx, ny) points back toward parent (sx, sy),
			# i.e. the next step along the gradient toward the goal.
			ff.directions[nidx] = Vector2(-dx, -dy).normalized()
			queue.append(nidx)

	return ff

# ────────────────────────────────────────────────────────────────────────────
# Public query API
# ────────────────────────────────────────────────────────────────────────────

## Sample the flow field at a world position for the given goal. Returns a
## normalised 2D direction (x, z), or Vector2.ZERO if no path exists.
func sample_flow(world_pos: Vector3, goal_key: StringName) -> Vector2:
	_flush_dirty_sectors()
	var goal: NavGoal = goals.get(goal_key, null) as NavGoal
	if goal == null or goal.target_cells_global.is_empty():
		return Vector2.ZERO
	_ensure_sector_next_hop(goal)

	var sub: Vector2i = _world_to_sub(world_pos)
	if sub.x < 0 or sub.y < 0 or sub.x >= sub_grid_size or sub.y >= sub_grid_size:
		return Vector2.ZERO
	var sector_idx: int = _sub_to_sector(sub.x, sub.y)
	if sector_idx < 0:
		return Vector2.ZERO

	var ff: FlowField = _get_or_compute_flow_field(goal, sector_idx)
	if ff == null:
		return Vector2.ZERO

	var sector: NavSector = sectors[sector_idx]
	var lx: int = sub.x - sector.sub_origin.x
	var ly: int = sub.y - sector.sub_origin.y
	return ff.sample_local(lx, ly)

## True if the given GLOBAL sub-cell is walkable in this layer.
func is_sub_walkable(gx: int, gy: int) -> bool:
	if gx < 0 or gy < 0 or gx >= sub_grid_size or gy >= sub_grid_size:
		return false
	var sec_idx: int = _sub_to_sector(gx, gy)
	if sec_idx < 0:
		return false
	var sector: NavSector = sectors[sec_idx]
	var lidx: int = sector.global_to_local_index(gx, gy)
	if lidx < 0:
		return false
	return sector.walkable[lidx] == 1

## True if the given game-grid tile is walkable (any of its sub-cells).
func is_grid_walkable(grid_pos: Vector2i) -> bool:
	var sub: Vector2i = _grid_to_sub(grid_pos)
	return is_sub_walkable(sub.x, sub.y)

# ────────────────────────────────────────────────────────────────────────────
# Coordinate helpers
# ────────────────────────────────────────────────────────────────────────────

func _world_to_sub(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		roundi(world_pos.x * SUB_CELL),
		roundi(world_pos.z * SUB_CELL)
	)

func _grid_to_sub(grid_pos: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	return grid_pos * SUB_CELL + Vector2i(SUB_CELL / 2, SUB_CELL / 2)

func _sub_to_sector(gx: int, gy: int) -> int:
	@warning_ignore("integer_division")
	var sx: int = gx / SECTOR_SUB_SIZE
	@warning_ignore("integer_division")
	var sy: int = gy / SECTOR_SUB_SIZE
	if sx < 0 or sy < 0 or sx >= sectors_per_axis or sy >= sectors_per_axis:
		return -1
	return sy * sectors_per_axis + sx

func _grid_to_sector(grid_pos: Vector2i) -> int:
	var sub: Vector2i = _grid_to_sub(grid_pos)
	return _sub_to_sector(sub.x, sub.y)
