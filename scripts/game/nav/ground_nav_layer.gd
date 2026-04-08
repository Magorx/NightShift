class_name GroundNavLayer
extends RefCounted

## Hierarchical flow-field navigation for ground monsters.
##
## ── Pipeline ────────────────────────────────────────────────────────────────
## rebuild()        →  walkable_mask
##                  →  edge_mask     (bakes elevation + L-rule corner check)
##                  →  sectors
##                  →  portals       (directed, asymmetric — descent-only
##                                    cliff edges become one-way portals)
##                  →  sector adjacency
## set_goal(k, ts)  →  register NavGoal, mark needs_recompute
## sample_flow(w, k)→  flush dirty sectors
##                  →  ensure goal.sector_distance (high-level BFS)
##                  →  lazy-compute per-sector local Dijkstra (8-connected,
##                     diagonals cost sqrt(2), edge_mask gated)
##                  →  bilinear-blend 4 tile directions around the query
##                     position, with each contribution gated by the query
##                     tile's edge_mask toward the sample tile. This is what
##                     stops diagonal leaks across impassable corners (the
##                     `.#/#.` elevation case).
##
## ── Key invariant ──────────────────────────────────────────────────────────
## Every "can the agent walk from A to B" check in the hot path is a single
## bitmask read on `edge_mask[A]`. The expensive work (walkable checks,
## elevation delta, L-rule corner check) happens ONCE per rebuild and is
## baked into the mask. Diagonal BFS relaxations and sampler edge-gates all
## resolve to the same mask lookup.
##
## ── The L-rule (diagonal corner prevention) ────────────────────────────────
## A diagonal step N → D is allowed iff BOTH L-shaped detours
## (N → sideA → D and N → sideB → D) are fully edge-traversable. This means:
##   src has cardinal edge to sideA AND to sideB
##   sideA has cardinal edge to D
##   sideB has cardinal edge to D
## Computed in two passes in `_rebuild_edge_mask`: cardinal bits first, then
## diagonals using already-resolved cardinal bits. The `.#/#.` elevation case
## resolves to "no cardinal bits → no diagonal bit → no leak."

# ── Tuning ──────────────────────────────────────────────────────────────────
const SECTOR_TILES := 8
const STEP_HEIGHT := 0.0  ## Ground monsters: no step-up, descent always allowed.

# Integer costs so Dijkstra stays on PackedInt32Array (no float compares in
# the inner loop). 10 / 14 ≈ 1 : sqrt(2).
const COST_CARDINAL := 10
const COST_DIAGONAL := 14
const UNREACHED := 0x7fffffff

# Direction table — 8 directions, same order as edge_mask bits.
# 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
const DIR_DX: Array[int] = [1, 1, 0, -1, -1, -1, 0, 1]
const DIR_DY: Array[int] = [0, 1, 1,  1,  0, -1, -1, -1]
const DIR_COST: Array[int] = [10, 14, 10, 14, 10, 14, 10, 14]
const DIR_IS_DIAG: Array[bool] = [false, true, false, true, false, true, false, true]

const BIT_E  := 1
const BIT_SE := 2
const BIT_S  := 4
const BIT_SW := 8
const BIT_W  := 16
const BIT_NW := 32
const BIT_N  := 64
const BIT_NE := 128

# ── Inner types ─────────────────────────────────────────────────────────────

## Per-sector metadata. Walkable state lives in the global `walkable_mask`;
## this class just holds identity + flash timestamps for the debug renderer.
class SectorData extends RefCounted:
	var idx: int = 0        ## linear sector index (sy * sector_count + sx)
	var sx: int = 0
	var sy: int = 0
	var x0: int = 0         ## tile AABB min x (inclusive)
	var y0: int = 0         ## tile AABB min y (inclusive)
	var x1: int = 0         ## tile AABB max x (exclusive)
	var y1: int = 0         ## tile AABB max y (exclusive)
	var last_walkable_rebuild_msec: int = 0
	var last_flow_compute_msec: int = 0

## A directed portal: a contiguous run of (a_tile, b_tile) pairs along the
## shared edge between two sectors, where each tile is walkable on its own
## side. Directions are independent (`a_to_b` / `b_to_a`) because elevation
## descent makes cliff edges one-way.
class Portal:
	extends RefCounted
	var sector_a: int = -1
	var sector_b: int = -1
	## (a_tile, b_tile) pairs stored as two parallel flat tile-index arrays.
	## tile_pairs_a[i] is in sector_a, tile_pairs_b[i] is in sector_b. They
	## are always cardinal neighbours on the shared edge.
	var tile_pairs_a: PackedInt32Array = PackedInt32Array()
	var tile_pairs_b: PackedInt32Array = PackedInt32Array()
	var a_to_b: bool = false  ## at least one pair has edge_mask a→b set
	var b_to_a: bool = false  ## at least one pair has edge_mask b→a set

## A named destination. Holds target tiles, the high-level per-sector distance
## table (computed lazily on first sample after a rebuild), and the cache of
## per-sector local flow fields (populated lazily).
class NavGoal:
	extends RefCounted
	var key: StringName
	## Flat target tile indices (`y * map_size + x`).
	var target_tiles: PackedInt32Array = PackedInt32Array()
	## Per-sector BFS cost from any target sector, in portal-hop units.
	## UNREACHED for unreachable sectors. Size == sector_count².
	var sector_distance: PackedInt32Array = PackedInt32Array()
	## Which sectors contain at least one target tile.
	var target_sectors: PackedInt32Array = PackedInt32Array()
	var needs_distance_recompute: bool = true
	## sector_idx → per-sector FlowField
	var flow_cache: Dictionary = {}

