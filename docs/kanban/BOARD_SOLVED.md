# Night Shift -- Solved Cards

## Done

### **P3.1** RoundManager autoload singleton `1h` -> `0.05h actual`
### **P3.2** Phase HUD: timer + round counter `0.5h` -> `0.05h actual`
### **P3.3** Build phase: enable placement, conveyors run `0.5h` -> `0.03h actual`
### **P3.4** Fight phase: freeze factory, placeholder combat `0.5h` -> `0.03h actual`
### **P3.5** Day/night visual shift `0.5h` -> `0.03h actual`
### **P3.6** Sim test: round cycling `0.5h` -> `0.05h actual`
### **P4.1** General HP component `0.5h` -> `0.1h actual`
### **P4.2** Night transform: conveyors become walls `1h` -> `0.15h actual`
### **P4.3** Aiming system + turret behavior `1.5h` -> `0.15h actual`
### **P4.4** Resource memory for buildings `0.5h` -> `0.05h actual`
### **P4.5** Night transform 3D models `2h` -> `0.2h actual`
### **P4.6** Sim test: transformation `0.25h` -> `0.1h actual`

### **MAP.1** Noise-based 3D terrain elevation `2h` -> `1.7h`

  - tags: [map-gen, core]
  - priority: high

### **SCN.1** Scenario test framework: scripted integration tests `4h` -> `0.4h`

  - tags: [testing, infrastructure, scenarios]
  - priority: medium
  - steps:
      - [x] ScenarioBase class extending SimulationBase (small maps, creative mode, visual-first)
      - [x] BotController: physical player movement via `bot_input` on CharacterBody3D
      - [x] BotController commands: walk_to, sprint_to, teleport_to, place, place_conveyor_line, mine_at, pickup, drop, jump
      - [x] ScenarioMonitor: track named metrics with callables, assert_eq/gt/lt/between, screenshot capture
      - [x] ScenarioMap: deposit/cluster/line, walls, pre-placed buildings, player_start
      - [x] run_scenario.gd: entry point with --fast (10x) / --visual (4x) / --screenshot modes
      - [x] Player `bot_input`/`bot_sprint` properties for real physics movement in tests
      - [x] Example: scn_drill_to_sink (production chain verification)
      - [x] Example: scn_player_movement (walk, jump, collision, sprint, damage, inventory)
    ```md
    Scripted integration test framework. Unlike existing simulations that bypass the player,
    scenarios physically move the CharacterBody3D through the world, place buildings via
    GameManager API near the player position, and verify both numeric metrics and screenshots.

    Cherry-picked from BOT cards: metric tracking (BOT.2 concept), visual mode (BOT.5 concept).
    BOT.1/3/4 autonomous brain system remains separate — scenarios are directed, not autonomous.

    Key design: Player.bot_input overrides keyboard input in _handle_movement(), so bot commands
    test the real physics pipeline (acceleration, friction, collision, move_and_slide).
    ```

### **PHYS.1** Physics item: RigidBody3D resource entity `2h` -> `0.1h`
### **PHYS.2** Conveyor belt: physics surface transport `3h` -> `0.1h`
### **PHYS.3** Building IO zones: 3D input/output areas `2h` -> `0.15h`
### **PHYS.4** Drill extractor: physics item spawner `1.5h` -> `0.05h`
### **PHYS.5** Smelter/Converter: physics-based processing `2h` -> `0.05h`
### **PHYS.6** Splitter: physics deflector `1.5h` -> `0.05h`
### **PHYS.7** Source/Sink debug buildings + junction/tunnel `1.5h` -> `0.05h`
### **PHYS.8** Gut old transport system `2h` -> `0.1h`
### **PHYS.9** Building .tscn 3D rewrite: all scenes `3h` -> `0.1h`
### **PHYS.10** Build system: 3D ghost preview + placement `2h` -> `0.03h`
### **PHYS.11** Physics sim tests `1.5h` -> `0.05h`

  - tags: [physics-factory, core]
  - priority: critical
    ```md
    All 11 PHYS cards completed in a single 0.7h session. Planned total: 22h.
    Overestimation ratio: 31x. Physics factory transport system fully replaced
    the old grid-based pull system with RigidBody3D items and force-field conveyors.
    ```

### **INT3D.1-7** 3D model integration: full game `12.5h` -> `0.3h`

  - tags: [3d-integration]
    ```md
    Integrated all 110+ .glb models into the game in 0.3h.
    - Ground: 2D tile sprites (existing MultiMesh) + 3D rock/chasm/rubble decorations
    - Player: swapped CapsuleMesh for player.glb with idle/walk/run animations
    - Deposits: 3D pyromite/crystalline/biovine models on deposit tiles with idle anims
    - Buildings: all 9 types use .glb models with AnimationPlayer state machine
    - Items: rewrote item_visual_manager for per-item .glb instances on conveyors
    - Lighting: WorldEnvironment with ambient light, SSAO, ACES tonemap
    All 8 sims pass, 33 unit tests pass.
    ```

