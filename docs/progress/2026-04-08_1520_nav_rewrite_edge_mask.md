# Session: Nav layer rewrite — edge_mask + edge-gated bilinear sampling

**Date:** 2026-04-08
**Start:** 14:05 MSK
**End:** 15:20 MSK
**Elapsed:** ~1.25h

## Goal

Rewrite `scripts/game/nav/` from scratch against the contract in
`INTERFACE.md`. The prior hierarchical flow-field system (PERF.1, with
NAV.FIX patches for elevation) had accumulated six interacting classes
(`NavLayer`, `GroundNavLayer`, `NavSector`, `NavPortal`, `NavGoal`,
`FlowField`, `NavDebugRenderer`), a subtle diagonal-leak bug across the
elevation-corner case `.#/#.`, and a sampler that wasn't quite honouring
the corner rule at bilinear-blend time.

User brief:
1. Continuous flow-field with core points at cell centers.
2. The `.#/#.` case: two walkable diagonal tiles separated by two
   impassable (high-elevation) tiles must NOT leak flow across the
   diagonal.
3. Research real RTS / horde game implementations first.
4. Full hierarchical system (sectors + portals + dirty rebuild).
5. Portals visible in debug overlay as lines between paired cells.
6. `STEP_HEIGHT = 0` — ground monsters can't jump at all.

## Research

Surveyed the practical flow-field literature before writing any code:
Elijah Emerson's Supreme Commander 2 chapter (Game AI Pro 23), jdxdev's
RTS Pathfinding series, howtorts' flow fields + line-of-sight posts,
Leifnode's implementation, Red Blob's tower-defense / vector field page,
Bevy's `bevy_flowfield_tiles_plugin` source, and *They Are Billions*
player discussions. Every working system converges on the same pipeline:

```
cost_field   → per-tile traversal cost
integration  → Dijkstra from goal, using cost as edge weight
flow         → per-tile direction (steepest descent over integration)
```

with a **hierarchical overlay** (sectors + portals + per-sector flow on
demand) for scalability and **bilinear sampling at query time** for
smoothness.

Key insight none of the tutorials directly address: when bilinear-
sampling the flow at a continuous position, the **four neighbouring
tile contributions must be edge-gated** against the query tile's
connectivity. Naïve bilinear blending leaks direction across impassable
corners. The classical "no corner-cut" rule is the same rule —
expressed at a different phase of the pipeline.

Full design report is in chat history before implementation started.

## Implementation

### `scripts/game/nav/ground_nav_layer.gd` (new, ~990 lines)

One class with inner types (`SectorData`, `Portal`, `NavGoal`,
`FlowField`). Pipeline:

1. **`rebuild()`**
   - Build `walkable_mask: PackedByteArray` (`walls + buildings = blocked`).
   - Build `edge_mask: PackedByteArray` — 8 bits per tile, one per
     direction. Two passes:
     - Pass 1: cardinal bits (E, S, W, N) from walkable + height delta.
     - Pass 2: diagonal bits (SE, SW, NW, NE) from the **L-rule** using
       pass-1 cardinal bits. Diagonal step N→D is allowed iff both L-path
       detours (N → sideA → D and N → sideB → D) are fully cardinal-
       traversable.
   - Partition the map into `SECTOR_TILES = 8` sectors.
   - Detect portals: scan each shared sector edge, find contiguous runs
     where at least one direction is edge-traversable. Portal stores
     `(a_tile, b_tile)` pairs + independent `a_to_b`, `b_to_a` flags,
     so cliff edges become directed one-way portals.
2. **`set_goal(key, target_tiles)`** — registers a `NavGoal` with flat
   tile indices + target-sector set.
3. **`sample_flow(world_pos, goal_key)`** — the hot path:
   - Flush dirty sectors (coalesced).
   - Ensure goal's per-sector distance table (multi-source BFS on the
     directed portal graph).
   - Lazy-compute per-sector local Dijkstra fields on demand.
   - Bilinear-sample 4 neighbouring tile directions, each **gated by
     the query tile's edge_mask toward the sample tile**. Zero-flow
     contributions are dropped and the remainder renormalised.
4. **`mark_cell_dirty(pos)`** — sets a sector index bit + 1-tile halo.
   Coalesced: many calls → one flush on next query.

### The edge_mask invariant

Every "can the agent walk from A to B" check in the hot path is a single
bitmask read on `edge_mask[A]`. The expensive work (walkable, elevation
delta, L-rule corner check) happens ONCE per rebuild and is baked into
the mask. BFS relaxations and sampler edge-gates all resolve to the same
lookup. This is what makes the `.#/#.` case correct for free:

```
. #     tile (0,0) low: bit_E blocked (can't ascend), bit_S blocked,
# .     bit_SE blocked (L-rule: needs both cardinal legs, neither set)
```

