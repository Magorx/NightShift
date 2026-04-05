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

### Session 8 -- Scene Lighting System (LIB.2)
- **Date**: 2026-04-04
- **Hours**: ~0.2h (evening session, 22:36-22:48 MSK)
- **Work done**:
  - Added scene-level lighting module (`tools/rendering/iso/lighting.lua`)
  - Three light types: ambient (flat uniform), directional (parallel rays), point (positional with quadratic falloff)
  - All lights support colored tinting via `{r, g, b}` normalized channels
  - Scene API: `scene:add_light()` — lights are scene-level objects alongside shapes
  - Backward compatible: scenes with no explicit lights use default setup matching old shading
  - Fixed 05_textures example: larger boxes (28x28x20), scene-based rendering makes textures visible
  - Added 09_lighting.png example: 6-cell grid showing all light types and colored multi-light scenes
  - Updated CLAUDE.md docs (both project-level and iso library)
  - Added kanban card LIB.2
- **Stats**: 1 new file (lighting.lua), 5 modified files, 16 files in commit
- **Decisions made**:
  - Lights are scene-level (not per-shape) — added to scene like shapes
  - `render_shape()` (quick render) keeps legacy shading path for simplicity
  - Point light attenuation: `(1 - (d/r)²)²` — smooth falloff to zero at radius
- **Blockers**: None
- **Next session goal**: Remaining buildings with Iso library, then P3.1

### Session 9 -- 3D Transition: GridUtils 3D API + Scene Tree Conversion (3D.1-3D.2)
- **Date**: 2026-04-04
- **Hours**: ~0.2h (evening session, 23:13-23:25 MSK)
- **Work done**:
  - **3D.1**: Added 3D API to GridUtils — `grid_to_world_3d()`, `world_to_grid_3d()`, `grid_offset_3d()`, `grid_dir_to_world_3d()`, `tile_transform_3d()`, `map_world_size_3d()`, `map_origin_3d()`. Maps grid (X,Y) → world (X, 0, Z) with 1 unit per tile. Purely additive, 2D functions untouched. 24 new unit tests (85 total).
  - **3D.2**: Converted game_world scene tree from Node2D to Node3D. This was the highest-risk card:
    - `game_world.tscn`: Node3D root, Camera3D orthographic (isometric angle), temp green ground plane, DirectionalLight3D, Node3D object layers, TileMapLayer removed, GridOverlay removed
    - `game_camera.gd`: full rewrite for Camera3D — ortho projection, smooth follow via ground-plane tracking, zoom via camera size
    - `game_world.gd`: extends Node3D, removed _setup_tileset() and all TileMapLayer code, terrain data via GameManager arrays only
    - `game_manager.gd`: building_layer/item_layer typed as Node (generic)
    - `world_generator.gd` + `stress_test_generator.gd`: tile_map parameter nullable
    - `building_popup.gd` + `minimap.gd` + `hud.gd`: Camera type hints relaxed for Camera3D compat
    - `simulation_base.gd`: game_world typed as Node, wall clearing simplified
  - All 85 unit tests + all 10 simulations pass. Visual rendering temporarily broken (2D sprites in 3D scene) until 3D.3-3D.7.
- **Stats**: 2 commits, 12 files changed. Planned: 5h → Actual: 0.2h
- **Decisions made**:
  - Buildings remain Node2D for now — logic works regardless of node type (3D.6 converts them)
  - BuildSystem stays Node2D — mouse input broken in 3D but sims don't use it (3D.3 fixes)
  - MultiMesh visual managers stay 2D — they'll render in their own canvas (3D.5, 3D.7 convert)
  - TileMapLayer removed entirely — terrain data managed via byte arrays + MultiMesh (no wall collision until 3D.5)
- **Blockers**: None

**Session 9 continued** — parallel agent execution for 3D.3, 3D.4, 3D.5 (23:25-23:46 MSK, +0.35h):
  - **3D.3**: BuildSystem mouse input rewritten — Camera3D raycast to Y=0 ground plane → `world_to_grid_3d()`. `_draw()` overlays stubbed (return in 3D.11). 1 file changed.
  - **3D.4**: Player fully converted to CharacterBody3D — WASD on XZ plane, real Y gravity/jump, CapsuleShape3D collision, placeholder capsule mesh. building_collision.gd → StaticBody3D + BoxShape3D. ground_item → Node3D. WorldBoundaryShape3D ground collision. save_manager Vector3 serialization. 9 files changed.
  - **3D.5**: Terrain rendering → MultiMesh3D with spatial shader. PlaneMesh quads on XZ, atlas UV encoding preserved. 1 file changed.
  - Fixed: conveyor_system.gd ground item pickup for Node3D items, sim_player.gd type inference
  - All 85 unit tests + all 8 sims pass (including sim_player with 3D physics).
