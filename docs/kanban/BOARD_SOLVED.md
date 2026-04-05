# Night Shift -- Solved Cards

## Done

### **SCN.1** Scenario test framework: scripted integration tests `4h` → `2h`

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

### **PHYS.1** Physics item: RigidBody3D resource entity `2h` → `0.1h`
### **PHYS.2** Conveyor belt: physics surface transport `3h` → `0.1h`
### **PHYS.3** Building IO zones: 3D input/output areas `2h` → `0.15h`
### **PHYS.4** Drill extractor: physics item spawner `1.5h` → `0.05h`
### **PHYS.5** Smelter/Converter: physics-based processing `2h` → `0.05h`
### **PHYS.6** Splitter: physics deflector `1.5h` → `0.05h`
### **PHYS.7** Source/Sink debug buildings + junction/tunnel `1.5h` → `0.05h`
### **PHYS.8** Gut old transport system `2h` → `0.1h`
### **PHYS.9** Building .tscn 3D rewrite: all scenes `3h` → `0.1h`
### **PHYS.10** Build system: 3D ghost preview + placement `2h` → `0.03h`
### **PHYS.11** Physics sim tests `1.5h` → `0.05h`

  - tags: [physics-factory, core]
  - priority: critical
  - steps:
      - [ ] Create `scripts/game/physics_item.gd` extending `RigidBody3D`
      - [ ] Properties: `item_id: StringName` (one item = one resource, no quantity/stacking)
      - [ ] On `_ready`: load .glb model from `resources/items/models/{item_id}_item.glb`, add as child
      - [ ] Collision: small `SphereShape3D` (radius ~0.1), physics material with moderate friction + bounce
      - [ ] Auto-despawn timer (120s), no merging — each item is a distinct physical object
      - [ ] Item spawning helper: `PhysicsItem.spawn(item_id, position, impulse)` static factory
      - [ ] Player pickup: detect via `Area3D` overlap, E to collect
    ```md
    The atomic unit of the physics factory. Items are real rigid bodies that roll,
    bounce, pile up, and get scattered by explosions. Replaces the old discrete
    conveyor slot system entirely.
    ```

### **PHYS.2** Conveyor belt: physics surface transport `3h`

  - tags: [physics-factory, transport]
  - priority: critical
  - depends: PHYS.1
  - steps:
      - [ ] Rewrite conveyor as `StaticBody3D` with conveyor.glb model
      - [ ] Transport mechanism: `Area3D` trigger zone on top surface, applies constant force to overlapping RigidBody3D items in the conveyor's facing direction
      - [ ] Tune force magnitude so items move at a satisfying speed (~2-3 tiles/sec)
      - [ ] Side walls on the conveyor model prevent items from falling off
      - [ ] Items pile up naturally at the end if blocked — no discrete slots
      - [ ] Conveyor-to-conveyor: items roll from one onto the next via physics
      - [ ] Update `conveyor.tscn` with the new StaticBody3D + Area3D structure
    ```md
    Conveyors are physical surfaces that push items. No pull system, no slots.
    Items roll along via applied forces. The conveyor.glb model already has
    side walls and rollers — use those as collision geometry.
    ```

### **PHYS.3** Building IO zones: 3D input/output areas `2h`

  - tags: [physics-factory, buildings]
  - priority: critical
  - depends: PHYS.1
  - steps:
      - [ ] Define input zones as `Area3D` volumes slightly inside the building mesh — items roll/slide into the building visually
      - [ ] Define output zones as `Area3D` volumes at the output edge — spawned items appear here with a small outward impulse
      - [ ] Replace the old IO marker system (ColorRect, direction masks) with `Marker3D` + `Area3D` pairs in each building .tscn
      - [ ] Input zone detects overlapping `PhysicsItem` nodes, building logic consumes them
      - [ ] Output zone is just a spawn point — building logic calls `PhysicsItem.spawn()` at the output position
      - [ ] Update `building_def.gd` to extract IO zone positions from `Marker3D` nodes instead of ColorRect offsets
    ```md
    Buildings don't blindly suck up all nearby items. Each building has dedicated
    input zones (recessed into the mesh so items visually flow in) and output zones
    (at the edge where products appear). The spatial design of IO creates natural
    item flow without a pull system.
    ```