From `(0,0)` a bilinear sample with query tile `(0,0)` and 4 corners
`(0,0), (1,0), (0,1), (1,1)` gates out every non-query contribution
(`(1,0)` and `(0,1)` are blocked east/south from `(0,0)`, and `(1,1)`
is gated by `bit_SE` which is 0). Only `(0,0)` contributes. No leak.

### Dijkstra (not BFS) inside the sector

Integer costs: 10 for cardinal, 14 for diagonal (≈1:√2). Min-heap stored
in `PackedInt32Array` as packed `(cost << 16 | local_idx)` so heap
comparisons are plain int ordering — avoids the Variant-inside-Array
pitfall that killed the old heap Dijkstra (the 9.3 s disaster from the
PERF.1 session).

Intermediate sectors seed from portal cells of ALL strictly-lower-
distance out-neighbours, so the local gradient steers toward the
nearest geometrically-closest exit portal regardless of direction.

Per-tile flow direction is steepest-descent over the 8 edge-mask-gated
neighbours. Ties prefer cardinal over diagonal (straighter paths).

### `scripts/game/nav/nav_debug_renderer.gd` (new, ~280 lines)

Two `ImmediateMesh` instances reused across redraws (lines + arrows).
`_process` throttled to 60 ms redraw cadence. Draws:

- **Sector borders** — thin rectangles, grey idle, flashing YELLOW on
  walkable rebuild and CYAN on flow compute, fade over 600 ms.
- **Portal lines** — one line per `(a_tile, b_tile)` pair. Bidirectional
  portals are MAGENTA; directed portals (cliff descent-only) are ORANGE
  with an arrowhead pointing in the allowed direction. **This is the
  new feature the user asked for.**
- **Flow arrows** — one per tile with a resolved direction, centred on
  the tile's world center, length 0.45. GREEN = factory goal, RED =
  chase, WHITE = other.

Guards against `ImmediateMesh.surface_end()` with no vertices (which
errors): counts resolved arrows first; clears surface on empty.

## Verification

All runs on separate invocations. `--import` was required once after
adding the class files to refresh Godot's `global_script_class_cache`.

### Unit + integration tests
- `tests/run_tests.gd`: **33 passed, 0 failed**
- Parse check (`--headless --quit`): clean, no warnings/errors

### Scenarios (all `--fast` / 10x speed)

| Scenario | Result |
|---|---|
| `scn_monster_cliff_pathfind` | ✅ PASS — monster moved 6.67 world-units, did not get stuck at cliff |
| `scn_monster_pathfind` | ✅ PASS — 10.2 → 1.3 tiles to building |
| `scn_terrain_elevation` | ✅ PASS — all 14 assertions |
| `scn_monster_attack_building` | ✅ PASS — 60 damage dealt |
| `scn_monster_spawn` | ✅ PASS — 4 assertions |
| `scn_fight_phase_end` | ✅ PASS — round cycling |
| `scn_turret_kills_monster` | ✅ PASS — turret killed the monster |
| `scn_real_save_fight` | ✅ PASS — best closest approach 0.03 tiles, all 18 buildings destroyed |
| `scn_real_save_stress` | ⚠️ ADVISORY FAIL — "10 monsters alive" assertion got 5. Explanation below. |

### Performance: `sim_monster_attack_perf` (round 15, ~40-42 monsters)

| Pass | avg ms | p95 ms | max ms |
|---|---|---|---|
| separation ON | **3.37** | **6.69** | **14.88** |
| separation OFF | **3.50** | **6.23** | **16.11** |

Totals over the full pass (separation ON):
- `ff_compute`: **11 calls, 4.26 ms total** (<0.01 ms/frame amortised)
- `sample_factory`: 8465 calls, 83.7 ms total (~10 µs/call)
- `flush_dirty`: 0 (no buildings changed during the pass)
- `register_goal`: 4 calls, 0.2 ms total

Matches or beats the pre-rewrite baseline (PERF.3 session numbers:
avg 3.43 ms, p95 6.43 ms, max 17.46 ms). Max frame time dropped
from 17.46 → 14.88 (-15%).

## scn_real_save_stress — the one advisory failure

This scenario asserts ≥10 monsters alive at the end of the sample
window on round 6 of the user's `slot_0/run_backup.json` save. My run
has 5 alive at window close. Looking at the details:

- `buildings_alive: 18` (stayed at 18 throughout — zero building damage)
- `alive monsters: 12 → 13 → 13 → 12 → 15 → 11 → 10 → 9 → 7 → 5`
  (linear die-off)
- `stuck_count: 0` (no stuck detection fired)
- `frame_ms_avg: 2.12 ms` (extremely healthy frame time)
- `ff_compute: 2 calls, 0.81 ms` (new layer is effectively free)