## Per-sector local flow field. Contains directions at every tile inside the
## sector (indexed by local `(ly * SECTOR_TILES + lx)`). Directions are the
## steepest-descent unit vectors from each tile's Dijkstra integration cost.
class FlowField:
	extends RefCounted
	## Two parallel packed arrays of length SECTOR_TILES * SECTOR_TILES.
	var dir_x: PackedFloat32Array = PackedFloat32Array()
	var dir_y: PackedFloat32Array = PackedFloat32Array()
	## Integration field (Dijkstra cost from seed). Used for steepest-descent
	## derivation, kept around for the debug renderer to display costs.
	var integration: PackedInt32Array = PackedInt32Array()


# ── State ───────────────────────────────────────────────────────────────────

## Optional map data provider for debug/tooling. When set, replaces MapManager
## and BuildingRegistry calls in all tile queries. Must implement:
##   map_size: int  |  is_walkable(x, y) -> bool  |  get_height(x, y) -> float
var map_provider: Object = null

var map_size: int = 0
var sector_count: int = 0  ## per axis

## 1 byte per tile. 1 = walkable (not wall, not building). 0 = blocked.
var walkable_mask: PackedByteArray = PackedByteArray()

## 1 byte per tile. 8 bits: bit N = "agent at this tile can step in direction N".
## Baked from walkable_mask + terrain heights + L-rule corner check. This is
## the ONLY place elevation/corner logic runs — every subsequent query reads
## the mask.
var edge_mask: PackedByteArray = PackedByteArray()

var sectors: Array = []  ## Array[SectorData]
var portals: Array = []  ## Array[Portal]
## sector_idx → PackedInt32Array of portal indices touching it.
## NOTE: typed `Array[PackedInt32Array]` so `arr[i].append(x)` actually
## mutates the stored value. An untyped `Array` returns a value-type copy
## from subscript access, and appends on that copy get silently dropped.
var portal_index_per_sector: Array[PackedInt32Array] = []

var goals: Dictionary = {}  ## StringName → NavGoal

## Set of sector indices awaiting rebuild; flushed at the start of sample_flow.
var _dirty_sectors: Dictionary = {}

# ────────────────────────────────────────────────────────────────────────────
# Public API
# ────────────────────────────────────────────────────────────────────────────

## Full rebuild from the current MapManager state. Called at the start of
## every fight phase. Throws nothing; if MapManager is not ready the layer
## becomes empty but still safely queryable (sample_flow returns ZERO).
func rebuild() -> void:
	map_size = map_provider.map_size if map_provider else MapManager.map_size
	if map_size <= 0:
		walkable_mask = PackedByteArray()
		edge_mask = PackedByteArray()
		sectors.clear()
		portals.clear()
		portal_index_per_sector.clear()
		goals.clear()
		_dirty_sectors.clear()
		return

	_rebuild_walkable_mask_full()
	_rebuild_edge_mask_full()
	_rebuild_sectors()
	_rebuild_portals_full()

	# Any existing goals need their high-level distance tables recomputed
	# against the fresh sector graph, and their per-sector flow caches dropped.
	for g: NavGoal in goals.values():
		g.needs_distance_recompute = true
		g.flow_cache.clear()
	_dirty_sectors.clear()


## Invalidate the sector containing `grid_pos` (and any portal runs along its
## boundary). Safe to call many times per frame — the actual rebuild is
## coalesced and deferred to the next query.
func mark_cell_dirty(grid_pos: Vector2i) -> void:
	if map_size <= 0:
		return
	if grid_pos.x < 0 or grid_pos.x >= map_size or grid_pos.y < 0 or grid_pos.y >= map_size:
		return
	var s := _sector_index_of_tile(grid_pos.x, grid_pos.y)
	_dirty_sectors[s] = true
	# Neighbour sectors must also be touched because the tile's edge_mask
	# contributes to cross-sector portal runs along the shared edge, and
	# the diagonal L-rule reads edge bits from neighbour tiles which may
	# straddle the sector boundary.
	var sx: int = s % sector_count
	@warning_ignore("integer_division")
	var sy: int = s / sector_count
	var local_x := grid_pos.x - sx * SECTOR_TILES
	var local_y := grid_pos.y - sy * SECTOR_TILES
	if local_x <= 1 and sx > 0:
		_dirty_sectors[s - 1] = true
	if local_x >= SECTOR_TILES - 2 and sx < sector_count - 1:
		_dirty_sectors[s + 1] = true
	if local_y <= 1 and sy > 0:
		_dirty_sectors[s - sector_count] = true
	if local_y >= SECTOR_TILES - 2 and sy < sector_count - 1:
		_dirty_sectors[s + sector_count] = true


## Register or replace a named multi-tile destination. `target_tiles` is a
## flat list of `Vector2(gx, gy)` tile coordinates. Passing an empty array
## clears the goal. This invalidates any cached per-sector flow fields for
## the goal.
func set_goal(key: StringName, target_tiles: PackedVector2Array) -> void:
	if target_tiles.is_empty():
		goals.erase(key)
		return
	var g: NavGoal = goals.get(key)
	if g == null:
		g = NavGoal.new()
		g.key = key
		goals[key] = g
	g.target_tiles.clear()
	var tgt_sectors := {}
	for v in target_tiles:
		var tx := int(v.x)
		var ty := int(v.y)
		if tx < 0 or ty < 0 or tx >= map_size or ty >= map_size:
			continue
		if walkable_mask[ty * map_size + tx] == 0:
			continue
		g.target_tiles.append(ty * map_size + tx)
		tgt_sectors[_sector_index_of_tile(tx, ty)] = true
	g.target_sectors = PackedInt32Array(tgt_sectors.keys())
	g.needs_distance_recompute = true
	g.flow_cache.clear()