### **ART3D.1** Smelter 3D model `~0.2h`

  - tags: [3d-art, buildings]
    ```md
    Smelter model with crucible, hoppers, chimney, gears, control panel.
    60+ parts, 4 NLA animations. Flat + textured exports.
    ```

### **ART3D.2** Splitter 3D model `~0.2h`

  - tags: [3d-art, buildings]
    ```md
    Splitter with round body, rotating distributor hub, 3 output chutes.
    4 NLA animations. Flat + textured exports.
    ```

### **ART3D.3** Conveyor belt 3D model `~0.2h`

  - tags: [3d-art, buildings]
    ```md
    Low-profile conveyor track with rollers, side walls, directional arrows.
    3 NLA states (idle/active/wall). Custom roller generator. Flat + textured.
    ```

### **ART3D.4** Junction + Tunnel 3D models `~0.2h`

  - tags: [3d-art, buildings]
    ```md
    Junction: 4-way crossover with raised guide arches for silhouette.
    Tunnel: arch portals with dark void interior. Custom arch_portal generator.
    Both flat + textured exports.
    ```

### **ART3D.5** Source + Sink debug buildings `~0.2h`

  - tags: [3d-art, buildings, debug]
    ```md
    Source: green upward arrow, output indicator. Sink: red grate funnel.
    Distinct silhouettes for instant identification. Flat + textured.
    ```

### **ART3D.6** M1 elemental deposits `~0.2h`

  - tags: [3d-art, resources, deposits]
    ```md
    Pyromite (jagged volcanic cones), Crystalline (hex crystal clusters),
    Biovine (mushroom/organic blobs). All distinguishable by color AND silhouette.
    ```

### **ART3D.7** Post-M1 elemental deposits `~0.2h`

  - tags: [3d-art, resources, deposits, post-m1]
    ```md
    Voltite (zig-zag lightning shards), Umbrite (amorphous dark mass),
    Resonite (crystals with torus rings). Extended elements palette.
    ```

### **ART3D.8** 3D item models: 6 elemental resources `~0.2h`

  - tags: [3d-art, resources, items]
    ```md
    6 tiny item models (~0.2 Blender units) with distinct colors and shapes.
    Fire teardrop, ice prism, nature seed, lightning shard, shadow orb, force diamond.
    ```

### **ART3D.9** 3D item models: combination resources `~0.2h`

  - tags: [3d-art, resources, items]
    ```md
    15 combination items (all pairwise combos). Visual blends of parent shapes/colors.
    Extended elements palette with 12 new combo color sets.
    ```

### **ART3D.10** Tendril Crawler monster model `~0.2h`

  - tags: [3d-art, monsters]
    ```md
    Psychedelic monster with pulsating sphere body, curving tendrils,
    neon green eye, torus collar. 3 NLA states: idle/move/attack.
    ```

### **ART3D.11** Acid Bloom + Phase Shifter monster models `~0.2h`

  - tags: [3d-art, monsters, post-m1]
    ```md
    Acid Bloom: toxic flower/fungus with petals, dripping acid, gold core.
    Phase Shifter: geometric diamond body with orbiting torus rings and fragments.
    ```

### **ART3D.12** Player character 3D model `~0.2h`

  - tags: [3d-art, player]
    ```md
    Chunky industrial worker with yellow hardhat (key identifier).
    20 mesh parts from prefabs. 4 NLA states: idle/walk/run/build.
    Added animate_scale() helper to anim_helpers.py.
    ```

### **ART3D.13** Projectile + effect models `~0.2h`

  - tags: [3d-art, combat, effects]
    ```md
    6 elemental projectiles: fire teardrop, ice shard, nature spore,
    lightning bolt, shadow orb+ring, force diamond. Spinning idle animation.
    ```

### **ART3D.14** Terrain features `~0.2h`

  - tags: [3d-art, terrain]
    ```md
    Rock cluster (boulders + facets), chasm pit (recessed void + crumbling edges),
    rubble debris pile (broken panels + pipes + scattered bolts). Flat + textured.
    ```

### **ART3D.15** Night-mode building variants `~0.2h`

  - tags: [3d-art, buildings, combat]
    ```md
    Conveyor wall (raised barriers + spikes), smelter turret (weapon barrel),
    splitter multi-turret (3 barrels), drill cache (armored + retracted derrick).
    3 NLA states: idle/active/transition. Flat + textured.
    ```
  
