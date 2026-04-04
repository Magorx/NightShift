# Factor -> Night Shift: Detailed Transition Plan

## Overview

This document maps every file change needed to transform Factor (a Factorio clone) into Night Shift (a factory roguelite). Organized into 6 phases that each produce a compilable, testable state.

**Total estimated effort**: 40-60 hours across ~16-20 evening sessions (3h each)

---

## What We Keep (Untouched Core)

These systems transfer directly with minimal changes:

| System | Files | Why Keep |
|--------|-------|----------|
| Pull system | `GameManager.pull_item()`, `has_output_at()`, `peek_output_item()` | Core of all item transfer |
| BuildingLogic base | `buildings/shared/building_logic.gd` | All buildings extend this |
| BuildingDef | `buildings/shared/building_def.gd` | Data-driven building definitions |
| BuildSystem | `scripts/game/build_system.gd` | Grid placement, rotation, drag, destroy |
| ConveyorSystem | `scripts/game/conveyor_system.gd` | Per-frame belt processing |
| ConveyorVisualManager | `scripts/game/conveyor_visual_manager.gd` | MultiMesh belt rendering |
| ItemVisualManager | `scripts/game/item_visual_manager.gd` | MultiMesh item dots |
| TerrainVisualManager | `scripts/game/terrain_visual_manager.gd` | MultiMesh terrain |
| BuildingTickSystem | `scripts/game/building_tick_system.gd` | Batched building updates |
| BuildingCollision | `scripts/game/building_collision.gd` | Player-building collision |
| ItemBuffer | `buildings/shared/item_buffer.gd` | Item queue with progress |
| RoundRobin | `scripts/round_robin.gd` | Fair multi-direction pulling |
| GameLogger | `scripts/autoload/logger.gd` | Debugging |
| Inventory script | `scripts/inventory.gd` | Per-building item storage |
| BuildingBase | `buildings/shared/building_base.gd` | Root node for all buildings |

## What We Remove

| System | Files | References to Clean |
|--------|-------|-------------------|
| ResearchManager | `scripts/autoload/research_manager.gd` | 14 files reference it |
| ContractManager | `scripts/autoload/contract_manager.gd` | 11 files reference it |
| AccountManager | `scripts/autoload/account_manager.gd` | 6 files reference it |
| TutorialManager | `scripts/autoload/tutorial_manager.gd` | 7 files reference it |
| EnergySystem | `scripts/energy/` (3 .gd files + overlay + scenes) | 14 files reference it |
| ResearchPanel | `scripts/ui/research_panel.gd` | |
| RecipeBrowser | `scripts/ui/recipe_browser.gd` | |
| BuildingInfoPanel | `scripts/ui/building_info_panel.gd` | |
| TutorialPanel | `scripts/ui/tutorial_panel.gd` | |
| 24 building types | See Phase 1.5 | BuildingDef auto-discovery handles this |

## What We Build New

| System | Purpose | Phase |
|--------|---------|-------|
| RoundManager | Build/fight/shop phase cycle | 3 |
| NightTransform | Building -> defense conversion | 4 |
| BuildingHealth | HP, damage, degradation | 4 |
| TurretBehavior | Converter -> turret at night | 4 |
| Projectile | Turret ammunition | 4 |
| MonsterBase | Monster entity framework | 5 |
| MonsterSpawner | Wave-based spawning | 5 |
| MonsterPathfinding | A* grid navigation | 5 |
| DayNightVisual | Phase-based visual shift | 3 |

---

## Phase 1: Strip Factor Systems

### Goal
Remove ResearchManager, ContractManager, AccountManager, TutorialManager, EnergySystem, and unused buildings/UI. Game compiles and runs as a simplified sandbox.

### P1.1 -- Remove ResearchManager

**game_manager.gd** changes:
```gdscript
# REMOVE this line in can_place_building() (around line 384):
if not ResearchManager.is_tag_unlocked(def.research_tag):
    return false

# REMOVE in clear_all():
ResearchManager.reset()
```