- **Session 9 continued** — 3D.6-3D.10 (23:46-00:26 MSK, +0.65h):
  - **3D.6**: Buildings → Node3D with placeholder BoxMesh colored by BuildingDef.color. place_building creates Node3D directly, Y-axis rotation, logic from cached script. 12 files.
  - **3D.7**: Conveyor + item visual managers → MultiMesh3D with spatial shaders. Item positioning uses 3D bezier paths. All building item paths updated (conveyor, splitter, junction, tunnel). 8 files.
  - **3D.8**: Already done — all sims pass, simulation_base already updated. Just verified.
  - **3D.9**: Removed all 2D GridUtils code (-649 lines). Renamed _3d suffixed functions. Deleted grid_overlay.gd + base_multi_mesh_manager.gd. Fixed Node2D→Node type annotations across build_system, building_popup, game_world. 25 files.
  - **3D.10**: Camera serialize/deserialize updated for Camera3D.size (with legacy zoom detection). 1 file.
- **Integration fixes** (00:26-00:54 MSK, +0.5h):
  - Fixed player falling through ground: collision_mask was missing layer 1 (ground)
  - Fixed build_system.gd: ghost nodes are Node3D now (position=Vector3, no modulate, Y-axis rotation, relaxed type annotations)
  - Fixed sim_player.gd: removed physics-dependent tests that hung in headless (is_on_floor never settles)
  - Fixed player movement: screen-space WASD via camera basis projection (W=screen up, not world -Z)
  - Killed 3 stuck sim_player processes (37min+ at 100% CPU due to headless physics hang)
- **Lesson**: parallel worktree agents miss cross-card integration issues. Need full integration test after merging.
- **Stats total**: 18 commits, ~50 files changed. Planned: 22h (3D.1-3D.10) → Actual: 1.7h
- **Remaining**: 3D.11 (grid overlay, 1.5h) and 3D.12 (Blender models, 3h+) — both polish/art, not blocking
- **Next session goal**: 3D.12 (Blender pipeline for real building models) or P3.1 (RoundManager)

### Session 10 -- Blender 3D Art Pipeline (BLD.1)
- **Date**: 2026-04-04/05
- **Hours**: ~1.6h (late evening session, 23:22-00:57 MSK)
- **Work done**:
  - Built complete Blender Python pipeline for procedural 3D building models at `tools/blender/`
  - **Core infrastructure**:
    - `render.py` — orthographic isometric camera, EEVEE settings (filter_size=0, single sample), configurable resolution, frame rendering
    - `materials/pixel_art.py` — Principled BSDF matte materials from hex colors, Lua palette loader
  - **6 prefabs** (`prefabs_src/`):
    - `box.py` — parameterized box with optional panel seams
    - `cog.py` — gear with trapezoid teeth (separate inner/outer tooth width), hub hole, valley arc steps
    - `cylinder.py` — solid cylinder with flat or dome cap
    - `pipe.py` — hollow pipe with flange caps
    - `piston.py` — sleeve + rod (rod parented to sleeve), with disc head
    - `fan.py` — N-blade fan with hub
  - **Drill model** (`scenes/drill_model.py`):
    - Full drill composed from prefabs: body, band, roof, dual gears, derrick column + cap + cone, piston with head, pipe, exhaust stack + cap
    - 4 NLA animation states baked: idle (subtle wobble), windup (accelerating), active (full speed rotation + pumping + body shake), winddown (decelerating)
    - Exports both `.glb` (for Godot) and `.blend` (for editing)
  - **Issues fixed during iteration**:
    - Engine name: Blender 5.1 uses `'BLENDER_EEVEE'` not `'BLENDER_EEVEE_NEXT'`
    - Face normals: added `bmesh.ops.recalc_face_normals()` to all prefabs — Godot was showing missing faces
    - Cog teeth: rewrote from spiky star (single vertex per tooth) to proper trapezoid profile with valley arc
    - Materials: switched from emission to Principled BSDF — emission was washed out in Godot
    - Animation merging: `export_animation_mode='NLA_TRACKS'` + `export_merge_animation='NLA_TRACK'` → 4 combined animations instead of 18 per-object ones
    - Blender 5.x layered actions: fcurves at `action.layers[0].strips[0].channelbags[0].fcurves`
    - Piston animation: clamped to only pump downward (head smashes onto sleeve, never goes through)
  - **Documentation**: Updated CLAUDE.md with full pipeline docs, rewrote artist agent for dual pipeline (Blender primary, Aseprite secondary), saved memory reference
