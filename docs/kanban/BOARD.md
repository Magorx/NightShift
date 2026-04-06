# Night Shift -- Project Board

## In Progress

## Done (move to BOARD_SOLVED.md next session)

### **SPAWN.1** Monster spawn area system `0.3h`

  - tags: [monsters, spawning]
  - priority: high
  - planned: 0.5h | actual: 0.3h
  - steps:
      - [x] Add budget_cost to MonsterBase (default 2 for TendrilCrawler)
      - [x] Create SpawnArea class with square (5x5) and line (8-cell) shapes
      - [x] Create SpawnLogic base + OneByOne and AllTogether implementations
      - [x] Rewrite MonsterSpawner: ring placement, budget distribution, area orchestration
      - [x] Spawn area visuals: ground highlight mesh + searing particle emitter
      - [x] Fix scn_fight_phase_end scenario (add more buildings to survive budget)
    ```md
    Replaced simple ring-spawner with SpawnArea zones.
    Budget formula: 10*round + 2*round^1.5. Areas: 2-6 scaling with round.
    ```

## Backlog

### **P6.1** Simplify player inventory to 8 slots `0.25h`

  - tags: [phase-6, player]
  - priority: low
  - steps:
      - [ ] Change INVENTORY_SLOTS to 8 in `player/player.gd` (keep STACK_SIZE=16)
      - [ ] Update `scripts/ui/inventory_panel.gd` to 8-slot layout (1 row of 8)
    ```md
    Simpler inventory for roguelite pacing.
    Original estimate 1h, recalibrated to 0.25h (trivial constant change).
    ```

### **P6.2** Player combat actions during fight `1h`

  - tags: [phase-6, player]
  - priority: low
  - steps:
      - [x] LMB shoots turret-style projectiles when not in build/destroy mode
      - [x] Aim at cursor ground pos + half player height offset
      - [x] Debug aim line (red, neck→aim point, debug mode only)
      - [ ] Player moves freely during fight but cannot place buildings
      - [ ] Keep simple for M1
    ```md
    Light player combat. No building placement during fight phase.
    Original estimate 2h, recalibrated to 1h.
    ```

