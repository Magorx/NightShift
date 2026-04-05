# Night Shift -- Project Board

## Done

### **3D.1** GridUtils 3D API + dual-API bridge `2h` ✓ `0.1h actual`

### **3D.2** Game world scene tree: Node2D → Node3D `3h` ✓ `0.2h actual`

### **3D.3** BuildSystem 3D input (mouse → grid via raycast) `2h` ✓ `0.1h actual`

### **3D.4** Player CharacterBody2D → CharacterBody3D `2h` ✓ `0.2h actual`

### **3D.5** Terrain rendering: MultiMesh3D ground plane `2h` ✓ `0.1h actual`

### **3D.6** Building base Node3D + placeholder meshes `2h` ✓ `0.1h actual`

### **3D.7** Conveyor + item visual manager 3D `3h` ✓ `0.2h actual`

### **3D.8** Simulation + test infrastructure update `1.5h` ✓ `0.05h actual`

### **3D.9** GridUtils 2D API removal (cleanup) `1h` ✓ `0.3h actual`

### **3D.10** Save/load migration `1h` ✓ `0.05h actual`

## Backlog

### **3D.11** 3D grid overlay + debug visualization `1.5h`

  - tags: [3d-transition, polish]
  - priority: low
  - depends: 3D.9
  - steps:
      - [ ] Rewrite grid_overlay using ImmediateMesh or ArrayMesh on ground plane
      - [ ] Add debug visualization for building footprints, IO directions
      - [ ] 3D destroy highlight (shader on MeshInstance3D or decal)
    ```md
    Polish card. Not required for gameplay but useful for development.
    ```

### **P3.1** RoundManager autoload singleton `2h`

  - tags: [phase-3, core]
  - priority: medium
  - steps:
      - [ ] Create `scripts/autoload/round_manager.gd`
      - [ ] State machine: BUILD -> FIGHT -> (SHOP later)
      - [ ] Signals: `phase_changed(phase: StringName)`, `round_started(round_number)`, `round_ended`
      - [ ] State: `current_round`, `current_phase`, `phase_timer`, `is_running`
      - [ ] API: `start_run()`, `skip_phase()` (debug), `get_time_remaining()`
      - [ ] Build phase: 180s (round 1, decreasing). Fight phase: 60s (round 1, increasing)
      - [ ] Register in Project Settings > Autoload
    ```md
    Core game loop manager. Phases: &"build", &"fight", &"transition".
    ```

### **P3.2** Phase HUD: timer + round counter `1.5h`

  - tags: [phase-3, ui]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Gut existing HUD content (speed controls, currency, delivery counter)
      - [ ] Add round counter, phase label, countdown timer
      - [ ] Modify `scenes/ui/hud.tscn` with new layout
      - [ ] Add screen flash/pulse for phase transitions
    ```md
    Minimal HUD replacing Factor's complex UI.
    ```

### **P3.3** Build phase: enable placement, conveyors run `1h`

  - tags: [phase-3, gameplay]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Wire `RoundManager.phase_changed` in `game_world.gd` to toggle systems
      - [ ] Add `set_enabled(bool)` to `build_system.gd` to block placement during fight
      - [ ] Verify conveyor/building tick runs normally during build phase
    ```md
    Build phase is basically current Factor behavior, just wired to RoundManager.
    ```

### **P3.4** Fight phase: freeze factory, placeholder combat `1.5h`

  - tags: [phase-3, gameplay]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Pause conveyor/building systems during fight in `game_world.gd`
      - [ ] Create `scripts/game/phase_transition.gd` -- visual transition effect (screen darken, text)
      - [ ] Fight phase is just a timer countdown (no monsters yet)
      - [ ] Validate: game cycles build->fight->build, can place during build only
    ```md
    Placeholder fight phase -- just a timer. Monsters come in Phase 5.
    ```

### **P3.5** Day/night visual shift `1.5h`

  - tags: [phase-3, visual]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Create `scripts/game/day_night_visual.gd` -- manages CanvasModulate transitions
      - [ ] Add CanvasModulate node to `scenes/game/game_world.tscn`
      - [ ] Fight: darken terrain, slight color distortion. Build: normal bright look
    ```md
    CanvasModulate-based day/night. Full psychedelic shader is post-M1.
    ```