### **PHYS.4** Drill extractor: physics item spawner `1.5h`

  - tags: [physics-factory, buildings]
  - priority: critical
  - depends: PHYS.1, PHYS.3
  - steps:
      - [ ] Rewrite drill logic to spawn `PhysicsItem` at its output zone on a timer
      - [ ] Item gets a small outward impulse so it rolls onto an adjacent conveyor
      - [ ] If no conveyor, items pile up at the output — player can pick them up manually
      - [ ] Update `drill.tscn`: Node3D root + drill.glb model + output `Area3D`/`Marker3D` + logic script
      - [ ] Remove all references to the old pull-based extraction
    ```md
    Drills periodically spawn physical resource items at their output. No pull
    system — items just appear and roll. If nothing carries them away, they pile up.
    ```

### **PHYS.5** Smelter/Converter: physics-based processing `2h`

  - tags: [physics-factory, buildings]
  - priority: critical
  - depends: PHYS.1, PHYS.3
  - steps:
      - [ ] Rewrite converter logic: input `Area3D` detects items entering, accumulates recipe ingredients
      - [ ] When recipe is satisfied (e.g. 1 pyromite + 1 crystalline), consume both items (queue_free) and spawn output `PhysicsItem` at output zone
      - [ ] Input zone positioned inside the mesh — items roll in and visually disappear into the building
      - [ ] Output zone at the building edge with outward impulse
      - [ ] Update `smelter.tscn` with input/output Area3D zones
      - [ ] Visual: play "active" animation while processing
    ```md
    Converters have input zones slightly inside the building so items flow into them
    visually. When the right combination arrives, the output appears at the other side.
    No pull system — just spatial item detection.
    ```

### **PHYS.6** Splitter: physics deflector `1.5h`

  - tags: [physics-factory, buildings]
  - priority: high
  - depends: PHYS.2
  - steps:
      - [ ] Rewrite splitter as a physical geometry that deflects items
      - [ ] Rotating distributor hub in the model directs items to alternating output chutes
      - [ ] Or: angled collision surfaces split incoming item stream mechanically
      - [ ] 3 output directions (forward, left-forward, right-forward)
      - [ ] Update `splitter.tscn` with collision geometry
    ```md
    The splitter physically redirects items using geometry, not logic. The rotating
    hub or angled surfaces create a natural 3-way split. Items bounce and roll
    to different outputs based on timing and physics.
    ```

### **PHYS.7** Source/Sink debug buildings + junction/tunnel `1.5h`

  - tags: [physics-factory, buildings, debug]
  - priority: medium
  - depends: PHYS.1, PHYS.3
  - steps:
      - [ ] Source: spawns items at a configurable rate, outputs via physics
      - [ ] Sink: Area3D consumes any item that enters, counts deliveries
      - [ ] Junction: open crossover — items roll through in any direction (no blocking)
      - [ ] Tunnel: pair of portals — item entering one teleports to the other with preserved velocity
      - [ ] Update all .tscn files
    ```md
    Debug/utility buildings adapted for physics transport.
    ```

### **PHYS.8** Gut old transport system `2h`

  - tags: [physics-factory, cleanup]
  - priority: medium
  - depends: PHYS.2, PHYS.4, PHYS.5
  - steps:
      - [ ] Remove `ConveyorSystem` (per-frame tick processing)
      - [ ] Remove `GameManager.pull_item()` and the entire pull-based transfer system
      - [ ] Remove `ItemBuffer` class and discrete item slot logic
      - [ ] Remove `ConveyorBelt` class (replaced by physics conveyor)
      - [ ] Remove old `item_visual_manager.gd` and `item_visual_handle.gd` (items are now real nodes)
      - [ ] Remove `conveyor_visual_manager.gd` (conveyors are individual scene instances)
      - [ ] Clean up `GameManager` references to removed systems
      - [ ] Update/remove simulations that test the old transport
    ```md
    Delete everything from the Factor engine's discrete transport system.
    The physics system replaces it entirely. Big cleanup card.
    ```