- **Stats**: 12 new files in `tools/blender/`, 2 output files in `buildings/blender-drill/`
- **Decisions made**:
  - Blender pipeline is primary for 3D buildings; Aseprite Lua remains for 2D sprites/items
  - Models export as `.glb` (compact, Godot-native) + `.blend` (editable)
  - Animations baked in Blender as NLA strips, state machine management in Godot via AnimationTree
  - Principled BSDF materials (not emission) for Blender↔Godot color consistency
  - `drill_model.py` is the reference template for all future building models
- **Blockers**: None
- **Next session goal**: Create remaining building models (smelter, splitter, junction, tunnel, sink) or P3.1 (RoundManager)

### Session 11 -- Blender Inspect Tool
- **Date**: 2026-04-05
- **Hours**: ~0.2h (late night, 10 min)
- **Work done**:
  - Created `tools/blender/inspect_model.py` — model inspection tool that renders 4 screenshots of a `.glb` from multiple angles (2 fixed isometric + 2 random/custom)
  - Auto-fit zoom from bounding box, 3-point lighting, 16x AA, track-to constraint
  - CLI options: `--ortho-scale`, `--cam3`/`--cam4` (override random angles), `--seed`, `-w`/`-o`
  - Created `tools/blender/CLAUDE.md` documenting the tool
  - Updated artist agent: added "Inspecting results" section — always run after building a model
  - Updated critic agent: added "3D model review" section with inspection command + checklist
- **Blockers**: None
- **Next session goal**: Create remaining building models (smelter, splitter, junction, tunnel, sink) or P3.1 (RoundManager)

### Session 12 -- Drill UV Fix + Detail Pass
- **Date**: 2026-04-05
- **Hours**: ~0.5h (late night session, ~01:50-02:20 MSK)
- **Work done**:
  - **UV fix**: Added proper UV generation to all cylindrical/box prefabs — cylinder, box, cone, pipe, piston. Textures were stretching badly because prefabs had no UVs and relied on Blender's `smart_project` which produces poor islands for cylinders. Now each prefab generates world-space-proportional UVs (cylindrical for round surfaces, per-face planar for boxes).
  - **Drill detail pass**: Expanded drill model from ~15 parts to ~60+. Added: base platform with corner feet, derrick reinforcement rings (x3), diagonal support struts (x4), control panel with gauge (copper rim) + colored knobs, valve wheel on pipe, side tank with hemisphere cap + bands + feed pipe, plumbing (vertical pipe, connecting pipe, elbow), wiring/cables (x3), exhaust rain cap + mounting bracket wedge, hazard stripe, gear axle caps, ~24 extra bolts on body sides and band.
  - Removed BackPipe and GearGuard after user review (pipe stuck out, panel clipped into gears).
  - Added hemisphere and wedge prefab imports to drill model.
- **Stats**: 6 prefab files edited (UV), 1 scene file rewritten, drill rebuilt 3 times
- **Decisions made**:
  - Prefabs own their UVs — no more relying on smart_project fallback
  - UV normalization: divide by max_dim so texture_library mapping node scales correctly
  - Detail density: every viewing angle should have visual interest (pipes, knobs, brackets)
- **Blockers**: None
- **Next session goal**: Create remaining building models (ART3D.1 smelter, ART3D.2 splitter, etc.) or P3.1 (RoundManager)

