# CLAUDE.md

## Quota tracking

Run `/check-quota` to fetch live usage data. This invokes `bash ~/.claude/hooks/fetch-quota.sh` which reads `~/.claude/session-usage.txt`.

**Checking frequency depends on your entrypoint:**
- **CLI**: the statusLine hook fires automatically and writes both session (5hr) and weekly (7d) limits. Check every **5 tool calls**.
- **VSCode**: the statusLine hook does not fire, so `fetch-quota.sh` falls back to a CLI call that only returns the **bottleneck** (whichever bucket is more constrained). The other bucket is shown as `<N% (not bottleneck)` -- this means it is guaranteed to be lower than the bottleneck percentage. Check every **15 tool calls** (each check costs one API call).

**Output fields:**
- `Status: OK` -- continue normally
- `Status: PAUSE` -- **STOP all work immediately**. Tell the user quota is at 97%+, then run `sleep <N>` where N is the `Sleep:` value (seconds until reset). Resume after sleep completes.

**Pacing guidelines (based on session 5hr quota, or bottleneck if session is unavailable):**
- **> 80%**: use `/compact`, be concise, batch related reads, avoid unnecessary tool calls
- **> 90%**: warn the user, finish only the current task, skip nice-to-haves
- **> 97%**: PAUSE -- sleep until reset (mandatory, see above)

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

# Run a scenario (scripted integration test with player control)
# Visual (default, 4x speed, watchable):
$GODOT --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- <scn_name>
# Fast (headless, 10x speed, for CI):
$GODOT --headless --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- <scn_name> --fast

# Launch game
$GODOT --path .
```

## Workflow & Tracking

### Project board
- **Kanban board**: `docs/kanban/BOARD.md` -- active tasks (Backlog / In Progress). Solved cards in `BOARD_SOLVED.md`
- **Progress log**: `docs/progress/` -- individual session reports, summary in `SUMMARY.md`
- **Business tracker**: `docs/business.md` -- revenue projections, wishlist targets, timeline, costs
- **Design doc**: `docs/design.md` -- single source of truth for game design decisions

### Session workflow
1. **At session start**: run `date` to record the start time, read the kanban board and progress log
2. Pick the highest-priority unblocked task (or let the user direct)
3. Do the work (code, art, or both)
4. Run tests/simulations to verify
5. **Git commit after each completed kanban card** (or after each major step within a complex card). Don't batch commits -- commit as you go.
6. **MANDATORY at session end:**
   - Run `date` again and calculate elapsed time for the progress log
   - Update BOARD.md (move cards between columns)
   - Create new session file in docs/progress/ named `[date]_[time]_[name].md` (date, **actual measured hours**, work done, blockers, next goal)
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

### Art Pipeline: `tools/rendering/iso/` (2D sprites, legacy)
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
- **Scene lighting**: `Iso.light_ambient()`, `Iso.light_directional()`, `Iso.light_point()` — scene-level lights with colored tinting and attenuation
- **Scene builder**: `Iso.scene(w, h)` — compose multiple shapes with automatic depth sorting
- **Animation**: `Iso.anim_gear()`, `Iso.particle_emitter()`, oscillation, shake
- See `tools/rendering/iso/README.md` for full API, `examples/` for visual reference

### 3D Art Pipeline: `tools/blender/` (3D models for Godot)
Procedural 3D building models via Blender Python scripts. Outputs `.glb` + `.blend` files with baked NLA animations. Models import into Godot as scene hierarchies with AnimationPlayer.

```bash
BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"

# Generate a building model (creates .glb + .blend)
$BLENDER --background --python tools/blender/scenes/drill_model.py

# Custom output path
$BLENDER --background --python tools/blender/scenes/drill_model.py -- --output path/to/out.glb
```

**Directory structure:**
- `tools/blender/render.py` — core setup: orthographic isometric camera, EEVEE render settings, frame rendering
- `tools/blender/materials/pixel_art.py` — PBR materials from hex colors, Lua palette loader (`load_palette("buildings")`)
- `tools/blender/prefabs_src/` — parameterized mesh generators (box, cog, cylinder, pipe, piston, fan)
- `tools/blender/scenes/` — building composition scripts that import prefabs and bake animations

**Prefabs (all in `prefabs_src/`):**
- `box.py` — `generate_box(w, d, h, hex_color, seam_count)` — rectangular box with optional panel seams
- `cog.py` — `generate_cog(outer_radius, inner_radius, teeth, thickness, tooth_width_outer, tooth_width_inner)` — gear with trapezoid teeth
- `cylinder.py` — `generate_cylinder(radius, height, segments, cap_style)` — solid cylinder, flat or dome cap
- `pipe.py` — `generate_pipe(length, radius, wall_thickness, flange_radius)` — hollow pipe with flange caps
- `piston.py` — `generate_piston(sleeve_r, rod_r, sleeve_h)` — returns (sleeve, rod) tuple, rod parented to sleeve
- `fan.py` — `generate_fan(blades, radius, blade_width)` — N-blade fan with hub

**Creating a new building model:**
1. Create `tools/blender/scenes/<building>_model.py`
2. Import prefabs and `render.clear_scene()`
3. Compose parts with `generate_*()`, set `.name`, `.location`, `.parent`
4. Bake NLA animations: one action per object per state, push to NLA tracks with same name → glTF merges them into combined animations
5. Export with `export_scene.gltf(export_animation_mode='NLA_TRACKS', export_merge_animation='NLA_TRACK')`
6. Output goes to `buildings/<name>/models/` (`.glb` + `.blend`)

**Critical gotchas:**
- Always call `bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])` before `bm.to_mesh()` — otherwise Godot shows missing faces
- Blender 5.x uses `'BLENDER_EEVEE'` (not `'BLENDER_EEVEE_NEXT'`)
- Blender 5.x layered actions: fcurves at `action.layers[0].strips[0].channelbags[0].fcurves`
- Use Principled BSDF materials (not emission) so colors match between Blender and Godot
- NLA track names must match across objects to merge into combined animations in glTF
- Palette colors loaded from `tools/palettes/*.lua` via `load_palette()`
- Reference model: `tools/blender/scenes/drill_model.py` — the first building, well-commented

### Building Organization
Each building type lives in `buildings/<name>/` with `.tscn` scene + `.tres` BuildingDef + logic script extending `BuildingLogic`. No changes to GameManager needed to add new buildings.

### Testing
- **Unit tests**: extend `BaseTest` (`tests/base_test.gd`), methods prefixed `test_` are auto-discovered
- **Simulations**: extend `SimulationBase` in `tests/simulation/` — headless at 100x, test systems without player
- **Scenarios**: extend `ScenarioBase` in `tests/scenarios/` — scripted integration tests that physically move the player through the world, place buildings, and verify metrics + screenshots. See `tests/scenarios/CLAUDE.md` for full API.
- Always run at least the parse check after changes
- Run relevant simulations/scenarios before reporting work as complete
- When building a new feature, write a scenario that tests it end-to-end with player involvement

## Documentation
- `docs/design.md` -- Night Shift game design document
- `docs/kanban/BOARD.md` -- active project task board (`BOARD_SOLVED.md` for completed cards)
- `docs/progress/` -- development session reports (one file per session)
- `docs/business.md` -- business metrics and projections
- `docs/indie_game_market.md` -- market analysis
- `docs/archive/` -- archived Factor design documents