### **P3.6** Sim test: round cycling `1.5h`

  - tags: [phase-3, test]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Write `tests/simulation/sim_round_cycle.gd`
      - [ ] Verify phase transitions, timer countdown, 3 full rounds complete
      - [ ] Validate: sim passes headless
    ```md
    Automated test of build/fight cycle.
    ```

### **P4.1** Building HP component `1.5h`

  - tags: [phase-4, combat]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Create `buildings/shared/building_health.gd` -- HP, max_hp, damage/heal methods
      - [ ] Damage visual states: cracks at 75%, scarring at 50%, heavy at 25%, destroyed at 0%
      - [ ] Add `var health = null` to `building_logic.gd` (same pattern as energy was)
      - [ ] On destroy: remove building via GameManager, leave rubble marker
    ```md
    BuildingHealth component, same architecture pattern as the removed BuildingEnergy.
    ```

### **P4.2** Night transform: conveyors become walls `2h`

  - tags: [phase-4, transform]
  - priority: medium
  - steps:
      - [ ] Create `scripts/game/night_transform.gd` -- iterates buildings, applies night state
      - [ ] Register with `RoundManager.phase_changed`
      - [ ] On fight: conveyors gain HP, block monster pathing, stop moving items
      - [ ] Swap conveyor sprite to wall variant (darker, raised look)
      - [ ] Add wall state and HP values to `buildings/conveyor/conveyor_belt.gd`
    ```md
    Core Night Shift mechanic: your conveyor layout IS your defense layout.
    ```

### **P4.3** Night transform: converters become turrets `2h`

  - tags: [phase-4, transform]
  - priority: medium
  - steps:
      - [ ] Create `scripts/game/turret_behavior.gd` -- targeting, firing logic
      - [ ] Create `scripts/game/projectile.gd` + `scenes/game/projectile.tscn`
      - [ ] Add `last_processed_element` to `converter.gd`, toggle day/night behavior
      - [ ] Turret fires projectiles based on last processed resource, nearest monster in range
    ```md
    Converters become elemental turrets at night. Projectile color matches element.
    ```

### **P4.4** Sim test: transformation `0.5h`

  - tags: [phase-4, test]
  - priority: medium
  - steps:
      - [ ] Place buildings, trigger night, verify conveyors have HP
      - [ ] Verify converters fire projectiles
      - [ ] Validate: sim passes headless
    ```md
    Automated test of building transformation.
    ```

### **P5.1** Monster base class + Tendril Crawler `3h`

  - tags: [phase-5, monsters]
  - priority: medium
  - steps:
      - [ ] Create `monsters/monster_base.gd` -- HP, speed, damage, pathfinding, attack
      - [ ] Create `monsters/tendril_crawler/tendril_crawler.gd` -- line destruction pattern
      - [ ] Create `monsters/tendril_crawler/tendril_crawler.tscn` -- sprite, collision
      - [ ] Placeholder sprite: 16x16 pulsating geometric shape
    ```md
    First monster type. Follows A* path toward nearest building, attacks in melee range.
    ```

### **P5.2** Monster spawner `2h`

  - tags: [phase-5, monsters]
  - priority: medium
  - steps:
      - [ ] Create `scripts/game/monster_spawner.gd` -- connects to RoundManager
      - [ ] Spawn at map edges during fight phase, avoid walls
      - [ ] Wave scaling: round_1_count=5, count_per_round=3, spawn_interval=2.0s
    ```md
    Spawns monsters at map edges with wave scaling per round.
    ```

### **P5.3** Monster pathfinding (A*) `2.5h`

  - tags: [phase-5, monsters]
  - priority: medium
  - steps:
      - [ ] Create `scripts/game/monster_pathfinding.gd` -- wraps AStar2D
      - [ ] Build grid from GameManager.buildings (wall-mode conveyors are impassable)
      - [ ] Shared grid rebuilt once per fight start + when buildings destroyed
      - [ ] Individual monsters query for paths
    ```md
    Risk: performance with 50+ monsters. Use shared grid, batch pathfinding, limit recalculation.
    ```

