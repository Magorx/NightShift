# Session: PERF.2 — fight-phase lag fixes

**Date:** 2026-04-07
**Start:** 23:24
**End:** 23:40
**Elapsed:** ~0.25h (planned 1.5h — fast iteration via the existing benchmark)

## Goal

Implement all 6 fixes from the PERF.2 diagnosis (`docs/progress/2026-04-07_2301_fight_lag_diagnosis.md`):

1. Stagger batch spawns across frames
2. Preload `tendril_crawler.glb` PackedScene
3. **MonsterPool** — per-type object pool with lazy growth (size 8 → double on demand → hard cap 64), per the user's spec
4. Drop wasted affordability probe in `SpawnArea.spawn_monster`
5. Spatial-hash separation (replace `get_nodes_in_group` O(N²) per frame)
6. Skip `move_and_slide` in `State.ATTACKING`

## Results — `sim_monster_attack_perf` at round 15 (~41 monsters avg, ~130 spawned over fight)

| Metric | Original | After fixes | Δ |
|---|---|---|---|
| separation ON avg | 6.12 ms | **3.43 ms** | **-44%** |
| separation ON p95 | 12.77 ms | **6.43 ms** | **-50%** |
| separation ON max | 36.94 ms | **17.46 ms** | **-53%** |
| separation OFF avg | 7.66 ms | **2.83 ms** | **-63%** |
| separation OFF max | 27.44 ms | **10.84 ms** | **-60%** |
| `_apply_separation` total cost | 507 ms / 10 s | **128 ms / 10 s** | **-75%** |

Avg ~3 ms = ~330 fps theoretical headroom. Separation OFF max is 10.84 ms — well under the 16.7 ms 60-fps frame budget. ON max is 17 ms — right at the budget; one occasional dropped frame at peak load.

The deterministic ~30 ms spikes at frames 212/453 (batch-spawn moments) that the diagnosis identified are gone.

## Files Added

- `scripts/game/monster_pool.gd` — per-type object pool with capacity doubling 8 → 16 → 32 → 64
- `scripts/game/monster_separation_grid.gd` — spatial hash, rebuilt once/frame, 3×3 cell window query
- `scripts/game/monster_script_info.gd` — static cache for per-type metadata (currently `budget_cost`)

## Files Modified

- `monsters/monster_base.gd` — `reset_for_spawn` / `prepare_for_pool` / `_pool` ref / `_finish_death`. Refactored `_apply_separation` to query the spatial hash with a reusable scratch array. Skip `move_and_slide` in `ATTACKING` while `is_on_floor`. Lazy-resolve spawner via parent walk.
- `monsters/tendril_crawler/tendril_crawler.gd` — `preload(...)` instead of `load()` per spawn
- `scripts/game/monster_spawner.gd` — owns `monster_pool`, `separation_grid`, `_spawn_queue` (drained at `MAX_SPAWNS_PER_FRAME = 2/tick`). `process_physics_priority = -10` so the spatial hash is built before any monster's physics. Pooled monsters released back to pool in `_despawn_remaining`. Signal-connect guard for reuse.
- `scripts/game/spawn_area.gd` — uses `pool.acquire(...)`, add_child only when not already parented, calls `monster.reset_for_spawn()` after position. `finish()` enqueues spawns. Cached cost via `MonsterScriptInfo`.
- `scripts/game/spawn_logic_all_together.gd` — `_spawn_batch` enqueues into the spawner queue
- `scripts/game/spawn_logic_one_by_one.gd` — same enqueue pattern
- `scripts/game/health_component.gd` — `revive()` now emits `healed` so `HealthBar3D` refreshes for pooled monsters
- `tests/simulation/sim_monster_attack_perf.gd` — bumps `RoundManager.current_round = 15` so the benchmark uses realistic monster counts (round 1 only spawns ~5 monsters, would mask the optimisations)
- `docs/kanban/BOARD.md` — moved PERF.2 into Done with full breakdown

## Pool design notes

User spec: "size 8 per type, double when limit breached, hard cap 64". Implemented as:
- `INITIAL_CAPACITY = 8`, `HARD_CAP = 64`
- Lazy population: `total = 0` initially, instances created on first acquire
- When the free list is empty AND `total < capacity`: create new
- When `total == capacity` AND `capacity < HARD_CAP`: `capacity *= 2`, then create
- When `capacity == HARD_CAP` AND free is empty: return null → spawn skipped, budget preserved (the spawner retries next frame once a monster has died)

Pooled monsters stay parented to `monster_layer` after release. `prepare_for_pool` hides them, disables physics, removes from monsters group; `reset_for_spawn` reverses all that. The reason: `remove_child` + `add_child` was forcing the physics server to deregister and re-register the body, which showed up as a measurable cost on the spawn frame. Keeping nodes parented avoids it entirely.

A monster knows if it's pooled via `_pool` (set by `acquire`); on death it calls `prepare_for_pool() + _pool.release(self)`. Legacy / sim paths that don't go through the pool keep the original `queue_free` fallback.

## Verification

- **Parse check:** clean
- **Unit tests:** 33 passed, 0 failed
- **Scenarios run:**
  - `scn_turret_kills_monster` ✓
  - `scn_monster_attack_building` ✓
  - `scn_monster_pathfind` ✓
  - `scn_monster_spawn` ✓
  - `scn_fight_phase_end` ✓
  - `scn_full_combat_loop` ✓ (3 rounds completed)
  - `scn_monster_attack_player` ✗ — pre-existing failure on origin/main (player HP=0 at start, unrelated)
- **Benchmark:** see results table above

## Bugs hit during implementation

1. **Pool counter inflation between rounds.** First version of `_despawn_remaining` was queue_free'ing pooled monsters, leaving the pool's `total` counter at HARD_CAP with no actual instances → next round couldn't acquire any. Fix: release pooled monsters back to the pool instead of free.
2. **Duplicate signal connect.** `_on_area_monster_spawned` was re-connecting `died → _on_monster_died` on every reuse. Fix: guard with `is_connected`.
3. **physics-server registration cost on `add_child`.** First version of pool `release()` did `remove_child` + on next acquire the spawner did `add_child`, which forced the physics server to register the body — showed up as a per-spawn cost spike. Fix: keep node parented in the pool, just hide+disable.
4. **Spawn budget bumped to 300.** Realised mid-session that the `_calculate_budget` formula had been changed to `300.0 * round_num` (probably during the previous diagnosis session for stress testing). That made the scenario tests flood the world with monsters and break. Reverted to the original `10.0 * round_num` and updated the benchmark to bump `current_round = 15` so the benchmark still tests realistic load without affecting gameplay.

## Future work (not part of this card)

- Spike during batch drains (~17 ms with separation ON) is from new monsters' first physics tick. Could be reduced further by warming the bodies (one zero-velocity move_and_slide) at fight start, or by raising MAX_SPAWNS_PER_FRAME and accepting a smoother distribution.
- The `move_and_slide` skip in `ATTACKING` is conservative — it only kicks in when also on floor. Could be more aggressive once we trust the floor state.

## Next Goals

- The user can now play heavier rounds (15+) without lag spikes.
- Monitor the pool hard-cap-hit log in real playtests; if 64/type is too tight at later rounds, raise it.
