# CLAUDE.md

## Project: Night Shift

**Factory roguelite** built with **Godot 4.5** (GDScript). 30-minute session-based runs: build a factory during day phases, survive psychedelic monster attacks at night. Conveyors become walls, converters become elemental turrets. Built on the "Factor" engine (a Factorio clone used for prototyping).

Full design: `docs/design.md`

## Commands

```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

# Parse check (validates project loads)
$GODOT --headless --path . --quit

# Run all tests
$GODOT --headless --path . --script res://tests/run_tests.gd

# Run a specific simulation (--fixed-fps 60 is REQUIRED)
$GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- <sim_name>

# Visual mode (windowed, interactive)
$GODOT --path . --script res://tests/run_simulation.gd -- <sim_name> --visual

# Screenshot mode (needs rendering, no --headless)
$GODOT --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- <sim_name> --screenshot-baseline

# Launch game
$GODOT --path .
```

## Workflow & Tracking

### Project board
- **Kanban board**: `docs/kanban/BOARD.md` -- tasks organized as Backlog / In Progress / Done
- **Progress log**: `docs/progress.md` -- session-by-session log with hours, work done, velocity
- **Business tracker**: `docs/business.md` -- revenue projections, wishlist targets, timeline, costs
- **Design doc**: `docs/design.md` -- single source of truth for game design decisions

### Quota tracking
Run `/check-quota` every ~15 tool calls to fetch live usage data. This invokes `bash ~/.claude/hooks/fetch-quota.sh`, which sends a minimal CLI message to get fresh rate limits and writes them to `~/.claude/session-usage.txt`.

The output contains `Status:` and `Sleep:` fields:
- `Status: OK` -- continue normally
- `Status: PAUSE` -- **STOP all work immediately**. Tell the user quota is at 97%+, then run `sleep <N>` where N is the `Sleep:` value (seconds until reset). Resume work after the sleep completes.

Pacing guidelines:
- **> 80%**: use `/compact`, be concise, batch related reads, avoid unnecessary tool calls
- **> 90%**: warn the user, finish only the current task, skip nice-to-haves
- **> 97%**: PAUSE -- sleep until reset (mandatory, see above)

### Session workflow
1. **At session start**: run `date` to record the start time, read the kanban board and progress log
2. Pick the highest-priority unblocked task (or let the user direct)
3. Do the work (code, art, or both)
4. Run tests/simulations to verify
5. **Git commit after each completed kanban card** (or after each major step within a complex card). Don't batch commits -- commit as you go.
6. **MANDATORY at session end:**
   - Run `date` again and calculate elapsed time for the progress log
   - Update BOARD.md (move cards between columns)
   - Append to progress.md (date, **actual measured hours**, work done, blockers, next goal)
   - Update business.md timeline if estimates change

### Time tracking
- Use `date` (bash) at session start, after each completed kanban card, and at session end
- Never guess or copy hours from previous sessions -- always measure
- Report the actual time of day (morning/afternoon/evening) based on `date` output
- Each kanban card should track two times: **planned** (the estimate) and **actual** (measured with `date`). Use the difference to calibrate future estimates.

These tracking updates are the main session's responsibility -- always do them before the session ends, even if the user doesn't ask.

### Agent roles (`.claude/agents/`)
Five specialized agents available. Use them selectively -- not every session needs the full pipeline.

| Agent | Role | When to summon |
|-------|------|----------------|
| **manager** | Plans milestones, breaks features into kanban cards, writes briefs | Planning sessions, task breakdown, "what's next?" |
| **programmer** | Designs systems, writes GDScript, follows architecture patterns | Heavy feature implementation (most coding is done directly in main session) |
| **artist** | Creates pixel art via Aseprite Lua scripting | Art-focused sessions, sprite batches |
| **critic** | Reviews code for copy-paste, bad architecture; reviews art for quality | After a big feature is complete, before merging |
| **assessor** | Runs simulations, stress tests, evaluates fun and pacing | After milestone completion, playtesting |

**Typical session**: user talks to main session directly. Agents are summoned when their specialty is needed, not for every task.

**Full quality pipeline** (for big features): Manager assigns -> Programmer/Artist builds -> Critic reviews -> Assessor tests -> Done