### **P5.4** Monster-building combat `2h`

  - tags: [phase-5, combat]
  - priority: medium
  - steps:
      - [ ] Monsters attack buildings when adjacent (Tendril Crawler: 1 building per attack)
      - [ ] Turret projectiles damage monsters via collision
      - [ ] Monster death: no drops (currency comes with shop system)
      - [ ] Monsters deal damage to player if adjacent, player can dodge
    ```md
    Monster-building and monster-player combat interactions.
    ```

### **P5.5** Fight phase end condition `1h`

  - tags: [phase-5, core]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] End fight when all monsters dead OR timer expires
      - [ ] Timer expiry: remaining monsters flee/despawn
      - [ ] All buildings destroyed: game over
      - [ ] Simple "Game Over" screen with "Return to Menu" button
    ```md
    Win/lose conditions for fight phase.
    ```

### **P5.6** Sim test: full combat loop `1.5h`

  - tags: [phase-5, test]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Run 3 full rounds: build, survive waves, verify damage and kills
      - [ ] Validate: sim passes headless
    ```md
    End-to-end combat simulation.
    ```

### **P6.1** Simplify player inventory to 8 slots `1h`

  - tags: [phase-6, player]
  - priority: low
  - steps:
      - [ ] Change INVENTORY_SLOTS to 8 in `player/player.gd` (keep STACK_SIZE=16)
      - [ ] Update `scripts/ui/inventory_panel.gd` to 8-slot layout (1 row of 8)
    ```md
    Simpler inventory for roguelite pacing.
    ```

### **P6.2** Player combat actions during fight `2h`

  - tags: [phase-6, player]
  - priority: low
  - steps:
      - [ ] Player moves freely during fight but cannot place buildings
      - [ ] Add basic attack action (melee punch or elemental throw from inventory)
      - [ ] Keep simple for M1
    ```md
    Light player combat. No building placement during fight phase.
    ```

### **P6.3** Run-based save/load `1.5h`

  - tags: [phase-6, save]
  - priority: low
  - workload: Normal
  - steps:
      - [ ] Simplify SaveManager for run-based saves
      - [ ] Save mid-run state (round, buildings, player)
      - [ ] Auto-delete save on run completion (win or lose)
      - [ ] No meta-progression save for M1
    ```md
    No persistent progression for M1. Just mid-run save/load.
    ```

### **P6.4** New main menu `1.5h`

  - tags: [phase-6, ui]
  - priority: low
  - workload: Normal
  - steps:
      - [ ] "New Run", "Continue" (if save exists), "Settings", "Quit"
      - [ ] Modify `scripts/ui/main_menu.gd` and `scenes/ui/main_menu.tscn`
    ```md
    Replace Factor's account-slot menu with simple run-based menu.
    ```

### **P6.5** Building placement UX for M1 `1.5h`

  - tags: [phase-6, ui]
  - priority: low
  - workload: Normal
  - steps:
      - [ ] Set creative_mode = true in `game_manager.gd` (unlimited free buildings for M1)
      - [ ] Add simple building hotbar to HUD
      - [ ] All M1 buildings available: conveyor, drill, smelter, splitter
    ```md
    No shop yet, so player starts with unlimited buildings.
    ```

### **P6.6** End-to-end playtest + bug fixing `1.5h`

  - tags: [phase-6, test]
  - priority: low
  - workload: Normal
  - steps:
      - [ ] Play full 3-round run
      - [ ] Fix crashes, balance timing, adjust monster difficulty
      - [ ] Document issues for M2
    ```md
    Final M1 polish and bug bash.
    ```

## In Progress

## Done

### **ART3D.1** Smelter 3D model (2026-04-05)

  - tags: [3d-art, buildings]
    ```md
    Smelter model with crucible, hoppers, chimney, gears, control panel.
    60+ parts, 4 NLA animations. Flat + textured exports.
    ```

### **ART3D.2** Splitter 3D model (2026-04-05)

  - tags: [3d-art, buildings]
    ```md
    Splitter with round body, rotating distributor hub, 3 output chutes.
    4 NLA animations. Flat + textured exports.
    ```

### **ART3D.3** Conveyor belt 3D model (2026-04-05)

  - tags: [3d-art, buildings]
    ```md
    Low-profile conveyor track with rollers, side walls, directional arrows.
    3 NLA states (idle/active/wall). Custom roller generator. Flat + textured.
    ```

