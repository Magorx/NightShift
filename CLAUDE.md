# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Factor is a 2D top-down factory-building game built with **Godot 4.5** (GDScript). Players extract resources, transport them via conveyors, process them through converters, and deliver products to sinks. Inspired by Mindustry, Factorio, and Satisfactory.

## Commands

```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

# Validate project loads (parse check)
$GODOT --headless --path . --quit

# Run all tests (unit + integration)
$GODOT --headless --path . --script res://tests/run_tests.gd

# Run a specific simulation (fast headless — ~1s per sim)
# --fixed-fps 60 is REQUIRED: without it sims run in real time (~24s instead of ~1s)
$GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- <sim_name>

# Run simulation in visual mode (windowed, interactive, doesn't auto-quit)
$GODOT --path . --script res://tests/run_simulation.gd -- <sim_name> --visual

# Run simulation in screenshot mode (needs rendering, no --headless)
$GODOT --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- <sim_name> --screenshot-baseline

# Launch game with visible window
$GODOT --path .
```

Exit code 0 = pass, 1 = failure. All output goes to stdout/stderr.

## Architecture

### Autoload Singletons

Five singletons registered in Project Settings > Autoload:

- **GameManager** (`scripts/autoload/game_manager.gd`) — building registry, placement/removal API, unified pull system, currency/delivery tracking, building costs, item icon atlas, building hotkeys, conveyor sprite updates
- **SaveManager** (`scripts/autoload/save_manager.gd`) — JSON-based save/load with autosave rotation
- **AccountManager** (`scripts/autoload/account_manager.gd`) — 3-slot account management under `user://saves/`
- **ResearchManager** (`scripts/autoload/research_manager.gd`) — tech tree with ring-based progression, science pack delivery, building unlock gating
- **ContractManager** (`scripts/autoload/contract_manager.gd`) — dynamic gate + side contracts, delivery integration, progression milestones

### Unified Pull System

All item transfers go through `GameManager.pull_item(target_pos, from_dir_idx)`. Buildings never push items — they only pull from neighbors. Key API:

- `pull_item(target_pos, from_dir_idx)` — pull an item from the neighbor in direction `from_dir_idx`
- `peek_output_item(target_pos, from_dir_idx)` — check what's available without removing
- `has_output_at()` / `has_input_at()` — check neighbor IO compatibility

Direction system: `DIRECTION_VECTORS = [RIGHT, DOWN, LEFT, UP]` (indices 0–3).

### Data-Driven Design via Custom Resources

Game content is defined as `.tres` resource files — adding new items, recipes, or buildings requires no code changes:

- **ItemDef** (`scripts/resources/item_def.gd`) — id, display_name, color, category, export_value, research_value, icon_atlas_index
- **RecipeDef** (`scripts/resources/recipe_def.gd`) — converter_type, inputs/outputs as ItemStack arrays, craft_time, energy_cost, energy_output
- **ItemStack** (`scripts/resources/item_stack.gd`) — item + quantity pair used in recipes and building costs
- **BuildingDef** (`buildings/shared/building_def.gd`) — scene reference, display_name, color, category, description, unlock_tech, build_cost, replaceable_by; auto-extracts shape/inputs/outputs/anchor from the scene's marker nodes; owns all rotation/shape math
- **TechDef** (`scripts/resources/tech_def.gd`) — id, display_name, ring, cost (science packs), unlocks (building IDs)

Current content: 36 items across 6 categories (8 raw, 7 smelted, 8 components, 6 assembly, 4 advanced, 3 science packs), 31 recipes. Resources live under `resources/items/` and `resources/recipes/`. Item sprites rendered via 16x16 atlas (`resources/items/sprites/item_atlas.png`).

### Building Organization

Each building type lives in its own folder under `buildings/`. Every building's logic node extends `BuildingLogic` (`buildings/shared/building_logic.gd`), which defines the common interface for the pull system, serialization, info panel, and lifecycle. No type-checking (`is ConveyorBelt`, etc.) is needed — GameManager and other systems interact through the interface.

