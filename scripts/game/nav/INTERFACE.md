# Navigation — interface contract

The live implementation lives in `ground_nav_layer.gd` (the class) and
`nav_debug_renderer.gd` (the overlay). This document describes the contract
the rest of the game depends on.

---

## Callers

Two files outside this directory depend on the nav system:

- [scripts/game/monster_pathfinding.gd](../monster_pathfinding.gd) — a thin
  façade owned by `MonsterSpawner`. Holds one `GroundNavLayer`, exposes
  `sample_factory_flow()` / `sample_chase_flow()` to `MonsterBase`, and
  re-registers goals when buildings change or the player crosses a tile.
- [scripts/game/monster_spawner.gd](../monster_spawner.gd) — constructs the
  `MonsterPathfinding` instance, calls `pathfinding.rebuild()` at the start
  of every fight phase, and instantiates a `NavDebugRenderer` as a child node
  so flow arrows are visible when `SettingsManager.debug_mode` is on.

Neither file should need to change when the nav system is re-implemented.

---

## Classes to re-create

### `GroundNavLayer` (class_name, extends RefCounted)

One instance per movement profile. For now we have exactly one — the
ground profile — which treats walls, buildings and un-climbable cliff
edges as obstacles. Future movement profiles (jumping, flying) would
subclass the same base and override the movement-profile hooks.

**Public properties accessed from outside this directory:**

- `goals: Dictionary` — map of `StringName → goal-data`. Callers only read
  `goals.has(key)` to check whether a goal has already been registered.

**Public methods accessed from outside this directory:**

```gdscript
func rebuild() -> void
```
Full rebuild from the current `MapManager.map_size`, walls, building layout,
and terrain heights. Clears all cached state. Called at the start of every
fight phase.

```gdscript
func mark_cell_dirty(grid_pos: Vector2i) -> void
```
Invalidate the sector containing `grid_pos` (and any portal runs along its
boundary). Safe to call many times per frame — the actual rebuild must be
coalesced and deferred to the next query. Used by building
placement / removal.

```gdscript
func set_goal(key: StringName, target_tiles: PackedVector2Array) -> void
```
Register or replace a named multi-tile destination. `target_tiles` is a
flat list of `Vector2(gx, gy)` tile coordinates (stored as
`PackedVector2Array` for cheap interop). Passing an empty array clears the
goal. Calling this must invalidate any cached per-sector flow fields tied
to the named goal.

```gdscript
func sample_flow(world_pos: Vector3, goal_key: StringName) -> Vector2
```
Query the flow direction at a continuous world position for the given goal.
Returns a `Vector2(x, z)` direction the monster should steer toward, or
`Vector2.ZERO` when the goal is unreachable / unregistered / empty — in
which case the caller falls back to direct movement.

**Required sampling semantics (the hard requirement for the rewrite):**
the returned direction MUST be a smooth function of `world_pos`. Use
**bilinear sampling** of the four neighbouring tile directions weighted by
the monster's fractional position inside its current tile, so crossing a
tile boundary does not produce a step discontinuity in the steering
direction. Discrete per-tile sampling causes monsters to wiggle along the
boundary between two parallel rows whose arrows converge on the edge.

```gdscript
func is_grid_walkable(grid_pos: Vector2i) -> bool
```
True iff the given tile is not blocked on the ground profile. Used by the
legacy `is_cell_walkable()` helper on `MonsterPathfinding`.

### `NavDebugRenderer` (class_name, extends Node3D)

A debug overlay child node owned by the spawner. When
`SettingsManager.debug_mode` is on, draws:

- **Sector borders** as thin rectangle outlines, colour-flashed when a
  sector's walkable mask was just rebuilt (yellow) or when a per-sector
  flow field was just recomputed (cyan). Flashes fade over ~600 ms.