### **ART3D.4** Junction + Tunnel 3D models (2026-04-05)

  - tags: [3d-art, buildings]
    ```md
    Junction: 4-way crossover with raised guide arches for silhouette.
    Tunnel: arch portals with dark void interior. Custom arch_portal generator.
    Both flat + textured exports.
    ```

### **ART3D.5** Source + Sink debug buildings (2026-04-05)

  - tags: [3d-art, buildings, debug]
    ```md
    Source: green upward arrow, output indicator. Sink: red grate funnel.
    Distinct silhouettes for instant identification. Flat + textured.
    ```

### **ART3D.6** M1 elemental deposits (2026-04-05)

  - tags: [3d-art, resources, deposits]
    ```md
    Pyromite (jagged volcanic cones), Crystalline (hex crystal clusters),
    Biovine (mushroom/organic blobs). All distinguishable by color AND silhouette.
    ```

### **ART3D.7** Post-M1 elemental deposits (2026-04-05)

  - tags: [3d-art, resources, deposits, post-m1]
    ```md
    Voltite (zig-zag lightning shards), Umbrite (amorphous dark mass),
    Resonite (crystals with torus rings). Extended elements palette.
    ```

### **ART3D.8** 3D item models: 6 elemental resources (2026-04-05)

  - tags: [3d-art, resources, items]
    ```md
    6 tiny item models (~0.2 Blender units) with distinct colors and shapes.
    Fire teardrop, ice prism, nature seed, lightning shard, shadow orb, force diamond.
    ```

### **ART3D.9** 3D item models: combination resources (2026-04-05)

  - tags: [3d-art, resources, items]
    ```md
    15 combination items (all pairwise combos). Visual blends of parent shapes/colors.
    Extended elements palette with 12 new combo color sets.
    ```

### **ART3D.10** Tendril Crawler monster model (2026-04-05)

  - tags: [3d-art, monsters]
    ```md
    Psychedelic monster with pulsating sphere body, curving tendrils,
    neon green eye, torus collar. 3 NLA states: idle/move/attack.
    ```

### **ART3D.11** Acid Bloom + Phase Shifter monster models (2026-04-05)

  - tags: [3d-art, monsters, post-m1]
    ```md
    Acid Bloom: toxic flower/fungus with petals, dripping acid, gold core.
    Phase Shifter: geometric diamond body with orbiting torus rings and fragments.
    ```

### **ART3D.12** Player character 3D model (2026-04-05)

  - tags: [3d-art, player]
    ```md
    Chunky industrial worker with yellow hardhat (key identifier).
    20 mesh parts from prefabs. 4 NLA states: idle/walk/run/build.
    Added animate_scale() helper to anim_helpers.py.
    ```

### **ART3D.13** Projectile + effect models (2026-04-05)

  - tags: [3d-art, combat, effects]
    ```md
    6 elemental projectiles: fire teardrop, ice shard, nature spore,
    lightning bolt, shadow orb+ring, force diamond. Spinning idle animation.
    ```

### **ART3D.14** Terrain features (2026-04-05)

  - tags: [3d-art, terrain]
    ```md
    Rock cluster (boulders + facets), chasm pit (recessed void + crumbling edges),
    rubble debris pile (broken panels + pipes + scattered bolts). Flat + textured.
    ```

### **ART3D.15** Night-mode building variants (2026-04-05)

  - tags: [3d-art, buildings, combat]
    ```md
    Conveyor wall (raised barriers + spikes), smelter turret (weapon barrel),
    splitter multi-turret (3 barrels), drill cache (armored + retracted derrick).
    3 NLA states: idle/active/transition. Flat + textured.
    ```

### **LIB.2** Scene lighting: ambient + point lights (2026-04-04)

  - tags: [art-pipeline, tooling]
    ```md
    Scene-level lighting module (lighting.lua). Three light types: ambient,
    directional, point (with colored tinting and quadratic falloff).
    Lights added via scene:add_light(). Default lights match old behavior.
    Fixed 05_textures example, added 09_lighting example. Planned 1.5h, actual ~0.2h.
    ```