### **3D.1** GridUtils 3D API + dual-API bridge `2h` -> `0.1h`
### **3D.2** Game world scene tree: Node2D -> Node3D `3h` -> `0.2h`
### **3D.3** BuildSystem 3D input (mouse -> grid via raycast) `2h` -> `0.1h`
### **3D.4** Player CharacterBody2D -> CharacterBody3D `2h` -> `0.2h`
### **3D.5** Terrain rendering: MultiMesh3D ground plane `2h` -> `0.1h`
### **3D.6** Building base Node3D + placeholder meshes `2h` -> `0.1h`
### **3D.7** Conveyor + item visual manager 3D `3h` -> `0.2h`
### **3D.8** Simulation + test infrastructure update `1.5h` -> `0.05h`
### **3D.9** GridUtils 2D API removal (cleanup) `1h` -> `0.3h`
### **3D.10** Save/load migration `1h` -> `0.05h`

### **LIB.1** Isometric 3D Geometry Library `5h` -> `0.5h`

  - tags: [art-pipeline, tooling]
    ```md
    Full 3D-to-isometric rendering library at tools/rendering/iso/.
    10 modules: config, projection, zbuffer, shading, primitives (9 shapes),
    mechanical (gear/pipe/piston/fan), texture (12 patterns), animation,
    scene composition. Configurable projection (not hardcoded 2:1).
    8 example PNGs generated.
    ```

### **LIB.2** Scene lighting: ambient + point lights `1.5h` -> `0.2h`

  - tags: [art-pipeline, tooling]
    ```md
    Scene-level lighting module (lighting.lua). Three light types: ambient,
    directional, point (with colored tinting and quadratic falloff).
    Lights added via scene:add_light(). Default lights match old behavior.
    Fixed 05_textures example, added 09_lighting example.
    ```

### **S0** Design & Planning `~3h`

  - tags: [planning]
    ```md
    Market analysis, concept selection, design doc, project tracking setup.
    ~3h evening session. This was pure planning, no code.
    ```

### **P1.1** Gut ResearchManager references `~0.17h`

  - tags: [phase-1, strip]

### **P1.2** Gut ContractManager references `~0.17h`

  - tags: [phase-1, strip]

### **P1.3** Gut TutorialManager `~0.17h`

  - tags: [phase-1, strip]
    ```md
    AccountManager retained -- only TutorialManager removed. AccountManager needed for save slots.
    ```

### **P1.4** Gut EnergySystem `~0.17h`

  - tags: [phase-1, strip]

### **P1.5** Remove unused buildings and complex UI `~0.17h`

  - tags: [phase-1, strip]
    ```md
    Deleted 24 building types, research panel, recipe browser, tutorial panel, building info panel.
    Kept: conveyor, drill, smelter, splitter, junction, tunnel, sink, source.
    ```

### **P1.6** Strip test: run remaining simulations `~0.17h`

  - tags: [phase-1, test]
    ```md
    Updated simulation_base.gd, deleted 8 obsolete sims. All kept sims pass.
    All 6 P1 cards completed in a single 1h session.
    ```

### **P2.1** Define 3 elemental resources as ItemDef .tres `~0.1h`

  - tags: [phase-2, resources]
    ```md
    Created pyromite, crystalline, biovine + 3 combo items (steam_burst, verdant_compound, frozen_flame).
    New item atlas with 6 pixel art sprites. Deleted 63 Factor items.
    ```

### **P2.2** Define elemental recipes `~0.1h`

  - tags: [phase-2, resources]
    ```md
    3 smelter recipes: pyromite+crystalline->steam_burst, crystalline+biovine->verdant_compound, pyromite+biovine->frozen_flame.
    Deleted 58 Factor recipes.
    ```

### **P2.3** New world generator: 128x128 with elemental deposits `~0.1h`

  - tags: [phase-2, worldgen]
    ```md
    Rewrote world_generator.gd for 128x128 arena. 3 deposit types at 3 distance tiers.
    Noise walls with distance-based density, stone veins, connectivity guarantee.
    Updated TileDatabase with TILE_PYROMITE, TILE_CRYSTALLINE, TILE_BIOVINE.
    ```

### **P2.4** Update BuildingDefs for kept buildings `~0.1h`

  - tags: [phase-2, resources]
    ```md
    All 9 BuildingDefs updated: removed build_cost (free placement for M1), removed iron_plate references.
    Updated all code references from old item IDs to elemental IDs.
    ```

### **P2.5** Sim test: resource flow `~0.1h`

  - tags: [phase-2, test]
    ```md
    New sim_elemental_flow.gd: tests drill->conveyor->smelter->sink with 2-input recipes.
    Fixed simulation exit hang (reset time_scale before quit). All 8 sims pass.
    All 5 P2 cards completed in a single 0.5h session.
    ```

