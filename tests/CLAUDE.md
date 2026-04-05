# Tests

## Structure
- `unit/` — fast, isolated tests for single functions/classes
- `integration/` — tests that need multiple systems running together
- `simulation/` — full game simulations that run the scene tree (headless, no player control)
- `scenarios/` — scripted integration tests with physical player control (see `scenarios/CLAUDE.md`)

## Writing Tests
- Extend `BaseTest` (`base_test.gd`) — methods prefixed `test_` are auto-discovered
- Available assertions: `assert_eq()`, `assert_true()`, `assert_false()`, `assert_not_null()`
- Optional `before_each()` / `after_each()` lifecycle hooks

## Writing Simulations
- Extend `SimulationBase` in `simulation/`
- File naming: `sim_<name>.gd` (the `sim_` prefix is required)
- `--fixed-fps 60` is REQUIRED when running simulations headless
- Simulations test systems (conveyors, drills, recipes) without player involvement
- Run at 100x speed headless — good for factory/building system tests

## Writing Scenarios
- Extend `ScenarioBase` in `scenarios/scenarios/`
- File naming: `scn_<name>.gd` (the `scn_` prefix is required)
- Scenarios physically move the player via `BotController` and verify game behavior
- Run at 10x speed headless (CharacterBody3D physics unstable at higher speeds)
- Default mode is visual (4x, window open) — designed to be watched
- **Use scenarios when**: testing player-related features, building placement UX, collision, production chains end-to-end, anything where the player is part of the test
- **Use simulations when**: testing isolated systems (conveyor routing, recipe processing, stress tests)

## Running
```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

# All unit/integration tests
$GODOT --headless --path . --script res://tests/run_tests.gd

# Single simulation (headless)
$GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- <sim_name>

# Simulation visual mode (windowed)
$GODOT --path . --script res://tests/run_simulation.gd -- <sim_name> --visual

# Screenshot baseline capture (needs rendering, no --headless)
$GODOT --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- <sim_name> --screenshot-baseline

# Scenario visual mode (default, 4x speed)
$GODOT --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- <scn_name>

# Scenario fast mode (headless, 10x speed)
$GODOT --headless --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- <scn_name> --fast

# List available scenarios
$GODOT --headless --path . --script res://tests/scenarios/run_scenario.gd -- --list
```

## Screenshots
- Baselines stored in `simulation/screenshots/<sim_name>/baseline/`
- Use screenshot mode to update baselines after intentional visual changes