### **PHYS.9** Building .tscn 3D rewrite: all scenes `3h`

  - tags: [physics-factory, scenes]
  - priority: critical
  - depends: PHYS.3
  - steps:
      - [ ] Rewrite `drill.tscn`: Node3D root + drill.glb (pre-scaled) + output Marker3D/Area3D + ExtractorLogic
      - [ ] Rewrite `conveyor.tscn`: StaticBody3D root + conveyor.glb + transport Area3D + ConveyorLogic
      - [ ] Rewrite `smelter.tscn`: Node3D root + smelter.glb + input/output Area3D + ConverterLogic
      - [ ] Rewrite `splitter.tscn`: Node3D root + splitter.glb + deflection geometry + SplitterLogic
      - [ ] Rewrite `source.tscn`, `sink.tscn`: debug buildings with Area3D zones
      - [ ] Rewrite `junction.tscn`, `tunnel_input.tscn`, `tunnel_output.tscn`
      - [ ] Each scene: .glb model pre-scaled to grid size, Marker3D for anchor, Area3D for IO
      - [ ] Remove all Node2D/ColorRect/AnimatedSprite2D remnants
      - [ ] Update `building_def.gd` extraction for the new 3D scene structure
    ```md
    Every building .tscn becomes a clean 3D scene: Node3D root, imported .glb model
    at correct scale, Area3D IO zones, and logic script. No more 2D legacy nodes.
    This is the central card — all physics building cards depend on the scene structure
    defined here.
    ```

### **PHYS.10** Build system: 3D ghost preview + placement `2h`

  - tags: [physics-factory, ui]
  - priority: high
  - depends: PHYS.9
  - steps:
      - [ ] Update `build_system.gd` ghost creation to instantiate the new 3D .tscn scenes
      - [ ] Ghost tinting: iterate MeshInstance3D children, apply transparent overlay material
      - [ ] Ghost placement: position in GhostLayer (Node3D), not Node2D
      - [ ] Ghost rotation: Y-axis rotation matching building rotation
      - [ ] Validity coloring: green tint = valid, red tint = blocked
      - [ ] Disable physics/Area3D on ghost instances (set collision layers to 0)
    ```md
    Build mode shows proper 3D model ghosts. The ghost is the actual building scene
    with physics disabled and a transparent tint applied to all meshes.
    ```

### **PHYS.11** Physics sim tests `1.5h`

  - tags: [physics-factory, test]
  - priority: medium
  - depends: PHYS.4, PHYS.5, PHYS.6
  - steps:
      - [ ] Write sim: drill spawns items, items roll onto conveyor, reach sink
      - [ ] Write sim: two resources converge at smelter, output produced
      - [ ] Write sim: splitter divides item stream
      - [ ] Write sim: items pile up when blocked (no crash, no leak)
      - [ ] All sims must run headless with `--fixed-fps 60`
    ```md
    New simulation tests for the physics transport system. The old conveyor/pull
    simulations will be removed in PHYS.8.
    ```

### **INT3D.1-7** 3D model integration: full game (2026-04-05)

  - tags: [3d-integration]
    ```md
    Integrated all 110+ .glb models into the game. Planned 12.5h, actual ~0.3h.
    - Ground: 2D tile sprites (existing MultiMesh) + 3D rock/chasm/rubble decorations
    - Player: swapped CapsuleMesh for player.glb with idle/walk/run animations
    - Deposits: 3D pyromite/crystalline/biovine models on deposit tiles with idle anims
    - Buildings: all 9 types (drill, conveyor, smelter, splitter, source, sink,
      junction, tunnel) use .glb models with AnimationPlayer state machine
    - Items: rewrote item_visual_manager for per-item .glb instances on conveyors;
      ground items also get 3D models with fallback colored spheres
    - Lighting: WorldEnvironment with ambient light, SSAO, ACES tonemap
    All 8 sims pass, 33 unit tests pass.
    ```

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
