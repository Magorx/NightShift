# Phase 3: RoundManager + Build/Fight Cycle

**Date:** 2026-04-06, morning (10:48 - 11:49 MSK)
**Duration:** 1.0h actual (3.5h estimated for P3 cards)

## Work Done

### Phase 3 Cards (all 6 completed)
- **P3.1** RoundManager autoload singleton (`scripts/autoload/round_manager.gd`)
  - BUILD/FIGHT state machine, signals, scaling durations
  - Build: 180s round 1, -15s/round (min 60s). Fight: 60s round 1, +10s/round (max 180s)
- **P3.2** Phase HUD — top-right panel with round counter, phase label, countdown timer, skip button
- **P3.3** Build phase wiring — `set_enabled()` on BuildSystem, factory ticks normally
- **P3.4** Fight phase — factory frozen via `building_tick_system.set_physics_process(false)`, build system disabled
- **P3.5** Day/night visual shift — tweens WorldEnvironment + DirectionalLight3D (not CanvasModulate, since 3D game)
- **P3.6** Sim test `sim_round_cycle` — 15 assertions over 3 full rounds, all passing

### Additional Fixes
- **Terrain shader PBR conversion** — removed `unshaded` render mode, terrain now responds to scene lighting
- **Inverted normals fix** — `generate_normals(true)` was flipping all terrain normals downward; changed to `generate_normals()` (no flip)
- **Light energy rebalance** — ambient 0.4→1.8, directional 0.9→1.5 to compensate for PBR energy conservation
- **Dead code removal** — removed `restore_visuals()` call in save_manager (method never existed on TunnelLogic)
- **Day/night screenshot test** — `sim_day_night_visual` captures day and night screenshots for visual verification

## Commits
1. `ac6835c` — Implement Phase 3: RoundManager + build/fight cycle
2. `1604d17` — Update kanban: move Phase 3 cards to Done
3. `dc60b56` — Fix terrain PBR lighting, polish phase HUD, add day/night screenshot test

## Blockers
None

## Next
Phase 4 cards (P4.1-P4.4): Building HP, night transforms (conveyors→walls, converters→turrets)
