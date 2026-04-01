# Factor - Implementation Details

## Engine & Project Structure

Engine: **Godot 4.x** (GDScript primary, C# optional for performance-critical systems)

```
factor/
  scenes/
    ui/
      main_menu.tscn
      settings_menu.tscn
      hud.tscn
      account_select.tscn
      pause_menu.tscn
    game/
      game_world.tscn          # root of gameplay
      tile_map.tscn             # the factory grid
    buildings/
      extractor/
        drill.tscn
        pump.tscn
        pumpjack.tscn
        dredger.tscn
      conveyor/
        conveyor.tscn
        splitter.tscn
        merger.tscn
        bridge.tscn
        router.tscn
        sorter.tscn
      converter/
        smelter.tscn
        assembler.tscn
        chemical_plant.tscn
        advanced_factory.tscn
      sink/
        export_terminal.tscn
        research_lab.tscn
  resources/
    items/                      # .tres Resource files per item
      iron_ore.tres
      copper_ore.tres
      ...
    recipes/                    # .tres Resource files per recipe
      smelt_iron.tres
      forge_steel.tres
      ...
    buildings/                  # .tres BuildingDef resources
      drill.tres
      smelter.tres
      ...
    tech_tree/
      tech_tree.tres            # TechTree resource
  scripts/
    autoload/
      game_manager.gd           # global game state singleton
      save_manager.gd           # save/load singleton
      account_manager.gd        # account slot management
    buildings/
      building_base.gd
      extractor.gd
      conveyor.gd
      converter.gd
      sink.gd
    ui/
      main_menu.gd
      settings_menu.gd
      hud.gd
    resources/
      item_def.gd               # custom Resource class
      recipe_def.gd             # custom Resource class
      building_def.gd           # custom Resource class
  data/
    saves/                      # save files live here at runtime
```

---

## Main Menu

### Scene: `scenes/ui/main_menu.tscn`

Layout (VBoxContainer centered on screen):

```
[Game Logo / Title]

[Continue]          -- resumes last played save, hidden if no saves exist
[Start New Run]     -- starts a new run in the active account slot
[Settings]          -- opens settings_menu.tscn
[Quit]

            [Account: Slot 1 v]   -- dropdown in bottom-right corner
```

### Account Selector

A small dropdown (`OptionButton`) in the corner of the main menu showing the current account slot. Clicking it opens `account_select.tscn` as an overlay.

**Account Select Panel** (`scenes/ui/account_select.tscn`):
- Shows 3-5 account slots as a `VBoxContainer` of `PanelContainer` items
- Each slot shows: slot number, player name (editable), total playtime, last played date
- Buttons per slot: **Select**, **Rename**, **Delete** (with confirmation dialog)
- One slot is marked "active" with a highlight

---

## Save System

### Architecture

Two singletons registered as Autoloads:

1. **`AccountManager`** (`scripts/autoload/account_manager.gd`)
2. **`SaveManager`** (`scripts/autoload/save_manager.gd`)

### Account Slots (Metagame Save)

Each account slot is a directory under `user://saves/`:

```
user://saves/
  slot_0/
    meta.json          # account-level metadata
    run_autosave.json  # current run state
    run_backup.json    # previous autosave (rotation)
  slot_1/
    meta.json
    ...
  slot_2/
    meta.json
    ...
```

#### `meta.json` — Metagame Save

Stores persistent cross-run progress for one account slot:

```json
{
  "version": 1,
  "slot_id": 0,
  "player_name": "Player 1",
  "created_at": "2026-03-22T10:00:00Z",
  "last_played": "2026-03-22T14:30:00Z",
  "total_playtime_sec": 16200,
  "unlocked_tech": ["basic_smelting", "fast_conveyors", "steel"],
  "campaign_progress": {
    "current_level": 3,
    "completed_levels": [1, 2]
  },
  "settings_overrides": {}
}
```

#### `run_autosave.json` — Current Run Save

Stores the full state of the current factory/level:

```json
{
  "version": 1,
  "level_id": "campaign_03",
  "playtime_sec": 3600,
  "saved_at": "2026-03-22T14:30:00Z",
  "camera": { "x": 512, "y": 384, "zoom": 1.0 },
  "buildings": [
    {
      "type": "drill",
      "grid_x": 10,
      "grid_y": 5,
      "rotation": 0,
      "state": { "progress": 0.5 }
    },
    {
      "type": "conveyor",
      "grid_x": 11,
      "grid_y": 5,
      "rotation": 1,
      "item_on_belt": "iron_ore"
    },
    {
      "type": "smelter",
      "grid_x": 12,
      "grid_y": 5,
      "rotation": 0,
      "recipe_id": "smelt_iron",
      "input_buffer": { "iron_ore": 1 },
      "output_buffer": {},
      "craft_progress": 0.3
    }
  ],
  "resources_delivered": {
    "export_terminal": { "iron_plate": 150, "steel": 30 },
    "research_lab": { "circuit": 10 }
  }
}
```

### SaveManager API

```gdscript
# scripts/autoload/save_manager.gd
extends Node

signal save_completed
signal load_completed(success: bool)

# Save current run to the active account slot
func save_run() -> void

# Load a run from the active account slot
func load_run() -> bool

# Check if a run save exists for the active slot
func has_run_save() -> bool

# Delete run save for the active slot
func delete_run_save() -> void

# Save metagame data for the active slot
func save_meta() -> void

# Load metagame data for a slot
func load_meta(slot_id: int) -> Dictionary
```

### AccountManager API

```gdscript
# scripts/autoload/account_manager.gd
extends Node

signal active_slot_changed(slot_id: int)

var active_slot: int = 0
var slot_count: int = 3  # configurable

# Get metadata for all slots (for the account select UI)
func get_all_slots() -> Array[Dictionary]

# Set the active slot
func set_active_slot(slot_id: int) -> void

# Create/reset a slot
func create_slot(slot_id: int, player_name: String) -> void

# Delete a slot and all its saves
func delete_slot(slot_id: int) -> void

# Rename
func rename_slot(slot_id: int, new_name: String) -> void
```

### Save Flow

1. **Autosave**: `SaveManager.save_run()` is called every 60 seconds during gameplay and on pause/quit. Before writing, the current `run_autosave.json` is copied to `run_backup.json` (rotation).
2. **Save format**: JSON via `JSON.stringify()` / `JSON.parse_string()`. Chosen over Godot's binary `ResourceSaver` for debuggability and version migration.
3. **Versioning**: Every save file has a `"version"` field. On load, `SaveManager` checks the version and runs migration functions if needed.

### Load Flow

1. Player selects account slot in main menu
2. Clicks "Continue" -> `SaveManager.load_run()` reads `run_autosave.json`
3. `GameManager` receives the parsed data, instantiates the level scene, and rebuilds all buildings from the save
4. If `run_autosave.json` is corrupt, falls back to `run_backup.json`

### New Run Flow

1. Player clicks "Start New Run"
2. If a run save exists, show confirmation dialog ("This will overwrite your current run")
3. `SaveManager.delete_run_save()`, then `GameManager` loads the first unlocked campaign level (or sandbox) fresh

---

## Scene & Node Architecture

### Leveraging Godot Scenes for Editor Workflow

Every building is its own `.tscn` scene so that designers can open, preview, and tweak buildings in the Godot editor without touching code:

**Building scene structure** (example: `smelter.tscn`):

```
Smelter (Node2D)                    # root, has building_base.gd + converter.gd
  Sprite2D                          # visual, editable in editor
  CollisionShape2D                  # for click detection (Area2D child)
  InputMarkers (Node2D)             # position markers for input sides
    InputSlot0 (Marker2D)
    InputSlot1 (Marker2D)
  OutputMarkers (Node2D)
    OutputSlot0 (Marker2D)
  AnimationPlayer                   # crafting animation
  AudioStreamPlayer2D               # crafting sound
```

**Key design principle**: building properties that a designer wants to tweak are `@export` vars on the script, visible and editable in the Godot Inspector:

```gdscript
# scripts/buildings/converter.gd
extends "building_base.gd"

@export var building_def: BuildingDef      # drag-drop .tres in inspector
@export var default_recipe: RecipeDef      # drag-drop .tres in inspector
@export var craft_speed_multiplier: float = 1.0
@export var input_slots: int = 2
@export var output_slots: int = 1
```

### Custom Resources (`.tres` files editable in Inspector)

```gdscript
# scripts/resources/item_def.gd
class_name ItemDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var category: String  # "raw", "intermediate", "advanced"
@export var export_value: int = 1
@export var research_value: int = 0
```

```gdscript
# scripts/resources/recipe_def.gd
class_name RecipeDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var converter_type: String  # "smelter", "assembler", etc.
@export var inputs: Array[ItemStack]  # custom sub-resource
@export var outputs: Array[ItemStack]
@export var craft_time: float = 5.0
```

```gdscript
# scripts/resources/building_def.gd
class_name BuildingDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var scene: PackedScene       # the .tscn to instantiate
@export var size: Vector2i = Vector2i(1, 1)
@export var category: String
@export var unlock_tech: StringName  # tech tree node required
```

This way, adding a new building or recipe is a pure editor task:
1. Create a new `.tres` resource file
2. Fill in properties in the Inspector
3. If it's a building, create a `.tscn` scene and reference it from the `.tres`

### Game World Scene

```
GameWorld (Node2D)                   # scenes/game/game_world.tscn
  Camera2D                           # player camera, zoom/pan
  TileMap                            # terrain layer (sources shown as special tiles)
  BuildingLayer (Node2D)             # all placed buildings are children here
  ItemLayer (Node2D)                 # items moving on conveyors (visual only)
  UI (CanvasLayer)
    HUD (scenes/ui/hud.tscn)        # toolbar, resource counts, minimap
    BuildMenu                        # building selection palette
    PauseMenu                        # ESC overlay
```

### Scene Transitions

Use `SceneTree.change_scene_to_packed()` for major transitions:

- Main Menu -> Game World (on Continue/Start)
- Game World -> Main Menu (on quit-to-menu)
- Settings is an overlay (added as child of current scene), not a scene change

---

## Autoload Singletons

Register in `Project > Project Settings > Autoload`:

| Name             | Script                              | Purpose                        |
|-----------------|-------------------------------------|--------------------------------|
| GameManager     | `scripts/autoload/game_manager.gd`  | Game state, level loading      |
| SaveManager     | `scripts/autoload/save_manager.gd`  | Save/load operations           |
| AccountManager  | `scripts/autoload/account_manager.gd`| Account slot management       |

These persist across scene changes and provide global access to game state and save operations.

---

## Settings

Settings are stored in `user://settings.json` (global, not per-account). Editable via `scenes/ui/settings_menu.tscn`.

Categories:
- **Audio**: master, sfx, music volume
- **Video**: resolution, fullscreen, vsync
- **Gameplay**: autosave interval, conveyor animation speed
- **Controls**: key rebinds (stored as action -> key mappings)

---

## Headless Testing & Simulation Runs

### Goals

1. Every feature has automated tests runnable from the CLI
2. Full gameplay can be simulated end-to-end without a display
3. User input can be synthesized programmatically
4. Claude Code can launch, observe, and debug the game from the conversation

### Godot Headless Execution

Godot 4.x supports headless mode via the `--headless` flag. This runs the engine without creating a window or rendering — ideal for CI and CLI-driven testing.

**Binary location** (macOS): `/Applications/Godot.app/Contents/MacOS/Godot`

**Alias** (add to project scripts or shell):
```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
```

**Key flags:**
```bash
$GODOT --headless --path /path/to/factor --script res://tests/run_tests.gd   # run test suite
$GODOT --headless --path /path/to/factor --script res://tests/run_simulation.gd  # run simulation
$GODOT --headless --path /path/to/factor --quit                               # validate project loads
```

The `--path` flag sets the project root. `--script` runs a specific GDScript as a MainLoop override (the script must extend `MainLoop` or `SceneTree`). `--quit` exits after one idle frame — useful for "does it parse" checks.

---

### Test Framework

We use a lightweight custom test runner (no external plugin dependencies) so tests work in headless mode without editor plugins.

#### Project Structure

```
tests/
  run_tests.gd              # MainLoop entry point — discovers and runs all tests
  run_simulation.gd          # MainLoop entry point — runs gameplay simulations
  base_test.gd               # base class all test scripts extend
  unit/
    test_item_def.gd
    test_recipe_def.gd
    test_save_manager.gd
    test_account_manager.gd
    test_conveyor_logic.gd
    test_converter_logic.gd
  integration/
    test_extractor_to_conveyor.gd
    test_conveyor_to_converter.gd
    test_full_production_chain.gd
    test_save_load_roundtrip.gd
  simulation/
    sim_basic_factory.gd
    sim_campaign_level_1.gd
```

#### Base Test Class

```gdscript
# tests/base_test.gd
class_name BaseTest
extends Node

var _pass_count: int = 0
var _fail_count: int = 0
var _test_name: String = ""

func run_all() -> Dictionary:
    var results := { "passed": 0, "failed": 0, "errors": [] }
    for method in get_method_list():
        if method.name.begins_with("test_"):
            _test_name = method.name
            # Call setup if it exists
            if has_method("before_each"):
                call("before_each")
            # Run test
            var err = call(method.name)
            if has_method("after_each"):
                call("after_each")
    results.passed = _pass_count
    results.failed = _fail_count
    return results

func assert_eq(a, b, msg: String = "") -> void:
    if a == b:
        _pass_count += 1
    else:
        _fail_count += 1
        var text = "%s: expected %s == %s" % [_test_name, str(a), str(b)]
        if msg:
            text += " (%s)" % msg
        printerr("  FAIL: " + text)

func assert_true(cond: bool, msg: String = "") -> void:
    assert_eq(cond, true, msg)

func assert_false(cond: bool, msg: String = "") -> void:
    assert_eq(cond, false, msg)

func assert_not_null(val, msg: String = "") -> void:
    if val != null:
        _pass_count += 1
    else:
        _fail_count += 1
        printerr("  FAIL: %s: expected non-null (%s)" % [_test_name, msg])
```

#### Test Runner (MainLoop Entry Point)

```gdscript
# tests/run_tests.gd
extends SceneTree

func _init():
    # Discover and run all test scripts
    var test_dirs = ["res://tests/unit/", "res://tests/integration/"]
    var total_passed := 0
    var total_failed := 0

    for dir_path in test_dirs:
        var dir = DirAccess.open(dir_path)
        if not dir:
            printerr("Cannot open: " + dir_path)
            continue
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.begins_with("test_") and file_name.ends_with(".gd"):
                var script = load(dir_path + file_name)
                var instance = script.new()
                print("Running: %s" % file_name)
                var results = instance.run_all()
                total_passed += results.passed
                total_failed += results.failed
                instance.free()
            file_name = dir.get_next()

    print("\n===== Results: %d passed, %d failed =====" % [total_passed, total_failed])

    if total_failed > 0:
        printerr("TESTS FAILED")
        # Exit code 1 for CI
        quit(1)
    else:
        print("ALL TESTS PASSED")
        quit(0)
```

#### Running Tests from CLI

```bash
# Run all tests (unit + integration)
$GODOT --headless --path . --script res://tests/run_tests.gd

# Exit code: 0 = all pass, 1 = failures
echo $?
```

Output is plain text to stdout/stderr, fully readable from Claude Code's Bash tool.

---

### Gameplay Simulation

Simulations are scripted play-throughs that instantiate real game scenes, synthesize user input, advance the game loop, and assert on outcomes.

#### Simulation Runner

```gdscript
# tests/run_simulation.gd
extends SceneTree

# Pass simulation name via command line:
#   $GODOT --headless --path . --script res://tests/run_simulation.gd -- sim_basic_factory
func _init():
    var args = OS.get_cmdline_user_args()  # args after "--"
    var sim_name = args[0] if args.size() > 0 else "sim_basic_factory"
    var sim_path = "res://tests/simulation/%s.gd" % sim_name
    var script = load(sim_path)
    if not script:
        printerr("Simulation not found: " + sim_path)
        quit(1)
        return
    var sim = script.new()
    root.add_child(sim)
    # Simulation script drives itself and calls quit() when done
```

#### Simulation Base Class

```gdscript
# tests/simulation/simulation_base.gd
class_name SimulationBase
extends Node

var game_world: Node2D
var tick_count: int = 0

func _ready():
    # Load the real game world scene
    var scene = load("res://scenes/game/game_world.tscn")
    game_world = scene.instantiate()
    add_child(game_world)
    print("[SIM] Game world loaded")
    run_simulation()

func run_simulation() -> void:
    # Override in subclass
    pass

# --- Input simulation helpers ---

func sim_place_building(building_id: StringName, grid_pos: Vector2i, rotation: int = 0) -> void:
    # Calls GameManager's building placement API directly
    GameManager.place_building(building_id, grid_pos, rotation)
    print("[SIM] Placed %s at %s rot=%d" % [building_id, str(grid_pos), rotation])

func sim_remove_building(grid_pos: Vector2i) -> void:
    GameManager.remove_building(grid_pos)
    print("[SIM] Removed building at %s" % str(grid_pos))

func sim_click(screen_pos: Vector2) -> void:
    var event = InputEventMouseButton.new()
    event.position = screen_pos
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = true
    Input.parse_input_event(event)
    # Release next frame
    var release = event.duplicate()
    release.pressed = false
    Input.parse_input_event.call_deferred(release)

func sim_key(keycode: Key) -> void:
    var event = InputEventKey.new()
    event.keycode = keycode
    event.pressed = true
    Input.parse_input_event(event)
    var release = event.duplicate()
    release.pressed = false
    Input.parse_input_event.call_deferred(release)

func sim_action(action_name: StringName) -> void:
    Input.action_press(action_name)
    Input.action_release.call_deferred(action_name)

# --- Time helpers ---

func sim_advance_ticks(count: int) -> void:
    # Advance the SceneTree by N physics frames
    for i in count:
        await get_tree().physics_frame
        tick_count += 1

func sim_advance_seconds(seconds: float) -> void:
    # At 60 fps physics, advance that many frames
    var frames = int(seconds * 60)
    await sim_advance_ticks(frames)

# --- Assertion helpers ---

func sim_assert(condition: bool, msg: String) -> void:
    if not condition:
        printerr("[SIM FAIL] " + msg)
        get_tree().quit(1)
    else:
        print("[SIM OK] " + msg)

func sim_finish() -> void:
    print("[SIM] Simulation complete. Ticks: %d" % tick_count)
    get_tree().quit(0)
```

#### Example Simulation

```gdscript
# tests/simulation/sim_basic_factory.gd
extends SimulationBase

func run_simulation() -> void:
    # Place a drill on an iron deposit at (10, 5)
    sim_place_building(&"drill", Vector2i(10, 5))

    # Place conveyors leading to a smelter
    sim_place_building(&"conveyor", Vector2i(11, 5), 0)  # right
    sim_place_building(&"conveyor", Vector2i(12, 5), 0)

    # Place a smelter at (13, 5)
    sim_place_building(&"smelter", Vector2i(13, 5))

    # Place output conveyor and export terminal
    sim_place_building(&"conveyor", Vector2i(15, 5), 0)
    sim_place_building(&"export_terminal", Vector2i(16, 5))

    # Run for 60 simulated seconds
    await sim_advance_seconds(60)

    # Assert that items were delivered
    var delivered = GameManager.get_total_exported(&"iron_plate")
    sim_assert(delivered > 0, "Iron plates were exported (got %d)" % delivered)

    # Assert drill is producing
    var drill = GameManager.get_building_at(Vector2i(10, 5))
    sim_assert(drill != null, "Drill exists at (10,5)")

    sim_finish()
```

#### Running Simulations from CLI

```bash
# Run a specific simulation
$GODOT --headless --path . --script res://tests/run_simulation.gd -- sim_basic_factory

# Output is logged to stdout, exit code indicates pass/fail
```

---

### CLI Cheat Sheet

All commands assume `GODOT="/Applications/Godot.app/Contents/MacOS/Godot"` and working directory is the project root.

| Task                          | Command                                                             |
|-------------------------------|---------------------------------------------------------------------|
| Validate project loads        | `$GODOT --headless --path . --quit`                                 |
| Run all tests                 | `$GODOT --headless --path . --script res://tests/run_tests.gd`      |
| Run a simulation              | `$GODOT --headless --path . --script res://tests/run_simulation.gd -- <sim_name>` |
| Launch game with visible window (debug) | `$GODOT --path .`                                        |
| Print scene tree for debugging| `$GODOT --headless --path . --script res://tests/debug_print_tree.gd`|
| Export debug info             | `$GODOT --headless --path . --script res://tests/debug_dump.gd`     |

All output goes to stdout/stderr and is fully capturable by Claude Code via the Bash tool. Exit codes propagate for pass/fail detection.

---

### Workflow: Adding a New Feature

1. Write the feature (scenes, scripts, resources)
2. Add unit tests in `tests/unit/test_<feature>.gd`
3. Run `$GODOT --headless --path . --script res://tests/run_tests.gd` — verify pass
4. If the feature affects gameplay, add or update a simulation in `tests/simulation/`
5. Run the simulation — verify expected outcomes
6. Commit
