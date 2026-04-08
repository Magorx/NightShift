# Session: Fight-phase lag root-cause diagnosis

**Date:** 2026-04-07
**Start:** 23:01
**End:** 23:18
**Elapsed:** ~0.3h

## Goal

User reported "When monsters start attacking buildings, it causes heavy lags" and asked to analyse whether the cause is pathfinding, collisions, or all-buildings scans. Benchmarked against save 1 (slot_0 — Player 1, 14 buildings, 64×64 map).

## Approach

Wrote a benchmark sim that loads slot_0 directly via `SaveManager.load_run()`, forces RoundManager into the FIGHT phase, and samples per-physics-frame wall time for ~10 s while monsters spawn and walk to the factory. Two passes back-to-back, A/B'ing `monster_separation_enabled`. Hot functions instrumented via a static counter helper so the overhead is one bool check when disabled.

## Results

```
buildings = 14, map_size = 64, ~42 monsters avg
pass               | avg ms | p95 ms | max ms |
separation ON      |   6.12 |  12.77 |  36.94 |
separation OFF     |   3.04 |   6.36 |  33.98 |
```

Top spikes (separation ON):

```
#453  36.94 ms total / 35.59 monster_phys / 33.45 move_slide  alive=65 attacking=2 moving=47
#212  31.87 ms total / 29.87 monster_phys / 28.93 move_slide  alive=41 attacking=0 moving=25
#452  19.95 ms total /  6.66 monster_phys /  5.07 move_slide  alive=65 attacking=2 moving=47
```

Hot function counters over the 10 s pass (separation ON):

```
_apply_separation     24,457 calls   507,030 µs   ← 13% of total CPU
sample_factory_flow   23,105 calls   106,912 µs   ←  3%
ff_compute (BFS)          20 calls    14,015 µs   lazy + cached
_register_factory_goal     2 calls       159 µs
_find_target             522 calls     3,051 µs
_damage_nearby           291 calls     1,799 µs
flush_dirty_sectors        0 calls
```

## Diagnosis

### Spikes are NOT from monster combat

Top spike frames (#212, #453) have **0–2 attacking monsters out of 41–65 alive**. Both spike frames are at the **same indices in both passes** — deterministic, not stochastic. Indices match `SpawnLogicAllTogether._batch_interval`: batches at t=0.5, 4.5, 8.5, ... s into the fight, which lines up exactly with frames 212 (4.5 s) and 453 (8.5 s).

Frame 452 has only 6.66 ms in monster physics but 20 ms total → **14 ms is allocator + node-setup outside monster code**. The next frame (453) jumps to 35 ms in monster physics → all 16 fresh CharacterBody3Ds running their first `_physics_process` with cold caches.

**Root cause:** [scripts/game/spawn_logic_all_together.gd:43-47](../../scripts/game/spawn_logic_all_together.gd#L43-L47) `_spawn_batch()` and [scripts/game/spawn_area.gd:89-94](../../scripts/game/spawn_area.gd#L89-L94) `finish()` spawn many monsters synchronously in a single physics frame. Each spawn instantiates a `tendril_crawler` which loads the .glb model + builds collision + health + debug-path nodes. ~10 nodes × 16 monsters per batch = ~160 allocations + 16 model `load()` calls in one tick.

### Constant baseline overhead — `_apply_separation` is O(N²)

[monsters/monster_base.gd:358-386](../../monsters/monster_base.gd#L358-L386) calls `get_tree().get_nodes_in_group(&"monsters")` per monster per frame. At 42 monsters that's 24 k calls / 507 ms total in 10 s → ~13 % of all frame time. Scales quadratically: ~10 ms/frame at N=100, ~40 ms/frame at N=200. Toggling it off cut average frame time from 6.12 → 3.04 ms (–50 %).

### NOT the cause (cleared)

- Pathfinding flow-field sampling — 5 µs/call, 3 % of avg frame
- Per-building distance scans (`_find_target`, `_damage_nearby_buildings`) — ~5 ms total over 10 s, only 14 buildings
- Sector flow-field BFS — only 20 lazy computes, 14 ms total
- Dirty sector flush — 0 calls
- Goal re-registration — 2 calls / 159 µs total
- CharacterBody3D bunching — disproved by spike-frame state breakdown (≈0 attacking monsters)

## Recommended fixes (ranked)

1. **Stagger batch spawns across frames** — `_spawn_batch()` and `area.finish()` should yield between spawns. Eliminates the ~30 ms spikes outright.
2. **Pre-warm `tendril_crawler.glb`** PackedScene (preload instead of `load()` per spawn) — [tendril_crawler.gd:25](../../monsters/tendril_crawler/tendril_crawler.gd#L25)
3. **Pool dead monsters** — recycle the node graph instead of `new()`
4. **Drop the wasted affordability probe** in `spawn_monster()` — instantiates+frees a temp monster per pool entry per call ([spawn_area.gd:55-60](../../scripts/game/spawn_area.gd#L55-L60))
5. **Replace `_apply_separation`'s `get_nodes_in_group()` with a spatial hash** maintained by `monster_spawner` — drops O(N²) → O(N·k)
6. **Skip `move_and_slide()` in `State.ATTACKING`** — small win, cleans up wasted work

## Files Added (instrumentation, gated under `MonsterPerf.enabled = false`)

- `scripts/game/monster_perf.gd` — new static counter helper
- `tests/simulation/sim_monster_attack_perf.gd` — new benchmark sim, A/B separation, top-spike report

## Files Modified (instrumentation hooks only)

- `monsters/monster_base.gd` — timed `_physics_process`, `move_and_slide`, `_apply_separation`, `_find_target`, `_damage_nearby_buildings`; per-frame state counts
- `scripts/game/monster_pathfinding.gd` — timed `sample_factory_flow`, `_register_factory_goal`
- `scripts/game/nav/nav_layer.gd` — counted `_flush_dirty_sectors`, timed `_get_or_compute_flow_field`

All instrumentation is one bool check when disabled (default off). Zero cost in production builds.

## Next Goals

- Decide which fixes to land. My recommendation: **#1 (stagger spawns) + #2 (preload model)** kill the spike, then **#5 (spatial hash separation)** future-proofs against bigger swarms. Could be a single PERF.1 kanban card "Eliminate fight-phase lag spikes".

## How to re-run the benchmark

```bash
$GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- sim_monster_attack_perf
```

Loads slot_0, runs two 10 s fight passes (separation ON / OFF), prints top spike frames + hot-function counters.