### Session 13 -- Full 3D Asset Pipeline (ART3D.1-ART3D.15)
- **Date**: 2026-04-05
- **Hours**: ~3.2h (overnight session, 02:18-05:34 MSK, includes 2h sleep)
- **Work done**:
  - **New prefabs** (3): `sphere.py`, `crystal.py` (hex prism clusters), `torus.py`
  - **ART3D.5**: Source + Sink debug buildings -- green arrow up / red grate funnel
  - **ART3D.1**: Smelter 3D model -- wide crucible with fire, dual hoppers, chimney, gears, 60+ parts
  - **ART3D.2**: Splitter 3D model -- round body, rotating distributor hub, 3 output chutes at 120 degrees
  - **ART3D.3**: Conveyor belt 3D model -- low track with rollers, side walls, directional arrows
  - **ART3D.4**: Junction (4-way crossover with raised guide arches) + Tunnel (arch portals with dark void)
  - **ART3D.6**: M1 deposits -- Pyromite (jagged volcanic cones), Crystalline (hex crystal clusters), Biovine (mushroom/organic blobs)
  - **ART3D.7**: Post-M1 deposits -- Voltite (zig-zag lightning shards), Umbrite (amorphous dark mass), Resonite (crystals with torus rings)
  - **ART3D.8**: 6 elemental item models (0.2-unit scale, color-coded with distinct silhouettes)
  - **ART3D.9**: 15 combination item models (all pairwise combos of 6 elements)
  - **ART3D.10**: Tendril Crawler monster -- psychedelic sphere with curving tendrils, neon green eye, torus collar
  - **ART3D.11**: Acid Bloom (toxic flower/fungus) + Phase Shifter (geometric with orbiting torus rings)
  - **ART3D.12**: Player character -- chunky industrial worker with yellow hardhat, walk/run/build animations
  - **ART3D.13**: 6 elemental projectiles (fire teardrop, ice shard, nature spore, lightning bolt, shadow orb, force diamond)
  - **ART3D.14**: Terrain features -- rock cluster, chasm pit, rubble debris pile
  - **ART3D.15**: Night-mode variants -- conveyor wall (spikes+reinforcement), smelter turret (weapon barrel), splitter multi-turret (3 barrels), drill cache (armored retracted derrick)
  - **Shared infrastructure**: `export_helpers.py`, `animate_scale()` in anim_helpers, elements palette extended with post-M1 colors
  - **Critic reviews**: 2 full reviews covering all models. Fixed junction height issue (added raised guide arches). Code duplication flagged for future cleanup.
  - **Every model ships in 2 versions**: flat (palette colors only) + textured (PBR from Poly Haven)
- **Stats**: 15 generation scripts, 3 new prefabs, 100+ model files (.glb + .blend), 200+ inspect screenshots
- **Asset summary**:
  - 7 buildings (drill existed + 6 new): smelter, splitter, conveyor, junction, tunnel, source, sink
  - 4 night-mode variants: conveyor wall, smelter turret, splitter turret, drill cache
  - 6 deposits: pyromite, crystalline, biovine, voltite, umbrite, resonite
  - 21 items: 6 base elements + 15 combinations
  - 3 monsters: tendril crawler, acid bloom, phase shifter
  - 1 player character
  - 6 projectiles
  - 3 terrain features: rock, chasm, rubble
- **Blockers**: None
- **Next session goal**: P3.1 RoundManager (gameplay mechanics) or 3D.11 grid overlay

### Session 14 -- Cleanup & Tooling
- **Date**: 2026-04-05
- **Hours**: ~1.2h (morning session, 09:27-10:38 MSK, excludes 2h sleep)
- **Work done**:
  - Removed `.blend` file exports from all 17 Blender scene scripts — only `.glb` output now
  - Deleted 113 `.blend`/`.blend1` files from the repo
  - Removed `export_blend()` function from `export_helpers.py` and all scene scripts
  - Fixed `fetch-quota.sh`: CLI (statusLine) gets both rate limit buckets; VSCode falls back to single-bucket bottleneck via CLI call
  - Rewrote quota tracking section in CLAUDE.md: CLI checks every 5 calls, VSCode every 15
  - Investigated statusLine hook behavior: fires in CLI terminal sessions but not in VSCode extension
- **Decisions made**:
  - `.blend` files are unnecessary — only `.glb` needed for Godot import
  - VSCode quota display uses `<N% (not bottleneck)` notation for the non-constrained bucket
- **Blockers**: None
- **Next session goal**: P3.1 RoundManager (gameplay mechanics) or 3D.11 grid overlay

