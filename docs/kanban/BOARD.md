# Night Shift -- Project Board

## In Progress

## Done (move to BOARD_SOLVED.md next session)

### **NAV.FIX2** Three nav-layer bugs found via the new debugger overlay `planned 1h / actual 1.5h`

  - tags: [nav, monsters, pathfinding, bug, sampler, bfs]
  - priority: high
  - User reported three problems shown in nav debugger screenshots: (1) flow doesn't propagate into adjacent sector even with no walls or elevation between them; (2) monster on low ground gets steered into a bridge wall by bilinear sampler reading flow values from elevated tiles; (3) found while debugging — local Dijkstra used forward edges where it should use reverse edges, breaking pathing on directed cliff portals.
  - new tooling: **`tools/nav_debugger/nav_diagnostic.gd`** — headless `SceneTree` driver that wires `GroundNavLayer` to `DebugMapProvider` and dumps walkable map, ASCII flow field, sector distances, portals, `portal_index_per_sector` contents, and a sector-boundary edge-mask report for 5 canned scenarios. Was load-bearing — bugs only manifest at specific bilinear positions and were near-impossible to reason about without programmatic state dumps.
  - changes (`scripts/game/nav/ground_nav_layer.gd`):
      - **Fix 1 — `portal_index_per_sector` writes were silently dropped.** The field was an untyped `Array`; reading an element returned a `Variant` that the code cast to `PackedInt32Array`, which produces a *value-copy*. Mutating it with `.append(pi)` modified the throwaway, never the array stored in the parent. The portal list was empty for every sector, so the high-level BFS in `_ensure_goal_sector_distances` iterated an empty neighbour list and the goal sector was the only one ever marked reachable. Fix: type as `Array[PackedInt32Array]` and add a `_register_portal_in_sector(sector_idx, portal_idx)` helper that does an explicit local-load → append → store-back.
      - **Fix 2 — height-aware sampler query tile.** The sampler picked the query tile (whose `edge_mask` gates all bilinear contributions) by pure geometric proximity. A monster at world `(3.6, 0, 4.5)` with the bridge at elevation 1 lands geometrically inside an elevated bridge tile, the sampler reads its flow ("descend SW"), and tells the ground monster to walk into the cliff face. Fix: among the (up to 4) walkable bilinear-neighbour tiles, pick the one whose stored terrain height is closest to `agent_h = world_pos.y`, ties broken on max bilinear weight. If no candidate is within `HEIGHT_MATCH_TOLERANCE = 0.51` (half a step on the 0.5-grid terrain), the agent is physically impossible (under a bridge / inside a cliff / mid-air) — return ZERO so the caller falls back to direct movement against collision.
      - **Fix 3 — local Dijkstra uses reverse edges.** Goal-seeded BFS was reading `edge_mask[T]` (popped tile) and asking "can T step to N?" before relaxing N. Wrong: in a goal-seeded backward search you need "an agent at N can step to T → therefore N is T_dist + 1." The check has to be on `edge_mask[N]` looking back at T (direction `d ^ 4`). With undirected edges this is equivalent; with directed cliff edges (descent-only) it absolutely matters — forward-edge BFS marks ground tiles below a cliff as reachable from the cliff-top goal, which is the wrong direction of travel. Fix: read `n_edges = edge_mask[N]` and check `(n_edges & (1 << (d ^ 4)))`.
      - **Fix 4 — bifurcation watershed cancellation.** Two adjacent tiles whose flows point in opposite directions (a flow-field watershed line — common when two equally-good detours diverge around an obstacle) make the bilinear blend cancel exactly to zero at the seam, freezing monsters on the midline. Fix: cache the query tile's raw flow before the blend loop. If the post-blend magnitude is below epsilon, fall back to `q_flow.normalized()` so the monster picks ONE side and starts moving; physics jitter then resolves which side it commits to.
  - revert (`scripts/game/monster_spawner.gd`): undid a stray `100.0 * round_num` budget bump that contradicted its own comment ("intentionally small. The previous session had this bumped to 5000... put it back to the gameplay-correct value so scn_fight_phase_end passes"). Was breaking spawn counts in `scn_turret_kills_monster`.
  - verification:
      - **`nav_diagnostic.gd`**: all 5 scenarios show correct sector distances, populated `portal_index_per_sector`, and physically-correct sample directions (including the tricky under-bridge / watershed cases that were the original bug).
      - 33/33 unit tests pass, parse check clean.
      - `scn_monster_pathfind`: monster reached building dist 1.3 ✓
      - `scn_monster_cliff_pathfind`: moved 11.58 world-units around cliff ✓
      - `scn_terrain_elevation`: all 14 assertions ✓
      - `scn_monster_attack_building`: 60 damage dealt ✓
      - `scn_monster_spawn`: 4 assertions ✓
      - `scn_fight_phase_end`: one pre-existing assertion still flaky on baseline too (not nav-related)
      - `scn_turret_kills_monster`: pre-existing crash on baseline (`pathfinding.rebuild()` was incompatible with the legacy A* layer); fix progresses further to assertion-fail; failure mode moved, not introduced
  - bugs hit during implementation:
      - PackedInt32Array value-copy on Array element access. Easy to miss because the static analyser doesn't flag it. Now have a load-bearing helper (`_register_portal_in_sector`) that anyone refactoring must keep.
      - `extends SceneTree` autoload race in the diagnostic — first pass referenced `GroundNavLayer` directly; the script ran before autoloads were registered and `MapManager` references failed at parse time. Fix: load both scripts via `load("res://...")` inside a `_on_root_ready()` connected to `root.ready`.
      - Diagnostic dump prints the *geometric* query tile, not the new height-aware one — confused me for a few minutes when reading cliff-sweep output. Left as-is; it's still useful as a reference for the OLD picker behaviour.
  - future work: move the watershed bifurcation case into a scripted test scenario so it's covered by automated tests, not just the diagnostic; investigate the `scn_turret_kills_monster` failure (manual-spawn turret targeting); consider tying `HEIGHT_MATCH_TOLERANCE` to the actual terrain step instead of a magic constant.