### **LIB.1** Isometric 3D Geometry Library (2026-04-04)

  - tags: [art-pipeline, tooling]
    ```md
    Full 3D-to-isometric rendering library at tools/rendering/iso/.
    10 modules: config, projection, zbuffer, shading, primitives (9 shapes),
    mechanical (gear/pipe/piston/fan), texture (12 patterns), animation,
    scene composition. Configurable projection (not hardcoded 2:1).
    8 example PNGs generated. Planned 5h, actual ~0.5h.
    ```

### **S0** Design & Planning (2026-04-03)

  - tags: [planning]
    ```md
    Market analysis, concept selection, design doc, project tracking setup.
    ```

### **P1.1** Gut ResearchManager references (2026-04-04)

  - tags: [phase-1, strip]

### **P1.2** Gut ContractManager references (2026-04-04)

  - tags: [phase-1, strip]

### **P1.3** Gut TutorialManager (2026-04-04)

  - tags: [phase-1, strip]
    ```md
    AccountManager retained -- only TutorialManager removed. AccountManager needed for save slots.
    ```

### **P1.4** Gut EnergySystem (2026-04-04)

  - tags: [phase-1, strip]

### **P1.5** Remove unused buildings and complex UI (2026-04-04)

  - tags: [phase-1, strip]
    ```md
    Deleted 24 building types, research panel, recipe browser, tutorial panel, building info panel.
    Kept: conveyor, drill, smelter, splitter, junction, tunnel, sink, source.
    ```

### **P1.6** Strip test: run remaining simulations (2026-04-04)

  - tags: [phase-1, test]
    ```md
    Updated simulation_base.gd, deleted 8 obsolete sims. All kept sims pass.
    ```

### **P2.1** Define 3 elemental resources as ItemDef .tres (2026-04-04)

  - tags: [phase-2, resources]
    ```md
    Created pyromite, crystalline, biovine + 3 combo items (steam_burst, verdant_compound, frozen_flame).
    New item atlas with 6 pixel art sprites. Deleted 63 Factor items.
    ```

### **P2.2** Define elemental recipes (2026-04-04)

  - tags: [phase-2, resources]
    ```md
    3 smelter recipes: pyromite+crystalline→steam_burst, crystalline+biovine→verdant_compound, pyromite+biovine→frozen_flame.
    Deleted 58 Factor recipes.
    ```

### **P2.3** New world generator: 128x128 with elemental deposits (2026-04-04)

  - tags: [phase-2, worldgen]
    ```md
    Rewrote world_generator.gd for 128x128 arena. 3 deposit types at 3 distance tiers.
    Noise walls with distance-based density, stone veins, connectivity guarantee.
    Updated TileDatabase with TILE_PYROMITE, TILE_CRYSTALLINE, TILE_BIOVINE.
    ```

### **P2.4** Update BuildingDefs for kept buildings (2026-04-04)

  - tags: [phase-2, resources]
    ```md
    All 9 BuildingDefs updated: removed build_cost (free placement for M1), removed iron_plate references.
    Updated all code references from old item IDs to elemental IDs.
    ```

### **P2.5** Sim test: resource flow (2026-04-04)

  - tags: [phase-2, test]
    ```md
    New sim_elemental_flow.gd: tests drill→conveyor→smelter→sink with 2-input recipes.
    Fixed simulation exit hang (reset time_scale before quit). All 8 sims pass.
    ```

### **ISO.1** Centralize all coordinate math into GridUtils (2026-04-04)

  - tags: [isometric, refactor, critical-path]
    ```md
    De-risk step: 80+ coordinate conversions across 26 files funneled through one utility.
    After this, switching to isometric is a single-point change in GridUtils.
    Hardcoded 32 in shaders (conveyor_visual_manager.gd GLSL) noted but handled in ISO.4.
    ```

### **ISO.2** Switch GridUtils to isometric diamond projection (2026-04-04)

  - tags: [isometric, engine]
    ```md
    The actual projection switch. Because ISO.1 centralized everything, this changes
    two functions and the TileSet config. Sprites will look wrong (still top-down art)
    but placement/logic should work on the diamond grid.
    ```