### **ISO.1** Centralize all coordinate math into GridUtils `~0.06h`

  - tags: [isometric, refactor, critical-path]
    ```md
    De-risk step: 80+ coordinate conversions across 26 files funneled through one utility.
    After this, switching to isometric is a single-point change in GridUtils.
    ```

### **ISO.2** Switch GridUtils to isometric diamond projection `~0.06h`

  - tags: [isometric, engine]
    ```md
    The actual projection switch. grid_to_world/world_to_grid use isometric transform.
    TileSet configured with TILE_SHAPE_ISOMETRIC, TILE_LAYOUT_DIAMOND_DOWN.
    ```

### **ISO.3** Y-sort scene hierarchy + depth sorting `~0.06h`

  - tags: [isometric, engine]
    ```md
    Restructured scene hierarchy with ObjectLayer for y-sort depth sorting.
    Removed manual z_index layering.
    ```

### **ISO.4** Update BuildSystem for diamond grid `~0.06h`

  - tags: [isometric, gameplay]
    ```md
    Diamond grid overlay, isometric ghost preview, diamond destroy area visualization.
    ```

### **ISO.5** Update ConveyorSystem + item rendering for isometric `~0.06h`

  - tags: [isometric, engine]
    ```md
    Conveyor entry/exit points and item lerp paths follow diamond-projected directions.
    MultiMesh quad sizing updated to 64x32.
    ```

### **ISO.6** Isometric terrain art `~0.06h`

  - tags: [isometric, art]
    ```md
    New isometric terrain atlas (512x480, 8x15 grid of 64x32 diamonds).
    Diamond tiles show top face + slight front edge for depth.
    ```

### **ISO.7** Isometric building sprites `~0.06h`

  - tags: [isometric, art]
    ```md
    Building sprites kept at 32x32 (functional, art upgrade post-M1).
    ```

### **ISO.8** Isometric conveyor + item art `~0.06h`

  - tags: [isometric, art]
    ```md
    New isometric conveyor atlas (256x192, 4x6 grid). Updated item sprites.
    ```

### **ISO.9** Integration test: full isometric verification `~0.06h`

  - tags: [isometric, test]
    ```md
    45 unit tests for GridUtils coordinate math, all 9 simulations pass.
    All 9 ISO cards completed in a single 0.5h session.
    ```

### **ART.1** Terrain tiles with elevation and depth `~0.5h`

  - tags: [art, elevation, foundation]
    ```md
    Rewrote terrain atlas with front-edge depth shading, raised ore formations,
    textured walls. All 17 types improved. Atlas layout unchanged (512x480).
    ```

### **ART.2** Building sprites with vertical extension `~0.5h`

  - tags: [art, elevation, buildings]
    ```md
    Converted all 7 buildings from top-down 32x32 to isometric 64x48 with elevation.
    Created new generate.lua for splitter, junction, tunnel. Updated all .tscn files.
    ```

### **ART.3** Conveyor sprites with elevation `~0.5h`

  - tags: [art, elevation, conveyors]
    ```md
    Raised track with side walls, support struts, directional lighting.
    Atlas layout unchanged (256x192, 4x6 grid).
    ```

### **ART.4** Item sprites with depth and volume `~0.5h`

  - tags: [art, elevation, items]
    ```md
    8 tones per item (up from 6), specular highlights, anti-aliased shadow edges.
    All 6 items volumetric. Atlas unchanged (96x16).
    All 4 ART cards completed in a single 2h session.
    ```

## Velocity Reference

### Overestimation analysis (planned vs actual)

| Card Group | Planned | Actual | Ratio |
|-----------|---------|--------|-------|
| 3D.1-3D.10 (migration) | 22h | 1.7h | 13x over |
| PHYS.1-11 (migration) | 22h | 0.7h | 31x over |
| INT3D.1-7 (integration) | 12.5h | 0.3h | 42x over |
| SCN.1 (novel framework) | 4h | 0.4h | 10x over |
| LIB.1 (novel tooling) | 5h | 0.5h | 10x over |
| LIB.2 (novel tooling) | 1.5h | 0.2h | 7.5x over |
| MAP.1 (novel gameplay) | 2h | 1.7h | 1.2x over |
| P1.1-6 (stripping) | ~6h | 1h | 6x over |
| P2.1-5 (data setup) | ~5h | 0.5h | 10x over |
| ISO.1-9 (conversion) | ~9h | 0.5h | 18x over |

**Key finding**: Migration/refactoring tasks were 13-42x overestimated. Novel tooling was 7-10x over. Novel gameplay (MAP.1) was only 1.2x over -- nearly accurate.

**Calibration rule for remaining tasks**: Novel gameplay features should use ~50% of original estimates. Infrastructure/integration tasks should use ~10%.