**build_system.gd** changes:
- Search for `ResearchManager` references, remove any tag checks

**game_camera.gd** changes:
- Remove research-gated zoom levels, use hardcoded range `[0.5, 3.0]`

**buildings_panel.gd** changes:
- Remove `ResearchManager.is_tag_unlocked()` filtering in building list population
- Show all buildings unconditionally

**save_manager.gd** changes:
- Remove `research_state` serialization/deserialization blocks

**Project Settings** changes:
- Remove ResearchManager from Autoload list

**Delete**:
- `scripts/autoload/research_manager.gd` + `.uid`
- `scripts/ui/research_panel.gd` + `.uid`
- `buildings/research_lab/` (entire folder)
- `resources/tech/` (entire folder -- research_tree.json, TechDef, etc.)
- `scripts/resources/tech_def.gd` + `.uid`

### P1.2 -- Remove ContractManager

**game_manager.gd** changes:
```gdscript
# In record_delivery(), REMOVE:
ContractManager.on_item_delivered(item_id)

# In clear_all(), REMOVE:
ContractManager.reset()
```

**sink.gd** changes:
- Remove any ContractManager references

**hud.gd** changes:
- Remove contract display elements

**save_manager.gd** changes:
- Remove contract serialization

**Project Settings**: Remove from Autoload

**Delete**: `scripts/autoload/contract_manager.gd` + `.uid`

### P1.3 -- Remove AccountManager + TutorialManager

**game_world.gd** changes:
```gdscript
# REMOVE lines ~114-118:
var meta := AccountManager.load_meta(AccountManager.active_slot)
if meta.has("tutorial_step"):
    TutorialManager.load_from_account()
else:
    TutorialManager.start()
```

**save_manager.gd** changes:
- Replace `AccountManager.active_slot` with hardcoded `0` or simple path
- Remove tutorial state saving

**main_menu.gd** changes:
- Remove account slot selection, simplify to "Play" / "Continue" / "Quit"

**buildings_panel.gd** changes:
- Remove account-based hotkey persistence calls

**Project Settings**: Remove both from Autoload

**Delete**:
- `scripts/autoload/account_manager.gd` + `.uid`
- `scripts/autoload/tutorial_manager.gd` + `.uid`
- `scripts/ui/tutorial_panel.gd` + `.uid`

### P1.4 -- Remove EnergySystem

This is the most invasive removal. The key insight: converters currently check `energy.stored >= recipe.energy_cost` before crafting. We need to make them craft unconditionally (energy_cost treated as 0).

**game_manager.gd** changes:
```gdscript
# Remove var:
var energy_system: Node

# In place_building(), REMOVE entire energy block (~lines 468-477):
if energy_system and logic.energy:
    energy_system.register_building(logic)
    ...

# In remove_building(), REMOVE energy block (~lines 516-519):
if building.logic and energy_system:
    ...

# In clear_all(), REMOVE:
if energy_system:
    energy_system.clear_all()
```

**game_world.gd** changes:
```gdscript
# REMOVE:
GameManager.energy_system = $EnergySystem

# REMOVE from ESC cascade:
if build_system.energy_link_mode:
    build_system._exit_energy_link_mode()
```

**build_system.gd** changes:
- Remove `energy_link_mode` variable and all related methods
- Remove energy link rendering in ghost/preview

**building_logic.gd** changes:
```gdscript
# REMOVE:
var energy = null
var _cached_energy_node = ...
func get_energy_node(): ...
func get_max_affordable_recipe_cost(): ...
# Keep the method signature as stub if needed for converter compatibility
```

**converter.gd** (smelter) changes:
- Remove all `energy` checks in `_try_craft()`
- Remove `energy.stored >= cost` guard
- Remove `energy.stored -= cost` deduction
- Converters now craft whenever they have input resources

**save_manager.gd** changes:
- Remove energy state serialization

**Scene**: `scenes/game/game_world.tscn`
- Remove `EnergySystem` node
- Remove `EnergyOverlay` node (if present)