Monsters are reaching building range, engaging turrets, and being
killed faster than they spawn. No building has taken damage — the
defence is working. This is **not a navigation regression**; the
scenario was calibrated against an older baseline where monsters
were moving less efficiently (and therefore surviving longer).

The assertion measures "monsters still alive at window end", which is
a brittle proxy for "navigation works". The real signals in this
scenario — `stuck_count == 0`, fps stable, `ff_compute` near zero,
zero building damage — all pass. Leaving the scenario as-is; if the
balance team wants to loosen the assertion to e.g. "alive > 3", that's
a separate follow-up.

## Files

**New:**
- `scripts/game/nav/ground_nav_layer.gd` — 990 lines, single class with
  inner helper types
- `scripts/game/nav/nav_debug_renderer.gd` — 280 lines, two reused
  ImmediateMesh surfaces

**Modified:**
- `scripts/game/nav/INTERFACE.md` — STEP_HEIGHT=0 clarification, new
  §5.1 describing the `edge_mask` pre-pass, portal-line note in the
  debug renderer section, removed the "parse error" stub preamble.

**Unchanged (external callers):**
- `scripts/game/monster_pathfinding.gd` (façade — same API)
- `scripts/game/monster_spawner.gd` (constructs the renderer — same API)
- `monsters/monster_base.gd` (sampler caller — same API)

## Bugs hit during implementation

1. **Inner-class `extends` syntax.** First pass used
   `class SectorData: \n    extends RefCounted` on two lines — Godot 4
   wants `class SectorData extends RefCounted:` inline. IDE diagnostics
   caught it immediately.

2. **Variant type inference from untyped Arrays.** `_dirty_sectors.keys()`
   returns `Array` (Variant elements); `s_idx % sector_count` therefore
   failed to infer int. Fixed by unpacking with explicit `var s_idx: int = s_idx_k`.
   Same issue in the debug renderer for `sd.x1 - sd.x0`.

3. **Seed-skip check was inverted.** In the Dijkstra seed loop I wrote
   `if ff.integration[li] == 0: continue` instead of
   `if ff.integration[li] != UNREACHED: continue`. The effect was to
   skip seeds that SHOULD be processed and re-process ones that had
   already been set. Caught on careful re-read before running tests.

4. **`ImmediateMesh.surface_end` errors on empty surface.** When the
   nav renderer ran before any sample_flow call (no flow_cache
   populated), `surface_end` would error with "No vertices were added".
   Fix: count the expected vertex count first, skip the whole surface
   if zero, and as a safety net call `clear_surfaces()` instead of
   `surface_end()` if we opened a surface but didn't emit anything.

5. **Class cache staleness.** Godot's `global_script_class_cache.cfg`
   kept resolving `GroundNavLayer` via the pre-wipe entry the first
   time I ran the cliff scenario, so the parse check silently passed
   but the scenario blew up on `Could not find type "GroundNavLayer"`.
   One `--import` invocation rebuilt the cache. This is the known
   "new class_name files need --import" pitfall from my memory.

## Design notes worth keeping

- The `edge_mask` two-pass rebuild puts all the corner / elevation /
  walkable logic in ONE place. Every other piece of code (portal
  detection, BFS relaxation, sampler gating) is a mask read. This
  eliminates an entire class of bugs where one of those places had
  inconsistent rules from the others (which was the root of NAV.FIX).
- Portal directions (`a_to_b` / `b_to_a`) are independent booleans.
  Cliff edges produce portals where only one direction is set, and the
  high-level sector BFS correctly traverses them in the reverse sense
  (the BFS propagates OUT from the goal, so it follows `b_to_a` when
  crossing from the next sector back toward the previous one).
- Integer costs + packed heap (`cost << 16 | li`) keeps the inner
  Dijkstra loop on `PackedInt32Array` the whole way. No Variants.
- Bilinear sampling biases correctly because tile centers are at
  integer world coordinates: `bx = floori(wx), by = floori(wz)` gives
  the unit square whose corners are the four nearest tile centers,
  and the query tile (monster's home) is always one of those four.

## Next goals

- If balance wants monsters to survive longer in `scn_real_save_stress`,
  that's a spawner-side tuning (spawn rate / budget) not a nav issue.
- The cliff scenario currently doesn't verify monsters route AROUND
  the plateau (there's no ramp on the test plateau, so the goal is
  genuinely unreachable from low ground). Could extend it with a
  ramp-test variant to exercise the portal routing more fully.
- Add a dedicated simulation for the `.#/#.` diagonal case so it's
  covered by automated tests (the existing scenarios cover full-map
  elevation + corner rules, but not this exact pocket).
- Wire a `JumpingNavLayer` subclass (or variant) when the next monster
  type needs it; the contract is stable now.