### **ISO.3** Y-sort scene hierarchy + depth sorting (2026-04-04)

  - tags: [isometric, engine]
    ```md
    Replace the flat z_index layering with proper isometric depth sorting.
    MultiMesh y-sorting is the tricky part -- may need custom sort or shader discard.
    ```

### **ISO.4** Update BuildSystem for diamond grid (2026-04-04)

  - tags: [isometric, gameplay]
    ```md
    Most complex code change. Drag detection needs rethinking because
    "horizontal drag" in screen space crosses both grid axes in diamond projection.
    ```

### **ISO.5** Update ConveyorSystem + item rendering for isometric (2026-04-04)

  - tags: [isometric, engine]
    ```md
    Conveyor entry/exit points and item lerp paths must follow diamond-projected directions.
    Shader stripe frequency needs recalculation for 64x32 tiles.
    ```

### **ISO.6** Isometric terrain art (2026-04-04)

  - tags: [isometric, art]
    ```md
    First art pass. Terrain sets the visual foundation -- everything else sits on top.
    Diamond tiles show top face + slight front edge for depth.
    ```

### **ISO.7** Isometric building sprites (2026-04-04)

  - tags: [isometric, art]
    ```md
    Biggest art task. Each rotation looks different in isometric (you see different faces),
    so we need 4 distinct rotation sprites per building instead of programmatic rotation.
    ```

### **ISO.8** Isometric conveyor + item art (2026-04-04)

  - tags: [isometric, art]
    ```md
    Conveyor atlas is the most complex spritesheet. Items may stay top-down (small enough
    that perspective doesn't matter). Player sprite is placeholder for M1.
    ```

### **ISO.9** Integration test: full isometric verification (2026-04-04)

  - tags: [isometric, test]
    ```md
    Final verification before moving to Phase 3 gameplay systems.
    Everything built after this (rounds, combat, monsters) inherits the isometric view.
    ```

### **ART.1** Terrain tiles with elevation and depth (2026-04-04)

  - tags: [art, elevation, foundation]
    ```md
    Rewrote terrain atlas with front-edge depth shading, raised ore formations,
    textured walls. All 17 types improved. Atlas layout unchanged (512x480).
    ```

### **ART.2** Building sprites with vertical extension (2026-04-04)

  - tags: [art, elevation, buildings]
    ```md
    Converted all 7 buildings from top-down 32x32 to isometric 64x48 with elevation.
    Created new generate.lua for splitter, junction, tunnel. Updated all .tscn files.
    ```

### **ART.3** Conveyor sprites with elevation (2026-04-04)

  - tags: [art, elevation, conveyors]
    ```md
    Raised track with side walls, support struts, directional lighting.
    Atlas layout unchanged (256x192, 4x6 grid).
    ```

### **ART.4** Item sprites with depth and volume (2026-04-04)

  - tags: [art, elevation, items]
    ```md
    8 tones per item (up from 6), specular highlights, anti-aliased shadow edges.
    All 6 items volumetric. Atlas unchanged (96x16).
    ```

### **BOT.1** BotPlayer base class + random build behavior `3h`

  - tags: [botplayer, testing, infrastructure]
  - priority: medium
  - steps:
      - [ ] Create `tests/bot/bot_player.gd` extending `SimulationBase`
      - [ ] Implement `BotBrain` inner class — the decision-maker that runs each tick
      - [ ] `BotBrain` holds: player grid position, known deposits (scanned from `GameManager.deposits`), placed buildings list, current goal (enum: EXPLORE, BUILD, OBSERVE)
      - [ ] **Random walk**: each decision tick (every ~60 frames), pick a random walkable grid cell within radius 10 of current position, set as move target. Move one cell per tick toward target (cardinal directions only, skip walls)
      - [ ] **Random build**: when adjacent to an empty cell, roll a weighted random to place a building. Weights: conveyor 50%, drill 15% (only on deposit), smelter 15%, splitter 10%, source 5%, sink 5%. Pick random valid rotation (0-3). Skip if cell occupied or invalid (drill off-deposit, multi-cell overlap)
      - [ ] **Conveyor chaining**: 30% chance after placing a conveyor to place 1-4 more in the same direction (capped by obstacles). This creates usable conveyor lines instead of scattered singles
      - [ ] **Decision tick rate**: configurable `ticks_per_decision` (default 60 = 1 decision/sec at 60fps). Between decisions, bot just advances simulation time
      - [ ] **Run config**: `bot_duration_seconds` (default 300 = 5 min game time), `bot_seed` (RNG seed for reproducibility)
      - [ ] Log all actions to stdout: `[BOT] tick=120 action=place_building type=conveyor pos=(5,3) rot=0`
    ```md
    The core BotPlayer that makes random-but-valid decisions in headless simulation.
    Doesn't need rendering, player node, or input — it directly calls GameManager
    placement APIs (same as existing sim helpers). Think of it as a monkey-testing
    bot that places buildings and lets the factory run.

    Architecture: BotPlayer (extends SimulationBase) owns a BotBrain instance.
    run_simulation() loops: advance ticks → ask BotBrain for action → execute action → repeat.
    BotBrain is stateless-ish: it reads GameManager state each tick, doesn't cache stale data.

    The "player position" is virtual — just a Vector2i tracking where the bot
    is "standing" on the grid. No actual CharacterBody2D movement. This is
    purely for decision-making (build near me, explore outward).

    All randomness goes through a seeded RandomNumberGenerator so runs are
    reproducible: same seed = same build order = same factory layout.
    ```

