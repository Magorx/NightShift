# Night Shift -- Project Board

## In Progress

## Done (move to BOARD_SOLVED.md next session)

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

