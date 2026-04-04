# Tests

## Structure
- `unit/` — fast, isolated tests for single functions/classes
- `integration/` — tests that need multiple systems running together
- `simulation/` — full game simulations that run the scene tree

## Writing Tests
- Extend `BaseTest` (`base_test.gd`) — methods prefixed `test_` are auto-discovered
- Available assertions: `assert_eq()`, `assert_true()`, `assert_false()`, `assert_not_null()`
- Optional `before_each()` / `after_each()` lifecycle hooks

## Writing Simulations
- Extend `SimulationBase` in `simulation/`
- File naming: `sim_<name>.gd` (the `sim_` prefix is required)
- `--fixed-fps 60` is REQUIRED when running simulations headless

## Running
```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

# All tests
$GODOT --headless --path . --script res://tests/run_tests.gd

# Single simulation (headless)
$GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- <sim_name>

# Visual mode (windowed)
$GODOT --path . --script res://tests/run_simulation.gd -- <sim_name> --visual

# Screenshot baseline capture (needs rendering, no --headless)
$GODOT --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- <sim_name> --screenshot-baseline
```

## Screenshots
- Baselines stored in `simulation/screenshots/<sim_name>/baseline/`
- Use screenshot mode to update baselines after intentional visual changes
