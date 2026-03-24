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

# Run a specific simulation
$GODOT --headless --path . --script res://tests/run_simulation.gd -- <sim_name>

# Launch game with visible window
$GODOT --path .
```

Exit code 0 = pass, 1 = failure. All output goes to stdout/stderr.

## Architecture

### Autoload Singletons

Three singletons registered in Project Settings > Autoload:

- **GameManager** (`scripts/autoload/game_manager.gd`) — building registry, placement API, unified pull system, currency/delivery tracking, building hotkeys, linked buildings (tunnels)
- **SaveManager** (`scripts/autoload/save_manager.gd`) — JSON-based save/load with autosave rotation
- **AccountManager** (`scripts/autoload/account_manager.gd`) — 3-slot account management under `user://saves/`

### Unified Pull System

All item transfers go through `GameManager.pull_item(target_pos, from_dir_idx)`. Buildings never push items — they only pull from neighbors. Key API:

- `pull_item(target_pos, from_dir_idx)` — pull an item from the neighbor in direction `from_dir_idx`
- `peek_output_item(target_pos, from_dir_idx)` — check what's available without removing
- `has_output_at()` / `has_input_at()` — check neighbor IO compatibility

Direction system: `DIRECTION_VECTORS = [RIGHT, DOWN, LEFT, UP]` (indices 0–3).

### Data-Driven Design via Custom Resources

Game content is defined as `.tres` resource files — adding new items, recipes, or buildings requires no code changes:

- **ItemDef** (`scripts/resources/item_def.gd`) — id, display_name, color, category, export_value, research_value
- **RecipeDef** (`scripts/resources/recipe_def.gd`) — converter_type, inputs/outputs as ItemStack arrays, craft_time
- **ItemStack** (`scripts/resources/item_stack.gd`) — item + quantity pair used in recipes
- **BuildingDef** (`buildings/shared/building_def.gd`) — scene reference, display_name, color, category, description, unlock_tech, replaceable_by; auto-extracts shape/inputs/outputs/anchor from the scene's marker nodes

Current content: 4 items (iron_ore, copper_ore, coal, iron_plate), 1 recipe (smelt_iron). Resources live under `resources/items/` and `resources/recipes/`.

### Building Organization

Each building type lives in its own folder under `buildings/`:

```
buildings/
  shared/              # base scripts shared by all buildings
    building_base.gd   # BuildingBase class (root node script)
    building_def.gd    # BuildingDef resource class — auto-extracts shape/IO from scene
    item_buffer.gd     # core item queue with progress tracking (0.0–1.0)
    item_visual.gd     # item dot rendering on ItemLayer
    input_cell.gd      # ColorRect input marker with directional masks
    output_cell.gd     # ColorRect output marker with directional masks
    shape_cell.gd      # ColorRect shape marker
    building_arrow.gd  # direction arrow overlay
    destroy_highlight.gdshader
  conveyor/            # belt transport
  drill/               # resource extractor (timer-based production)
  smelter/             # converter (recipe crafting with multiple IO)
  sink/                # infinite item consumer, tracks deliveries
  source/              # simple timer-based item producer
  splitter/            # distributes items across multiple outputs
  junction/            # 4-directional pass-through routing
  tunnel/              # linked pair (input + output), multi-phase placement
```

### BuildingDef Auto-Extraction

BuildingDef reads the `.tscn` scene at load time to extract:
- **anchor_cell** — from `BuildAnchor` node position
- **shape[]** — from `Shape` group ColorRect children (grid cells the building occupies)
- **inputs[]** — from `Inputs` group ColorRects with directional masks
- **outputs[]** — from `Outputs` group ColorRects with directional masks

This means IO configuration lives in the `.tscn` scene, not in code.

### Game Systems

- **BuildSystem** (`scripts/game/build_system.gd`) — grid-based placement with rotation, drag multi-placement, destroy mode with shader highlights, multi-phase building support (tunnels)
- **ConveyorSystem** (`scripts/game/conveyor_system.gd`) — per-physics-frame processing: item advancement, pull-based transfers, progress clamping
- **GridOverlay** (`scripts/game/grid_overlay.gd`) — visual grid rendering
- **Inventory** (`scripts/inventory.gd`) — per-item storage with capacity limits (used by extractors/converters)
- **RoundRobin** (`scripts/round_robin.gd`) — fair round-robin iterator for multi-directional pulling

### Scene Tree (Gameplay)

```
GameWorld (Node2D)                    # scripts/game/game_world.gd
  Camera2D
  TileMapLayer                        # terrain + source locations
  BuildingLayer                       # placed buildings
  ItemLayer                           # conveyor item visuals
  UI (CanvasLayer)
    HUD                               # scripts/ui/hud.gd — speed controls, currency, buildings panel, minimap
    BuildingInfoPanel                  # scripts/ui/building_info_panel.gd — click-on-building info
    PauseMenu                         # scripts/ui/pause_menu.gd
```

Key scenes: `scenes/game/game_world.tscn` (gameplay), `scenes/game/test_world.tscn` (dev testing), `scenes/ui/main_menu.tscn` (entry point).

### Save System

- JSON format: `meta.json` (account), `run_autosave.json` + `run_backup.json` (game state)
- Autosave every 60s with backup rotation; corrupt autosave falls back to backup
- Serializes: buildings (type, grid_pos, rotation, per-type state including buffers/inventories/timers), currency, items_delivered, camera, time_speed
- Linked buildings (tunnel pairs) are serialized and restored on load
- Building hotkeys persisted per account slot in `meta.json`
- 3 account slots under `user://saves/slot_0/` through `slot_2/`

## Testing

Custom lightweight test framework (no plugin dependencies) for headless execution:

- Tests extend `BaseTest` (`tests/base_test.gd`) — methods prefixed `test_` are auto-discovered
- Assertions: `assert_eq()`, `assert_true()`, `assert_false()`, `assert_not_null()`
- Unit tests in `tests/unit/`, integration tests in `tests/integration/`
- Simulations in `tests/simulation/` extend `SimulationBase` — scripted play-throughs with time advancement and input synthesis

Available simulations: `sim_conveyor_transport`, `sim_unified_pull`, `sim_drill_extractor`, `sim_smelter_converter`, `sim_merge_and_source_sink`, `sim_junction`, `sim_splitter`.

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
