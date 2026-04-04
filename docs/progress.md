# Night Shift -- Progress Log

Updates appended after each work session. Tracks velocity for timeline projections.

## Session Log

### Session 0 -- Design & Planning
- **Date**: 2026-04-03
- **Hours**: ~3h (evening session)
- **Work done**:
  - Market analysis of 20 successful indie games (docs/indie_game_market.md)
  - Evaluated 2 game concepts, selected "Night Shift"
  - Core design: elemental resources, factory-as-defense, build/fight/shop cycle
  - Identified direct competitor (Tower Factory) and market positioning
  - Set up project tracking system (board, design doc, progress, business)
- **Decisions made**:
  - 30-min session-based roguelite with factory building
  - 6 elemental resources with 15 pairwise combinations
  - Conveyors = walls, converters = turrets at night
  - Psychedelic aesthetic (not horror)
  - 128x128 fixed map, 8-slot inventory
  - Meta-progression via planet biome map
  - Reuse Factor's engine (pull system, conveyors, building framework)
- **Blockers**: None
- **Next session goal**: Begin M1 prototype -- strip Factor systems, implement round manager

### Session 1 -- Transition Planning
- **Date**: 2026-04-04
- **Hours**: ~1h (planning session with Claude)
- **Work done**:
  - Full codebase audit: mapped all files to keep, remove, and create
  - Identified 14 files referencing ResearchManager, 11 for ContractManager, 14 for EnergySystem
  - Created 6-phase transition plan with 30 tasks, ordered by dependency
  - Each task has specific file paths, function changes, and validation steps
  - Estimated 48h total (~16 sessions) for M1 core loop prototype
  - Identified 3 highest-risk tasks: energy removal, pathfinding performance, turret behavior
  - Updated BOARD.md with full kanban breakdown
  - Created TRANSITION_PLAN.md with detailed file-level change specs
- **Decisions made**:
  - Keep 8 building types for M1: conveyor, drill, smelter, splitter, junction, tunnel, sink, source
  - Delete 24 building types, 4 autoload singletons, energy system
  - Phase order: Strip -> Resources -> RoundManager -> Transform -> Monsters -> Polish
  - M1 uses creative_mode (free placement), no shop system yet
  - 3 elemental resources for M1: Pyromite, Crystalline, Biovine (other 3 deferred)
  - 1 monster type for M1: Tendril Crawler
- **Blockers**: None
- **Next session goal**: P1.1-P1.3 -- strip ResearchManager, ContractManager, AccountManager, TutorialManager

### Session 2 -- Phase 1: Strip Factor Systems
- **Date**: 2026-04-04
- **Hours**: ~1h (morning session, 11:20-12:27 MSK)
- **Work done**:
  - P1.1: Gutted ResearchManager -- removed from game_manager, save_manager, build_system, game_camera, buildings_panel. Deleted research_manager.gd, research_panel.gd, research_lab/ folder
  - P1.2: Gutted ContractManager -- removed from game_manager, save_manager, hud. Simplified sink to accept all items. Deleted contract_manager.gd
  - P1.3: Gutted TutorialManager -- removed from game_world, hud. Deleted tutorial_manager.gd, tutorial_panel.gd. **AccountManager retained** (needed for save slots)
  - P1.4: Gutted EnergySystem -- removed energy_system var, energy registration/unregistration, energy link mode from build_system, energy checks from converter. Deleted scripts/energy/ folder, 6 energy building folders, building_energy.gd, energy_node.gd
  - P1.5: Deleted 24 unused building folders (assembler, centrifuge, chemical_plant, press, etc.). Removed research panel, recipe browser, tutorial panel, building info panel from HUD scene
  - P1.6: Updated simulation_base.gd (removed contract/tutorial setup). Deleted 8 obsolete sims. All kept sims pass (conveyor_transport, unified_pull, splitter, merge_and_source_sink)
  - Fixed player.gd energy_link_mode reference crash
  - Cleaned up stress_test_generator (removed energy infrastructure)
  - Simplified settings_menu (removed tutorial reset)