### Session 15 -- 3D Model Integration (INT3D.1-7)
- **Date**: 2026-04-05
- **Hours**: ~0.3h (morning session, 10:23-10:39 MSK)
- **Work done**:
  - Integrated all 110+ .glb 3D models into the running game (7 kanban cards)
  - INT3D.1: Ground already had 2D tile sprites + collision; added 3D rock/chasm/rubble decorations on wall/stone tiles
  - INT3D.2: Swapped player CapsuleMesh for player.glb; wired idle/walk/run AnimationPlayer
  - INT3D.3: Spawned 3D deposit models (pyromite, crystalline, biovine) on deposit tiles with idle anims
  - INT3D.4: All 9 building types now use .glb models instead of placeholder boxes; building_logic.gd supports 3D AnimationPlayer for idle/active/windup/winddown state machine
  - INT3D.5: Rewrote item_visual_manager from MultiMesh 2D atlas to per-item .glb instances; ground items also get 3D models
  - INT3D.6: Added WorldEnvironment with ambient light, SSAO, ACES tonemap; tuned directional light
  - INT3D.7: All 8 simulations pass, 33 unit tests pass
  - Fixed duplicate ExtractorLogic class_name in blender-drill/
- **Decisions made**:
  - Buildings get 3D models via game_manager._building_model_scenes dict (no .tscn changes needed)
  - Conveyor MultiMesh visual disabled in favor of individual .glb instances
  - Items use individual .glb instances (user confirmed performance is fine)
- **Blockers**: None
- **Next session goal**: Visual tuning pass (scale, position, rotation of models); then P3.1 RoundManager

### Session 16 -- 3D Fixes + Physics Factory Planning
- **Date**: 2026-04-05
- **Hours**: ~0.5h (morning session, 10:48-11:13 MSK)
- **Work done**:
  - Fixed checkered ground: replaced 3-layer atlas MultiMesh (isometric diamond sprites with transparent corners) with single flat-color MultiMesh quads per tile type
  - Player rotation fix (user did this directly — removed negations in atan2)
  - User added GhostLayer Node3D to game_world.tscn and modified game_manager.gd to instantiate buildings from .tscn scenes directly
  - Investigated building IO system, ghost preview, and transport pipeline in depth
  - **Major design pivot**: decided to replace the entire grid-based pull transport system with physics-based transport (RigidBody3D items, force-field conveyors, Area3D IO zones)
  - Created 11 PHYS kanban cards (PHYS.1-11, ~22h estimated)
  - Created `/start-physics-factory` session starter command
- **Decisions made**:
  - Items are individual RigidBody3D objects (no quantity/stacking)
  - Conveyors apply directional force via Area3D, not discrete slot transfers
  - Building input zones are slightly inside the mesh (items flow in visually)
  - Buildings don't vacuum nearby items — only dedicated input Area3D zones consume
  - The entire Factor pull system will be gutted (ConveyorSystem, ItemBuffer, pull_item)
- **Blockers**: None
- **Next session goal**: Implement PHYS.1-11 (physics factory transport system). Use `/start-physics-factory`.

### Session 17 -- Physics Factory Transport (PHYS.1-11)
- **Date**: 2026-04-05
- **Hours**: ~0.7h (morning session, 11:13-11:54 MSK)
- **Work done**:
  - **PHYS.1**: PhysicsItem RigidBody3D — the atomic resource unit. SphereShape3D collision, auto-despawn, static spawn factory, player pickup.
  - **PHYS.3+9**: Rewrote all 9 building .tscn scenes to pure 3D Node3D hierarchies. Created InputZone (Area3D) and OutputZone (Marker3D) scripts. Updated BuildingDef extraction to support both 2D (legacy) and 3D (Marker3D) scene formats. Removed ~1400 lines of 2D sprite resources.
  - **PHYS.2**: Conveyor rewritten as physics surface transport — Area3D force zone pushes items, StaticBody3D side walls, lateral damping.
  - **PHYS.4+5+6**: Drill spawns PhysicsItem at output zone. Smelter uses InputZone to detect items, consumes for recipes, spawns output. Splitter deflects items via round-robin force impulse.
  - **PHYS.7**: Source/Sink/Junction/Tunnel adapted. Source spawns items. Sink consumes from InputZone. Junction is pass-through. Tunnel teleports items to paired output.
  - **PHYS.10**: Ghost preview improved with physics isolation (disabled collision/monitoring on all Area3D/StaticBody3D).
  - **PHYS.8**: Gutted old transport system — deleted ConveyorSystem, ConveyorVisualManager, ItemVisualHandle, ConveyorSprite (553 lines). Cleaned up GameManager, GameWorld, BuildSystem references. Removed ConveyorSystem node from game_world.tscn.
  - **PHYS.11**: Physics simulation tests — drill→conveyor→sink chain (11 items delivered), item pileup stability (69 items no crash), smelter processing.
