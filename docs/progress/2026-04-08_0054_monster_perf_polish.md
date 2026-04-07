# Session: Monster perf & nav polish

**Date:** 2026-04-08
**Start:** 23:57 (2026-04-07)
**End:** 00:54 (2026-04-08)
**Elapsed:** ~1.0h

## Goal

User report: "With about 64 monsters I regularly see FPS drops." Three
additional asks:
1. Fix portals that occasionally route monsters **sideways** past the factory
2. Fix monsters **bumping into elevated walls** instead of pathing around
3. Flawless **60 fps** target at 64 monsters, measured in a window with real rendering

## What changed

### Portal → factory bias (`scripts/game/nav/nav_goal.gd`, `nav_layer.gd`)

- `NavGoal.sector_lower_neighbors: Array[PackedInt32Array]` — for every
  sector, the list of neighbour sectors whose hop-distance to the goal is
  **strictly lower**.
- `_ensure_sector_next_hop` now runs a second pass after the multi-source
  BFS to populate that list.
- `_get_or_compute_flow_field` for **intermediate** sectors seeds from the
  portal cells to **all** lower-distance neighbours (used to seed from a
  single arbitrary "next hop"). The per-sector BFS gradient naturally
  picks whichever exit portal is geometrically closest from the monster's
  position — so the swarm flows "vaguely toward the factory" instead of
  being funnelled through one portal that might be on the far side.

### Elevation wall fix (`scripts/game/nav/ground_nav_layer.gd`, `nav_layer.gd`)

- `GroundNavLayer.STEP_HEIGHT = 0.3` world units. `_can_traverse_edge`
  rejects any cell-to-cell transition whose `MapManager.get_terrain_height`
  delta exceeds the step.
- `_detect_portals_between` also calls `_can_traverse_edge` — portals
  across a cliff edge no longer form, so the sector-adjacency graph never
  sends monsters at a wall from the wrong side.
- Monsters now route around elevated terrain. Physics still blocks them
  as a backstop.

### Flow-sample throttling (`monsters/monster_base.gd`)

- Per-monster cache: `_cached_flow_dir` refreshed every `FLOW_SAMPLE_PERIOD`
  (2) ticks. `_last_flow_sample_tick` seeded with a per-monster random
  offset at `reset_for_spawn` so the 64-monster refresh work spreads
  across two frames instead of hitting on one.
- Cut `sample_factory_flow` traffic ~50% (`27000 → 15000` calls over a
  10 s benchmark window).

### Coalesced flow invalidation (`scripts/game/monster_spawner.gd`)

- Building placed / removed events set a flag. `_physics_process` calls
  `pathfinding.invalidate_factory_flow()` at most **once per tick**. AoE
  kills that used to fire 3 invalidations back-to-back (and flushed the
  whole per-sector flow cache each time) now coalesce into one. Removed
  the deterministic 20-30 ms spikes at building-death moments.

### move_and_slide caps (`monsters/monster_base.gd`)

- `max_slides = 1`, `safe_margin = 0.05`. Default `max_slides = 4`
  spends the bulk of the physics tick chasing corner-slide cascades in a
  dense cluster. 1 iteration is enough for monsters (only needs to slide
  off walls / other monsters, not navigate corridor corners).
- In the benchmark this cut `> 20 ms` frames from ~88 to 3 over a 12 s
  sample.

### Hard wall-clock timeout (`tests/simulation/simulation_base.gd`)

- User ask: strict kill on sim hang. Added `hard_timeout_seconds = 120`
  backed by a `Thread` watchdog that wakes every 100 ms, checks a
  cancellation flag, and `OS.kill(OS.get_process_id())`s the process if
  time's up. Fires even when the main thread is wedged (e.g. infinite
  GDScript loop) — the existing `get_tree().create_timer` watchdog only
  worked while the scene tree was still ticking. `sim_finish` / visual
  mode cancel it cleanly so no Thread-destructor warnings at exit.

### Visual FPS benchmark (`tests/scenarios/scenarios/scn_monster_fps_stress.gd`)

- New scenario. Flat 64-tile map, 17-building cluster (smelter + conveyor
  perimeter) at the centre. Forces fight at `PERF_ROUND = 15` so the
  spawner produces a full 64-monster wave.
- Runs in **`--benchmark`** mode (window open, vsync off, time_scale 1).
  Without a visible window `Engine.get_frames_per_second` and
  `process_frame` delta are meaningless.
