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

### Session 5 -- Isometric Conversion (ISO.1-ISO.9)
- **Date**: 2026-04-04
- **Hours**: ~0.5h (afternoon session, 16:10-16:44 MSK)
- **Work done**:
  - ISO.1: Created GridUtils autoload -- centralized 80+ coordinate conversions from 28 files into 7 static functions. Removed 14 duplicate TILE_SIZE constants. All sims pass.
  - ISO.2: Switched GridUtils to isometric diamond projection (64x32 dimetric). grid_to_world/world_to_grid use isometric transform. TileSet configured with TILE_SHAPE_ISOMETRIC, TILE_LAYOUT_DIAMOND_DOWN. Diamond tile images for terrain.
  - ISO.3: Restructured scene hierarchy with ObjectLayer for y-sort depth sorting. Removed manual z_index layering.
  - ISO.4: Updated BuildSystem for diamond grid -- diamond grid overlay, isometric ghost preview, diamond destroy area visualization.
  - ISO.5: Updated conveyor/junction/splitter/tunnel item paths for isometric. Entry/exit points use GridUtils.grid_offset. MultiMesh quad sizing updated to 64x32.
  - ISO.6-8: New isometric terrain atlas (512x480, 8x15 grid of 64x32 diamonds). New isometric conveyor atlas (256x192, 4x6 grid). Updated item sprites (slightly less cartoonish). Building sprites kept at 32x32 (functional, art upgrade post-M1).
  - ISO.9: Full verification -- 45 unit tests for GridUtils coordinate math, all 9 simulations pass. Critic review found 5 issues, all fixed: diamond collision shape, player conveyor push direction, dead parameters, stale comments.
  - Fixed building_def.gd scene parsing (SCENE_CELL_SIZE=32 for .tscn files vs display TILE_WIDTH=64)
  - Fixed sim_player.gd spawn position test for isometric center
  - Added Aseprite Lua generation scripts for terrain/conveyor/item art
- **Stats**: ~30 files changed across 6 commits. 45 unit tests + 9 simulations all pass.
- **Decisions made**:
  - Building sprites stay 32x32 for M1 (top-down in iso world is acceptable, upgrade post-M1)
  - Minimap uses top-down grid view (standard for iso games)
  - SCENE_CELL_SIZE constant separates scene-file parsing from display tile size
- **Doubts for user clarification**:
  - Building sprite art: currently top-down 32x32 in isometric world. Looks functional but not polished. Should we invest time now or wait for post-M1?
  - Stress test sim still fails item delivery (pre-existing issue, not related to iso conversion). Should we investigate?
  - Player movement is still in screen-space (WASD moves in screen directions, not grid directions). Is this desired for isometric?
  - Conveyor shader highlight stripe effect uses FRAGCOORD which is screen-space -- looks different in isometric. Worth adjusting?
- **Blockers**: None
- **Next session goal**: P3.1-P3.6 -- RoundManager, phase HUD, build/fight cycle

### Session 6 -- Art Pass: Elevation & Depth (ART.1-ART.4)
- **Date**: 2026-04-04
- **Hours**: ~2h (evening session, 18:56-20:57 MSK)
- **Work done**:
  - ART.1: Rewrote terrain atlas with front-edge depth, raised ore formations, textured walls
  - ART.2: Converted all 7 buildings to isometric. Created new generate.lua for splitter, junction, tunnel
  - ART.3: Rewrote conveyor atlas, fixed tiling (removed ELEV side walls), added UV rotation in shader for correct ridge direction
  - ART.4: Item atlas with volumetric 3D shading, 8 tones per item
  - Created shared tools/iso_box.lua module for 3D isometric box geometry
  - Multiple iteration rounds on drill+source: flat diamond → 3D box → critic review → brown palette + derrick/hopper
  - Fixed building sprite positions: (32,32) → (0,-8) → (0,-11) → (0,-19) as canvas grew
  - Fixed conveyor shader: added direction-based UV rotation so ridges flow correctly
- **Stats**: 48 files changed, +4274 / -1525 lines. ~12 agent runs (artists, programmers, critic)
- **Decisions made**:
  - 3D isometric box approach: roof + left wall + right wall, no diamond platform
  - Brown shared palette for structure, identity colors as accents only
  - Silhouette-breaking features extend above roofline (derrick, hopper)
  - Base layer = shadow only (transparent, terrain shows through)
  - iso_box.lua shared module for geometry reuse