```
buildings/
  shared/              # base scripts shared by all buildings
	building_base.gd   # BuildingBase class (root node script), has typed `logic: BuildingLogic`
	building_logic.gd  # BuildingLogic base class — pull interface, configure, serialize, info stats, lifecycle
	building_def.gd    # BuildingDef resource class — auto-extracts shape/IO from scene, rotation math
	item_buffer.gd     # core item queue with progress tracking (0.0–1.0)
	item_visual.gd     # item dot rendering on ItemLayer
	input_cell.gd      # ColorRect input marker with directional masks
	output_cell.gd     # ColorRect output marker with directional masks
	shape_cell.gd      # ColorRect shape marker
	building_arrow.gd  # direction arrow overlay
	destroy_highlight.gdshader
  conveyor/            # belt transport (ConveyorBelt extends BuildingLogic), supports mk1/mk2/mk3 speed tiers
  conveyor_mk2/        # faster belt (2x speed, 3 capacity), reuses ConveyorBelt
  conveyor_mk3/        # fastest belt (3x speed, 4 capacity), reuses ConveyorBelt
  drill/               # resource extractor (ExtractorLogic extends BuildingLogic), supports mk1/mk2 tiers
  drill_mk2/           # faster extractor (2x speed), reuses ExtractorLogic
  smelter/             # converter (ConverterLogic extends BuildingLogic) — base class for all converters
  press/               # 2x1 converter — stamps plates into gears, tubes, beams, lenses
  wire_drawer/         # 1x2 converter — draws plates into wire
  coke_oven/           # 1x2 converter — bakes coal into coke
  hand_assembler/      # 1x1 manual crafter (HandAssemblerLogic) — recipes disabled by default, craft queue
  assembler/           # 2x2 automated assembler with energy, ConverterLogic
  assembler_mk2/       # 3x2 advanced assembler (the 3-part building!), ConverterLogic
  fuel_generator/      # 2x2 energy generator — burns coke, ConverterLogic
  research_lab/        # 2x2 science consumer (ResearchLabLogic) — delivers packs to ResearchManager
  coal_burner/         # 2x1 energy generator (CoalBurnerLogic)
  solar_panel/         # 1x1 passive energy generator
  energy_pole/         # 1x1 energy relay with EnergyNode
  battery/             # 1x1 energy storage with EnergyNode
  sink/                # infinite item consumer (ItemSink extends BuildingLogic)
  source/              # simple timer-based item producer (ItemSource extends BuildingLogic)
  splitter/            # distributes items across multiple outputs (SplitterLogic extends BuildingLogic)
  junction/            # 4-directional pass-through routing (JunctionLogic extends BuildingLogic)
  tunnel/              # linked pair (TunnelLogic extends BuildingLogic), multi-phase placement
```

### BuildingLogic Interface

All building logic nodes extend `BuildingLogic` and override virtual methods as needed:

- **Pull system**: `has_output_toward()`, `can_provide_to()`, `peek_output_for()`, `take_item_for()`, `has_input_from()`, `can_accept_from()`
- **Energy**: `get_max_affordable_recipe_cost()` — returns highest energy_cost of craftable recipes (used by network for floor calculation)
- **Configuration**: `configure(def, grid_pos, rotation)` — each building self-configures from its BuildingDef
- **Serialization**: `serialize_state()` / `deserialize_state()` — each building handles its own save/load
- **Info panel**: `get_info_stats()` — returns structured `[{type, ...}]` entries (types: "stat", "progress", "recipe", "inventory")
- **Popup interface**: `get_popup_recipe()` (current/last/first recipe), `get_popup_progress()` (craft progress 0.0–1.0, -1.0 = none), `get_inventory_items()` (items as `[{id, count}]`)
- **Lifecycle**: `on_removing()` (cleanup on deletion), `cleanup_visuals()`, `get_linked_positions()`

To add a new building type: create a script extending `BuildingLogic`, override the relevant methods, and place it as a child node in the building's `.tscn` scene. No changes to GameManager or other systems needed.

### BuildingDef Auto-Extraction