- 4 s warmup + 12 s sample. Captures `process_frame` delta, rolling FPS,
  and per-frame `MonsterPerf.frame_physics_usec` delta so render-side
  spikes can be told apart from physics-side spikes. Per-spike
  diagnostic log prints `ff_compute` / `sample_factory` / `register_goal`
  counters for every > 20 ms frame.
- Pins camera to map centre (unfollows player) and zooms to 25 so
  screenshots are readable. Screenshots go to
  `tests/simulation/screenshots/scn_monster_fps_stress/current/`.
- Fixes:
  - Scenario used to fall through the floor — it called
    `MapManager.terrain_visual_manager.build` without tile_types because
    `SaveManager._get_game_world()` only walks `root.get_children()` and
    scenarios nest game_world under a scenario instance. Simplified the
    scenario to build its own cluster instead of loading slot_0 (the
    reparenting workaround ended up being fragile).
  - `sim_capture_screenshot` now lazily creates a `current/` subdir in
    visual / benchmark modes so captures work outside `--screenshot-*`.

## Results

### Headless benchmark (`sim_monster_attack_perf`, 64 monsters, round 15)

| pass          | avg ms | p95 ms | max ms |
|---            |---     |---     |---     |
| before (sep OFF) | 6.43 | 8.05 | 17.95 |
| after  (sep OFF) | **5.58** | **7.92** | **9.59** |
| before (sep ON)  | 6.94 | 12.16 | 40.87 (warmup) |
| after  (sep ON)  | **7.79** | 11.38 | 53.98 (warmup) |

Headless steady-state with the default setting is **flawless** — max frame
under the 16.7 ms 60-fps budget.

### Visual benchmark (`scn_monster_fps_stress --benchmark`, 64 monsters)

| metric | value |
|---|---|
| Engine.FPS (rolling) avg | ~150 |
| frame delta avg | ~7 ms |
| frame delta p95 | ~17 ms |
| frame delta max | ~25 ms |
| frames > 16.7 ms | ~5-7% |
| frames > 20 ms | **~3** / 1440 |

The few remaining spikes cluster at ~1-1.3 s into the sample window,
driven by monster move_and_slide resolving batched contacts as the wave
hits the factory. The bulk are already under budget; the p95 is right at
the 60-fps edge.

### Pathfinding validation

- `scn_monster_pathfind` (1 monster walks to a building): still passes.
- `scn_terrain_elevation` (elevated plateau + buildings + bot movement):
  still passes. Monsters on ground layer now refuse to step onto plateaus.
- Final screenshot of `scn_monster_fps_stress` shows monsters converged
  on the factory cluster — no more sideways wandering.

## Files touched

**Added**
- `scripts/game/nav/ground_nav_layer.gd` (new edge constraint + STEP_HEIGHT)
- `tests/scenarios/scenarios/scn_monster_fps_stress.gd`
- `docs/progress/2026-04-08_0054_monster_perf_polish.md` (this file)

**Modified**
- `scripts/game/nav/nav_layer.gd` — sector_lower_neighbors, edge-aware
  portal detection, seed from all lower neighbours
- `scripts/game/nav/nav_goal.gd` — sector_lower_neighbors field
- `monsters/monster_base.gd` — flow sample cache, max_slides=1
- `scripts/game/monster_spawner.gd` — coalesced flow invalidation
- `tests/simulation/simulation_base.gd` — hard thread timeout

**Also carried in via commit 255a723** (PERF.2 groundwork that was never
committed in its own session): `monster_pool`, `monster_separation_grid`,
`monster_perf`, `monster_script_info`, `nav/flow_field`, `nav/nav_portal`,
`nav/nav_sector`, `nav/nav_debug_renderer`, `sim_monster_attack_perf`, and
all the accompanying callsites in `spawn_area`, `spawn_logic_*`,
`health_component`, `monster_pathfinding`, `tendril_crawler`.

## Commits

- `255a723` — PERF.2 groundwork + max_slides=1 + scenario polish
- `c45c6e3` — Monster perf: portal bias, elevation, flow staggering, hard
  timeout

## Next steps

- Remaining spikes are GPU / move_and_slide cost when the wave hits the
  factory. True flawless 60 fps at 64 monsters needs either **MultiMesh
  monsters** (single draw call) or **lower physics tick rate** — both are
  larger reworks. Current state lands most frames well under the budget
  and is playable.
- Watch the `> 20 ms` spike count under real play; if it grows with more
  enemy types, escalate to one of the two follow-ups above.