### **P6.3** Run-based save/load `0.5h`

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
    Original estimate 1.5h, recalibrated to 0.5h.
    ```

### **P6.4** New main menu `0.5h`

  - tags: [phase-6, ui]
  - priority: low
  - workload: Normal
  - steps:
      - [ ] "New Run", "Continue" (if save exists), "Settings", "Quit"
      - [ ] Modify `scripts/ui/main_menu.gd` and `scenes/ui/main_menu.tscn`
    ```md
    Replace Factor's account-slot menu with simple run-based menu.
    Original estimate 1.5h, recalibrated to 0.5h.
    ```

### **P6.5** Building placement UX for M1 `0.5h`

  - tags: [phase-6, ui]
  - priority: low
  - workload: Normal
  - steps:
      - [ ] Set creative_mode = true in `game_manager.gd` (unlimited free buildings for M1)
      - [ ] Add simple building hotbar to HUD
      - [ ] All M1 buildings available: conveyor, drill, smelter, splitter
    ```md
    No shop yet, so player starts with unlimited buildings.
    Original estimate 1.5h, recalibrated to 0.5h.
    ```

### **P6.6** End-to-end playtest + bug fixing `1h`

  - tags: [phase-6, test]
  - priority: low
  - workload: Normal
  - steps:
      - [ ] Play full 3-round run
      - [ ] Fix crashes, balance timing, adjust monster difficulty
      - [ ] Document issues for M2
    ```md
    Final M1 polish and bug bash. Playtesting is inherently time-consuming.
    Original estimate 1.5h, recalibrated to 1h.
    ```

### **BOT.1** BotPlayer base class + random build behavior `1h`

  - tags: [botplayer, testing, infrastructure]
  - priority: medium
  - steps:
      - [ ] Create `tests/bot/bot_player.gd` extending `SimulationBase`
      - [ ] Implement `BotBrain` inner class -- the decision-maker that runs each tick
      - [ ] `BotBrain` holds: player grid position, known deposits (scanned from `GameManager.deposits`), placed buildings list, current goal (enum: EXPLORE, BUILD, OBSERVE)
      - [ ] **Random walk**: each decision tick (every ~60 frames), pick a random walkable grid cell within radius 10 of current position, set as move target. Move one cell per tick toward target (cardinal directions only, skip walls)
      - [ ] **Random build**: when adjacent to an empty cell, roll a weighted random to place a building. Weights: conveyor 50%, drill 15% (only on deposit), smelter 15%, splitter 10%, source 5%, sink 5%. Pick random valid rotation (0-3). Skip if cell occupied or invalid (drill off-deposit, multi-cell overlap)
      - [ ] **Conveyor chaining**: 30% chance after placing a conveyor to place 1-4 more in the same direction (capped by obstacles). This creates usable conveyor lines instead of scattered singles
      - [ ] **Decision tick rate**: configurable `ticks_per_decision` (default 60 = 1 decision/sec at 60fps). Between decisions, bot just advances simulation time
      - [ ] **Run config**: `bot_duration_seconds` (default 300 = 5 min game time), `bot_seed` (RNG seed for reproducibility)
      - [ ] Log all actions to stdout: `[BOT] tick=120 action=place_building type=conveyor pos=(5,3) rot=0`
    ```md
    The core BotPlayer that makes random-but-valid decisions in headless simulation.
    Similar scope to SCN.1 (0.4h actual from 4h estimate).
    Original estimate 3h, recalibrated to 1h.
    ```

### **BOT.2** Metric collector + run summary `0.5h`

  - tags: [botplayer, testing, metrics]
  - priority: medium

### **BOT.3** Bot strategies: greedy builder + line builder `1h`

  - tags: [botplayer, testing, strategies]
  - priority: medium

### **BOT.4** Bot runner: batch execution + comparison `0.5h`

  - tags: [botplayer, testing, runner]
  - priority: medium

### **BOT.5** Visual bot mode: watch the bot build `0.5h`

  - tags: [botplayer, testing, visual]
  - priority: low

### **BOT.6** Sim test: bot smoke test `0.25h`

  - tags: [botplayer, testing, verification]
  - priority: medium

### ~~Bug: conveyors restore into wrong direction after the night. Also they are offset in night mode~~ FIXED

  - defaultExpanded: false

## Estimate Summary

## Post-M1 Backlog

### **3D.1** Migrate grid from Vector2i to Vector3i `3h`

  - tags: [post-m1, 3d-world, architecture]
  - priority: high (blocks vertical building, foundations, caves)
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
  - priority: high (blocks foundations)
  - depends: 3D.1
  - steps:
      - [ ] Auto-detect stacking height: placing on a cell finds the topmost solid block and stacks at z+1
      - [ ] Ghost preview renders at correct Y elevation (terrain_height + z * LAYER_HEIGHT)
      - [ ] `can_place_building()` enforces support rule: cell at (x, y, z-1) must be solid (terrain or building)
      - [ ] Player destroy mode targets topmost building in column by default
      - [ ] Click/inspect targets topmost building at grid (x, y) column
      - [ ] Monster targeting: iterate by top-of-column (don't target buried buildings)
    ```md
    Makes vertical building feel natural. The player never manually selects a z-layer —
    the system auto-stacks. Destroy peels from the top down. Monsters see the top.
    ```

### **3D.3** 3D terrain: caves and overhangs `4h`

  - tags: [post-m1, 3d-world, terrain]
  - priority: medium
  - depends: 3D.1
  - steps:
      - [ ] Replace flat `terrain_heights: PackedFloat32Array` with volumetric or layered data (solid/air per cell per z-layer)
      - [ ] Cave generation: predefined cave biomes carved into terrain, not player-dug
      - [ ] Terrain collision for 3D volumes (update HeightMapShape3D or switch to trimesh chunks)
      - [ ] Visual rendering: multi-layer terrain meshes with cave ceilings
      - [ ] Pathfinding: A* grid accounts for solid/air per layer, monsters navigate cave interiors
    ```md
    Full 3D terrain. Caves are pre-generated map features, not player-created.
    This is the most complex 3D card — can be deferred past 3D.1/3D.2 if vertical
    building on flat terrain is sufficient for initial playtesting.
    ```

### **3D.4** Pathfinding for vertical world `1.5h`

  - tags: [post-m1, 3d-world, pathfinding]
  - priority: medium
  - depends: 3D.1
  - steps:
      - [ ] Update A* grid to handle z-layers (separate walkable grid per layer, or 3D A*)
      - [ ] Monsters walk on top of foundations/buildings (if `is_ground_level`)
      - [ ] Ramps/stairs between z-layers (or vertical movement at designated cells)
      - [ ] Monster targeting respects vertical distance, not just XZ
    ```md
    Monsters need to navigate a world with elevation. Can be scoped down for M2:
    just block z>0 cells as walls and pathfind on z=0 only.
    ```

### **FOUND.1** Foundation building `1h`

  - tags: [post-m1, buildings, structure]
  - priority: medium
  - depends: 3D.1, 3D.2
  - steps:
      - [ ] 3D model: 1x1x1 metal cube via Blender script (`tools/blender/scenes/foundation_model.py`)
      - [ ] `buildings/foundation/`: `.gd` (extends BuildingLogic, no processing, no IO), `.tscn`, `.tres`
      - [ ] BuildingDef: `category="structure"`, `is_ground_level=false`, no build cost for M2
      - [ ] Night mode: `set_night_mode()` does nothing — stays a metal cube
      - [ ] Any building can be placed at z+1 above a foundation (standard 3D.2 stacking rules)
      - [ ] Destruction: top building destroyed first, foundation only when exposed (standard 3D.2 top-down destroy)
    ```md
    Trivial once 3D grid + vertical placement exist. A 1x1x1 cube that does nothing.
    Player builds on top of it for elevation. At night it stays inert — a wall, basically.
    Future: HP bonus for buildings on foundations, reinforced variants.
    ```

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
