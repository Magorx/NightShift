# Scripts

## Autoloads (`autoload/`)
Singletons registered in `project.godot`, available globally:
- `GridUtils` — isometric coordinate math, diamond helpers, tile transforms, ROTATION parameter
- `GameLogger` — debug logging with categories
- `MapManager` — terrain data, deposits, walls, world seed/size
- `ItemRegistry` — item definitions, icons, atlas, visual acquire/release
- `BuildingRegistry` — building defs, recipes, placed buildings, placement/removal, queries
- `EconomyTracker` — currency, item delivery tracking, creative mode
- `GameManager` — thin facade: scene-layer references (player, building_layer), hotkeys, clear_all()
- `AccountManager` — player account state (will be simplified for Night Shift)
- `SaveManager` — save/load serialization
- `SettingsManager` — user settings
- `RoundManager` — build/fight phase cycling

## Key Rules
- Items are physics-based (PhysicsItem RigidBody3D) — buildings use InputZone/OutputZone Area3Ds
- Grid coordinates are `Vector2i`; screen positions use `GridUtils` for iso conversion
- `GridUtils.ROTATION` controls the isometric camera angle (default aligns grid axes with 45deg screen diagonals)
- New autoloads must be registered in `project.godot` under `[autoload]`
