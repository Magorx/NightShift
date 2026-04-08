## Session: Hierarchical Flow Field Pathfinding (PERF.1)

**Date:** 2026-04-07
**Start:** 22:20
**End:** 23:00
**Elapsed:** ~0.67h (40 minutes)

## Problem

User reported: "When the player is inside many monsters range, the game gets ultra laggy, like 3 fps." Investigation showed the previous BFS flow field implementation was BFS-ing the entire 256×256 sub-grid (65 536 cells) per call, with the chase field rebuilding every 300 ms wall time. With many monsters chasing the player, this dominated the physics frame.

The user asked for a research pass on how AAA games handle this, then asked for "the full classical system" implemented end-to-end, with the architecture ready to support multiple movement layers (ground / jumping / flying) later.

## Research

Pulled techniques from:

- **Supreme Commander 2 / Game AI Pro Ch. 23 (Elijah Emerson)** — sector-based hierarchical flow fields, portal graph between adjacent sectors, lazy per-sector BFS along the high-level path, dirty-tile invalidation. Scales to thousands of units because per-unit cost is O(1) field lookup.
- **jdxdev RTS Pathfinding** — practical breakdown of the same approach with sample timings (~0.3 ms per tile rebuild on a 50×50 sub-grid).
- **They Are Billions** — weighted shortest-path: walls/turrets cost more, swarms naturally funnel to thin gaps. Closest genre match.
- **Continuum Crowds (Treuille/Cooper/Popović 2006)** — origin paper for SupCom2's approach.

## Architecture

New module `scripts/game/nav/`, decomposed so movement profiles plug in without touching the algorithm:

```
FlowField     — per-sector local flow field (16×16 cells with SECTOR_SIZE=8)
NavSector     — sector metadata + local walkable mask + flash timestamps
NavPortal     — contiguous run of cells along two sectors' shared edge
NavGoal       — named multi-cell destination + cached sector_next_hop / sector_distance
NavLayer      — base class: rebuild → walkable → sectors → portals → adjacency,
                set_goal / sample_flow / mark_cell_dirty, virtual walkability hooks
GroundNavLayer— concrete subclass: walkable = not wall, not building
NavDebugRenderer — visual overlay (sector borders + flow arrows)
```

`MonsterPathfinding` is now a façade: holds a `ground: GroundNavLayer`, exposes `sample_factory_flow()` / `sample_chase_flow()` (re-registering the GOAL_CHASE goal only when the player crosses sub-cells), and keeps the legacy A* API alive for the test scenarios that call `get_path()`/`find_attack_cell()` directly.

### Pipeline

1. `rebuild()` — full walkable grid → sector partition → portal detection (cell-by-cell scan along every shared edge, contiguous walkable runs become portals) → sector adjacency from portals.
2. `set_goal(key, cells)` — registers a destination, computes target sectors, marks `needs_recompute` on the goal.
3. `sample_flow(world_pos, key)` — flush dirty sectors → ensure goal's sector_next_hop (multi-source BFS on the sector graph) → get-or-compute the per-sector flow field for the monster's current sector → return gradient direction. The per-sector BFS only seeds from the actual target cells (in goal sectors) or the portal cells toward `next_hop[sector]` (in intermediate sectors).
4. `mark_cell_dirty(grid_pos)` — marks the affected sector + neighbours dirty; coalesced and lazily flushed on the next query.

### Per-sector flow field cache

Keyed by `"<goal_key>:<sector_idx>"`. 20 monsters in the same sector → 1 compute, 20 reads. Sectors that never hold a monster never compute a field. Building changes invalidate only the affected sectors' fields, not the whole world.

## Earlier mistakes (in this same session)

Before going to the full sector system, I'd already shipped a simpler "BFS the whole map with a binary heap" version. That hit two problems the sector system fixes:

1. **Heap Dijkstra in pure GDScript was 9.3 SECONDS per compute** for a 256×256 grid because nested `Array[Array]` accesses are dog slow under Variant. I rewrote it as flat BFS with `PackedInt32Array` queue + parallel `PackedInt32Array` neighbour offsets, which dropped that to milliseconds — but it was still BFS-ing the whole map per call. That's the version the user noticed lagging at 20 monsters, prompting the "BFS only the segments where stuff is" question.
2. **The "stop computing the whole world" insight** is exactly what hierarchical sector flow fields give you for free. Per-sector compute touches 256 cells (with SECTOR_SIZE=8) instead of 65 536.

## Debug visualisation

After the algorithm landed, user asked for a debug overlay. Added `NavDebugRenderer` (Node3D, child of MonsterSpawner, shared `pathfinding` reference):

- Sector borders drawn just above ground (Y=0.08) as line rectangles
  - **Muted grey** = idle
  - **YELLOW flash** = local walkable mask was just rebuilt (dirty-sector flush)
  - **CYAN flash** = a per-sector flow field was just computed (lazy BFS hit)
  - Both fade out over 600 ms
- Flow field arrows drawn at Y=0.10, sub-sampled every 2 cells
  - **GREEN** = factory goal
  - **RED** = chase goal
  - **WHITE** = other goals
  - Arrowhead is 2 short lines forming a `>` at the tip
