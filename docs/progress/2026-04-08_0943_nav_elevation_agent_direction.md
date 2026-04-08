# Session: Nav elevation fix — BFS edge check uses agent direction

**Date:** 2026-04-08
**Start:** 09:43
**End:** 11:28
**Elapsed:** ~1.75h (planned 1h)

## Problem

The user reported two pathfinding bugs on a real save (slot_0 run_backup.json — 17 buildings on a 64 map with elevation terrain):

1. **Monsters stuck head-butting elevation walls.** Screenshot showed a tendril crawler sitting directly in front of a raised terrain cell with white flow arrows pointing INTO the wall. The monster never moved.
2. **Flow arrows leading to the side of the base instead of at it.** Portals between sectors with elevation were asymmetric and disappearing, causing sector-level BFS to route swarms around the factory rather than through it.

These happened even after last session's elevation-related fixes (`STEP_HEIGHT = 0.6`, descent allowed, `sector_lower_neighbors` multi-seed). The PERF.3 session proved the nav system was *fast*; this session fixed what was *wrong*.

## Root cause

`NavLayer._compute_sector_flow_field` ran the `_can_traverse_edge` check in the BFS-propagation direction (parent → neighbour), but the monster eventually walks in the OPPOSITE direction (neighbour → parent). BFS flood-filling from a goal on HIGH ground would happily descend across cliff edges (descent is always allowed) and record a flow arrow at the LOW cell pointing UP to its high parent. Monsters sampling the flow at that low cell would walk into the cliff and stick to the collider forever.

The same asymmetry broke portal detection: `_detect_portals_between` checked only the A→B direction, so a cliff-edge portal where descent worked but ascent didn't was silently dropped. Sector adjacency became one-way, and high-level BFS routed swarms around the affected sectors — matching the "arrows lead to the side of the base" symptom.

## Fix (scripts/game/nav/nav_layer.gd)

1. **BFS edge check now uses agent direction.** In `_compute_sector_flow_field`, swap the args: `_can_traverse_edge(neighbor_gx, neighbor_gy, parent_gx, parent_gy)`. The check now asks "can the agent at the new cell move back to the current cell (which is the next step toward the goal)?". That's the direction the monster will actually travel.

2. **Portal detection is now symmetric.** `_detect_portals_between` allows a portal if monsters can cross in EITHER direction: `_can_traverse_edge(a, b) or _can_traverse_edge(b, a)`. Sector adjacency becomes permissive so high-level BFS can still route through cliff portals.

3. **Portal seeding respects agent direction.** In `_get_or_compute_flow_field`, intermediate-sector seeds are filtered by whether the agent can actually cross `from_sector → other` at each portal cell pair. Portal cells that are only traversable in the reverse direction don't seed the BFS for this sector. Without this, a symmetric-detected portal would seed cells the agent couldn't exit through, leading to "walks to portal then gets stuck" behaviour.

## New tests

### `scn_monster_cliff_pathfind` (new regression test)

- Builds a 40-tile map with a 1.5-unit plateau from (16,12) to (28,20)
- Factory sits **on top** of the plateau at (22, 16)
- Spawns a single tendril crawler on LOW ground west of the plateau at (8, 16)
- Asserts the monster moves > 5 world-units (proving it found a route, not head-butting the cliff)
- **Actual result:** monster travelled 13.14 world-units, physics-sliding around the southern edge of the plateau and ending at (21.25, 19.81) adjacent to the SE corner of the cliff
- Without the fix, the BFS would direct flow UP into the cliff face and the monster would sit at x≈15.5 forever

### `scn_real_save_stress` (new perf + liveness scenario)

