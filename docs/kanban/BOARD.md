# Night Shift -- Project Board

## In Progress

## Done (move to BOARD_SOLVED.md next session)

### **P5.1** Monster base class + Tendril Crawler `1.5h` -> `0.3h actual`
### **P5.2** Monster spawner `1h` -> `0.15h actual`
### **P5.3** Monster pathfinding (A*) `1h` -> `0.15h actual`
### **P5.4** Monster-building combat `1h` -> `0.2h actual`
### **P5.5** Fight phase end condition `0.5h` -> `0.15h actual`
### **P5.6** Sim test: full combat loop `0.5h` -> `0.5h actual`

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
      - [ ] Player moves freely during fight but cannot place buildings
      - [ ] Add basic attack action (melee punch or elemental throw from inventory)
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
