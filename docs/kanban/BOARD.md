# Night Shift -- Project Board

## In Progress

## Done (move to BOARD_SOLVED.md next session)

### **P3.1** RoundManager autoload singleton `1h` -> `0.05h actual`


### **P3.2** Phase HUD: timer + round counter `0.5h` -> `0.05h actual`


### **P3.3** Build phase: enable placement, conveyors run `0.5h` -> `0.03h actual`


### **P3.4** Fight phase: freeze factory, placeholder combat `0.5h` -> `0.03h actual`


### **P3.5** Day/night visual shift `0.5h` -> `0.03h actual`


### **P3.6** Sim test: round cycling `0.5h` -> `0.05h actual`


## Backlog

### **P4.1** General HP component `0.5h`

  - tags: [phase-4, combat]
  - priority: medium
  - workload: Normal
  - defaultExpanded: false
  - steps:
      - [ ] Create `scripts/game/health_component.gd` -- general-purpose HP node: max_hp, current_hp, damage(amount), heal(amount), signals (damaged, healed, died)
      - [ ] Damage visual states for buildings: cracks at 75%, scarring at 50%, heavy at 25%, destroyed at 0%
      - [ ] Attach to buildings via `building_logic.gd` (same pattern as energy was)
      - [ ] On building destroy: remove building via GameManager, leave rubble marker
      - [ ] Reusable for monsters, player, and any future destructible entity
    ```md
    General-purpose HealthComponent, not building-specific. Will be used by buildings, monsters,
    player -- everything that has HP. Same architecture pattern as the removed BuildingEnergy.
    Original estimate 1.5h, recalibrated to 0.5h.
    ```

### **P4.2** Night transform: conveyors become walls `1h`

  - tags: [phase-4, transform]
  - priority: medium
  - steps:
      - [ ] Conveyors always have HP (via HealthComponent from P4.1) -- they are normal buildings, damage persists across phases
      - [ ] Create `scripts/game/night_transform.gd` -- iterates buildings, applies night state
      - [ ] Register with `RoundManager.phase_changed`
      - [ ] On fight: conveyors block monster pathing, stop moving items
      - [ ] Straight conveyors → walls (1-tile height barriers)
      - [ ] Turn conveyors → towers (2-tile height constructs, elevated vantage)
      - [ ] Swap to night-form model (wall/tower), swap back on day
      - [ ] Damage from previous nights persists until the player repairs the conveyor
    ```md
    Core Night Shift mechanic: your conveyor layout IS your defense layout.
    Conveyors always have HP like any other building -- they don't magically gain it at night.
    If a conveyor gets damaged during a night, it stays damaged until repaired.
    Straight conveyors become walls, turn conveyors become towers (taller, more strategic).
    Original estimate 2h, recalibrated to 1h.
    ```

### **P4.3** Aiming system + turret behavior `1.5h`

  - tags: [phase-4, combat, aiming]
  - priority: medium
  - steps:
      - [ ] Create `scripts/game/aim_component.gd` -- general-purpose aiming node: given a target position, compute the rotation/transform to face it. Usable by turrets, shooting monsters, player
      - [ ] Supports configurable turn speed (instant snap vs smooth tracking), aim constraints (e.g. max angle)
      - [ ] Create `scripts/game/turret_behavior.gd` -- uses AimComponent, handles target selection (nearest enemy in range), firing cooldown
      - [ ] Create `scripts/game/projectile.gd` + `scenes/game/projectile.tscn`
      - [ ] Add `last_processed_element` to `converter.gd`, toggle day/night behavior
      - [ ] Turret fires projectiles based on last processed resource, nearest monster in range
    ```md
    General aiming system first, then turret on top. AimComponent is a reusable node:
    "I want to look at this position, give me the right transform." Used by turrets,
    shooting monsters, and player aiming alike. Then turret behavior composes
    AimComponent + firing logic for the converter night transform.
    Converters become elemental turrets at night. Projectile color matches element.
    Original estimate 2h, bumped to 1.5h to account for the general aiming system.
    ```

### **P4.4** Resource memory for buildings `0.5h`

  - tags: [phase-4, combat, transform]
  - priority: medium
  - steps:
      - [ ] Drills remember the resource type they last mined (e.g. iron, copper) -- stored as `last_resource: ItemDef`
      - [ ] Converters remember the last recipe they processed -- stored as `last_recipe: RecipeDef`
      - [ ] This determines the element/damage type when buildings transform at night
      - [ ] Persist across day/night transitions within the same run
    ```md
    Buildings need to remember what they produced so their night form knows what
    damage type to deal. Drill on iron ore → fire element turret, converter
    that last ran copper wire recipe → electric element, etc.
    ```