- **Portal lines** — one line per `(a_tile, b_tile)` pair in every portal
  run. Bidirectional portals are drawn magenta; directed portals (cliff
  descent-only) are drawn orange with an arrowhead indicating the allowed
  direction of travel.
- **Flow-field arrows**: exactly ONE arrow per physical game tile that has
  a resolved direction, centred on the tile's world centre, length fits
  inside a 1-unit tile. Colour by goal:
  - green = factory goal
  - red = chase goal
  - white = any other goal key

Property `pathfinding: MonsterPathfinding` is assigned by the spawner.
Everything is redrawn on a throttled interval (~60 ms, independent of game
FPS) so the overlay never bottlenecks the render loop.

**Two `ImmediateMesh` instances reused across redraws — no per-frame
allocations.**

---

## Movement-profile hooks (ground)

The ground profile distinguishes two concerns:

**Tile blocked** — a hard obstacle that cannot be stood on:
- `MapManager.walls.has(tile)`
- `BuildingRegistry.get_building_at(tile) != null`

**Edge traversable** — whether an agent can cross from one tile to its
neighbour. Elevation enters here:
```gdscript
var h_from := MapManager.get_terrain_height(from_tile)
var h_to   := MapManager.get_terrain_height(to_tile)
return (h_to - h_from) <= STEP_HEIGHT
```
`STEP_HEIGHT = 0.0`: the current ground profile is for monsters that cannot
jump at all, so any height jump — even a fraction of a unit — is treated as
a vertical wall. Descent is always allowed (a negative delta trivially
satisfies `<= 0`), ascent is never allowed. This produces directed cliff
edges: a high tile has a west bit toward its low neighbour, but the low
tile has no east bit back.

**Argument order is always `(from, to)`** representing the agent's
direction of travel. Cliff edges are therefore **directed**: descent-only,
not symmetric.

---

## Design requirements for the rewrite

Collected from the iterations we went through before wiping the directory.
Any reimplementation must satisfy all of these simultaneously:

### 1. Tile-level field, no sub-cells
One flow-field entry per physical game tile. The old 2×2 sub-cell layout
produced corner-cutting bugs and made the debug overlay dense. A 128-tile
map has 16 384 tile entries spread across 256 sectors of 64 tiles each.

### 2. Hierarchical sectors + directed portals
The map is partitioned into `SECTOR_TILES × SECTOR_TILES` sectors
(currently `SECTOR_TILES = 8`). Sectors connect via **portals**: runs of
adjacent tile pairs along a shared edge, each with TWO directed
passability flags (`A→B` and `B→A`) so cliff edges can be descent-only.

A high-level BFS on the **directed** sector graph computes
`sector_distance[s]` from each goal. A per-sector flow field is then
computed on demand, seeded either from goal tiles (if `s` is a goal
sector) or from portal tiles that lead to a lower-distance out-neighbour.

### 3. 8-connected local BFS with a strict corner rule
Within a sector, BFS is 8-connected so monsters take diagonal paths in
open space. For a diagonal step `N → C` the relaxation is only valid
when **both** L-shaped detours (`N → corner_A → C` and `N → corner_B → C`)
are fully walkable AND fully edge-traversable. This guarantees every
2×2 square on a diagonal trajectory is at compatible elevation, so the
monster's capsule never clips a cliff face.

### 4. Direction stored at N points TOWARD parent C
`directions[N] = (C - N).normalized()`. The agent at N walks toward the
BFS parent. Relaxation is only allowed when `_can_traverse_tile_edge(N, C)`
is true — the agent's direction, not the BFS's direction of expansion.

### 5. Edge-gated bilinear sampling at query time
`sample_flow()` MUST bilinearly interpolate the four neighbouring tile
directions using the monster's fractional position inside its current
tile. This is the load-bearing requirement — discrete per-tile sampling
causes the "wiggle between two parallel rows" oscillation even when the
underlying BFS is correct.

