# Session: Scenario Test Framework

**Date:** 2025-04-05 (evening)
**Duration:** ~0.4h (20:07 - 20:28)
**Card:** SCN.1 — Scenario test framework

## Work Done

Built a scripted integration-test framework that physically moves the player character through the game world. This is a new testing layer between existing unit tests (fast, no game world) and simulations (game world but no player control).

### Framework components
- **ScenarioBase** — extends SimulationBase, adds bot/monitor/map subsystems, visual-first defaults
- **BotController** — walks the real CharacterBody3D via `Player.bot_input` property (tests actual physics pipeline: acceleration, friction, collision, move_and_slide)
- **ScenarioMonitor** — named metric tracking with callables, assertions (eq/gt/lt/between), screenshot capture, structured report at end
- **ScenarioMap** — DSL for quick map setup: deposits, clusters, walls, pre-placed buildings, player start position
- **run_scenario.gd** — CLI entry point with --fast (10x) / --visual (4x) / --screenshot modes

### Player modifications
- Added `bot_input: Vector3` — overrides keyboard input in `_handle_movement()`, so bot commands go through the real movement code
- Added `bot_sprint: bool` — enables sprint speed without keyboard
- Both properties are zero/false by default, no impact on normal gameplay

### Example scenarios (both pass)
- **scn_drill_to_sink** — tests full production chain: walk to deposit, place drill, lay conveyor line, place sink, verify 132 items delivered
- **scn_player_movement** — tests walking, jumping (peak height check), smelter collision blocking, sprinting + stamina drain, damage/regen, inventory drop/pickup

### Key design decisions
- Fast mode uses 10x speed (not 100x like simulations) because CharacterBody3D physics is unstable at high time_scale (delta=1.67s breaks move_and_slide)
- Bot sets `bot_input` direction, player's own `_handle_movement` processes it — tests real acceleration/friction/collision
- Cherry-picked from BOT cards: metric tracking concept (BOT.2), visual mode concept (BOT.5). Autonomous bot brains (BOT.1/3/4) remain separate

## Blockers / Notes
- Walk_to fails when path goes through buildings (no pathfinding — bot walks in straight lines). This is expected; scenarios should design walkable paths.
- Pickup test doesn't pick up the dropped item (physics item settles too far from player). Minor issue, doesn't affect framework utility.

## Next
- Write more scenarios as features are developed (each new card gets a scenario)
- Consider adding simple A* pathfinding to BotController if straight-line walk becomes too limiting
- BOT.1-6 autonomous bot system is separate work