### **P4.5** Night transform 3D models `2h`

  - tags: [phase-4, art, blender]
  - priority: medium
  - steps:
      - [ ] Wall model (straight conveyor night form): 1-tile height, solid barrier look
      - [ ] Tower model (turn-conveyor night form): 2-tile height construct, watchtower feel
      - [ ] Basic turret model (1x1 buildings like drill night form): small gun/cannon on a base
      - [ ] Rocket turret model (smelter night form): larger, more intimidating launcher
      - [ ] All models follow Blender pipeline: prefabs, NLA animations, .glb export
      - [ ] Output to respective `buildings/<name>/models/` directories
    ```md
    Night-form 3D models for all building transformations:
    - Straight conveyors → walls (1-tile height barriers)
    - Turn conveyors → towers (2-tile height constructs)
    - 1x1 buildings (drill etc.) → basic turrets
    - Smelter → rocket turret (special, larger)
    ```

### **P4.6** Sim test: transformation `0.25h`

  - tags: [phase-4, test]
  - priority: medium
  - steps:
      - [ ] Place buildings, trigger night, verify conveyors have HP and transform to walls/towers
      - [ ] Verify converters fire projectiles with correct element from last recipe
      - [ ] Verify drills remember last resource and pick correct damage type
      - [ ] Validate: sim passes headless
    ```md
    Automated test of building transformation + resource memory.
    Original estimate 0.5h, recalibrated to 0.25h.
    ```

### **P5.1** Monster base class + Tendril Crawler `1.5h`

  - tags: [phase-5, monsters]
  - priority: medium
  - steps:
      - [ ] Create `monsters/monster_base.gd` -- HP, speed, damage, pathfinding, attack
      - [ ] Create `monsters/tendril_crawler/tendril_crawler.gd` -- line destruction pattern
      - [ ] Create `monsters/tendril_crawler/tendril_crawler.tscn` -- sprite, collision
      - [ ] Placeholder sprite: 16x16 pulsating geometric shape
    ```md
    First monster type. Follows A* path toward nearest building, attacks in melee range.
    Original estimate 3h, recalibrated to 1.5h (most complex novel card in M1).
    ```

### **P5.2** Monster spawner `1h`

  - tags: [phase-5, monsters]
  - priority: medium
  - steps:
      - [ ] Create `scripts/game/monster_spawner.gd` -- connects to RoundManager
      - [ ] Spawn at map edges during fight phase, avoid walls
      - [ ] Wave scaling: round_1_count=5, count_per_round=3, spawn_interval=2.0s
    ```md
    Spawns monsters at map edges with wave scaling per round.
    Original estimate 2h, recalibrated to 1h.
    ```

### **P5.3** Monster pathfinding (A*) `1h`

  - tags: [phase-5, monsters]
  - priority: medium
  - steps:
      - [ ] Create `scripts/game/monster_pathfinding.gd` -- wraps AStar2D
      - [ ] Build grid from GameManager.buildings (wall-mode conveyors are impassable)
      - [ ] Shared grid rebuilt once per fight start + when buildings destroyed
      - [ ] Individual monsters query for paths
    ```md
    Risk: performance with 50+ monsters. Use shared grid, batch pathfinding, limit recalculation.
    Original estimate 2.5h, recalibrated to 1h.
    ```

### **P5.4** Monster-building combat `1h`

  - tags: [phase-5, combat]
  - priority: medium
  - steps:
      - [ ] Monsters attack buildings when adjacent (Tendril Crawler: 1 building per attack)
      - [ ] Turret projectiles damage monsters via collision
      - [ ] Monster death: no drops (currency comes with shop system)
      - [ ] Monsters deal damage to player if adjacent, player can dodge
    ```md
    Monster-building and monster-player combat interactions.
    Original estimate 2h, recalibrated to 1h.
    ```

### **P5.5** Fight phase end condition `0.5h`

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
    Original estimate 1h, recalibrated to 0.5h.
    ```

### **P5.6** Sim test: full combat loop `0.5h`

  - tags: [phase-5, test]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Run 3 full rounds: build, survive waves, verify damage and kills
      - [ ] Validate: sim passes headless
    ```md
    End-to-end combat simulation.
    Original estimate 1.5h, recalibrated to 0.5h.
    ```

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