## Architecture (Factor Engine)

### Key Systems to Reuse
- **Unified pull system**: All item transfers via `GameManager.pull_item()`. Buildings never push.
- **BuildingLogic base class**: `buildings/shared/building_logic.gd` -- all buildings extend this
- **BuildingDef**: `buildings/shared/building_def.gd` -- auto-extracts shape/IO from `.tscn` scenes
- **Data-driven design**: Items (`.tres` ItemDef), recipes (`.tres` RecipeDef), buildings (`.tres` BuildingDef)
- **ConveyorSystem**: Per-physics-frame processing with MultiMesh rendering
- **BuildSystem**: Grid-based placement with rotation and drag multi-placement
- **BuildingTickSystem**: Batched per-frame building updates

### Systems Being Removed
- ResearchManager + tech tree
- EnergySystem + EnergyNetwork
- ContractManager
- Complex UI panels (ResearchPanel, RecipeBrowser)
- AccountManager (replaced by simpler progression save)

### Systems to Build (see kanban board for task breakdown)
- RoundManager (build/fight/shop cycle)
- ElementSystem (6 resources, 15 combinations)
- NightTransform (buildings become defenses)
- MonsterSystem (AI, pathfinding, destruction patterns)
- DamageSystem (building HP, degradation, visual scarring)
- ShopSystem (random offerings between rounds)
- MetaProgression (planet screen, biome unlocks)

### Code Conventions
- Visual resources defined in `.tscn` scenes, not in code
- UI elements defined in `.tscn` scenes, never created in code
- New `class_name` files need `--import` to generate `.uid` before other scripts can reference them
- Use `remove_child()` before `queue_free()` when measuring layout immediately
- UI popups use `MOUSE_FILTER_PASS`; only interactive elements use `STOP`
- Direction system: `DIRECTION_VECTORS = [RIGHT, DOWN, LEFT, UP]` (indices 0-3)

### Art Pipeline: `tools/rendering/iso/`
Isometric 3D geometry library for building sprite generation. Replaces hand-coded perspective math with a proper 3D→2D pipeline. Load in Aseprite Lua scripts:

```lua
local Iso = dofile(REPO .. "/tools/rendering/iso/init.lua")
Iso._set_helper(H)  -- pass aseprite_helper instance
```

- **Configurable projection**: `Iso.configure({ tile_ratio = 2, z_scale = 1 })` — not hardcoded to 2:1
- **9 primitives**: `Iso.box()`, `Iso.cylinder()`, `Iso.cone()`, `Iso.sphere()`, `Iso.hemisphere()`, `Iso.wedge()`, `Iso.prism()`, `Iso.torus()`, `Iso.arch()`
- **Mechanical parts**: `Iso.gear()` (animated rotation), `Iso.pipe()`, `Iso.piston()`, `Iso.fan()`
- **CSG**: `Iso.union()`, `Iso.subtract()`, `Iso.intersect()`
- **12 textures**: brick, metal plate, grate, rivets, wood, corrugated, hex mesh, etc.
- **Scene builder**: `Iso.scene(w, h)` — compose multiple shapes with automatic depth sorting
- **Animation**: `Iso.anim_gear()`, `Iso.particle_emitter()`, oscillation, shake
- See `tools/rendering/iso/README.md` for full API, `examples/` for visual reference

### Building Organization
Each building type lives in `buildings/<name>/` with `.tscn` scene + `.tres` BuildingDef + logic script extending `BuildingLogic`. No changes to GameManager needed to add new buildings.

### Testing
- Tests extend `BaseTest` (`tests/base_test.gd`), methods prefixed `test_` are auto-discovered
- Simulations extend `SimulationBase` in `tests/simulation/`
- Always run at least the parse check after changes
- Run relevant simulations before reporting work as complete

## Documentation
- `docs/design.md` -- Night Shift game design document
- `docs/kanban/BOARD.md` -- project task board
- `docs/progress.md` -- development session log
- `docs/business.md` -- business metrics and projections
- `docs/indie_game_market.md` -- market analysis
- `docs/archive/` -- archived Factor design documents