## Query the flow direction at a continuous world position for the given
## goal. Returns a `Vector2(x, z)` unit direction to steer toward, or
## `Vector2.ZERO` when the goal is unreachable / unregistered / empty —
## caller should fall back to direct movement.
##
## Uses edge-gated bilinear sampling of the four nearest tile directions.
## The query tile (the tile the monster is standing in) is always the
## anchor; neighbouring sample tiles are only included in the blend if the
## query tile has a direct edge_mask bit toward them. This is what prevents
## diagonal leaks across impassable corners.
func sample_flow(world_pos: Vector3, goal_key: StringName) -> Vector2:
	if map_size <= 0:
		return Vector2.ZERO
	var g: NavGoal = goals.get(goal_key)
	if g == null or g.target_tiles.is_empty():
		return Vector2.ZERO

	_flush_dirty_sectors()
	_ensure_goal_sector_distances(g)

	var wx := world_pos.x
	var wy := world_pos.z
	var agent_h := world_pos.y

	# Bilinear base: the unit square whose corners are (bx,by), (bx+1,by),
	# (bx,by+1), (bx+1,by+1). Since tile centers are at integer world coords
	# and TILE_SIZE=1, this square is the Voronoi overlap of the 4 nearest
	# tile centers around the monster. The monster is always inside it.
	var bx := floori(wx)
	var by := floori(wy)
	var fx := wx - float(bx)
	var fy := wy - float(by)

	# Query-tile selection — the tile the monster is physically STANDING on.
	#
	# The naive rule (pick the geometrically closest tile) breaks at cliff
	# edges: a ground-level monster at world pos (x=3.9, y=0, z=4) is
	# geometrically inside tile (4, 4)'s Voronoi cell, but if that tile is
	# an elevated plateau the monster can't actually be up there. Using
	# tile (4, 4) as the query makes us read its flow / edge mask, which
	# was computed for an agent sitting on top of the cliff — nonsense
	# for a monster at y=0.
	#
	# Correct rule: among the (up to 4) walkable bilinear-neighbour tiles,
	# pick the one whose stored terrain height matches `agent_h` best.
	# Ties broken by bilinear weight (so we still prefer the tile that
	# has the most overlap with the monster's footprint). If NO candidate
	# matches the agent's elevation (within HEIGHT_MATCH_TOLERANCE), the
	# query position is physically impossible — return ZERO so the caller
	# falls back to direct movement instead of reading bridge / cliff flow
	# that would push the monster into a wall.
	const HEIGHT_MATCH_TOLERANCE := 0.51  # half a step on the 0.5-grid terrain
	var qx := -1
	var qy := -1
	var q_best_dh := INF
	var q_best_w := -1.0
	for j in 2:
		for i in 2:
			var cx := bx + i
			var cy := by + j
			if cx < 0 or cy < 0 or cx >= map_size or cy >= map_size:
				continue
			if walkable_mask[cy * map_size + cx] == 0:
				continue
			var ch: float = _get_height(cx, cy)
			var dh: float = absf(ch - agent_h)
			var cw := (1.0 - fx if i == 0 else fx) * (1.0 - fy if j == 0 else fy)
			# Strict height preference, then maximum bilinear weight.
			if dh < q_best_dh - 0.0001 or (dh <= q_best_dh + 0.0001 and cw > q_best_w):
				q_best_dh = dh
				q_best_w = cw
				qx = cx
				qy = cy
	if qx < 0 or q_best_dh > HEIGHT_MATCH_TOLERANCE:
		# Either no walkable candidate, or the agent's y is too far from
		# every neighbour's terrain height (e.g. monster physically inside
		# a cliff wall, or sitting in mid-air). Caller falls back.
		return Vector2.ZERO
	var q_tile := qy * map_size + qx
	var q_edges: int = edge_mask[q_tile]
	var q_flow := _sample_tile_flow(g, qx, qy)

	var blend_x := 0.0
	var blend_y := 0.0
	var wsum := 0.0

	for j in 2:
		for i in 2:
			var sx := bx + i
			var sy := by + j
			if sx < 0 or sy < 0 or sx >= map_size or sy >= map_size:
				continue
			var w := (1.0 - fx if i == 0 else fx) * (1.0 - fy if j == 0 else fy)
			if w <= 0.0:
				continue
			# Edge-gate every neighbour contribution against the query tile.
			# The query tile itself is always allowed.
			if sx != qx or sy != qy:
				var dx := sx - qx
				var dy := sy - qy
				var dir_idx := _delta_to_dir(dx, dy)
				if dir_idx < 0:
					continue
				if (q_edges & (1 << dir_idx)) == 0:
					continue
			var flow := _sample_tile_flow(g, sx, sy)
			if flow.length_squared() < 0.0001:
				continue  # drop zero-flow contributions from the blend
			blend_x += flow.x * w
			blend_y += flow.y * w
			wsum += w

	if wsum < 0.0001:
		# No contributions at all — nothing reachable through any sample
		# tile. Bail and let the caller handle it.
		return Vector2.ZERO
	var out := Vector2(blend_x / wsum, blend_y / wsum)
	if out.length_squared() < 0.0001:
		# Bifurcation: two adjacent flows pointed in opposite directions
		# (a flow-field "watershed" line — common when two equally-good
		# routes diverge around an obstacle). The bilinear blend cancels
		# to zero at the perfect midline, which would freeze the monster
		# right at the seam. Fall back to the query tile's raw direction
		# so the monster picks ONE side and starts moving; whichever side
		# it drifts to via physics jitter then becomes self-reinforcing.
		if q_flow.length_squared() > 0.0001:
			return q_flow.normalized()
		return Vector2.ZERO
	return out.normalized()