**Delete entire folders**:
- `scripts/energy/` (energy_system.gd, energy_network.gd, energy_overlay.gd, etc.)
- `buildings/coal_burner/`
- `buildings/solar_panel/`
- `buildings/energy_pole/`
- `buildings/battery/`
- `buildings/fuel_generator/`
- `buildings/nuclear_reactor/`

**Delete files**:
- `buildings/shared/building_energy.gd` + `.uid`
- `buildings/shared/energy_node.gd` + `.uid`

### P1.5 -- Remove Unused Buildings + UI

**Buildings to DELETE** (entire folders):
```
buildings/assembler/
buildings/assembler_mk2/
buildings/centrifuge/
buildings/chemical_plant/
buildings/fabricator/
buildings/greenhouse/
buildings/hand_assembler/
buildings/particle_accelerator/
buildings/press/
buildings/wire_drawer/
buildings/coke_oven/
buildings/pump/
buildings/borer/
buildings/biomass_extractor/
buildings/pipeline/
buildings/conveyor_mk2/
buildings/conveyor_mk3/
buildings/drill_mk2/
```

**Buildings KEPT for M1**:
```
buildings/conveyor/     -- belt transport, becomes wall at night
buildings/drill/        -- resource extraction
buildings/smelter/      -- converter, becomes turret at night
buildings/splitter/     -- distributes items
buildings/junction/     -- 4-way routing
buildings/tunnel/       -- underground transport
buildings/sink/         -- test/debug item consumer
buildings/source/       -- test/debug item producer
buildings/shared/       -- base classes
```

**UI to delete**:
- `scripts/ui/recipe_browser.gd` + `.uid`
- `scripts/ui/building_info_panel.gd` + `.uid`

**game_manager.gd cleanup**:
- Remove `_register_placement_phases()` entries for pipeline and biomass_extractor (keep tunnel)
- Remove `_link_biomass_extractor()` function
- Update `DEFAULT_HOTKEYS` to only reference kept buildings

### P1.6 -- Fix Tests

**Delete obsolete simulations**:
- `tests/simulation/sim_energy.gd`
- `tests/simulation/sim_content_update.gd`
- `tests/simulation/sim_new_buildings.gd`
- `tests/simulation/sim_ui_panels.gd`
- `tests/simulation/sim_ui_screenshot.gd`
- `tests/simulation/sim_animation_showcase.gd`
- `tests/unit/test_energy.gd`

**Fix remaining simulations**:
- `tests/simulation/simulation_base.gd` -- remove ContractManager references
- Keep: `sim_conveyor_transport`, `sim_unified_pull`, `sim_splitter`, `sim_merge_and_source_sink`, `sim_junction`, `sim_player`, `sim_smelter_converter`, `sim_drill_extractor`
- These sims reference specific item IDs (iron_ore, copper_plate, etc.) that will be deleted in Phase 2. For now, update them to use any still-existing item or skip if items are gone.

---

## Phase 2: New Resource System

### P2.1 -- 3 Elemental Resources

Create ItemDef `.tres` files:

**`resources/items/pyromite.tres`**:
- id: `pyromite`, display_name: "Pyromite", color: `Color(0.9, 0.4, 0.1)`, category: "raw", icon_atlas_index: 0

**`resources/items/crystalline.tres`**:
- id: `crystalline`, display_name: "Crystalline", color: `Color(0.3, 0.7, 0.95)`, category: "raw", icon_atlas_index: 1

**`resources/items/biovine.tres`**:
- id: `biovine`, display_name: "Biovine", color: `Color(0.2, 0.8, 0.3)`, category: "raw", icon_atlas_index: 2

Create 1 combination output:

**`resources/items/steam_burst.tres`**:
- id: `steam_burst`, display_name: "Steam Burst", color: `Color(0.8, 0.8, 0.9)`, category: "intermediate", icon_atlas_index: 3

**New item atlas**: `resources/items/sprites/item_atlas.png` -- 4 items in 8x8 grid (only 4 used, rest blank). Each a distinct 16x16 silhouette.

