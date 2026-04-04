# Night Shift -- Project Board

## Backlog

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