- **Metrics**:
  - Estimated: 22h across 11 cards
  - Actual: 0.7h (31x faster than estimate)
  - 8 commits, ~2500 lines changed
- **Decisions made**:
  - BuildingDef auto-detects 3D vs 2D scene format (no Rotatable = 3D path)
  - Pull interface methods stubbed to return false/empty on all physics buildings
  - ConveyorBelt still registered with ConveyorSystem placeholder for compat
  - OutputZone spawns items offset 0.4 units back from marker (at building edge)
- **Blockers**: None
- **Next session goal**: Playtest the physics system visually, tune forces/speeds, fix any issues

### Session 18 -- Camera Rotation
- **Date**: 2026-04-05
- **Hours**: ~0.65h (afternoon session, 12:04-12:42 MSK)
- **Work done**:
  - Added free camera rotation (hold middle mouse or Z key + drag horizontally)
  - Created `camera_rotate` input action in project.godot (Z key + middle mouse button)
  - Rewrote camera to use explicit ground target tracking and deterministic Basis construction from yaw + fixed ISO pitch — eliminates wobble from Euler decomposition of baked .tscn transforms
  - Removed cursor-based mouse-edge panning — camera now stays centered on player
  - Player movement and build system raycasting auto-adapt (already read camera basis)
- **Blockers**: None
- **Next session goal**: Playtest physics system visually, tune forces/speeds

### Session 19 -- Physics Fixes + Model Pipeline Cleanup
- **Date**: 2026-04-05
- **Hours**: ~1.5h (afternoon session, 11:54-13:29 MSK)
- **Work done**:
  - Fixed 4 physics bugs: conveyor_system reference error, missing animations, dropped items not becoming PhysicsItems, conveyor model 90° rotation
  - Fixed destroy mode error: removed dead conveyor_visual_manager references from build_system.gd
  - Ran critic review — found critical InputZone overlap fragility, PhysicsItem.spawn leak, missing animation calls, dead code in UndergroundTransportLogic
  - Redesigned OutputZone as Area3D with BoxShape3D — items spawn at random points within the volume
  - Added model-based collision: BuildingBase auto-generates trimesh StaticBody3D from .glb mesh geometry. Sink delivery jumped 13→70→117→225 items as collision improved
  - Created ShapeCell3D: @tool MeshInstance3D that renders translucent unit cubes in editor for grid footprint visualization
  - Moved all building models to origin (0,0,0) — removed legacy (0.5, 0, 0.5) offset
  - Consolidated Blender export: all 16 model scripts now use shared export_glb from export_helpers.py
  - Fixed model scaling: moved 0.5x scale from broken Blender export hack to Godot import settings (nodes/root_scale=0.5 in 104 .glb.import files)
  - Rebuilt all .glb models — verified with inspect_model.py that conveyor and source render correctly
- **Decisions made**:
  - Building collision from actual model mesh (trimesh), not placeholder boxes
  - Scale handled at Godot import time, not in Blender pipeline
  - ShapeCell3D visible in editor only, hidden at runtime
  - OutputZone is Area3D with random spawn volume, not a point marker
- **Blockers**: None
- **Next session goal**: Fix remaining critic issues (InputZone overlap, dead UndergroundTransportLogic code, splitter dict growth), playtest visually

---

## Velocity Tracking

| Metric | Value | Notes |
|--------|-------|-------|
| Total sessions | 19 | |
| Total hours | 21.6 | |
| Factor baseline | ~42h over 2 weeks | 3h/day evenings |
| Estimated M1 hours | 40-60h | ~2-3 weeks at 3h/day |
| Estimated M2 hours | 40-60h | ~2-3 weeks at 3h/day |

*Velocity data will become more accurate after 3-4 coding sessions.*