BuildingDef reads the `.tscn` scene at load time to extract:
- **anchor_cell** — from `BuildAnchor` node position
- **shape[]** — from `Shape` group ColorRect children (grid cells the building occupies)
- **inputs[]** — from `Inputs` group ColorRects with directional masks
- **outputs[]** — from `Outputs` group ColorRects with directional masks

This means IO configuration lives in the `.tscn` scene, not in code.

### Energy System

Energy flows through a graph of buildings connected by adjacency edges and EnergyNode links. **Energy never teleports** — all transfers respect per-edge throughput limits.

**Core classes:**
- **EnergySystem** (`scripts/energy/energy_system.gd`) — registration, network rebuild (flood-fill + full edge graph)
- **EnergyNetwork** (`scripts/energy/energy_network.gd`) — per-tick 4-phase distribution algorithm
- **BuildingEnergy** (`buildings/shared/building_energy.gd`) — per-building energy state component (null = no energy)
- **EnergyNode** (`buildings/shared/energy_node.gd`) — long-range connection component (attach to scene for explicit links)

**4-phase tick algorithm (shared throughput budget per edge per tick):**
1. **Generate** — generators add `generation_rate * delta` to own storage
2. **Demand redistribution** — buildings with `base_energy_demand > 0` order energy; iterative edge relaxation fills deficits; then consume demand and set `is_powered`
3. **Recipe redistribution** — converters signal `energy_demand` (set every tick via `get_max_affordable_recipe_cost()`); edge relaxation delivers energy toward them
4. **Equalization** — balance fill ratios across the network, respecting floors and remaining throughput

**Energy floor:** each building protects a minimum energy level it won't release during redistribution:
`floor = base_energy_demand * DEMAND_BUFFER_SECONDS + get_max_affordable_recipe_cost()`
- Batteries/generators (no demand, no recipes): floor = 0 → freely donate
- Converters with resources for powered recipes: floor = recipe cost → hold energy for crafting

**Throughput:** every edge has a per-tick budget (`throughput * delta`), shared across all 4 phases. Adjacency edges use `min(a.adjacency_throughput, b.adjacency_throughput)` (default 200/s). Node edges use `min(node_a.throughput, node_b.throughput)`.

**Tuning constants** (in EnergyNetwork): `DEMAND_BUFFER_SECONDS = 5.0`, `RELAXATION_PASSES = 3`.

**Converter energy behavior:** converters use priority-based recipe selection via `RecipeConfig` (lower priority number = tried first). Disabled recipes are skipped. If a powered recipe can't be afforded locally, they immediately fall back to a cheaper/free recipe — no waiting. `energy_demand` is signaled every tick (even mid-craft) so redistribution proactively delivers energy.

### Game Systems

- **BuildSystem** (`scripts/game/build_system.gd`) — grid-based placement with rotation, drag multi-placement, destroy mode with shader highlights, multi-phase building support (tunnels)
- **ConveyorSystem** (`scripts/game/conveyor_system.gd`) — per-physics-frame processing: item advancement, pull-based transfers, progress clamping
- **EnergySystem** (`scripts/energy/energy_system.gd`) — energy network management, edge graph rebuild, per-tick distribution
- **GridOverlay** (`scripts/game/grid_overlay.gd`) — visual grid rendering
- **Inventory** (`scripts/inventory.gd`) — per-item storage with capacity limits (used by extractors/converters)
- **RoundRobin** (`scripts/round_robin.gd`) — fair round-robin iterator for multi-directional pulling

### Building Popup & Recipe Menu

Contextual popup appears above clicked buildings. Click-through design: all containers use `MOUSE_FILTER_PASS` so clicks pass to the game world; only `RecipeRowButton` uses `MOUSE_FILTER_STOP`.

