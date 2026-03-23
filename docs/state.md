# Factor — Implementation State

## Message to Next Claude

Read `docs/design.md` and `docs/implementation_details.md` for full game design and architecture specs. Read `CLAUDE.md` for quick reference. This file tracks implementation progress — check which step is current, read its description, and implement it. After completing a step, mark it `[x]` and tell the user to launch the game to verify. Do NOT skip ahead to future steps.

The game is a Godot 4.5 project. All scripts use GDScript. Visual style is flat/geometric with colored rectangles and simple shapes — no external art assets needed. Use `32x32` tile size throughout.

---

## Implementation Plan

### Step 1: Project Skeleton & Launchable Window `[x]`

**Goal:** Game launches and shows a colored background with a title label. Establishes the main scene and project settings.

**What to build:**
- Set main scene in `project.godot` to `scenes/ui/main_menu.tscn`
- Create `scenes/ui/main_menu.tscn` — a Control scene with:
  - Dark background (ColorRect filling the screen)
  - "Factor" title label centered, large font
  - "Start Game" button (non-functional yet, just visible)
  - "Quit" button that calls `get_tree().quit()`
- Create `scripts/ui/main_menu.gd` with button signal connections
- Set window size to 1280x720 in project settings

**What you see when launched:** A dark screen with "Factor" title and two buttons. Quit works. Start Game does nothing yet.

---

### Step 2: Game World with TileMap Grid & Camera `[x]`

**Goal:** Clicking "Start Game" transitions to a game world scene with a visible tile grid and a camera the player can pan and zoom.

**What to build:**
- Create `scenes/game/game_world.tscn` with:
  - `Camera2D` with zoom (scroll wheel) and pan (middle-mouse drag or WASD)
  - `TileMapLayer` with a simple tileset (programmatic — colored squares for ground)
  - `BuildingLayer` (empty Node2D)
  - `ItemLayer` (empty Node2D)
  - `UI` (CanvasLayer, empty for now)
- Create `scripts/game/game_world.gd` — camera controls
- Wire "Start Game" button to `change_scene_to_file("res://scenes/game/game_world.tscn")`
- Add ESC key to return to main menu

**What you see when launched:** Click Start Game → a green/brown tiled grid. WASD/arrow keys pan. Scroll zooms. ESC returns to menu.

---

### Step 3: Grid Cursor & Building Placement Ghost `[x]`

**Goal:** Mouse cursor snaps to the grid. Player can select a "building" and see a placement ghost that follows the cursor. Click to place a colored rectangle on the grid. Right-click to remove.

