# Night Shift -- Project Board

## In Progress

## Done (move to BOARD_SOLVED.md next session)

### **SPAWN.1** Monster spawn area system `0.3h`

  - tags: [monsters, spawning]
  - priority: high

## Backlog

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

