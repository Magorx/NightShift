# Factor — Implementation State

## Message to Next Claude

Read `CLAUDE.md` for quick reference. Read `docs/design.md` for full game design (items, recipes, converters, tech tree, campaigns). Read `docs/implementation_details.md` for architecture details. This file tracks implementation progress — check which step is current, read its description, and implement it. After completing a step, mark it `[x]` and tell the user to launch the game to verify. Do NOT skip ahead to future steps.

The game is a Godot 4.5 project. All scripts use GDScript. Visual style is flat/geometric with colored rectangles and simple shapes — no external art assets needed. Use `32x32` tile size throughout.

---

## What's Done

Steps 1–13 are complete. Here's what exists:

**Core infrastructure** — Main menu, game world with TileMapLayer, camera (pan/zoom), grid-based build system with rotation, drag placement, destroy mode with shader highlights.

**Data-driven resources** — ItemDef, RecipeDef, ItemStack, BuildingDef custom resources. BuildingDef auto-extracts shape/inputs/outputs/anchor from scene marker nodes. Currently 4 items defined (iron_ore, copper_ore, coal, iron_plate) and 1 recipe (smelt_iron).

**Buildings implemented** — Conveyor (belt transport with ItemBuffer progress tracking), Drill/Extractor (timer-based production on source tiles), Smelter/Converter (recipe crafting with multiple IO, round-robin input pulling), Sink (infinite consumer, tracks deliveries for currency), Source (simple item producer), Splitter (round-robin output distribution), Junction (4-directional pass-through), Tunnel (linked input/output pair with multi-phase placement).

**Unified pull system** — All item transfers go through `GameManager.pull_item()`. No direct pushing. ConveyorSystem processes all conveyors per physics frame.

**Save/Load** — 3 account slots, JSON autosave every 60s with backup rotation, per-building state serialization (buffers, inventories, timers, linked buildings). Building hotkeys persisted per slot.

**UI** — HUD with speed controls, currency display, item delivery counter, buildings panel, minimap, building hotkeys. Building info panel on click. Pause menu. Main menu with Continue/New Game.

**Tests** — Custom test framework with 7 simulations: conveyor_transport, unified_pull, drill_extractor, smelter_converter, merge_and_source_sink, junction, splitter.

---

## Remaining Steps

### Step 14: All Raw Resources, Recipes & Converters `[ ]`

**Goal:** Add all remaining resource types, recipes, converter buildings, and source types from `docs/design.md`. The full production tree is playable.

**What to build:**

Items (create `.tres` in `resources/items/`):
- Raw: quartz_sand, water, oil (iron_ore, copper_ore, coal already exist)
- Intermediate: copper_wire, steel, glass, circuit, plastic (iron_plate already exists)
- Advanced: processor, battery, engine, solar_panel

Recipes (create `.tres` in `resources/recipes/`, smelt_iron already exists):
- Smelter: draw_copper_wire (1 copper_ore → 2 copper_wire, 3s), forge_steel (1 iron_plate + 1 coal → 1 steel, 4s), melt_glass (2 quartz_sand → 1 glass, 4s)
- Chemical Plant: refine_plastic (2 oil → 1 plastic, 5s)
- Assembler: make_circuit (2 copper_wire + 1 glass → 1 circuit, 5s), make_processor (2 circuit + 1 steel → 1 processor, 8s), make_battery (1 copper_wire + 1 plastic + 1 coal → 1 battery, 6s)
- Advanced Factory: build_engine (2 steel + 1 circuit + 1 plastic → 1 engine, 10s), build_solar_panel (2 glass + 1 circuit + 1 steel → 1 solar_panel, 10s)

New buildings (create scene + `.tres` in `buildings/`):
- Assembler (3x3): 2 input sides, 1 output side
- Chemical Plant (3x3): 2 input sides, 1-2 output sides
- Advanced Factory (4x4): 3 input sides, 1-2 output sides
- Dredger (extractor for sand pits)
- Pump (extractor for water wells)
- Pumpjack (extractor for oil geysers)

New source tiles on the TileMapLayer: sand pit, water well, oil geyser.

**Existing patterns to follow:**
- Items: copy `resources/items/iron_ore.tres` structure
- Recipes: copy `resources/recipes/smelt_iron.tres` structure, set `converter_type` to match building
- Buildings: follow `buildings/smelter/` pattern — scene with Shape/Inputs/Outputs marker nodes, BuildingDef `.tres` referencing the scene
- Extractors: follow `buildings/drill/` pattern — `extractor.gd` logic, placed on matching source tiles
- The converter logic (`buildings/smelter/converter.gd`) already supports multiple inputs/outputs and round-robin pulling — new converters reuse it, just with different scene layouts and recipes

**What you see when launched:** Map has all source types. Full recipe chains are buildable: ore → plate → steel → processor, etc. All converters work.

---

### Step 15: Tech Tree & Research Lab `[ ]`

**Goal:** Research lab sink that unlocks new buildings and recipes via the tech tree.

**What to build:**
- Tech tree data structure (directed graph as custom resource)
- Research lab building: accepts specific items, fills progress toward tech nodes
- Tech tree viewer UI: shows nodes, connections, costs, and unlock status
- Buildings/recipes locked behind tech nodes are hidden from build menu until unlocked
- Starting unlocks: drill, basic conveyor, smelter, export terminal
- `BuildingDef` already has an `unlock_tech` field — use it to gate visibility

**What you see when launched:** Only basic buildings available at start. Deliver items to research lab → unlock new buildings. Tech tree UI shows progress.

---

### Step 16: Campaign Levels & Sandbox `[ ]`

**Goal:** Multiple maps with different source layouts. Campaign is a linear sequence of levels with missions. Sandbox is a large open map.

**What to build:**
- Level data format: which sources are where, mission objectives
- 3 campaign levels with increasing complexity
- Mission objective system: "deliver X of item Y" as win condition
- Level complete screen with stats
- Sandbox mode: large map with all source types scattered
- Level select in main menu (unlocked levels only)

**What you see when launched:** Campaign with 3 levels. Each has objectives to complete. Sandbox mode available for free play.

---

### Step 17: Audio, Animations & Visual Polish `[ ]`

**Goal:** The game feels alive with sound effects, animations, and visual feedback.

**What to build:**
- Conveyor belt animation (scrolling texture or arrow animation)
- Building placement/removal sound effects
- Crafting sounds on converters
- Item pickup/delivery sounds
- Ambient background music (or tone)
- Particle effects: drill sparks, smelter glow, export terminal flash
- Smooth camera transitions
- Building hover highlight

**What you see when launched:** The factory feels alive — belts animate, machines hum, items clink, and the world has ambient sound.