- **Stats**: 286 files changed, +265 / -26,278 lines
- **Decisions made**:
  - AccountManager kept (user requested) -- save slots still useful
  - Camera zoom range fixed at 0.5-3.0 (was research-gated)
  - Converters work without power (energy_cost ignored)
  - Sinks accept all items (no contract filtering)
- **Blockers**: None
- **Next session goal**: P2.1-P2.5 -- new elemental resource system (3 resources, recipes, world gen)

### Session 3 -- Phase 2: Elemental Resource System
- **Date**: 2026-04-04
- **Hours**: ~0.5h (morning session, 12:30-12:58 MSK)
- **Work done**:
  - P2.1: Created 3 elemental resources (pyromite, crystalline, biovine) + 3 combo items (steam_burst, verdant_compound, frozen_flame). New item atlas with 6 pixel art sprites (unique silhouettes). Deleted 63 Factor items
  - P2.2: Created 3 smelter recipes (2-input elemental combinations). Deleted 58 Factor recipes
  - P2.3: Rewrote world_generator.gd for 128x128 arena -- 3 deposit types at 3 distance tiers (close/medium/far), noise walls with distance-based density creating natural chokepoints, stone veins, connectivity guarantee. Updated TileDatabase
  - P2.4: Updated all 9 BuildingDefs -- removed build_cost for free placement, removed iron_plate references. Updated all code references (source, extractor, player, build_system, stress_test_generator, hud)
  - P2.5: New sim_elemental_flow.gd testing full drill→conveyor→smelter→sink with 2-input recipes. Both steam_burst and verdant_compound chains verified
  - Fixed simulation exit hang: reset Engine.time_scale before quit() to prevent getting stuck in physics batch
  - Added sim_map_size=64 to simulation_base for fast test execution (game default is 128)
  - Updated sim_smelter_converter for 2-input recipes
- **Stats**: 151 files changed, +952 / -5,444 lines. All 8 sims pass
- **Decisions made**:
  - 6 items total for M1 (3 raw + 3 combo), not just 3+1 as originally planned
  - All deposits infinite (-1 stock) -- no biomass finite mechanic
  - Combo names: steam_burst (fire+ice), verdant_compound (ice+nature), frozen_flame (fire+nature)
- **Blockers**: None
- **Next session goal**: P3.1-P3.6 -- RoundManager, phase HUD, build/fight cycle, day/night visuals

### Session 4 -- Isometric Conversion Planning
- **Date**: 2026-04-04
- **Hours**: ~0.3h (afternoon session, 13:05-13:26 MSK)
- **Work done**:
  - Researched Godot 4.x isometric approaches: isometric TileMapLayer, 3D billboard sprites, oblique 3/4 view
  - Evaluated 3 options: oblique 3/4 (Graveyard Keeper style), dimetric isometric (Factorio style), 3D+billboard (Don't Starve style)
  - Decision: dimetric isometric (Option B) for strongest visual hook / viral potential
  - Full codebase audit: found 80+ coordinate conversions across 26 files, 16 duplicate TILE_SIZE constants, hardcoded 32 values in shaders and tests
  - Created 9-card Isometric Phase (ISO.1-ISO.9) on kanban board, inserted before Phase 3
  - Critical path: centralize coord math → switch projection → (art + code fixes parallel) → integration test
- **Decisions made**:
  - Dimetric 2:1 diamond grid (64x32 tiles) over oblique rectangular or 3D billboard
  - De-risk via GridUtils centralization before any visual changes
  - Y-sort replaces manual z_index layering
  - 4 rotation sprite variants per building (isometric shows different faces)
- **Blockers**: None
- **Next session goal**: ISO.1 -- centralize all coordinate math into GridUtils autoload

---

## Velocity Tracking

| Metric | Value | Notes |
|--------|-------|-------|
| Total sessions | 4 | |
| Total hours | 8 | |
| Factor baseline | ~42h over 2 weeks | 3h/day evenings |
| Estimated M1 hours | 40-60h | ~2-3 weeks at 3h/day |
| Estimated M2 hours | 40-60h | ~2-3 weeks at 3h/day |

*Velocity data will become more accurate after 3-4 coding sessions.*