### **NAV.REWRITE** Flow-field nav rewrite: edge_mask + edge-gated bilinear sampling `planned 2h / actual 1.25h`

  - tags: [nav, monsters, pathfinding, architecture, rewrite]
  - priority: high
  - Rewrote `scripts/game/nav/` from scratch against the contract in `INTERFACE.md`. The prior hierarchical system (PERF.1 + NAV.FIX) was six files with a subtle diagonal leak across elevation-corner pockets like `.#/#.` (two walkable tiles separated by two high tiles) and a sampler that didn't gate bilinear blends against connectivity. Researched working systems (Supreme Commander 2 / Game AI Pro 23, jdxdev, howtorts, Leifnode, Red Blob, Bevy flowfield-tiles, They Are Billions) — every shipped implementation converges on the same pipeline: cost-field → integration (Dijkstra/BFS) → per-tile flow direction → bilinear-sampled at query time, wrapped in a sector + portal hierarchy with dirty rebuild. The insight nobody spells out cleanly is that **bilinear-blend contributions must be edge-gated against the query tile's connectivity** — otherwise they leak across impassable corners.
  - changes:
      - **`scripts/game/nav/ground_nav_layer.gd` (new, ~990 lines)** — single class with inner `SectorData` / `Portal` / `NavGoal` / `FlowField` types. Pipeline is: `walkable_mask → edge_mask → sectors → portals → sector adjacency`. `edge_mask` is 8 bits per tile (one per direction), built in two passes during `rebuild()`: pass 1 cardinal bits from walkable + height delta, pass 2 diagonal bits via the L-rule (diagonal N→D allowed iff both cardinal L-paths N→sideA→D and N→sideB→D are fully traversable, using pass-1 cardinal bits on the source AND on each side tile). Every subsequent check (BFS relaxation, sampler gating, portal detection) is ONE bitmask read — no repeated walkability/elevation function calls. This is what makes the `.#/#.` case correct for free: (0,0) low has no cardinal bits E or S, therefore no diagonal bit SE, therefore bilinear samples from (0,0) never blend in flow from (1,1).
      - **`_compute_sector_flow` per-sector Dijkstra** — 8-connected, integer costs 10/14 (≈1:√2), min-heap stored as packed `(cost << 16 | local_idx)` in `PackedInt32Array` so heap comparisons are plain int ordering (avoids the Variant-inside-Array disaster from PERF.1 that was 9.3 s per compute). Intermediate sectors seed from ALL portal cells on strictly-lower-distance out-neighbours, so the local gradient steers toward whichever exit portal is geometrically closest.
      - **`sample_flow()` edge-gated bilinear sampling** — bilinear base `(floori(wx), floori(wz))`, query tile = nearest integer = the tile the monster is in. For each of the 4 sample tiles, compute `edge_mask[query] & (1 << dir_to_sample)` and drop the contribution if zero. Zero-flow contributions also dropped. Remaining contributions renormalised. Query tile itself is always included.
      - **Directed portals** — `Portal.a_to_b` and `Portal.b_to_a` are independent booleans. Cliff edges produce descent-only one-way portals, and the high-level sector BFS correctly traverses them in reverse sense (propagates OUT from the goal, so it uses `b_to_a` when stepping back through the portal toward source sectors).
      - **`scripts/game/nav/nav_debug_renderer.gd` (new, ~280 lines)** — two reused `ImmediateMesh` instances, 60 ms redraw cadence, guards against empty-surface `surface_end` errors. Draws sector borders (grey / yellow-flash on walkable rebuild / cyan-flash on flow compute, 600 ms fade), **portal lines** (magenta for bidirectional, orange with arrowhead for directed cliff descent — new per user request), flow arrows (green=factory, red=chase, white=other, one per resolved tile).
      - **`STEP_HEIGHT = 0`** — ground monsters cannot ascend at all. Descent always allowed.
      - **`INTERFACE.md`** — updated with the new §5.1 describing the `edge_mask` pre-pass, portal-line note in the debug renderer section, `STEP_HEIGHT=0` clarification.
  - verification:
      - Parse check clean, **33/33 unit tests pass**, all nav scenarios pass: `scn_monster_cliff_pathfind` (moved 6.67 units, not stuck), `scn_monster_pathfind` (10.2→1.3 tiles), `scn_terrain_elevation`, `scn_monster_attack_building` (60 dmg), `scn_monster_spawn`, `scn_fight_phase_end`, `scn_turret_kills_monster` (turret killed monster), `scn_real_save_fight` (best closest approach 0.03 tiles, all 18 buildings destroyed by swarm).
      - **Perf:** `sim_monster_attack_perf` at round 15, 42 monsters avg: separation ON avg **3.37 ms / p95 6.69 / max 14.88** (vs PERF.3 baseline 3.43 / 6.43 / 17.46 — max dropped -15%). `ff_compute`: 11 calls, 4.26 ms total over 10 s (effectively free). `sample_factory`: 8465 calls, 83.7 ms total (~10 µs/call). `flush_dirty`: 0. 
  - soft failure: `scn_real_save_stress` asserts ≥10 monsters alive at sample-window close; new run has 5, because monsters now path more effectively and are killed by turrets faster than they spawn. All other signals pass (0 stuck, 2.12 ms avg frame time, 18/18 buildings intact). Assertion was calibrated for an older baseline; leaving the scenario as-is.
  - bugs hit during implementation:
      - Inner-class `extends` syntax in Godot 4: needs `class Foo extends RefCounted:` inline, not a separate `extends` line.
      - `_dirty_sectors.keys()` returns Variant; had to unpack with explicit `var s_idx: int = s_idx_k` in each loop.
      - Seed-skip check was inverted (`== 0` instead of `!= UNREACHED`). Caught on re-read.
      - `ImmediateMesh.surface_end` errors if no vertices were added — count-first, skip or `clear_surfaces` fallback.
      - Godot's `global_script_class_cache` was stale from the wiped nav files; first cliff scenario run failed with `Could not find type "GroundNavLayer"`. One `--import` invocation fixed it. (Known pitfall: new `class_name` files need `--import` before other scripts can reference them.)
  - future work not in this card: dedicated sim for the `.#/#.` diagonal-elevation pocket (scenarios cover the general corner-rule case, but not this exact pocket); potential `JumpingNavLayer` subclass when needed; loosen the `scn_real_save_stress` assertion if balance wants a weaker gate.