## True iff the given tile is not blocked on the ground profile. Used by the
## legacy `is_cell_walkable()` helper on `MonsterPathfinding`.
func is_grid_walkable(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.y < 0 or grid_pos.x >= map_size or grid_pos.y >= map_size:
		return false
	return walkable_mask[grid_pos.y * map_size + grid_pos.x] != 0


# ────────────────────────────────────────────────────────────────────────────
# Rebuild: walkable mask
# ────────────────────────────────────────────────────────────────────────────

## Rebuilds the whole walkable_mask from MapManager.walls + BuildingRegistry.
## One pass over the map, O(tiles).
func _rebuild_walkable_mask_full() -> void:
	walkable_mask.resize(map_size * map_size)
	for y in map_size:
		var row := y * map_size
		for x in map_size:
			walkable_mask[row + x] = 1 if _compute_tile_walkable(x, y) else 0


func _compute_tile_walkable(x: int, y: int) -> bool:
	if map_provider:
		return map_provider.is_walkable(x, y)
	var v := Vector2i(x, y)
	if MapManager.walls.has(v):
		return false
	if BuildingRegistry.get_building_at(v) != null:
		return false
	return true


func _get_height(x: int, y: int) -> float:
	if map_provider:
		return map_provider.get_height(x, y)
	return MapManager.get_terrain_height(Vector2i(x, y))


# ────────────────────────────────────────────────────────────────────────────
# Rebuild: edge mask (the load-bearing bit)
# ────────────────────────────────────────────────────────────────────────────

## Two-pass edge-mask rebuild for the entire map.
##   Pass 1: cardinal bits — walkable neighbour + elevation delta ≤ STEP_HEIGHT.
##   Pass 2: diagonal bits — L-rule using cardinal bits from pass 1.
## Asymmetric by design: descent is always allowed, ascent never is.
func _rebuild_edge_mask_full() -> void:
	edge_mask.resize(map_size * map_size)
	# Pass 1: cardinal bits
	for y in map_size:
		var row := y * map_size
		for x in map_size:
			var idx := row + x
			if walkable_mask[idx] == 0:
				edge_mask[idx] = 0
				continue
			edge_mask[idx] = _compute_cardinal_bits(x, y)
	# Pass 2: diagonal bits (reads cardinal bits from neighbouring tiles)
	for y in map_size:
		var row := y * map_size
		for x in map_size:
			var idx := row + x
			if walkable_mask[idx] == 0:
				continue
			edge_mask[idx] |= _compute_diagonal_bits(x, y, edge_mask[idx])


func _compute_cardinal_bits(x: int, y: int) -> int:
	var h: float = _get_height(x, y)
	var bits := 0
	# E
	if x + 1 < map_size and walkable_mask[y * map_size + x + 1] != 0:
		if _get_height(x + 1, y) - h <= STEP_HEIGHT:
			bits |= BIT_E
	# S
	if y + 1 < map_size and walkable_mask[(y + 1) * map_size + x] != 0:
		if _get_height(x, y + 1) - h <= STEP_HEIGHT:
			bits |= BIT_S
	# W
	if x - 1 >= 0 and walkable_mask[y * map_size + x - 1] != 0:
		if _get_height(x - 1, y) - h <= STEP_HEIGHT:
			bits |= BIT_W
	# N
	if y - 1 >= 0 and walkable_mask[(y - 1) * map_size + x] != 0:
		if _get_height(x, y - 1) - h <= STEP_HEIGHT:
			bits |= BIT_N
	return bits


## Given cardinal bits already set on (x, y), compute the diagonal bits using
## the L-rule: a diagonal step N → D is allowed iff BOTH cardinal sides are
## walkable and each side can in turn step to D.
func _compute_diagonal_bits(x: int, y: int, cardinal: int) -> int:
	var bits := 0
	# SE: sides E(0) + S(2). Need E & S on self, plus S bit on east-tile
	# and E bit on south-tile.
	if (cardinal & BIT_E) != 0 and (cardinal & BIT_S) != 0:
		var east_bits: int = edge_mask[y * map_size + (x + 1)]
		var south_bits: int = edge_mask[(y + 1) * map_size + x]
		if (east_bits & BIT_S) != 0 and (south_bits & BIT_E) != 0:
			# Height gate is implicit: both L-legs already satisfied it.
			# Still check the diagonal itself for completeness (cheap).
			if _diag_walkable_and_height(x, y, x + 1, y + 1):
				bits |= BIT_SE
	# SW: sides S(2) + W(4).
	if (cardinal & BIT_S) != 0 and (cardinal & BIT_W) != 0:
		var south_bits2: int = edge_mask[(y + 1) * map_size + x]
		var west_bits: int = edge_mask[y * map_size + (x - 1)]
		if (south_bits2 & BIT_W) != 0 and (west_bits & BIT_S) != 0:
			if _diag_walkable_and_height(x, y, x - 1, y + 1):
				bits |= BIT_SW
	# NW: sides W(4) + N(6).
	if (cardinal & BIT_W) != 0 and (cardinal & BIT_N) != 0:
		var west_bits2: int = edge_mask[y * map_size + (x - 1)]
		var north_bits: int = edge_mask[(y - 1) * map_size + x]
		if (west_bits2 & BIT_N) != 0 and (north_bits & BIT_W) != 0:
			if _diag_walkable_and_height(x, y, x - 1, y - 1):
				bits |= BIT_NW
	# NE: sides N(6) + E(0).
	if (cardinal & BIT_N) != 0 and (cardinal & BIT_E) != 0:
		var north_bits2: int = edge_mask[(y - 1) * map_size + x]
		var east_bits2: int = edge_mask[y * map_size + (x + 1)]
		if (north_bits2 & BIT_E) != 0 and (east_bits2 & BIT_N) != 0:
			if _diag_walkable_and_height(x, y, x + 1, y - 1):
				bits |= BIT_NE
	return bits


## Check walkability and the STEP_HEIGHT delta for the diagonal tile itself.
## The L-rule's cardinal legs already implicitly guarantee elevation is OK via
## intermediate tiles, but we double-check the diagonal endpoint against the
## source to avoid pathological ripple cases.
func _diag_walkable_and_height(fx: int, fy: int, tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= map_size or ty >= map_size:
		return false
	if walkable_mask[ty * map_size + tx] == 0:
		return false
	var h_from: float = _get_height(fx, fy)
	var h_to: float = _get_height(tx, ty)
	return (h_to - h_from) <= STEP_HEIGHT


# ────────────────────────────────────────────────────────────────────────────
# Rebuild: sectors
# ────────────────────────────────────────────────────────────────────────────

func _rebuild_sectors() -> void:
	@warning_ignore("integer_division")
	var sc: int = (map_size + SECTOR_TILES - 1) / SECTOR_TILES
	sector_count = sc
	sectors.clear()
	sectors.resize(sector_count * sector_count)
	for sy in sector_count:
		for sx in sector_count:
			var s := SectorData.new()
			s.idx = sy * sector_count + sx
			s.sx = sx
			s.sy = sy
			s.x0 = sx * SECTOR_TILES
			s.y0 = sy * SECTOR_TILES
			s.x1 = mini((sx + 1) * SECTOR_TILES, map_size)
			s.y1 = mini((sy + 1) * SECTOR_TILES, map_size)
			sectors[s.idx] = s


func _sector_index_of_tile(x: int, y: int) -> int:
	@warning_ignore("integer_division")
	var sx: int = x / SECTOR_TILES
	@warning_ignore("integer_division")
	var sy: int = y / SECTOR_TILES
	return sy * sector_count + sx


# ────────────────────────────────────────────────────────────────────────────
# Rebuild: portals
# ────────────────────────────────────────────────────────────────────────────

## Scans every shared sector edge, finds contiguous runs of tile pairs where
## at least one direction is edge-traversable, and records each run as a
## Portal. Directions (a_to_b / b_to_a) are derived from the edge_mask.
func _rebuild_portals_full() -> void:
	portals.clear()
	portal_index_per_sector.clear()
	portal_index_per_sector.resize(sector_count * sector_count)
	for i in portal_index_per_sector.size():
		portal_index_per_sector[i] = PackedInt32Array()

	# Horizontal edges (shared between sector (sx, sy) and (sx+1, sy))
	for sy in sector_count:
		for sx in sector_count - 1:
			_detect_portal_run_vertical_edge(sx, sy)
	# Vertical edges (shared between sector (sx, sy) and (sx, sy+1))
	for sy in sector_count - 1:
		for sx in sector_count:
			_detect_portal_run_horizontal_edge(sx, sy)


## Edge between sector (sx, sy) (a) and sector (sx+1, sy) (b), scanned top to
## bottom. "Vertical edge" because the shared line is vertical in grid space.
func _detect_portal_run_vertical_edge(sx: int, sy: int) -> void:
	var a_sector_idx := sy * sector_count + sx
	var b_sector_idx := sy * sector_count + (sx + 1)
	var a_col := (sx + 1) * SECTOR_TILES - 1
	var b_col := (sx + 1) * SECTOR_TILES
	if b_col >= map_size:
		return
	var y0 := sy * SECTOR_TILES
	var y1 := mini((sy + 1) * SECTOR_TILES, map_size)

	var run_active := false
	var run_start_y := 0
	for y in range(y0, y1):
		var a_tile := y * map_size + a_col
		var b_tile := y * map_size + b_col
		var pair_ok := walkable_mask[a_tile] != 0 and walkable_mask[b_tile] != 0 \
			and ((edge_mask[a_tile] & BIT_E) != 0 or (edge_mask[b_tile] & BIT_W) != 0)
		if pair_ok:
			if not run_active:
				run_active = true
				run_start_y = y
		else:
			if run_active:
				_finalize_vertical_run(a_sector_idx, b_sector_idx, a_col, b_col, run_start_y, y - 1)
				run_active = false
	if run_active:
		_finalize_vertical_run(a_sector_idx, b_sector_idx, a_col, b_col, run_start_y, y1 - 1)


func _finalize_vertical_run(a_sector_idx: int, b_sector_idx: int, a_col: int, b_col: int, ry0: int, ry1: int) -> void:
	var p := Portal.new()
	p.sector_a = a_sector_idx
	p.sector_b = b_sector_idx
	var a2b := false
	var b2a := false
	for y in range(ry0, ry1 + 1):
		var a_tile := y * map_size + a_col
		var b_tile := y * map_size + b_col
		p.tile_pairs_a.append(a_tile)
		p.tile_pairs_b.append(b_tile)
		if (edge_mask[a_tile] & BIT_E) != 0:
			a2b = true
		if (edge_mask[b_tile] & BIT_W) != 0:
			b2a = true
	p.a_to_b = a2b
	p.b_to_a = b2a
	if not a2b and not b2a:
		return  # both sides blocked — don't register
	var pi := portals.size()
	portals.append(p)
	_register_portal_in_sector(a_sector_idx, pi)
	_register_portal_in_sector(b_sector_idx, pi)


## Edge between sector (sx, sy) (a) and sector (sx, sy+1) (b), scanned left to
## right. "Horizontal edge" because the shared line is horizontal in grid space.
func _detect_portal_run_horizontal_edge(sx: int, sy: int) -> void:
	var a_sector_idx := sy * sector_count + sx
	var b_sector_idx := (sy + 1) * sector_count + sx
	var a_row := (sy + 1) * SECTOR_TILES - 1
	var b_row := (sy + 1) * SECTOR_TILES
	if b_row >= map_size:
		return
	var x0 := sx * SECTOR_TILES
	var x1 := mini((sx + 1) * SECTOR_TILES, map_size)

	var run_active := false
	var run_start_x := 0
	for x in range(x0, x1):
		var a_tile := a_row * map_size + x
		var b_tile := b_row * map_size + x
		var pair_ok := walkable_mask[a_tile] != 0 and walkable_mask[b_tile] != 0 \
			and ((edge_mask[a_tile] & BIT_S) != 0 or (edge_mask[b_tile] & BIT_N) != 0)
		if pair_ok:
			if not run_active:
				run_active = true
				run_start_x = x
		else:
			if run_active:
				_finalize_horizontal_run(a_sector_idx, b_sector_idx, a_row, b_row, run_start_x, x - 1)
				run_active = false
	if run_active:
		_finalize_horizontal_run(a_sector_idx, b_sector_idx, a_row, b_row, run_start_x, x1 - 1)


func _finalize_horizontal_run(a_sector_idx: int, b_sector_idx: int, a_row: int, b_row: int, rx0: int, rx1: int) -> void:
	var p := Portal.new()
	p.sector_a = a_sector_idx
	p.sector_b = b_sector_idx
	var a2b := false
	var b2a := false
	for x in range(rx0, rx1 + 1):
		var a_tile := a_row * map_size + x
		var b_tile := b_row * map_size + x
		p.tile_pairs_a.append(a_tile)
		p.tile_pairs_b.append(b_tile)
		if (edge_mask[a_tile] & BIT_S) != 0:
			a2b = true
		if (edge_mask[b_tile] & BIT_N) != 0:
			b2a = true
	p.a_to_b = a2b
	p.b_to_a = b2a
	if not a2b and not b2a:
		return
	var pi := portals.size()
	portals.append(p)
	_register_portal_in_sector(a_sector_idx, pi)
	_register_portal_in_sector(b_sector_idx, pi)


## Append a portal index to `portal_index_per_sector[sector_idx]`. Must use a
## local + store-back because `PackedInt32Array` values copy on Array access;
## doing `(portal_index_per_sector[i] as PackedInt32Array).append(x)` mutates
## a throwaway copy and silently drops the write (the typed
## `Array[PackedInt32Array]` declaration guards against the same footgun).
func _register_portal_in_sector(sector_idx: int, portal_idx: int) -> void:
	var arr: PackedInt32Array = portal_index_per_sector[sector_idx]
	arr.append(portal_idx)
	portal_index_per_sector[sector_idx] = arr


# ────────────────────────────────────────────────────────────────────────────
# Dirty flush: partial rebuild of affected sectors
# ────────────────────────────────────────────────────────────────────────────

func _flush_dirty_sectors() -> void:
	if _dirty_sectors.is_empty():
		return
	if MonsterPerf.enabled:
		MonsterPerf.flush_dirty_calls += 1
	var now_msec := Time.get_ticks_msec()

	# Rebuild walkable_mask + edge_mask for every dirty sector. The edge_mask
	# rebuild reads neighbour tiles so we also widen by 1 tile into adjacent
	# sectors — but since we marked neighbours dirty on the way in, those
	# sectors are already in the set, so their interior is covered.
	for s_idx_k in _dirty_sectors.keys():
		var s_idx: int = s_idx_k
		var s: SectorData = sectors[s_idx]
		s.last_walkable_rebuild_msec = now_msec
		for y in range(s.y0, s.y1):
			var row := y * map_size
			for x in range(s.x0, s.x1):
				walkable_mask[row + x] = 1 if _compute_tile_walkable(x, y) else 0
	# Cardinal bits (pass 1) for dirty sectors.
	for s_idx_k in _dirty_sectors.keys():
		var s_idx2: int = s_idx_k
		var s2: SectorData = sectors[s_idx2]
		for y in range(s2.y0, s2.y1):
			var row2 := y * map_size
			for x in range(s2.x0, s2.x1):
				var idx := row2 + x
				if walkable_mask[idx] == 0:
					edge_mask[idx] = 0
				else:
					edge_mask[idx] = _compute_cardinal_bits(x, y)
	# Diagonal bits (pass 2) for dirty sectors.
	for s_idx_k in _dirty_sectors.keys():
		var s_idx3: int = s_idx_k
		var s3: SectorData = sectors[s_idx3]
		for y in range(s3.y0, s3.y1):
			var row3 := y * map_size
			for x in range(s3.x0, s3.x1):
				var idx2 := row3 + x
				if walkable_mask[idx2] == 0:
					continue
				edge_mask[idx2] |= _compute_diagonal_bits(x, y, edge_mask[idx2])

	# Rebuild portal runs that touched these sectors. Simpler path: rebuild
	# everything. Portal detection is cheap (one linear scan per sector edge,
	# ~16 scans on a 128 map) and we only pay it when buildings change.
	_rebuild_portals_full()

	# Drop stale flow caches for dirty sectors (and their neighbours, because
	# neighbour sectors' fields seed from portals that just changed).
	for s_idx_k in _dirty_sectors.keys():
		var s_idx4: int = s_idx_k
		for g: NavGoal in goals.values():
			g.flow_cache.erase(s_idx4)
		var sx: int = s_idx4 % sector_count
		@warning_ignore("integer_division")
		var sy: int = s_idx4 / sector_count
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nx: int = sx + dx
				var ny: int = sy + dy
				if nx < 0 or ny < 0 or nx >= sector_count or ny >= sector_count:
					continue
				var n_idx: int = ny * sector_count + nx
				for g2: NavGoal in goals.values():
					g2.flow_cache.erase(n_idx)
	# High-level distance tables must be recomputed since sector adjacency
	# may have changed.
	for g3: NavGoal in goals.values():
		g3.needs_distance_recompute = true
	_dirty_sectors.clear()


# ────────────────────────────────────────────────────────────────────────────
# Goal: high-level sector distance (BFS over the portal graph)
# ────────────────────────────────────────────────────────────────────────────

func _ensure_goal_sector_distances(g: NavGoal) -> void:
	if not g.needs_distance_recompute:
		return
	g.needs_distance_recompute = false
	var total := sector_count * sector_count
	g.sector_distance.resize(total)
	for i in total:
		g.sector_distance[i] = UNREACHED

	if g.target_sectors.is_empty():
		return

	# Multi-source BFS seeded from all sectors containing goal tiles.
	var queue: PackedInt32Array = PackedInt32Array()
	var head := 0
	for s in g.target_sectors:
		if g.sector_distance[s] == UNREACHED:
			g.sector_distance[s] = 0
			queue.append(s)
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		var cur_dist: int = g.sector_distance[cur]
		for pi in (portal_index_per_sector[cur] as PackedInt32Array):
			var p: Portal = portals[pi]
			var other: int
			var can_go: bool
			if p.sector_a == cur:
				other = p.sector_b
				# Reverse BFS: we're propagating OUT from the goal, so we need
				# the agent to be able to travel from `other` to `cur`.
				can_go = p.b_to_a
			else:
				other = p.sector_a
				can_go = p.a_to_b
			if not can_go:
				continue
			if g.sector_distance[other] != UNREACHED:
				continue
			g.sector_distance[other] = cur_dist + 1
			queue.append(other)


# ────────────────────────────────────────────────────────────────────────────
# Per-sector flow field (lazy, cached)
# ────────────────────────────────────────────────────────────────────────────

func _get_or_compute_sector_flow(g: NavGoal, sector_idx: int) -> FlowField:
	var cached = g.flow_cache.get(sector_idx)
	if cached != null:
		return cached
	if sector_idx < 0 or sector_idx >= sectors.size():
		return null
	var sd: SectorData = sectors[sector_idx]
	if sd == null:
		return null
	if g.sector_distance[sector_idx] == UNREACHED:
		return null

	var ff := _compute_sector_flow(g, sector_idx)
	g.flow_cache[sector_idx] = ff
	sd.last_flow_compute_msec = Time.get_ticks_msec()
	if MonsterPerf.enabled:
		MonsterPerf.ff_compute_calls += 1
	return ff


func _compute_sector_flow(g: NavGoal, sector_idx: int) -> FlowField:
	var _t0: int = Time.get_ticks_usec() if MonsterPerf.enabled else 0
	var sd: SectorData = sectors[sector_idx]
	var w := sd.x1 - sd.x0
	var h := sd.y1 - sd.y0
	var n := w * h

	var ff := FlowField.new()
	ff.integration = PackedInt32Array()
	ff.integration.resize(n)
	for i in n:
		ff.integration[i] = UNREACHED

	# Portal seed tiles have cost 0, so no in-sector neighbour is ever strictly
	# lower — steepest descent leaves them with zero direction. Store the
	# outbound direction at seed time and use it as a fallback below.
	var seed_dir_x := PackedInt32Array()
	var seed_dir_y := PackedInt32Array()
	seed_dir_x.resize(n)
	seed_dir_y.resize(n)

	# Min-heap of (cost << 16 | local_idx). For SECTOR_TILES=8 the local_idx
	# fits in 6 bits; costs are well under 16 bits in a 8x8 sector.
	var heap: PackedInt32Array = PackedInt32Array()

	# Seed:
	# - If this is a goal sector: seed from goal tiles inside the sector with cost 0.
	# - Else: seed from portal cells exiting toward any strictly-lower-distance
	#   out-neighbour sector, with cost 0 (so the local gradient simply steers
	#   toward the nearest exit portal).
	var is_goal_sector := g.sector_distance[sector_idx] == 0
	if is_goal_sector:
		for t in g.target_tiles:
			var tx: int = t % map_size
			@warning_ignore("integer_division")
			var ty: int = t / map_size
			if tx < sd.x0 or tx >= sd.x1 or ty < sd.y0 or ty >= sd.y1:
				continue
			if walkable_mask[t] == 0:
				continue
			var lx := tx - sd.x0
			var ly := ty - sd.y0
			var li := ly * w + lx
			if ff.integration[li] != UNREACHED:
				continue  # already seeded
			ff.integration[li] = 0
			_heap_push(heap, 0, li)
	else:
		var my_dist: int = g.sector_distance[sector_idx]
		for pi in (portal_index_per_sector[sector_idx] as PackedInt32Array):
			var p: Portal = portals[pi]
			var is_a := p.sector_a == sector_idx
			var other := p.sector_b if is_a else p.sector_a
			var other_dist: int = g.sector_distance[other]
			if other_dist == UNREACHED or other_dist >= my_dist:
				continue  # must strictly decrease
			# Seed from our-side tiles whose edge_mask bit points across the
			# shared edge. This is the directed subset — a descent-only cliff
			# only seeds on the high side that can actually descend.
			var pairs_ours := p.tile_pairs_a if is_a else p.tile_pairs_b
			var pairs_theirs := p.tile_pairs_b if is_a else p.tile_pairs_a
			for pair_i in pairs_ours.size():
				var our_tile: int = pairs_ours[pair_i]
				var their_tile: int = pairs_theirs[pair_i]
				var our_x: int = our_tile % map_size
				@warning_ignore("integer_division")
				var our_y: int = our_tile / map_size
				var their_x: int = their_tile % map_size
				@warning_ignore("integer_division")
				var their_y: int = their_tile / map_size
				var dx := their_x - our_x
				var dy := their_y - our_y
				var dir_idx := _delta_to_dir(dx, dy)
				if dir_idx < 0:
					continue
				if (edge_mask[our_tile] & (1 << dir_idx)) == 0:
					continue
				var lx2 := our_x - sd.x0
				var ly2 := our_y - sd.y0
				var li2 := ly2 * w + lx2
				if ff.integration[li2] != UNREACHED:
					continue  # already seeded
				ff.integration[li2] = 0
				seed_dir_x[li2] = dx
				seed_dir_y[li2] = dy
				_heap_push(heap, 0, li2)

	# Dijkstra relax over the sector's 8-connected grid, gated by edge_mask.
	#
	# Goal-seeded search uses REVERSE edges: when we pop tile T (already
	# reached by the search) and look at neighbour N, the relaxation asks
	# "can an agent at N step onto T?" — i.e. we check `edge_mask[N]` for a
	# bit pointing from N back to T, NOT `edge_mask[T]` for a bit from T to
	# N. With undirected edges the two are equivalent; with directed cliff
	# edges (descent-only) the difference matters: without this reversal
	# the integration field would say "agent at ground tile X is 20 units
	# from the goal" simply because the agent at the goal can jump DOWN
	# onto X, which is the wrong direction of travel for navigation.
	while heap.size() > 0:
		var packed := _heap_pop(heap)
		var cost := packed >> 16
		var li3 := packed & 0xffff
		if cost > ff.integration[li3]:
			continue
		var lx3: int = li3 % w
		@warning_ignore("integer_division")
		var ly3: int = li3 / w
		for d in 8:
			var nx := lx3 + DIR_DX[d]
			var ny := ly3 + DIR_DY[d]
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue  # stay inside this sector
			var n_gx := sd.x0 + nx
			var n_gy := sd.y0 + ny
			var n_global := n_gy * map_size + n_gx
			var n_edges: int = edge_mask[n_global]
			# Reverse edge: can neighbour N step to tile T? N→T is the
			# direction opposite to T→N, which is d XOR 4 (0↔4, 1↔5, ...).
			var d_back := d ^ 4
			if (n_edges & (1 << d_back)) == 0:
				continue
			var ni := ny * w + nx
			var new_cost: int = cost + DIR_COST[d]
			if new_cost < ff.integration[ni]:
				ff.integration[ni] = new_cost
				_heap_push(heap, new_cost, ni)

	# Derive the per-tile steering direction via steepest descent over the
	# same edge-mask-gated 8-neighbourhood. Tiles with no reachable lower
	# neighbour get ZERO — the sampler will drop them from the blend.
	ff.dir_x.resize(n)
	ff.dir_y.resize(n)
	for ly4 in h:
		for lx4 in w:
			var li4 := ly4 * w + lx4
			if ff.integration[li4] == UNREACHED:
				ff.dir_x[li4] = 0.0
				ff.dir_y[li4] = 0.0
				continue
			var gx4 := sd.x0 + lx4
			var gy4 := sd.y0 + ly4
			var global_tile4 := gy4 * map_size + gx4
			var src_edges4: int = edge_mask[global_tile4]
			var best_cost: int = ff.integration[li4]
			var best_dx := 0
			var best_dy := 0
			var best_is_diag := false
			for d2 in 8:
				if (src_edges4 & (1 << d2)) == 0:
					continue
				var nx2 := lx4 + DIR_DX[d2]
				var ny2 := ly4 + DIR_DY[d2]
				if nx2 < 0 or ny2 < 0 or nx2 >= w or ny2 >= h:
					continue
				var n_cost: int = ff.integration[ny2 * w + nx2]
				if n_cost == UNREACHED:
					continue
				# Prefer strictly lower cost. On a tie, prefer cardinal over
				# diagonal (straighter paths near the goal).
				if n_cost < best_cost or (n_cost == best_cost and best_is_diag and not DIR_IS_DIAG[d2]):
					best_cost = n_cost
					best_dx = DIR_DX[d2]
					best_dy = DIR_DY[d2]
					best_is_diag = DIR_IS_DIAG[d2]
			if best_dx == 0 and best_dy == 0:
				# No lower-cost in-sector neighbour — use portal seed direction if set.
				best_dx = seed_dir_x[li4]
				best_dy = seed_dir_y[li4]
			if best_dx == 0 and best_dy == 0:
				ff.dir_x[li4] = 0.0
				ff.dir_y[li4] = 0.0
			else:
				var inv_len := 1.0 / sqrt(float(best_dx * best_dx + best_dy * best_dy))
				ff.dir_x[li4] = float(best_dx) * inv_len
				ff.dir_y[li4] = float(best_dy) * inv_len

	if MonsterPerf.enabled:
		MonsterPerf.ff_compute_usec += Time.get_ticks_usec() - _t0
	return ff


# ────────────────────────────────────────────────────────────────────────────
# Sampler helpers
# ────────────────────────────────────────────────────────────────────────────

func _sample_tile_flow(g: NavGoal, tx: int, ty: int) -> Vector2:
	var t_idx := ty * map_size + tx
	if walkable_mask[t_idx] == 0:
		return Vector2.ZERO
	var s_idx := _sector_index_of_tile(tx, ty)
	var ff := _get_or_compute_sector_flow(g, s_idx)
	if ff == null:
		return Vector2.ZERO
	var sd: SectorData = sectors[s_idx]
	var w := sd.x1 - sd.x0
	var lx := tx - sd.x0
	var ly := ty - sd.y0
	var li := ly * w + lx
	return Vector2(ff.dir_x[li], ff.dir_y[li])


func _delta_to_dir(dx: int, dy: int) -> int:
	if dx ==  1 and dy ==  0: return 0
	if dx ==  1 and dy ==  1: return 1
	if dx ==  0 and dy ==  1: return 2
	if dx == -1 and dy ==  1: return 3
	if dx == -1 and dy ==  0: return 4
	if dx == -1 and dy == -1: return 5
	if dx ==  0 and dy == -1: return 6
	if dx ==  1 and dy == -1: return 7
	return -1


# ────────────────────────────────────────────────────────────────────────────
# Min-heap of packed (cost << 16 | local_idx)
# ────────────────────────────────────────────────────────────────────────────

func _heap_push(heap: PackedInt32Array, cost: int, li: int) -> void:
	var v: int = (cost << 16) | (li & 0xffff)
	heap.append(v)
	var i := heap.size() - 1
	while i > 0:
		@warning_ignore("integer_division")
		var parent := (i - 1) / 2
		if heap[parent] <= heap[i]:
			break
		var tmp: int = heap[parent]
		heap[parent] = heap[i]
		heap[i] = tmp
		i = parent


func _heap_pop(heap: PackedInt32Array) -> int:
	var top: int = heap[0]
	var last: int = heap[heap.size() - 1]
	heap.remove_at(heap.size() - 1)
	if heap.size() > 0:
		heap[0] = last
		var i := 0
		var n := heap.size()
		while true:
			var l := 2 * i + 1
			var r := 2 * i + 2
			var smallest := i
			if l < n and heap[l] < heap[smallest]:
				smallest = l
			if r < n and heap[r] < heap[smallest]:
				smallest = r
			if smallest == i:
				break
			var tmp: int = heap[i]
			heap[i] = heap[smallest]
			heap[smallest] = tmp
			i = smallest
	return top
