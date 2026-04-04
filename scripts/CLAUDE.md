# Scripts

## Autoloads (`autoload/`)
Singletons registered in `project.godot`, available globally:
- `GameManager` — central hub: building registry, grid state, `pull_item()` transfer system, tick orchestration
- `GridUtils` — isometric coordinate math, diamond helpers, tile transforms, ROTATION parameter
- `Logger` — debug logging with categories
- `SaveManager` — save/load serialization
- `AccountManager` — player account state (will be simplified for Night Shift)

## Key Rules
- All item transfers go through `GameManager.pull_item()` — never push directly between buildings
- Grid coordinates are `Vector2i`; screen positions use `GridUtils` for iso conversion
- `GridUtils.ROTATION` controls the isometric camera angle (default aligns grid axes with 45deg screen diagonals)
- New autoloads must be registered in `project.godot` under `[autoload]`
