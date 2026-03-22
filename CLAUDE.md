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

Three singletons registered in Project Settings > Autoload, persisting across scene changes:

- **GameManager** (`scripts/autoload/game_manager.gd`) — game state, level loading, building placement API
- **SaveManager** (`scripts/autoload/save_manager.gd`) — JSON-based save/load with autosave rotation
- **AccountManager** (`scripts/autoload/account_manager.gd`) — account slot management (3 slots under `user://saves/`)

### Data-Driven Design via Custom Resources

Game content is defined as `.tres` resource files editable in Godot's Inspector — adding new items, recipes, or buildings requires no code changes:

- **ItemDef** (`scripts/resources/item_def.gd`) — item properties, export/research values
- **RecipeDef** (`scripts/resources/recipe_def.gd`) — converter type, inputs/outputs, craft time
- **BuildingDef** (`buildings/shared/building_def.gd`) — references the `.tscn` scene, size, unlock requirements

### Building Organization

Each building type lives in its own folder under `buildings/`:

```
buildings/
  shared/              # base scripts shared by all buildings
    building_base.gd   # BuildingBase class (root node script)
    building_def.gd    # BuildingDef resource class
    building_arrow.gd  # direction arrow overlay
    item_visual.gd     # item dot rendering
  conveyor/            # conveyor belt
    conveyor.tscn      # scene (editable in Godot)
    conveyor.gd        # belt logic (items, movement)
    conveyor_sprite.gd # sprite variant selection + animation
    conveyor.tres      # BuildingDef resource
    sprites/            # sprite sheet PNGs
  drill/  sink/  smelter/  source/   # same pattern
```

### Building Scene Pattern

Each building is a standalone `.tscn` scene with this structure:
- Root `Node2D` with `building_base.gd`
- `Background` ColorRect for the building color
- Type-specific logic node (e.g., `ConveyorLogic`, `SourceLogic`, `SinkLogic`)
- Optional `ConveyorSprite` (Sprite2D), `Arrow` (Node2D)
- `BuildingDef.scene` references the `.tscn`; `GameManager.place_building()` instantiates it

### Scene Tree (Gameplay)

```
GameWorld (Node2D)
  Camera2D
  TileMap              # terrain + source locations
  BuildingLayer        # placed buildings
  ItemLayer            # conveyor item visuals
  UI (CanvasLayer)
    HUD / BuildMenu / PauseMenu
```

Scene transitions use `SceneTree.change_scene_to_packed()`. Settings menu is an overlay, not a scene change.

### Save System

- JSON format (`meta.json` for account, `run_autosave.json` + `run_backup.json` for runs)
- Autosave every 60s with backup rotation
- Version field in every save file for migration support
- Corrupt autosave falls back to backup

## Testing

Custom lightweight test framework (no plugin dependencies) for headless execution:

- Tests extend `BaseTest` (`tests/base_test.gd`) — methods prefixed `test_` are auto-discovered
- Assertions: `assert_eq()`, `assert_true()`, `assert_false()`, `assert_not_null()`
- Unit tests in `tests/unit/`, integration tests in `tests/integration/`
- Simulations in `tests/simulation/` extend `SimulationBase` — scripted play-throughs with input synthesis and time advancement

### Workflow for New Features

1. Write feature (scenes, scripts, resources)
2. Add unit tests in `tests/unit/test_<feature>.gd`
3. Run tests headlessly to verify
4. Add/update simulation if it affects gameplay