### **BOT.2** Metric collector + run summary `2h`

  - tags: [botplayer, testing, metrics]
  - priority: medium
  - depends: BOT.1
  - steps:
      - [ ] Create `tests/bot/bot_metrics.gd` — standalone metric tracker, receives events from BotPlayer
      - [ ] Track placement metrics: buildings placed (by type), placement failures (by reason: occupied, off-deposit, overlap), total conveyors, total production buildings
      - [ ] Track production metrics: poll `GameManager.items_delivered` every 60 ticks, record items/min throughput over time. Track which item types are being produced
      - [ ] Track factory health: count idle drills (on deposit but output blocked), count disconnected buildings (no conveyor path to/from), count conveyor deadends
      - [ ] Track stability: record any error prints or script errors caught during run (hook `printerr`)
      - [ ] **Run summary**: at `sim_finish()`, print a structured report:
        ```
        [BOT REPORT] seed=42 duration=300s ticks=18000
        Buildings placed: conveyor=47 drill=8 smelter=3 splitter=2 sink=1 source=0
        Placement failures: 12 (occupied=8 off_deposit=3 overlap=1)
        Production: pyromite=24 crystalline=18 steam_burst=6
        Throughput: 3.2 items/min (avg over last 120s)
        Idle drills: 2/8  Disconnected buildings: 4/61
        Errors: 0
        ```
      - [ ] Optionally dump full timeline to JSON file (`tests/bot/results/<seed>.json`) for post-hoc analysis
    ```md
    The metric collector answers: "did the factory work?" and "did anything break?"
    without needing a human to watch.

    Key insight: we don't just want crash detection. We want to know if the bot
    built something *functional*. Throughput > 0 means items are flowing. Idle drills
    mean the bot failed to connect things. Disconnected buildings mean wasted placements.

    The JSON dump enables comparing runs across code changes: "did this refactor
    accidentally break smelter throughput?" by diffing metric summaries.
    ```

### **BOT.3** Bot strategies: greedy builder + line builder `2.5h`

  - tags: [botplayer, testing, strategies]
  - priority: medium
  - depends: BOT.1
  - steps:
      - [ ] Refactor BotBrain into a base class with virtual `decide(state: Dictionary) -> Dictionary` method
      - [ ] **RandomBrain** (already built in BOT.1) — move to its own file `tests/bot/brains/random_brain.gd`
      - [ ] **GreedyBrain** (`tests/bot/brains/greedy_brain.gd`):
        - Prioritizes connecting deposits to smelters. Scans for nearest unconnected deposit, walks there, places drill, then lays conveyors toward nearest smelter (or places a new smelter if none nearby)
        - Places sink at end of production chain
        - Falls back to random placement when no clear goal
      - [ ] **LineBrain** (`tests/bot/brains/line_brain.gd`):
        - Builds long straight conveyor lines across the map, placing drills at deposits encountered along the way, smelters at intersections
        - Tests the "highway" factory layout style
      - [ ] Each brain selectable via constructor: `BotPlayer.new(brain_type: StringName)` or sim argument
      - [ ] Add `--bot-brain <name>` argument parsing in bot runner
    ```md
    Different brains stress different parts of the engine:
    - RandomBrain: maximum chaos, best for crash detection and edge cases
    - GreedyBrain: builds functional factories, best for production/balance testing
    - LineBrain: creates long conveyor highways, best for stress-testing conveyor
      system performance and item rendering at scale

    The brain interface is simple: receive a state snapshot (deposits, buildings,
    bot position, available building types), return an action dict. No async,
    no signals — pure function each decision tick.
    ```