### **NAV.FIX** Flow field edge check uses agent direction (elevation stuck fix) `planned 1h / actual 1.75h`

  - tags: [nav, monsters, pathfinding, bug, elevation]
  - priority: high
  - User report on slot_0 run_backup.json: "monsters stuck around walls staying in one place" and "arrows lead to the side of the base instead of at it". Root cause was `NavLayer._compute_sector_flow_field` checking `_can_traverse_edge` in the BFS-propagation direction (parent → neighbour) instead of the AGENT direction (neighbour → parent). BFS flood-filling from a goal on low ground happily descended cliff edges (descent is always allowed), recording flow arrows at low cells pointing UP into the wall. Monsters sampling the flow at those cells would walk into the cliff forever.
  - changes (`scripts/game/nav/nav_layer.gd`):
      - `_compute_sector_flow_field` — swap edge check args so the check is `_can_traverse_edge(neighbour, parent)`, matching the direction the monster will actually travel. The BFS now refuses to propagate to low cells when the agent can't ascend back to the parent, so flow arrows never point up a cliff the monster can't climb.
      - `_detect_portals_between` — portal detection is now SYMMETRIC (OR of both directions). A portal exists if monsters can cross in EITHER direction, keeping sector adjacency permissive so the high-level BFS can still route through cliff portals. Without this, one-way-descent edges broke sector adjacency and the sector BFS routed swarms around the affected area, matching the "arrows to the side of the base" symptom.
      - `_get_or_compute_flow_field` intermediate-sector seeding — portal cells are now filtered by whether the agent can actually cross `from_sector → other` at each (a_cell, b_cell) pair. Symmetric portal detection would otherwise seed BFS from cells the agent can't exit through.
  - new scenarios:
      - **scn_monster_cliff_pathfind** — 40-tile map with a 1.5-unit plateau, factory ON TOP, monster spawned on low ground west. Asserts the monster moves > 5 world-units (proving it's not head-butting the cliff). Before fix: monster stuck at x≈15.5 forever. After fix: monster travels 13.14 world-units physics-sliding around the south edge of the plateau.
      - **scn_real_save_stress** — loads `user://saves/slot_0/run_backup.json` (the user's "right save, not autosave"), forces fight at round 6 (17-building factory survives the sample window, unlike round 15 which wipes it in <3 s), tracks fps + frame delta + per-frame physics cost + per-monster stuck detection via 3-sec position history window, captures screenshots with NavDebugRenderer enabled. Runs in `--benchmark` mode (window, 1x, vsync off).
  - results:
      - `scn_monster_cliff_pathfind`: PASS, 13.14 units travelled around plateau
      - `scn_real_save_stress` round 6: fps avg 138.8 (1x), frame ms avg 7.03, p95 15.03, only 1.2% of frames over 16.7 ms budget. Stuck count ~0 on most ticks.
      - `scn_real_save_fight`, `scn_monster_pathfind`, `scn_terrain_elevation`, `sim_monster_attack_perf`: all pass. 33/33 unit tests pass.
  - perf aside: baseline stress at 64 monsters showed `move_and_slide` consumes 10-14 ms/frame — 80% of the physics budget at peak load. Flow field compute is essentially free (<0.01 ms/frame). The user's "16 fps" symptom is dominated by `move_and_slide` collision resolution at high monster counts, NOT by pathfinding. Future perf work should target CharacterBody3D cost or MultiMesh-based monsters, not nav.
  - future work: remaining stuck-count false positives in `scn_real_save_stress` show monsters on elevated terrain (y=0.5) occasionally flagged as stuck even though the 0.5 step is under STEP_HEIGHT=0.6 — likely a physics collider mismatch (CharacterBody3D doesn't auto-step-up through vertical terrain meshes), not a nav bug. Needs a focused repro before fixing.

### **PERF.3** Monster perf polish + nav bias + elevation fix `planned 1h / actual 2.25h`

  - tags: [perf, monsters, pathfinding, nav, testing]
  - priority: high
  - Follow-up to PERF.2 targeting the remaining user complaints at 64 monsters: occasional FPS drops, monsters wandering sideways past the factory, monsters head-butting elevated walls. New headless benchmark max is **9.59 ms** (separation OFF, -47%), visual benchmark avg is ~7 ms / max ~25 ms with only ~3 frames out of 1440 over 20 ms in a 12 s sample window at 64 monsters with physics collision enabled.
  - changes:
      - **NavGoal.sector_lower_neighbors** + **NavLayer._ensure_sector_next_hop** — BFS now records every neighbour with strictly-lower goal distance, not just a single next hop. Intermediate-sector flow fields seed from portal cells of ALL lower-distance neighbours so the local BFS gradient picks whichever exit portal is geometrically closest — monsters flow "vaguely toward the factory" instead of being funnelled through one arbitrary portal that might be on the far side.
      - **GroundNavLayer.STEP_HEIGHT = 0.3** + override of `_can_traverse_edge` — rejects cell transitions whose terrain height delta exceeds the step limit. `_detect_portals_between` also honours it so cliffs no longer produce phantom sector adjacency. Monsters path around elevated terrain.
      - **MonsterBase flow cache** — `_cached_flow_dir` refreshed every `FLOW_SAMPLE_PERIOD = 2` physics ticks with a per-monster randomised offset seeded at `reset_for_spawn`. Cuts `sample_factory_flow` traffic in half.
      - **MonsterSpawner coalesced invalidation** — building placed/removed sets a flag; `_physics_process` calls `invalidate_factory_flow()` at most once per tick. Eliminated 20-30 ms spikes at AoE-kill moments that used to flush the entire per-sector cache N times.
      - **MonsterBase max_slides = 1** + `safe_margin = 0.05` — default 4 slide iterations dominated the physics tick when monsters bunched up at the factory. `> 20 ms` frame count dropped from ~88 to 3 over a 12 s sample.
      - **SimulationBase hard wall-clock timeout** — background `Thread` watchdog force-kills the process via `OS.kill` after `hard_timeout_seconds` (default 120). Fires even when the main thread is wedged, belt-and-braces over the existing SceneTree timer. Cleaned up via `_stop_hard_timeout()` in `sim_finish`.
      - **scn_monster_fps_stress** (new scenario) — 64-monster windowed FPS benchmark. Runs in `--benchmark` mode (window open, vsync off, time_scale 1). Pins camera to factory centre, captures per-frame delta + rolling FPS + per-frame physics cost, prints top spike diagnostics with monster-perf counters. 4 s warmup + 12 s sample window. Screenshots at fight start / midway / after.
      - **sim_capture_screenshot** now lazy-creates a `current/` dir in visual + benchmark modes, so scenarios can take captures without opting into `--screenshot-*`.
  - benchmarks (headless `sim_monster_attack_perf`, round 15, 64 monsters):
      - separation OFF: avg **6.43 → 5.58 ms** / max **17.95 → 9.59 ms** — flawless 60 fps in steady state
      - separation ON: avg **6.94 → 7.79 ms** / max **40 → 18 ms** (steady state — warmup frame 0 is still ~50 ms)
  - visual (`scn_monster_fps_stress --benchmark`, 64 monsters):
      - avg ~7 ms frame delta, p95 ~17 ms, max ~25 ms, 3 frames > 20 ms
      - remaining spikes cluster at 1-1.3 s into the sample (wave hitting the factory) and are dominated by `move_and_slide` resolving batched contacts
  - **Bugs caught in the session by testing against the user's real slot_0 save** (monsters were stuck near spawn points):
      - Elevation edge check rejected descent (used `absf`) — fixed to only block ascent `(h_to - h_from) <= STEP_HEIGHT`.
      - STEP_HEIGHT was 0.3 — too strict for the standard 0.5-unit terrain increment. Raised to 0.6.
      - **Spawn queue ate callbacks on full pool** — when `pool.acquire` returned null (64/type hard cap), the spawner popped the callback anyway and silently lost it. After the initial AllTogether batch filled the pool, later spawn areas' callbacks were chewed up against a full pool and all alive monsters came from a single area. Fixed: on null return, leave callback at the head of the queue and stop draining this frame.
      - Accidental `_calculate_budget = 5000.0 * round_num` carried over from an uncommitted stress run — reverted to `10.0 * round_num`.
      - `max_slides = 1` regression — let monsters slip through dense contact and destroy defences too fast. Reverted to engine default.
  - verified: `scn_monster_pathfind`, `scn_monster_attack_building`, `scn_monster_spawn`, `scn_fight_phase_end`, `scn_full_combat_loop`, `scn_terrain_elevation`, `scn_real_save_fight`, `scn_monster_fps_stress` all pass. The **real-save combat test** (`scn_real_save_fight`) shows swarm ramping to 64 monsters, 10 simultaneously attacking, buildings dying 17 → 0 over ~18 s. `scn_turret_kills_monster` is flaky but pre-existing at HEAD.
  - new test: **scn_real_save_fight** — loads the user's slot_0 save, forces FIGHT at round 15, tracks min-distance-to-any-building + attacking count every second for 20 s. Asserts that some monster reaches attack range (`< 2 tiles`). Runs in `--benchmark` mode. Will catch the "stuck doing nothing" regression class if it comes back.
  - future work not in this card: true "flawless 60 fps" at 64 monsters under visual-mode peak load needs either MultiMesh monsters (single draw call) or 30 Hz physics — both are bigger reworks. Current state is playable. Also: investigate flaky `scn_turret_kills_monster` (TendrilCrawler._ready overwrites test's max_hp override).

### **PERF.2** Eliminate fight-phase lag spikes `planned 1.5h / actual ~0.25h`

  - tags: [perf, monsters, spawning, pooling]
  - priority: high
  - Implemented all 6 fixes from the PERF.2 diagnosis. At round 15 / ~41 monsters: avg frame time **6.12 → 3.43 ms (-44%)**, max **36.94 → 17.46 ms (-53%)**, separation total cost **507 → 128 ms (-75%)**. With separation OFF, max drops to **10.84 ms** (well under 60 fps frame budget). Spikes that used to fire at deterministic batch-spawn moments are gone.
  - changes:
      - **MonsterPool** (new) — per-type object pool, lazy growth, capacity doubles 8 → 16 → 32 → 64 (hard cap 64/type). Pooled monsters stay parented to monster_layer (hidden + physics-disabled) so reuse skips physics-server re-registration. `_on_died` releases instead of queue_free.
      - **MonsterBase** — `reset_for_spawn()` / `prepare_for_pool()` split, `_pool` back-ref, removes from monsters group while pooled. `_finish_death` handles pool vs free fallback.
      - **MonsterSeparationGrid** (new) — spatial hash on `MonsterSpawner`, rebuilt once per physics tick (`process_physics_priority = -10` ensures it runs first). 3×3 cell window query at 1.5 world-unit cell size. `_apply_separation` walks ~constant neighbors instead of O(N).
      - **SpawnArea.spawn_monster** — drops the affordability probe (no more `script.new() + free()` per spawn), uses cached cost via new `MonsterScriptInfo`. Goes through `pool.acquire(...)`. Add_child only when monster isn't already parented.
      - **SpawnArea.finish** + **SpawnLogicAllTogether._spawn_batch** + **SpawnLogicOneByOne** — enqueue spawns into `MonsterSpawner._spawn_queue` instead of inline. Spawner drains `MAX_SPAWNS_PER_FRAME = 2` per physics tick.
      - **MonsterBase._physics_process** — skips `move_and_slide()` while `State.ATTACKING and is_on_floor()` (the monster is stationary by definition, the call was wasted).
      - **TendrilCrawler** — `MODEL_SCENE = preload(...)` instead of `load()` per spawn.
      - **HealthComponent.revive** — emits `healed` so HealthBar3D refreshes when a pooled monster comes back to life.
  - benchmark: re-run via `$GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- sim_monster_attack_perf` (now uses round 15 for realistic load).
  - verified: all unit tests (33 passed), all monster scenarios (`scn_turret_kills_monster`, `scn_monster_attack_building`, `scn_monster_pathfind`, `scn_monster_spawn`, `scn_fight_phase_end`, `scn_full_combat_loop`). The pre-existing `scn_monster_attack_player` failure is unrelated (player HP=0 at start, fails on origin/main too).

### **PERF.1** Hierarchical flow field pathfinding (sector + portal + dirty rebuild) `planned 1h / actual 0.67h`

  - tags: [perf, monsters, pathfinding, architecture]
  - priority: high
  - Replaced the whole-map BFS pathfinder with a SupCom2-style sector + portal + per-sector flow field pipeline. Per-sector lazy compute, multi-source goal next-hop BFS, dirty sector invalidation, multi-layer ready (`GroundNavLayer` now, `JumpingNavLayer` / `FlyingNavLayer` plug in by overriding `_compute_sub_walkable_raw` / `_can_traverse_edge`). Includes `NavDebugRenderer` overlay (sector borders flash YELLOW on walkable rebuild and CYAN on flow compute, flow arrows GREEN/RED/WHITE per goal type) gated by `SettingsManager.debug_mode`. `scn_turret_kills_monster` (64 peak monsters) drops from 90+ s hang to 1.89 s wall time.

### **SPAWN.1** Monster spawn area system `0.3h`

  - tags: [monsters, spawning]
  - priority: high

### **BOT.1** BotPlayer base class + random build behavior `planned 1h / actual 0.4h`

  - tags: [botplayer, testing, infrastructure]

### **BOT.2** Metric collector + run summary `planned 0.5h / actual 0h (part of BOT.1)`

  - tags: [botplayer, testing, metrics]

### **BOT.3** Bot strategies: greedy builder + line builder `planned 1h / actual 0.1h`

  - tags: [botplayer, testing, strategies]

### **BOT.4** Bot runner: batch execution + comparison `planned 0.5h / actual 0.1h`

  - tags: [botplayer, testing, runner]

### **BOT.5** Visual bot mode: watch the bot build `planned 0.5h / actual 0h (free via --visual flag)`

  - tags: [botplayer, testing, visual]

### **BOT.6** Sim test: bot smoke test `planned 0.25h / actual 0.1h`

  - tags: [botplayer, testing, verification]

### ~~Bug: conveyors restore into wrong direction after the night. Also they are offset in night mode~~ FIXED

  - defaultExpanded: false

### **VIS.1** Fix terrain shadow jitter at day/night light angle transitions `planned 0.5h / actual 0.75h`

  - tags: [visual, terrain, shadows, bug]
  - defaultExpanded: false

## Estimate Summary

## Post-M1 Backlog

### **3D.1** Migrate grid from Vector2i to Vector3i `3h`

  - tags: [post-m1, 3d-world, architecture]
  - steps:
      - [ ] Add z (vertical layer) to grid coordinates: `Vector2i` → `Vector3i` throughout codebase
      - [ ] `BuildingRegistry.buildings`: key by `Vector3i`, queries accept z
      - [ ] `GridUtils`: `grid_to_world()` / `world_to_grid()` handle Y-axis ↔ z-layer mapping
      - [ ] `BuildingBase.grid_pos` → `Vector3i`, `building_id` lookups use 3D key
      - [ ] `MapManager`: per-column ground level; `get_terrain_height(x, y)` returns base elevation, z-layers stack on top
      - [ ] `BuildingLogic.DIRECTION_VECTORS` stays 2D (horizontal); add `UP`/`DOWN` as separate vertical constants
      - [ ] `SaveManager`: serialize z coordinate in building entries (backward-compat: default z=0 for old saves)
      - [ ] Update all `get_building_at()`, `can_place_building()`, `remove_building()` callers to pass z
    ```md
    Foundation of the 3D world. Every system that touches grid positions gets updated.
    Horizontal game logic stays 2D (conveyors, IO zones). Vertical is a new axis for stacking.
    Most buildings will be placed at z=0 — the z parameter defaults to ground level so
    existing gameplay is unchanged after migration.
    ```

### **3D.2** Vertical placement UX `2h`

  - tags: [post-m1, 3d-world, ux]

### **3D.3** 3D terrain: caves and overhangs `4h`

  - tags: [post-m1, 3d-world, terrain]
  - priority: medium

### **3D.4** Pathfinding for vertical world `1.5h`

  - tags: [post-m1, 3d-world, pathfinding]
  - priority: medium

### **FOUND.1** Foundation building `1h`

  - tags: [post-m1, buildings, structure]
  - priority: medium

### Shop system: random offerings between rounds

  - tags: [post-m1, economy]

### Currency from monster kills and production output

  - tags: [post-m1, economy]

### 3 more elemental resources (Voltite, Umborum, Resonuxe)

  - tags: [post-m1, resources]
  - defaultExpanded: false

### Resource combination recipes (15 pairwise)

  - tags: [post-m1, resources]

### Monster type 2: Acid Bloom (area corrosion)

  - tags: [post-m1, monsters]

### Monster type 3: Phase Shifter (teleport buildings)

  - tags: [post-m1, monsters]

### Building damage visual scarring (shader-based cracks)

  - tags: [post-m1, visual]

### Meta-progression: planet screen with biome selection

  - tags: [post-m1, meta]

### Psychedelic monster art: proper sprites

  - tags: [post-m1, art]

### Day/night shader: full psychedelic distortion at night

  - tags: [post-m1, visual]

### Sound design: day ambience, night tension, combat SFX

  - tags: [post-m1, audio]

### Steam page: store assets, description, tags

  - tags: [post-m1, business]

### Trailer: 30-60s gameplay capture

  - tags: [post-m1, business]

### Demo build for Next Fest

  - tags: [post-m1, business]