**BuildingPopup** (`scripts/ui/building_popup.gd`, `scenes/ui/building_popup.tscn`):
- **Recipe row**: `[qty][icon] [qty][icon] —Xs→ [qty][icon]` with per-column aligned widths
- **Craft progress bar**: 4 segments filling at 20/40/60/80% thresholds (defined in scene as Seg0–Seg3)
- **Energy bar**: blue fill with cur/max label, right-aligned
- **Inventory row**: `[qty][icon]` slots with aligned number widths
- **Width locking**: on `show_building()`, populates recipe_row with each recipe, reads `get_combined_minimum_size()`, sets `recipe_row.custom_minimum_size.x` to widest. Uses `remove_child()` before `queue_free()` for immediate layout updates.
- **Recipe menu toggle**: clicking recipe row opens `RecipeMenu` to the right of popup

**RecipeMenu** (`scripts/ui/recipe_menu.gd`, `scenes/ui/recipe_menu.tscn`):
- Shows all recipes with per-column aligned numbers, arrow with craft time, energy cost as yellow slot
- Priority (click to select, click another to swap) and enabled toggle (green/red square) per recipe
- Full-screen click blocker: clicks outside both popups dismiss everything

**RecipeConfig** (`scripts/resources/recipe_config.gd`):
- Per-building, per-recipe state: `priority` (int, lower = first) and `enabled` (bool)
- Stored on `ConverterLogic.recipe_configs`, serialized/deserialized with building state
- Priority fully replaces old productivity-based sorting

### Scene Tree (Gameplay)

```
GameWorld (Node2D)                    # scripts/game/game_world.gd
  Camera2D
  TileMapLayer                        # terrain + source locations
  BuildingLayer                       # placed buildings
  ItemLayer                           # conveyor item visuals
  UI (CanvasLayer)
	HUD                               # scripts/ui/hud.gd — speed controls, currency, buildings panel, minimap
	BuildingPopup                     # scripts/ui/building_popup.gd — contextual popup above clicked building
	PauseMenu                         # scripts/ui/pause_menu.gd
```

Key scenes: `scenes/game/game_world.tscn` (gameplay), `scenes/game/test_world.tscn` (dev testing), `scenes/ui/main_menu.tscn` (entry point).

### Save System

- JSON format: `meta.json` (account), `run_autosave.json` + `run_backup.json` (game state)
- Autosave every 60s with backup rotation; corrupt autosave falls back to backup
- Serializes: buildings (type, grid_pos, rotation, state via `logic.serialize_state()`), currency, items_delivered, camera, time_speed
- Linked buildings (tunnel pairs) are serialized and restored on load
- Building hotkeys persisted per account slot in `meta.json`
- 3 account slots under `user://saves/slot_0/` through `slot_2/`

## Testing

Custom lightweight test framework (no plugin dependencies) for headless execution:

- Tests extend `BaseTest` (`tests/base_test.gd`) — methods prefixed `test_` are auto-discovered
- Assertions: `assert_eq()`, `assert_true()`, `assert_false()`, `assert_not_null()`
- Unit tests in `tests/unit/`, integration tests in `tests/integration/`
- Simulations in `tests/simulation/` extend `SimulationBase` — scripted play-throughs with time advancement and input synthesis

Available simulations: `sim_conveyor_transport`, `sim_unified_pull`, `sim_drill_extractor`, `sim_smelter_converter`, `sim_merge_and_source_sink`, `sim_junction`, `sim_splitter`, `sim_energy`, `sim_new_buildings`.

### Workflow for New Buildings

1. Create a folder under `buildings/<name>/` with a `.tscn` scene and a `.tres` BuildingDef
2. Add a logic script extending `BuildingLogic`, override relevant interface methods
3. Place the logic node as a child in the `.tscn` scene — GameManager finds it automatically via `is BuildingLogic`
4. No changes to GameManager, SaveManager, or BuildingInfoPanel needed

### Workflow for New Features

1. Write feature (scenes, scripts, resources)
2. Add unit tests in `tests/unit/test_<feature>.gd`
3. Run tests headlessly to verify
4. Add/update simulation if it affects gameplay

## Documentation

- `docs/design.md` — full game design (items, recipes, converters, research, campaigns)
- `docs/implementation_details.md` — detailed architecture and save format
- `docs/state.md` — implementation progress tracking
- `docs/step13_ui_design.md` — UI layout specifications