### **BOT.4** Bot runner: batch execution + comparison `2h`

  - tags: [botplayer, testing, runner]
  - priority: medium
  - depends: BOT.2, BOT.3
  - steps:
      - [ ] Create `tests/bot/run_bot_batch.sh` — shell script that runs N bot simulations with different seeds
      - [ ] Usage: `./tests/bot/run_bot_batch.sh --count 10 --brain random --duration 300`
      - [ ] Each run gets seed 1..N, runs headless via: `$GODOT --headless --fixed-fps 60 --path . --script res://tests/bot/run_bot.gd -- <brain> <seed> <duration>`
      - [ ] Create `tests/bot/run_bot.gd` — entry point script that parses args, instantiates BotPlayer with chosen brain, runs it
      - [ ] Collect all JSON results into `tests/bot/results/batch_<timestamp>/`
      - [ ] Print aggregate summary after batch: average throughput, crash count, min/max buildings placed, % of runs with production > 0
      - [ ] Exit code 1 if any run crashed (non-zero Godot exit), enabling CI integration
    ```md
    The batch runner is how you use BotPlayer in practice. Run 10-50 bots overnight,
    check the summary in the morning.

    Typical workflow:
    1. Make a code change
    2. Run `./tests/bot/run_bot_batch.sh --count 20 --brain greedy`
    3. Check: any crashes? Throughput regressed? More idle drills than before?

    The shell script is intentionally simple — no Python dependency, just a loop
    calling Godot headless. Results are JSON files you can diff or feed into
    a spreadsheet.

    CI integration: add to GitHub Actions as a nightly job. If any run exits
    non-zero, the workflow fails and you get notified.
    ```

### **BOT.5** Visual bot mode: watch the bot build `1.5h`

  - tags: [botplayer, testing, visual]
  - priority: low
  - depends: BOT.1
  - steps:
      - [ ] Add `--visual` flag support to `run_bot.gd` — opens windowed game, bot runs at 2x speed
      - [ ] Render a marker sprite at the bot's virtual grid position (simple colored diamond on the grid) so you can see where it's "standing"
      - [ ] Add bot action log overlay — small text panel in corner showing last 5 bot actions
      - [ ] Camera follows bot position (reuse existing camera follow logic from player)
      - [ ] Don't auto-quit — let the user watch and close manually (same as sim visual mode)
    ```md
    Debugging aid. When a bot run produces weird metrics, launch it in visual mode
    with the same seed to see exactly what it did. Also useful for screenshots/GIFs
    showing emergent factory layouts.

    Usage: $GODOT --path . --script res://tests/bot/run_bot.gd -- random 42 300 --visual
    ```

### **BOT.6** Sim test: bot smoke test `1h`

  - tags: [botplayer, testing, verification]
  - priority: medium
  - depends: BOT.1, BOT.2
  - steps:
      - [ ] Create `tests/simulation/sim_bot_smoke.gd` extending `SimulationBase`
      - [ ] Run RandomBrain bot for 60 seconds (3600 ticks) with seed 42
      - [ ] Assert: no script errors during run
      - [ ] Assert: at least 5 buildings placed (bot isn't stuck)
      - [ ] Assert: at least 1 conveyor placed
      - [ ] Assert: simulation completes without timeout
      - [ ] Add to standard test suite (runs with `run_tests.gd`)
    ```md
    Minimal smoke test that the bot system itself works. Not testing game balance —
    just verifying the bot can run without crashing and actually does stuff.
    Runs as part of the normal test suite so bot infrastructure regressions
    are caught immediately.
    ```

## Post-M1 Backlog

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