**Delete**: All existing `.tres` files in `resources/items/` (iron_ore, copper_ore, coal, etc.)

### P2.2 -- Elemental Recipes

**`resources/recipes/smelt_steam_burst.tres`**:
- converter_type: "smelter"
- inputs: [{item: pyromite, quantity: 1}, {item: crystalline, quantity: 1}]
- outputs: [{item: steam_burst, quantity: 1}]
- craft_time: 2.0
- energy_cost: 0

**Delete**: All existing `.tres` files in `resources/recipes/`

### P2.3 -- World Generator Rewrite

Replace internals of `scripts/game/world_generator.gd`:

**New parameters**:
- Map size: 128x128 (set in game_world.gd `GameManager.map_size = 128`)
- 5-6 deposit clusters total across 3 resource types
- 2 deposits close to spawn (within 20 tiles)
- 2-3 medium distance (30-50 tiles)
- 1-2 far (60+ tiles)
- Rock walls forming natural chokepoints
- Clear 12-tile radius around spawn

**New tile IDs** in `scripts/game/tile_database.gd`:
- `TILE_PYROMITE`, `TILE_CRYSTALLINE`, `TILE_BIOVINE`
- Map to deposit items: `TILE_PYROMITE -> &"pyromite"`, etc.
- Remove old deposit tile IDs (TILE_IRON, TILE_COPPER, etc.)

**Deposit shape**: Each deposit is a cluster of 8-15 tiles in organic blob shape (reuse existing blob generation logic).

### P2.4 -- Update BuildingDefs

For each kept building's `.tres` file:
- Set `research_tag = ""` (always available)
- Set `build_cost = []` (free for M1)
- Smelter: ensure `converter_type = "smelter"` matches new recipes

### P2.5 -- Resource Flow Simulation