**What to build:**
- Create `scripts/game/build_system.gd` — handles placement logic:
  - Grid-snapped cursor highlight (semi-transparent square following mouse)
  - Left-click places a building (stored in a Dictionary keyed by `Vector2i`)
  - Right-click removes a building
  - Placement validation (can't overlap)
- Create `scripts/buildings/building_base.gd` — base class with `grid_pos`, `rotation`, `building_id`
- For now, only one building type: a 1x1 colored square (placeholder)
- Visual: each placed building is a `ColorRect` or `Sprite2D` added to `BuildingLayer`

**What you see when launched:** A grid cursor follows the mouse. Click to stamp colored squares on the grid. Right-click to remove them.

---

### Step 4: Resource Definitions & Data Layer `[x]`

**Goal:** Define the custom Resource classes (ItemDef, RecipeDef, BuildingDef) and create `.tres` files for raw resources and the Drill extractor. Register GameManager autoload.

**What to build:**
- Create `scripts/resources/item_def.gd` (class_name ItemDef)
- Create `scripts/resources/recipe_def.gd` (class_name RecipeDef)
- Create `scripts/resources/building_def.gd` (class_name BuildingDef)
- Create `.tres` resource files for: iron_ore, copper_ore, coal (just 3 to start)
- Create `.tres` for BuildingDef: drill, conveyor, smelter
- Create `scripts/autoload/game_manager.gd` — registered as autoload, holds:
  - `buildings: Dictionary` (grid_pos -> building node)
  - `place_building()` / `remove_building()` API
  - Building registry: loads all BuildingDef resources at startup
- Refactor Step 3's placement system to use GameManager and BuildingDef

**What you see when launched:** Same as before visually, but now placement uses the data-driven system. Buildings are placed via GameManager. No new visual features, but the architecture is in place.

---

### Step 5: Build Menu & Multiple Building Types `[x]`

**Goal:** A bottom toolbar shows available buildings. Player clicks a building to select it, then places it on the grid. Each building type has a distinct color and size.

**What to build:**
- Create `scenes/ui/hud.tscn` with a bottom `HBoxContainer` toolbar
- Create `scripts/ui/hud.gd` — populates toolbar from GameManager's building registry
- Each toolbar button shows building name and colored icon
- Selected building type determines what gets placed
- Buildings render as colored rectangles matching their size (1x1, 2x2, 3x3)
- Drill = gray, Conveyor = yellow, Smelter = orange (2x2)
- Add rotation support: R key rotates placement ghost by 90°

**What you see when launched:** Bottom bar with building buttons. Select Drill/Conveyor/Smelter, place them on the grid as colored rectangles of appropriate size. R rotates.

---

### Step 6: Conveyor System — Items Moving on Belts `[x]`

**Goal:** Conveyors are directional 1x1 tiles. Items placed on them (manually or from code) visually slide to the next conveyor in the chain.

**What to build:**
- Create `scripts/buildings/conveyor.gd`:
  - Has a direction (based on rotation)
  - Holds 0-N items
  - Each tick: if holding an item and next tile is a conveyor with not max capacity, transfer it
- Create `scripts/game/conveyor_system.gd` — processes all conveyors each physics frame
- Items on conveyors rendered as small colored circles on the ItemLayer
- Arrow indicator on each conveyor showing direction
- For testing: a debug key (e.g., T) spawns a test item on the conveyor under the cursor

**What you see when launched:** Place a chain of conveyors, press T to spawn an item, watch it slide along the belt chain. Items stop at the end or if blocked.

---

### Step 7: Sources & Extractors `[x]`

**Goal:** The map has source deposits (special tiles). Placing a Drill on a deposit makes it produce items onto adjacent conveyors.

**What to build:**
- Add source tiles to the TileMap: iron deposit (dark gray), copper deposit (orange), coal seam (black)
  - Place several deposits on the default map
- Create `scripts/buildings/extractor.gd`:
  - Checks if placed on a valid source tile
  - Timer-based production: every N seconds, creates an item
  - Pushes item onto the adjacent conveyor (based on output direction)
  - If no conveyor or conveyor full, waits
- Drill only placeable on deposit tiles (validation in build system)
- Show a small progress bar or pulse animation on the drill while producing

**What you see when launched:** Map has colored deposit patches. Place a drill on iron deposit, attach conveyors — iron ore items flow out automatically.

---

### Step 8: Converters — Smelter Processing `[x]`

**Goal:** Smelters pull items from input conveyors, process them over time, and push results onto output conveyors.

**What to build:**
- Create `scripts/buildings/converter.gd`:
  - Has input side(s) and output side(s) based on rotation
  - Pulls items from adjacent input conveyors into input buffer
  - When buffer satisfies a recipe, starts crafting timer
  - On craft complete, pushes output items to output conveyor
  - Pauses if output is blocked
- Create recipe `.tres` files: smelt_iron (iron_ore → iron_plate)
- The output points (multiple potentially) must be placed in tres file as anchor dots.
- Smelter has 1 input side, 1 output side, 2x3 size and one central square missing from its shape - the output goes there and only conveyors leading out of the buildings can get it
- Visual: show craft progress bar on the converter

**What you see when launched:** Drill → conveyor chain → smelter → output conveyor. Iron ore flows in, iron plates flow out. Progress bar visible during crafting.

---

### Step 9: Sinks — Export Terminal `[ ]`

**Goal:** Export terminals consume any item from adjacent conveyors and award points. A counter shows total points earned.

**What to build:**
- Create `scripts/buildings/sink.gd`:
  - Pulls items from all adjacent input conveyors
  - Adds export value to a running total in GameManager
  - Never blocks (infinite capacity)
- Create BuildingDef `.tres` for export_terminal
- Add points counter to HUD (top-right corner)
- GameManager tracks `total_currency: int`

**What you see when launched:** Full chain: Drill → conveyors → smelter → conveyors → export terminal. Points tick up in the HUD as iron plates are delivered.

---

### Step 10: All Raw Resources, Recipes & Converters `[ ]`

**Goal:** Add all remaining resource types, recipes, converter buildings, and source types from the design doc. The full production tree is playable.

**What to build:**
- All 6 raw resource ItemDef `.tres` files
- All intermediate + advanced ItemDef `.tres` files (10 total)
- All recipe `.tres` files (10 recipes)
- BuildingDef + scenes for: assembler (3x3), chemical_plant (3x3), advanced_factory (4x4)
- Source tiles for: sand pit, water well, oil geyser
- Extractor buildings: dredger, pump, pumpjack
- Each converter/extractor has distinct color

**What you see when launched:** Map has all source types. Full recipe chains are buildable: ore → plate → steel → processor, etc. All converters work.

---

### Step 11: Special Conveyor Buildings `[ ]`

**Goal:** Add splitter, merger, and bridge for more complex logistics.

**What to build:**
- Splitter: 1 input, 2-3 outputs, round-robin distribution
- Merger: 2-3 inputs, 1 output, round-robin intake
- Bridge: tunnels items over 1-4 tiles, skipping obstacles
- Each has distinct visual shape/color on the grid

**What you see when launched:** Can build complex conveyor networks with splits, merges, and crossings.

---

### Step 12: Main Menu, Save/Load System `[ ]`

**Goal:** Full main menu with Continue/New Run. Game state saves and loads from JSON files.

**What to build:**
- `scripts/autoload/save_manager.gd` — full implementation per design doc
- `scripts/autoload/account_manager.gd` — 3 account slots
- Main menu: Continue button (loads autosave), Start New Run (fresh game)
- Autosave every 60s during gameplay
- Pause menu (ESC) with Resume, Save, Quit to Menu
- Save/load all buildings, items on conveyors, currency, camera position

**What you see when launched:** Can start a new game, build a factory, quit to menu, continue and find everything preserved. Account slots work.

---

### Step 13: HUD Polish & Info Panels `[ ]`

**Goal:** Rich HUD with resource counts, building info on hover/click, recipe viewer, and minimap.

**What to build:**
- Building info panel: click a placed building to see its stats, recipe, throughput
- Resource delivery counter: items delivered per type
- Recipe browser: UI panel showing all unlocked recipes and their chains
- Minimap in corner showing building layout overview
- Tooltip on toolbar buttons showing building details

**What you see when launched:** Click buildings to see info. Recipe browser helps plan layouts. Minimap shows factory overview.

---

### Step 14: Tech Tree & Research Lab `[ ]`

**Goal:** Research lab sink that unlocks new buildings and recipes via the tech tree.

**What to build:**
- Tech tree data structure (directed graph as resource)
- Research lab building: accepts specific items, fills progress toward tech nodes
- Tech tree viewer UI: shows nodes, connections, costs, and unlock status
- Buildings/recipes locked behind tech nodes are hidden from build menu until unlocked
- Starting unlocks: drill, basic conveyor, smelter, export terminal

**What you see when launched:** Only basic buildings available at start. Deliver items to research lab → unlock new buildings. Tech tree UI shows progress.

---

### Step 15: Campaign Levels & Sandbox `[ ]`

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

### Step 16: Audio, Animations & Visual Polish `[ ]`

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
