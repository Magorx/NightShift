# Night Shift -- Project Board

## In Progress

## Done (move to BOARD_SOLVED.md next session)

## Backlog

### **P3.1** RoundManager autoload singleton `1h`

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
    Original estimate 2h, recalibrated to 1h based on velocity data.
    ```

### **P3.2** Phase HUD: timer + round counter `0.5h`

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
    Original estimate 1.5h, recalibrated to 0.5h.
    ```

### **P3.3** Build phase: enable placement, conveyors run `0.5h`

  - tags: [phase-3, gameplay]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Wire `RoundManager.phase_changed` in `game_world.gd` to toggle systems
      - [ ] Add `set_enabled(bool)` to `build_system.gd` to block placement during fight
      - [ ] Verify conveyor/building tick runs normally during build phase
    ```md
    Build phase is basically current Factor behavior, just wired to RoundManager.
    Original estimate 1h, recalibrated to 0.5h.
    ```

### **P3.4** Fight phase: freeze factory, placeholder combat `0.5h`

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
    Original estimate 1.5h, recalibrated to 0.5h.
    ```

### **P3.5** Day/night visual shift `0.5h`

  - tags: [phase-3, visual]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Create `scripts/game/day_night_visual.gd` -- manages CanvasModulate transitions
      - [ ] Add CanvasModulate node to `scenes/game/game_world.tscn`
      - [ ] Fight: darken terrain, slight color distortion. Build: normal bright look
    ```md
    CanvasModulate-based day/night. Full psychedelic shader is post-M1.
    Original estimate 1.5h, recalibrated to 0.5h.
    ```

### **P3.6** Sim test: round cycling `0.5h`

  - tags: [phase-3, test]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Write `tests/simulation/sim_round_cycle.gd`
      - [ ] Verify phase transitions, timer countdown, 3 full rounds complete
      - [ ] Validate: sim passes headless
    ```md
    Automated test of build/fight cycle.
    Original estimate 1.5h, recalibrated to 0.5h.
    ```

### **P4.1** Building HP component `0.5h`

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
    Original estimate 1.5h, recalibrated to 0.5h.
    ```

### **P4.2** Night transform: conveyors become walls `1h`

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
    Original estimate 2h, recalibrated to 1h.
    ```

### **P4.3** Night transform: converters become turrets `1h`

  - tags: [phase-4, transform]
  - priority: medium
  - steps:
      - [ ] Create `scripts/game/turret_behavior.gd` -- targeting, firing logic
      - [ ] Create `scripts/game/projectile.gd` + `scenes/game/projectile.tscn`
      - [ ] Add `last_processed_element` to `converter.gd`, toggle day/night behavior
      - [ ] Turret fires projectiles based on last processed resource, nearest monster in range
    ```md
    Converters become elemental turrets at night. Projectile color matches element.
    Original estimate 2h, recalibrated to 1h.
    ```

### **P4.4** Sim test: transformation `0.25h`

  - tags: [phase-4, test]
  - priority: medium
  - steps:
      - [ ] Place buildings, trigger night, verify conveyors have HP
      - [ ] Verify converters fire projectiles
      - [ ] Validate: sim passes headless
    ```md
    Automated test of building transformation.
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
  - depends: BOT.1
  - steps:
      - [ ] Create `tests/bot/bot_metrics.gd` -- standalone metric tracker, receives events from BotPlayer
      - [ ] Track placement metrics: buildings placed (by type), placement failures (by reason: occupied, off-deposit, overlap), total conveyors, total production buildings
      - [ ] Track production metrics: poll `GameManager.items_delivered` every 60 ticks, record items/min throughput over time. Track which item types are being produced
      - [ ] Track factory health: count idle drills (on deposit but output blocked), count disconnected buildings (no conveyor path to/from), count conveyor deadends
      - [ ] Track stability: record any error prints or script errors caught during run (hook `printerr`)
      - [ ] **Run summary**: at `sim_finish()`, print a structured report
      - [ ] Optionally dump full timeline to JSON file (`tests/bot/results/<seed>.json`) for post-hoc analysis
    ```md
    The metric collector answers: "did the factory work?" and "did anything break?"
    Original estimate 2h, recalibrated to 0.5h.
    ```

### **BOT.3** Bot strategies: greedy builder + line builder `1h`

  - tags: [botplayer, testing, strategies]
  - priority: medium
  - depends: BOT.1
  - steps:
      - [ ] Refactor BotBrain into a base class with virtual `decide(state: Dictionary) -> Dictionary` method
      - [ ] **RandomBrain** (already built in BOT.1) -- move to its own file `tests/bot/brains/random_brain.gd`
      - [ ] **GreedyBrain** (`tests/bot/brains/greedy_brain.gd`): prioritizes connecting deposits to smelters
      - [ ] **LineBrain** (`tests/bot/brains/line_brain.gd`): builds long straight conveyor lines
      - [ ] Each brain selectable via constructor: `BotPlayer.new(brain_type: StringName)` or sim argument
      - [ ] Add `--bot-brain <name>` argument parsing in bot runner
    ```md
    Different brains stress different parts of the engine.
    Original estimate 2.5h, recalibrated to 1h.
    ```

### **BOT.4** Bot runner: batch execution + comparison `0.5h`

  - tags: [botplayer, testing, runner]
  - priority: medium
  - depends: BOT.2, BOT.3
  - steps:
      - [ ] Create `tests/bot/run_bot_batch.sh` -- shell script that runs N bot simulations with different seeds
      - [ ] Usage: `./tests/bot/run_bot_batch.sh --count 10 --brain random --duration 300`
      - [ ] Create `tests/bot/run_bot.gd` -- entry point script that parses args
      - [ ] Collect all JSON results into `tests/bot/results/batch_<timestamp>/`
      - [ ] Print aggregate summary after batch
      - [ ] Exit code 1 if any run crashed
    ```md
    The batch runner. Simple shell script + Godot entry point.
    Original estimate 2h, recalibrated to 0.5h.
    ```

### **BOT.5** Visual bot mode: watch the bot build `0.5h`

  - tags: [botplayer, testing, visual]
  - priority: low
  - depends: BOT.1
  - steps:
      - [ ] Add `--visual` flag support to `run_bot.gd` -- opens windowed game, bot runs at 2x speed
      - [ ] Render a marker sprite at the bot's virtual grid position
      - [ ] Add bot action log overlay -- small text panel showing last 5 actions
      - [ ] Camera follows bot position
      - [ ] Don't auto-quit -- let the user watch and close manually
    ```md
    Debugging aid. Watch the bot build in real time.
    Original estimate 1.5h, recalibrated to 0.5h.
    ```

### **BOT.6** Sim test: bot smoke test `0.25h`

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
    Minimal smoke test that the bot system itself works.
    Original estimate 1h, recalibrated to 0.25h.
    ```

## Estimate Summary

| Phase | Cards | Old Total | New Total |
|-------|-------|-----------|-----------|
| P3 (RoundManager) | 6 | 9h | 3.5h |
| P4 (Transform) | 4 | 6.5h | 2.75h |
| P5 (Monsters) | 6 | 12h | 5.5h |
| P6 (Polish) | 6 | 9.5h | 3.75h |
| BOT (Testing) | 6 | 12h | 3.75h |
| **Total remaining** | **28** | **49h** | **19.25h** |

Recalibration based on 24 sessions of velocity data. See BOARD_SOLVED.md for full analysis.

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