**Every neighbour contribution must be edge-gated** against the query
tile's `edge_mask`. If the query tile has no direct edge (cardinal or
diagonal) toward a sample tile, that sample tile is dropped from the
blend. This is what prevents diagonal leakage across impassable corners —
the `.#/#.` elevation case where two low tiles form a diagonal pocket
separated by two high tiles must NOT blend flow directions across the
diagonal.

Directions that are `Vector2.ZERO` (unreached tiles) are also dropped from
the blend. The sampler re-normalises by the total weight of the remaining
contributions. Do NOT lerp toward zero, that drags monsters to a halt
near sector edges.

### 5.1 The edge_mask pre-pass
The corner-blocking rules from §3 and the elevation/corner gating from §5
collapse to a single 8-bit `edge_mask` per tile, pre-computed in two passes
during `rebuild()`:

- Pass 1: cardinal bits (E, S, W, N) — set iff neighbour is walkable and
  `(height_neighbour - height_self) <= STEP_HEIGHT`.
- Pass 2: diagonal bits (SE, SW, NW, NE) — set iff BOTH L-path detours
  are fully cardinal-traversable (the L-rule from §3).

Every BFS relaxation and every sampler edge-gate resolves to one bitmask
read. No per-query function calls for walkability/elevation/corner rules.

### 6. NO wall-clearance post-process, NO obstacle inflation
A previous iteration biased each arrow away from adjacent walls; this
created a fixed point between two parallel rows and made monsters
sawtooth-oscillate along the boundary. Bilinear sampling is the correct
fix — do not reintroduce a per-tile bias.

Obstacle inflation (dilating `blocked` by one tile) was also rejected:
it makes 1-tile gaps impassable and hides valid paths the player built.

### 7. Per-sector flow-field cache
Keyed by `"<goal_key>:<sector_idx>"`. Populated lazily on `sample_flow()`.
Fully cleared when the goal changes or any sector goes dirty. N monsters
standing in the same sector produce exactly one BFS per goal per dirty
cycle.

### 8. Coalesced dirty sectors
`mark_cell_dirty` records a sector index in a set. The set is flushed on
the next `sample_flow()` call: rebuild the affected sectors' walkable
masks, rebuild all portals and the directed sector graph (cheap — no
BFS), clear the flow-field cache, invalidate the goal distance tables.
Many marks between queries produce one flush.

### 9. Debug counters on `MonsterPerf`
If `MonsterPerf.enabled`, the layer increments these counters so the
perf overlays in the stress scenarios keep working:
- `ff_compute_calls` / `ff_compute_usec` — per-sector BFS runs
- `flush_dirty_calls` — coalesced dirty flushes
- `sample_factory_calls` / `sample_factory_usec` — sample_flow totals
  for the factory goal (tallied by `MonsterPathfinding`, not the layer)
- `register_goal_calls` / `register_goal_usec` — also tallied by the
  façade

---

## Known pitfalls (from prior iterations)

1. **Corner-cut bug**: diagonal BFS steps across a cliff corner where
   both endpoints are low-elevation but one of the two corner tiles is a
   high-wall. Solved by the strict "both L-paths traversable" rule in §3.

2. **Wiggle in 2-tile corridors**: caused by wall-clearance bias producing
   a fixed point on the edge between two rows whose arrows converge. Do
   not reintroduce this bias — use bilinear sampling instead (§5).

3. **Stuck on inside corners**: a `CharacterBody3D` pressed into two walls
   at 90° has no valid slide direction. The flow field cannot fix this
   after the fact; prevention is the only cure, and the prevention comes
   from bilinear sampling keeping the monster's trajectory smooth so it
   never arrives at the corner tangent to both walls simultaneously.

4. **Dropped goals after building death**: when a building is destroyed
   mid-fight, `invalidate_factory_flow()` is called. Until the goal is
   re-registered with the surviving buildings, `sample_flow()` must
   return `Vector2.ZERO` rather than stale directions. The spawner
   coalesces many building events into one re-register per physics tick.
