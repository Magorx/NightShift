# Buildings

## Structure
Each building lives in `buildings/<name>/` with:
- `<name>.tscn` — scene with visual nodes, ShapeCell/InputCell/OutputCell children, BuildAnchor
- `<name>.tres` — BuildingDef resource (id, display_name, category, scene ref, build_cost)
- `<logic>.gd` — script extending `BuildingLogic` (in `shared/building_logic.gd`)
- `sprites/` — Aseprite sources, generate.lua scripts, exported PNGs

## Adding a New Building
1. Create the `.tscn` scene with ShapeCells at 32px grid intervals
2. Add InputCell/OutputCell nodes under `Inputs`/`Outputs` groups with directional masks
3. Create a `.tres` BuildingDef pointing to the scene
4. Write a logic script extending `BuildingLogic` — GameManager finds it by type, no registration needed
5. Register the `.tres` in `scripts/autoload/game_manager.gd` building list

## Key Patterns
- **Pull system**: buildings never push items. All transfers go through `GameManager.pull_item()`
- **BuildingDef auto-extraction**: shape, IO points, and anchor are read from the `.tscn` at load time — don't duplicate in code
- **Direction system**: `DIRECTION_VECTORS = [RIGHT, DOWN, LEFT, UP]` (indices 0-3), opposite = `(dir + 2) % 4`
- **Animation state**: use `_anim_active`/`_active_hold_timer` from BuildingLogic base class, not custom timers
- **Visual resources in scenes**: sprites, materials, shaders go in `.tscn`, never constructed in code

## Shared Classes (`shared/`)
- `BuildingLogic` — base class, pull interface, animation state, serialization
- `BuildingDef` — resource definition, auto-extracts shape/IO from scenes
- `BuildingBase` — scene root script (placement, grid registration)
- `BuildingFill` — visual fill rendering
- `InputCell` / `OutputCell` / `ShapeCell` — grid cell markers in scenes
- `ItemBuffer` — internal item storage for processing buildings