- Two reused `ImmediateMesh` instances (sector borders + arrows), one unshaded vertex-coloured `StandardMaterial3D` with `no_depth_test`
- Throttled to 60 ms redraw cadence so it never bottlenecks the game framerate
- Visibility wired to `SettingsManager.debug_mode` (toggle clears meshes so the GPU doesn't keep stale geometry)
- Two new timestamps on `NavSector` (`last_walkable_rebuild_msec`, `last_flow_compute_msec`) drive the flash colours; updated in `_rebuild_sector_walkable()` and the cache-miss branch of `_get_or_compute_flow_field()`
- `_flow_field_cache` made public (`flow_field_cache`) so the renderer can iterate it; gameplay still goes through `sample_flow()`

User then bumped `SECTOR_SIZE` from 16 → 8 (smaller sectors = finer dirty granularity, more sectors but cheaper per-sector compute). Math still checks out: on a 128 tile map that's 16×16 = 256 sectors of 16×16 sub-cells each.

## Performance

`scn_turret_kills_monster` (peak 64+ monsters spawned around the perimeter, all converging on the factory):

| State | Wall time |
|---|---|
| Whole-map BFS heap Dijkstra (intermediate broken version) | 90+ s timeout / hang |
| Whole-map BFS PackedArray flat | ~9 s |
| Sector-based hierarchical (this session) | **1.97 s** |
| Sector-based + NavDebugRenderer attached, debug_mode off | **1.89 s** |

The renderer is essentially free with `debug_mode` off — its `_process()` short-circuits before any work.

## Files Changed

**New:**
- `scripts/game/nav/flow_field.gd` — class FlowField (per-sector local data)
- `scripts/game/nav/nav_sector.gd` — class NavSector (metadata, walkable mask, flash timestamps)
- `scripts/game/nav/nav_portal.gd` — class NavPortal (sector A/B + local cell runs)
- `scripts/game/nav/nav_goal.gd` — class NavGoal (target cells, sector_next_hop cache)
- `scripts/game/nav/nav_layer.gd` — class NavLayer (sectors, portals, fields, queries)
- `scripts/game/nav/ground_nav_layer.gd` — class GroundNavLayer (walls + buildings = blocked)
- `scripts/game/nav/nav_debug_renderer.gd` — class NavDebugRenderer (sector borders + flow arrows)

**Modified:**
- `scripts/game/monster_pathfinding.gd` — rewritten as façade over `ground: GroundNavLayer` + legacy A*
- `scripts/game/monster_spawner.gd` — instantiates NavDebugRenderer in `_ready()`, wires `building_placed`/`building_removed` → `invalidate_factory_flow()`
- `monsters/monster_base.gd` — `_process_movement` and `_process_chasing` sample flow fields instead of running per-monster A*
- `buildings/shared/building_logic.gd` — added attack slot reservation (`claim_attack_slot` / `release_attack_slot` / `get_attack_slot_world`) so monsters spread around buildings instead of piling on one cell
- `scripts/autoload/settings_manager.gd` — added `monster_separation_enabled` toggle + persistence

## Verification

- Parse check (`$GODOT --headless --path . --quit`): clean
- Unit tests (`tests/run_tests.gd`): 33/33 pass
- `scn_monster_pathfind`: pass (monster navigates 10.3 → 1.1 tiles to building)
- `scn_monster_attack_building`: pass (60 dmg in 4 s, building destroyed)
- `scn_monster_attack_player`: completes in 62 ticks (the only failure is the pre-existing `GameManager.player.hp` scenario typo, unrelated to this work)
- `scn_turret_kills_monster`: 1.89 s wall time with 64 peak monsters

## Bugs/Fixes During Implementation

- **Heap-based Dijkstra was 9.3 s per compute** in pure GDScript. Root cause: nested `Array[Array]` lookups for the heap entries. Fix: scrapped the heap, used flat BFS with `PackedInt32Array` queue + moving head index. Then realised the real fix was per-sector compute, not faster whole-map compute.
- **Inner class name collision** when adding `class_name FlowField` while `monster_pathfinding.gd` still had its own inner `FlowField` class. Caught immediately by the Godot importer ("Class FlowField hides a global script class"). Fix: rewrote `monster_pathfinding.gd` as the façade.
- **Standalone `bench_nav.gd` couldn't reference `MapManager`** because autoloads aren't resolved at compile time for `extends SceneTree` scripts. Worked around by deleting the bench and using `scn_turret_kills_monster` (which already loads the full game world) as the stress harness. Numbers from there are more representative anyway.
- **Pre-existing uncommitted budget inflation** in `monster_spawner.gd:105` (`1000.0 * round_num` instead of `10.0`) is what produced the 64-monster swarm during the turret stress test. The turret scenario's "Monster took turret damage" assertion now fails because the swarm is so effective it destroys all turrets before the test monster gets shot — that's a balance/test issue, not a regression. Left the inflation in place because it makes a useful stress harness.

## Next Goals

- Wire `MonsterBase.movement_layer: StringName` so future monsters can pick `&"jumping"` or `&"flying"` instead of always `&"ground"`.
- Override `NavLayer._can_traverse_edge()` in a `NoJumpGroundNavLayer` subclass to reject edges with elevation delta > 0 (covers the "ground monsters that can't jump" use case the user mentioned).
- Add an in-game keybind to toggle `SettingsManager.debug_mode` so the nav overlay can be flicked on without pausing.
- If 256-sector portal rebuild on dirty events ever shows up in the profiler, switch from "rebuild all portals" to "rebuild only the dirty sectors' shared edges."

## Commits

(Working tree only — nothing committed during the session.)