- **Blockers**: Art quality still unsatisfactory -- buildings look like crude boxes despite correct 3D structure. Need better pixel art technique or different approach (3D renders?)
- **Next session goal**: Revisit art approach (possibly 3D pre-renders), then P3.1-P3.6

### Session 8 -- Isometric 3D Geometry Library (LIB.1)
- **Date**: 2026-04-04
- **Hours**: ~0.5h (evening session, 20:54-21:22 MSK)
- **Work done**:
  - LIB.1: Built complete isometric 3D rendering library at `tools/rendering/iso/`
  - 10 Lua modules: config, projection, zbuffer, shading, primitives, mechanical, texture, animation, scene, init
  - 9 shape primitives: Box, Cylinder, Cone, Sphere, Hemisphere, Wedge, Prism, Torus, Arch
  - 6 mechanical parts: Gear (with rotation animation), Pipe, PipeElbow, Piston, Axle, Fan
  - 12 procedural textures: noise, brick, metal plate, grate, rivets, wood grain, corrugated, diamond plate, hex mesh, dithered blend, compose
  - CSG boolean operations: union, subtract, intersect
  - Animation helpers: rotation, oscillation, shake, particle emitter
  - Scene composition with automatic depth-sorted rendering
  - Configurable projection (5 presets + custom tile_ratio/z_scale + raw matrix)
  - 8 example PNGs generated demonstrating all features
  - README.md, CLAUDE.md, examples/README.md documentation
- **Stats**: 14 new files, ~1500 lines of Lua
- **Decisions made**:
  - Projection NOT hardcoded to 2:1 -- configurable via tile_ratio or raw 2x3 matrix
  - Shapes use analytical ray-intersection (box, cylinder, cone, sphere) or slice-sampling (torus, wedge)
  - All modules use Iso._H for aseprite_helper reference (single source of truth)
  - Shapes cache screen bounding boxes at creation time (must recreate after projection change)
- **Blockers**: None
- **Next session goal**: Use iso_geo in building generate.lua scripts to improve art quality, then P3.1

### Session 7 -- Drill & Source Sprites with Iso 3D Library
- **Date**: 2026-04-04
- **Hours**: ~1h (evening session, 21:38-22:38 MSK)
- **Work done**:
  - Rewrote drill and source building sprites from scratch using Iso 3D geometry library
  - **Drill**: industrial rig with dual gears (main + secondary counter-rotating), derrick column with cap/cone, piston assembly, exhaust stack with smoke particles. 4 animation states (idle/windup/active/winddown)
  - **Source**: item dispenser with central corrugated silo, 3-blade spinning fan, output/intake pipes, green energy bands and pulsing indicator lights. 4-frame default animation
  - Fixed critical bug in Iso library: **negated view direction** in config.lua — z-buffer was sorting backwards, causing buildings to render upside-down (bottom faces drawn over top faces)
  - Fixed grid alignment: scene origin OY changed from 60 to 55 to match tile diamond center (sprite position (0,-19) + centered=true → center at pixel 55)
  - Fixed source canvas overflow: scaled shapes down (box 30→22, cylinder r=10→7) to fit 64x72 canvas
  - Fixed drill gear rotation: changed frames_per_rev from 4 to 5 so 8-tooth gear doesn't produce identical frames (90° = 2×45° tooth symmetry)
  - Removed gear center holes, bore hole, status LED per user feedback
  - Reduced idle to single static frame
- **Stats**: ~8 files changed across sprites, .tscn scenes, and iso library
- **Decisions made**:
  - Iso 3D library is the standard for building sprites going forward (replaces iso_box.lua)
  - Scene origin formula: OY = sprite_height/2 + sprite_position_y_offset (36+19=55)
  - Gear tooth count must not divide evenly into frame rotation to avoid symmetry stasis
- **Blockers**: None
- **Next session goal**: Remaining buildings (smelter, splitter, junction, tunnel, sink) with Iso library, then P3.1

---

## Velocity Tracking

| Metric | Value | Notes |
|--------|-------|-------|
| Total sessions | 7 | |
| Total hours | 10.0 | |
| Factor baseline | ~42h over 2 weeks | 3h/day evenings |
| Estimated M1 hours | 40-60h | ~2-3 weeks at 3h/day |
| Estimated M2 hours | 40-60h | ~2-3 weeks at 3h/day |

*Velocity data will become more accurate after 3-4 coding sessions.*