New file: `tests/simulation/sim_elemental_flow.gd`
- Place drill on pyromite deposit
- Conveyor chain to smelter
- Place source producing crystalline (feeds smelter's second input)
- Verify smelter outputs steam_burst
- Conveyor to sink, verify delivery

---

## Phase 3: Round Manager

### P3.1 -- RoundManager Singleton

New file: `scripts/autoload/round_manager.gd`

```gdscript
extends Node

signal phase_changed(phase: StringName)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal run_ended(victory: bool)

enum Phase { BUILD, TRANSITION, FIGHT }

var current_round: int = 0
var current_phase: StringName = &"build"
var phase_timer: float = 0.0
var is_running: bool = false

# Timing config (tunable)
var build_times := [180.0, 150.0, 120.0, 100.0, 90.0, 75.0, 60.0, 60.0]
var fight_times := [60.0, 75.0, 90.0, 105.0, 120.0, 135.0, 150.0, 150.0]
const TRANSITION_TIME := 3.0
const MAX_ROUNDS := 8

func start_run() -> void: ...
func _physics_process(delta: float) -> void: ...  # countdown timer, phase transitions
func get_time_remaining() -> float: ...
func skip_phase() -> void: ...  # debug
func _advance_phase() -> void: ...
```

Register in Project Settings > Autoload.

### P3.2 -- Phase HUD

Modify `scripts/ui/hud.gd` and `scenes/ui/hud.tscn`:
- Remove: speed controls, currency display, delivery counter, buildings panel toggle, minimap, FPS counter
- Add: Round counter label ("Round 3/8"), Phase label ("BUILD" / "NIGHT"), Timer label ("1:45"), Phase progress bar
- Keep: building hotbar (simplified)

### P3.3 -- Build Phase Integration

In `scripts/game/game_world.gd`:
```gdscript
func _ready():
    ...
    RoundManager.phase_changed.connect(_on_phase_changed)
    RoundManager.start_run()

func _on_phase_changed(phase: StringName) -> void:
    match phase:
        &"build":
            build_system.set_enabled(true)
            # ConveyorSystem + BuildingTickSystem run normally
        &"fight":
            build_system.set_enabled(false)
            # Optionally slow/pause conveyors
        &"transition":
            build_system.set_enabled(false)
```

In `scripts/game/build_system.gd`:
- Add `var enabled: bool = true` + `func set_enabled(val: bool)`
- Early-return from placement/destroy input when disabled

### P3.4 -- Fight Phase Placeholder

During fight: timer counts down, no monsters yet. Screen darkens. "SURVIVE" text appears.

### P3.5 -- Day/Night Visual

New file: `scripts/game/day_night_visual.gd`
- Child of GameWorld, adds a CanvasModulate node
- BUILD phase: `Color(1, 1, 1)` (normal)
- TRANSITION: lerp to dark over 3 seconds
- FIGHT phase: `Color(0.4, 0.35, 0.55)` (dark purple tint)
- Back to normal on next BUILD

---

## Phase 4: Building Transformation

### P4.1 -- BuildingHealth Component

New file: `buildings/shared/building_health.gd`

```gdscript
class_name BuildingHealth
extends RefCounted

var hp: float
var max_hp: float
var damage_state: int = 0  # 0=pristine, 1=cracked, 2=scarred, 3=heavy, 4=destroyed

func _init(p_max_hp: float) -> void:
    max_hp = p_max_hp
    hp = p_max_hp

func take_damage(amount: float) -> void:
    hp = maxf(hp - amount, 0.0)
    _update_damage_state()

func heal(amount: float) -> void:
    hp = minf(hp + amount, max_hp)
    _update_damage_state()

func is_destroyed() -> bool:
    return hp <= 0.0

func _update_damage_state() -> void:
    var ratio := hp / max_hp
    if ratio > 0.75: damage_state = 0
    elif ratio > 0.50: damage_state = 1
    elif ratio > 0.25: damage_state = 2
    elif ratio > 0.0: damage_state = 3
    else: damage_state = 4
```

**building_logic.gd** change: add `var health: BuildingHealth = null`

### P4.2 -- Conveyor Wall Mode

On fight phase start, `NightTransform` iterates all buildings:
- Conveyors: set `health = BuildingHealth.new(100.0)`, mark as `is_wall = true`
- During fight, conveyors with `is_wall` block monster A* pathing
- Visual: modulate conveyor sprite darker, add wall overlay

On build phase start:
- Remove health component, clear wall state
- Restore normal conveyor appearance

### P4.3 -- Converter Turret Mode

On fight phase start:
- Converters: set `health = BuildingHealth.new(200.0)`, attach TurretBehavior
- TurretBehavior reads `last_processed_element` from converter
- Targeting: scan for monsters in radius (6 tiles), pick nearest
- Fire projectile every 1.5s toward target

New file: `scripts/game/turret_behavior.gd`
```gdscript
class_name TurretBehavior extends RefCounted
var element: StringName
var fire_rate: float = 1.5
var range_tiles: float = 6.0
var damage: float = 25.0
var _timer: float = 0.0

func update(delta: float, world_pos: Vector2) -> void:
    _timer += delta
    if _timer >= fire_rate:
        var target = _find_nearest_monster(world_pos)
        if target:
            _fire(world_pos, target)
            _timer = 0.0
```

New file: `scripts/game/projectile.gd` + `scenes/game/projectile.tscn`
- Simple Area2D with CircleShape2D
- Moves toward target position at speed
- On contact with monster: deal damage, apply elemental effect (M1: just damage)
- Auto-despawn after 3 seconds or on hit

---

## Phase 5: Monster System

### Architecture

```
monsters/
    monster_base.gd          -- base class
    tendril_crawler/
        tendril_crawler.gd   -- extends monster_base
        tendril_crawler.tscn -- scene with sprite + collision
scripts/game/
    monster_spawner.gd       -- wave management
    monster_pathfinding.gd   -- shared A* grid
```

### MonsterBase

```gdscript
class_name MonsterBase extends CharacterBody2D
var hp: float = 50.0
var max_hp: float = 50.0
var move_speed: float = 40.0  # pixels/s (~1.25 tiles/s)
var attack_damage: float = 10.0
var attack_cooldown: float = 1.0
var _attack_timer: float = 0.0
var _path: PackedVector2Array = []
var _path_index: int = 0

func _physics_process(delta: float) -> void:
    if _path.is_empty(): return
    # Move along path
    # Attack adjacent buildings
    # Die when hp <= 0
```

### Pathfinding

Use Godot's AStar2D:
- Build grid from GameManager.map_size
- Mark wall tiles + building positions (wall-mode conveyors) as impassable
- Rebuild on fight phase start
- When a building is destroyed, mark that cell passable, monsters re-pathfind

### Spawner

- Listens to `RoundManager.phase_changed`
- On fight: spawn `base_count + round * per_round` monsters
- Spawn at random map edge positions (not in walls)
- Stagger spawns: 1 monster every `spawn_interval` seconds
- Track all alive monsters for end-of-wave detection

---

## Phase 6: Player + Polish

### P6.1 -- 8-Slot Inventory
Change `INVENTORY_SLOTS = 8` in player.gd. Update inventory_panel.gd layout.

### P6.2 -- Player Combat
Simple melee attack:
- During fight phase, left-click deals damage to nearest monster within 1.5 tiles
- 20 damage, 0.5s cooldown
- Visual: brief swing arc

### P6.3 -- Run Save/Load
- SaveManager saves: round number, phase, buildings, player state
- On game over or win: delete save
- On quit mid-run: save for continue

### P6.4 -- Main Menu
- "New Run" -> generate world, start round 1
- "Continue" -> load saved run (grayed out if no save)
- "Settings" -> existing settings menu
- "Quit"

### P6.5 -- Free Placement
For M1: `GameManager.creative_mode = true`. All buildings free. Hotkeys 1-6 map to conveyor, drill, smelter, splitter, junction, tunnel.

### P6.6 -- Playtest
Play 3 full rounds. Tune: monster count, build time, damage values, turret effectiveness.

---

## Session Planning

| Session | Tasks | Expected Result |
|---------|-------|----------------|
| 1 | P1.1, P1.2, P1.3 | Game runs without research/contracts/accounts/tutorial |
| 2 | P1.4, P1.5, P1.6 | Game runs without energy, reduced buildings, tests pass |
| 3 | P2.1, P2.2 | 3 elemental items + recipe defined |
| 4 | P2.3, P2.4, P2.5 | New map, resources flow through factory |
| 5 | P3.1 | RoundManager cycles phases |
| 6 | P3.2, P3.3 | HUD shows round/timer, build mode toggles |
| 7 | P3.4, P3.5, P3.6 | Day/night visual, fight placeholder, sim passes |
| 8 | P4.1, P4.2 | Conveyors become walls with HP |
| 9 | P4.3, P4.4 | Converters become turrets, fire projectiles |
| 10 | P5.1 | Tendril Crawler entity moves and attacks |
| 11 | P5.2, P5.3 | Spawner + pathfinding working |
| 12 | P5.4 | Turrets kill monsters, monsters damage buildings |
| 13 | P5.5, P5.6 | Win/lose conditions, combat sim passes |
| 14 | P6.1, P6.2 | 8-slot inventory, player melee attack |
| 15 | P6.3, P6.4 | Save/load, new main menu |
| 16 | P6.5, P6.6 | Free placement, end-to-end playtest |

---

## Critical Path

The longest dependency chain is:
**Strip (6h) -> Resources (6h) -> RoundManager (9h) -> Transform (6h) -> Monsters (12h) -> Polish (9h)**

Total: ~48h = 16 sessions. Fits within the M1 budget of 40-60h.

The highest-risk tasks are:
1. **P1.4 (Energy removal)** -- most coupling, most likely to cause cascading compile errors
2. **P5.3 (Pathfinding)** -- performance unknown, may need iteration
3. **P4.3 (Turret behavior)** -- first new combat system, may need redesign

Start each session by running `$GODOT --headless --path . --quit` to verify compilation, and end each session by running relevant simulations.