- Loads `user://saves/slot_0/run_backup.json` (the "right save" the user asked for — not the autosave)
- Forces fight at round 6 (PERF_ROUND — chosen so the 17-building factory survives the sample window; round 15 wiped it in <3s and everything fell to IDLE)
- Tracks: fps rolling avg, frame delta avg/p95/max, per-frame physics cost, move_and_slide cost, stuck monster count (per-monster position history, 3-sec window, <0.5 unit travelled), building count over time
- Runs in `--benchmark` mode (window open, vsync off, time_scale 1x) with NavDebugRenderer enabled so screenshots show flow arrows overlaid on the terrain
- Includes per-spike diagnostic lines with MonsterPerf counters to attribute each >25 ms frame to physics / move_and_slide / flow field compute / sample_factory / find_target / damage_nearby
- Screenshots at 00_loaded, 01_fight_started, 02_fight_midway, 03_fight_after

## Results

**Real-save stress at round 6, 15-20 alive monsters, zoomed camera:**

| Metric | Before (earlier baseline, round 15) | After (this session, round 6) |
|---|---|---|
| FPS avg | 40 | **138.8** (1x timescale) |
| Frame ms avg | 25.29 | **7.03** |
| Frame ms p95 | 27.85 | **15.03** |
| Frame ms max | 51.29 | **127.22** (single 02_fight_midway screenshot capture spike) |
| Frames > 16.7 ms | 100% | **1.2%** |
| Stuck count (end) | 0 (but list showed transient false positives) | **0** on most ticks (transient spikes after building deaths) |

The avg frame drop from 25 → 7 ms isn't purely my fix — most of it is round 6 vs round 15 (15-20 monsters vs 64). The POINT of the fix is the flow arrows now route correctly and the tendril crawler cliff test passes.

**Cliff regression test:**

- `scn_monster_cliff_pathfind`: monster travelled 13.14 world-units around the plateau, ending at (21.25, 19.81). **PASS.** Without the fix, this monster would have head-butted the cliff.

**Screenshots show flow arrows converging toward the factory on the real save terrain instead of leading into walls.** Arrows visible on both elevated and low ground, and diagonally-routed around terrain obstacles.

## Verification

- Parse check: clean
- Unit tests: 33/33 pass
- `scn_terrain_elevation`: pass
- `scn_monster_pathfind`: pass (monster reached dist 1.2 from 10.2)
- `scn_real_save_fight`: pass (swarm reached 0.85 tiles from factory, < 2.0 threshold)
- `scn_monster_cliff_pathfind` (NEW): pass
- `scn_real_save_stress` (NEW): pass, asserts >10 monsters alive during stress window
- `sim_monster_attack_perf`: pass, avg 3.47 ms / p95 5.43 ms / max 11.73 ms (separation OFF) — no regression from last session's numbers

## Important perf finding not in the fix

The baseline run (BEFORE reducing test round) showed that at 64 monsters, **`move_and_slide` eats 10-14 ms/frame — 80% of the physics budget at peak load**. Flow field compute is ~3 calls / 12 sec sample window, total 2.28 ms. Pathfinding is NOT the perf bottleneck at that scale; the CharacterBody3D collision resolution is. The user's "16 fps" symptom is primarily `move_and_slide` dominated, not nav.

Future work to get to 60 fps at 64 monsters under peak load: either MultiMesh-drawn monsters with manual collision, or 30 Hz physics, or swap CharacterBody3D for a lighter collision primitive. Not in scope this session.

## Files changed

**Modified:**
- `scripts/game/nav/nav_layer.gd` — BFS edge check swap + symmetric portal detection + directional portal seeding

**New:**
- `tests/scenarios/scenarios/scn_real_save_stress.gd` — stress scenario for real save
- `tests/scenarios/scenarios/scn_monster_cliff_pathfind.gd` — cliff regression scenario

## Next goals

- If the user still sees stuck monsters in their real save, capture a repro save + exact grid positions so I can reproduce in a focused test.
- Investigate the remaining stuck-count false positives in `scn_real_save_stress`: some monsters on elevated terrain (y=0.5) are being flagged when the terrain IS under STEP_HEIGHT (0.5 < 0.6) and should be fully traversable. Might be a physics-layer issue (CharacterBody3D collider geometry), not a nav issue.
- The 64-monster `move_and_slide` cost is the next big perf lever if monster counts need to scale further.
