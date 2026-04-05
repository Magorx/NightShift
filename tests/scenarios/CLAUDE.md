# Scenario Tests

Scripted integration tests that physically move the player and verify game behavior.

## Structure
- `scenario_base.gd` — base class (extends SimulationBase), sets up bot + monitor + map
- `bot_controller.gd` — scripted player control via `Player.bot_input` (real physics)
- `scenario_monitor.gd` — metric tracking + screenshots + assertions
- `scenario_map.gd` — quick map setup (deposits, walls, buildings, player start)
- `run_scenario.gd` — entry point (like run_simulation.gd)
- `scenarios/` — individual scenario scripts (prefix: `scn_`)

## Running
```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

# Visual mode (default) — windowed at 4x speed, watchable
$GODOT --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- <name>

# Fast mode — headless at 10x for CI
$GODOT --headless --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- <name> --fast

# Screenshot baseline
$GODOT --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- <name> --screenshot-baseline

# List scenarios
$GODOT --headless --path . --script res://tests/scenarios/run_scenario.gd -- --list
```

## Writing a Scenario
```gdscript
extends ScenarioBase

func scenario_name() -> String:
    return "scn_my_test"

func setup_map() -> void:
    map.clear_walls()
    map.deposit(Vector2i(10, 10), &"pyromite")
    map.player_start(Vector2i(8, 10))

func setup_monitors() -> void:
    monitor.track("items", func() -> int:
        return GameManager.items_delivered.get(&"pyromite", 0))

func run_scenario() -> void:
    await bot.walk_to(Vector2i(9, 10))
    await bot.place(&"drill", Vector2i(10, 10), 0)
    await bot.wait(10.0)
    monitor.assert_gt("items", 0.0, "Items delivered")
    await monitor.screenshot("final")
```

## Key differences from simulations
- Default mode is **visual** (4x speed, window open) not fast
- Fast mode uses **10x** (not 100x) because CharacterBody3D physics is unstable at high timescale
- Player moves physically via `bot_input` — tests real collision/movement
- ScenarioMonitor provides structured metric tracking and assertion reporting
- 120s timeout (vs 60s for simulations)
