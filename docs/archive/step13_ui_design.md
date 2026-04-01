# Step 13: HUD Polish & Info Panels — UI Design

## Overview

Major HUD rework: categorized building selector, explicit building mode toggle, minimap, time speed controls, building info panel, and delivery counter. All UI defined in `.tscn` scenes; scripts only handle logic, signal connections, and data binding.

---

## HUD Layout Overview

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│  DeliveryPanel (top-right)                           │
│  ┌──────────┐                                        │
│  │Deliveries│                                        │
│  │Points: 42│                                        │
│  │ • Iron: 5│                                        │
│  └──────────┘                                        │
│                                                      │
│                    GAME WORLD                        │
│                                                      │
│                                                      │
│                          TimeSpeed (bottom-right)    │
│                          ┌─────────┐                 │
│                          │ [-] x1 [+] │              │
│                          ├─────────┤                 │
│                          │ Minimap │                 │
│                          │  160x160│                 │
│                          ├─────────┤                 │
│                          │[Buildings]│               │
│                          └─────────┘                 │
└──────────────────────────────────────────────────────┘
```

---

## 1. Building Mode

**Concept:** The player is NOT in building mode by default. Clicks on the ground do nothing. No blueprint ghost is shown. The player must explicitly enter building mode.

**Entering building mode:**
- Press **B** — enters building mode with the last selected building (defaults to Conveyor if nothing was ever selected)
- Press a **building hotkey** (user-assigned, see Buildings Panel §3) — selects that building and enters building mode
- Click a building in the **Buildings Panel** — selects it and enters building mode

**While in building mode:**
- Blueprint ghost follows cursor (existing behavior)
- LMB places buildings (existing behavior)
- **RMB exits building mode** (returns to default/inspect mode)
- R rotates placement ghost (existing behavior)

**While NOT in building mode (inspect mode):**
- LMB on a placed building → opens Building Info Panel (§2)
- LMB on empty ground → nothing
- RMB on a placed building → removes it (existing behavior)

**Implementation:**
- `BuildSystem` gets a `var building_mode: bool = false`
- `enter_building_mode(building_id: StringName)` — sets `building_mode = true`, `selected_building = building_id`
- `exit_building_mode()` — sets `building_mode = false`, clears ghost
- Input mapping: `build_mode_toggle` → B key, `build_mode_exit` → already handled by RMB context

**Changes to `build_system.gd`:**
- LMB when `building_mode == false`: raycast to building under cursor → emit `building_clicked(building_node)` signal
- LMB when `building_mode == true`: place building (existing)
- RMB when `building_mode == true`: call `exit_building_mode()` instead of removing
- RMB when `building_mode == false`: remove building under cursor (existing)

---

## 2. Building Info Panel

**Purpose:** Click a placed building (while NOT in building mode) to see its stats, current state, and recipe info.

**Trigger:** LMB on a placed building in inspect mode. Click elsewhere or press ESC to dismiss.

**Scene:** `scenes/ui/building_info_panel.tscn`

**Layout:**
```
PanelContainer (right side of screen, 280px wide, anchored top-right below DeliveryPanel)
├── MarginContainer (8px margins)
│   └── VBoxContainer
│       ├── Header (HBoxContainer)
│       │   ├── ColorRect (24x24, building color)
│       │   └── Label (building display_name, font 18, bold)
│       ├── HSeparator
│       ├── TypeLabel ("Extractor" / "Conveyor" / "Converter" / "Sink")
│       ├── HSeparator
│       ├── StatsSection (VBoxContainer)
│       │   └── [per building type — see below]
│       └── RecipeSection (VBoxContainer, visible only for converters)
│           ├── Label ("Recipe: Smelt Iron")
│           ├── InputsRow (HBoxContainer)
│           │   └── [ColorRect dot + "1x Iron Ore"] per input
│           ├── Label ("→")
│           └── OutputsRow (HBoxContainer)
│               └── [ColorRect dot + "1x Iron Plate"] per output
```

**Per-Building-Type Stats:**

| Building | Stats Shown |
|----------|-------------|
| Conveyor | Items on belt: 1/2, Direction: Right |
| Drill | Extracting: Iron Ore, Progress: [ProgressBar], Inventory: 2/5 |
| Smelter | Recipe: Smelt Iron, Craft progress: [ProgressBar], Input buffer: 1x Iron Ore, Output buffer: 0x Iron Plate |
| Sink | Items consumed: 47 |
| Source | Producing: Iron Ore, Rate: 1/s |

**Data Sources:**
- Building node from `GameManager.buildings[grid_pos]`
- Type-specific logic via `.get_meta("conveyor")`, `.get_meta("extractor")`, `.get_meta("converter")`, `.get_meta("sink")`
- Stats update every 0.25s via a Timer while panel is visible

**Script:** `scripts/ui/building_info_panel.gd`
- `show_building(building_node: Node2D)` — populates all fields, shows panel
- `hide_panel()` — hides
- `_update_stats()` — refreshes live data (progress bars, counts)

---

## 3. Buildings Panel

**Purpose:** Categorized building selector. Replaces the old bottom toolbar. Opened via the "Buildings" button in the bottom-right button group.

**Trigger:** Click the "Buildings" button (bottom-right, next to minimap). Click again or press ESC to close.

**Scene:** `scenes/ui/buildings_panel.tscn`

**Layout:**
```
PanelContainer (opens upward from the Buildings button, anchored bottom-right, 320px wide)
├── MarginContainer (8px)
│   └── VBoxContainer
│       ├── Header (Label, "Buildings", font 16, bold)
│       ├── HSeparator
│       │
│       ├── CategorySection "Transportation"
│       │   ├── CategoryLabel ("Transportation", font 13, bold, dim color)
│       │   └── BuildingGrid (GridContainer, 2-3 columns)
│       │       └── [BuildingCard] (PanelContainer, ~100x80)
│       │           └── VBoxContainer
│       │               ├── ColorRect (32x32, building color)
│       │               ├── Label (name, font 11)
│       │               └── HotkeyLabel ("[ ]" or "[1]", font 10, dim)
│       │
│       ├── CategorySection "Extractors"
│       │   ├── CategoryLabel ("Extractors", font 13, bold, dim color)
│       │   └── BuildingGrid (GridContainer)
│       │       └── [BuildingCard] ...
│       │
│       └── CategorySection "Converters"
│           ├── CategoryLabel ("Converters", font 13, bold, dim color)
│           └── BuildingGrid (GridContainer)
│               └── [BuildingCard] ...
```

**Current categories and buildings:**

| Category | Buildings |
|----------|-----------|
| Transportation | Conveyor |
| Extractors | Drill |
| Converters | Smelter |

Categories map to `BuildingDef.category`:
- `"conveyor"` → Transportation
- `"extractor"` → Extractors
- `"converter"` → Converters
- `"sink"` → (future: Logistics or Outputs)

**Hover behavior:**
When the mouse hovers over a BuildingCard, a tooltip/info area appears (either inline at the bottom of the panel or as a side popup) showing:
```
┌─────────────────────────┐
│ Smelter                 │
│ Category: Converter     │
│ Size: 2x3               │
│                         │
│ Processes raw ores into │
│ refined materials.      │
│                         │
│ Recipes:                │
│  • Smelt Iron (3s)      │
│    1x Iron Ore → 1x Iron Plate │
│                         │
│ Hotkey: [none]          │
│ (RMB to assign hotkey)  │
└─────────────────────────┘
```

The hover info shows:
- Building name, category, size
- Description (from `BuildingDef.description`)
- Recipes this building can process (for converters, from `GameManager.recipes_by_type`)
- Current hotkey assignment (or "none")
- Hint to RMB for hotkey assignment

**LMB on a BuildingCard:**
- Selects the building for placement
- Enters building mode (closes the Buildings Panel)
- `BuildSystem.enter_building_mode(building_id)`

**RMB on a BuildingCard:**
- Opens a small popup: "Assign hotkey: press a key (0-9, F1-F4)"
- Waits for next key press, then saves the mapping
- Mapping stored in `GameManager.building_hotkeys: Dictionary` (key_scancode → building_id)
- The HotkeyLabel on the card updates to show the assigned key
- Hotkey mappings persist via SaveManager

**Script:** `scripts/ui/buildings_panel.gd`
- `_ready()` — populates categories from `GameManager.building_defs`
- `_on_building_hovered(building_id)` — shows hover info
- `_on_building_clicked(building_id)` — selects + enters building mode
- `_on_building_rmb(building_id)` — opens hotkey assignment popup

---

## 4. Resource Delivery Counter

**Purpose:** Show a running tally of items delivered to sinks, broken down by type.

**Location:** Top-right corner of HUD.

**Scene:** Added as a section in `scenes/ui/hud.tscn`

**Layout:**
```
DeliveryPanel (PanelContainer, top-right, 200px wide)
├── MarginContainer (6px)
│   └── VBoxContainer
│       ├── Label ("Deliveries", font 14, bold)
│       ├── HSeparator
│       ├── CurrencyRow (HBoxContainer)
│       │   ├── Label ("Points:")
│       │   └── CurrencyLabel ("0", right-aligned)
│       ├── HSeparator
│       └── ItemList (VBoxContainer)
│           └── [ItemRow per delivered type] (HBoxContainer)
│               ├── ColorRect (12x12, item color)
│               ├── Label (item display_name)
│               └── Label (count, right-aligned)
```

**Data Source:**
- New `items_delivered: Dictionary` in GameManager (item_id → count)
- Updated by `ItemSink` when it consumes an item
- `total_currency` already exists in GameManager

**Behavior:**
- Only shows item types that have been delivered at least once
- Updates every 0.5s via Timer
- Rows sorted by count (highest first)

**Script:** Logic added to `scripts/ui/hud.gd`
- `_update_delivery_counter()` — reads `GameManager.items_delivered`, populates rows

---

## 5. Minimap

**Purpose:** Small overview in the bottom-right corner showing all placed buildings as colored dots on a dark background.

**Location:** Bottom-right corner of HUD, above the "Buildings" button.

**Scene:** Added as a section in `scenes/ui/hud.tscn`

**Layout:**
```
MinimapPanel (PanelContainer, bottom-right, 160x160)
└── MinimapDisplay (Control with custom _draw())
```

**What gets drawn in `_draw()`:**
1. Dark background rect (the map area)
2. Deposit tiles as dim colored dots (from `GameManager.deposits`)
3. Each placed building as a small colored rect (2-3px per tile, building color from BuildingDef)
4. Camera viewport as a white outline rectangle showing current view area
5. Clicking on minimap moves camera to that position

**Scale:** 64-tile map → 160px display = 2.5px per tile.

**Data Source:**
- `GameManager.buildings` — all placed buildings with grid positions
- `GameManager.building_defs` — colors per building type
- `GameManager.deposits` — deposit locations
- Camera position from the game world's Camera2D node

**Update:** Redraws every 1.0s via Timer (buildings don't move). Camera rect updates every frame via `queue_redraw()` in `_process()`.

**Script:** `scripts/ui/minimap.gd`
- `_draw()` — renders all elements
- `_process()` — updates camera rect, triggers redraw only if camera moved
- `_gui_input()` — click-to-pan camera

---

## 6. Time Speed Controls

**Purpose:** Let the player speed up, slow down, or pause the simulation.

**Location:** Bottom-right, directly above the minimap.

**Speed steps:** `[0.25, 0.5, 1.0, 1.5, 2.0, 3.0]`

**Default:** `x1` (index 2)

**Scene:** Added as a section in `scenes/ui/hud.tscn`

**Layout:**
```
TimeSpeedPanel (HBoxContainer, bottom-right, above minimap)
├── SlowButton (Button, "−", 28x28)
├── SpeedLabel (Label, "x1", font 14, min_width 48, center-aligned)
└── FastButton (Button, "+", 28x28)
```

When paused, the SpeedLabel changes to `"▮▮"` (pause icon) or `"PAUSED"` with a distinct color (e.g., yellow text).

**Hotkeys:**

| Key | Action |
|-----|--------|
| `=` (plus key) | Increase speed one step |
| `-` (minus key) | Decrease speed one step |
| `Space` | Toggle pause. When unpausing, speed restores to what it was before pausing |

**Implementation:**
- Speed is applied via `Engine.time_scale`
- Pausing sets `Engine.time_scale = 0.0` (NOT `get_tree().paused` — that would block UI)
- Unpausing via Space restores `Engine.time_scale` to the pre-pause speed
- Increase/decrease while paused: updates the stored speed but stays paused
- Speed steps stored as `const SPEED_STEPS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0]`
- Current index tracked in script: `var speed_index: int = 2`
- Paused state tracked separately: `var paused: bool = false`

**Clamping:** Cannot decrease below x0.25 or increase above x3. Buttons visually dim at limits.

**Script:** Logic in `scripts/ui/hud.gd`
- `_set_speed(index: int)` — updates `Engine.time_scale`, updates label
- `_toggle_pause()` — toggles pause, resets to x1 on unpause
- `_on_slow_pressed()` / `_on_fast_pressed()` — step speed down/up
- Input actions: `time_speed_up` → `=`, `time_speed_down` → `-`, `time_pause` → `Space`

**Save/Load:** Current speed index and paused state saved in run save file.

---

## Bottom-Right Button Group

**Purpose:** Main UI action buttons, grouped vertically above the minimap in the bottom-right corner.

**Current buttons (just one for now):**

```
BottomRightPanel (VBoxContainer, bottom-right)
├── TimeSpeedPanel (HBoxContainer)
│   ├── SlowButton (Button, "−")
│   ├── SpeedLabel (Label, "x1")
│   └── FastButton (Button, "+")
├── MinimapPanel (160x160)
└── ButtonGroup (VBoxContainer)
    └── BuildingsButton (Button, "Buildings", 160x40)
```

**Future:** More buttons can be added to `ButtonGroup` (e.g., "Research", "Stats").

---

## Visual Style Notes

- **Panel backgrounds:** Slightly transparent dark gray (`Color(0.12, 0.12, 0.14, 0.9)`)
- **Text color:** White/light gray
- **Separators:** Thin lines, subtle gray
- **Item color dots:** Small ColorRects matching `ItemDef.color`
- **Building color squares:** Small ColorRects matching `BuildingDef.color`
- **Font sizes:** Headers 16-18, body 14, small labels 11-12
- **Consistent 6-8px margins** inside panels
- **No drop shadows or gradients** — flat style matching the game
- **Paused label:** Yellow/amber text to stand out
- **Hotkey labels:** Dim gray text, brackets around key name

---

## Interaction Summary

| Action | Context | Result |
|--------|---------|--------|
| LMB on placed building | Inspect mode | Building Info Panel opens |
| LMB on empty ground | Inspect mode | Nothing (dismiss info panel if open) |
| RMB on placed building | Inspect mode | Remove building |
| LMB drag | Building mode | Place buildings |
| RMB | Building mode | Exit building mode |
| R | Building mode | Rotate placement ghost |
| B | Any | Enter building mode with last building |
| Building hotkey (e.g. 1) | Any | Select that building + enter building mode |
| ESC | Building mode | Exit building mode |
| ESC | Info panel open | Close info panel |
| Click "Buildings" button | Any | Toggle buildings panel |
| LMB on building card | Buildings panel | Select building + enter building mode |
| RMB on building card | Buildings panel | Open hotkey assignment popup |
| Hover building card | Buildings panel | Show building info/recipes |
| `=` | Any | Increase time speed |
| `-` | Any | Decrease time speed |
| Space | Any | Toggle pause (unpause restores previous speed) |
| Click minimap | Any | Pan camera to that position |

---

## GameManager Changes Required

```gdscript
# New properties:
var items_delivered: Dictionary = {}       # item_id (StringName) -> int count
var building_hotkeys: Dictionary = {}      # key_scancode (int) -> building_id (StringName)
var last_selected_building: StringName = &"conveyor"  # for B key

# New method — called by ItemSink:
func record_delivery(item_id: StringName) -> void:
    if item_id not in items_delivered:
        items_delivered[item_id] = 0
    items_delivered[item_id] += 1
```

## BuildingDef Changes Required

```gdscript
# New export:
@export var description: String = ""  # hover description text
```

---

## New Files

| File | Type |
|------|------|
| `scenes/ui/building_info_panel.tscn` | Scene |
| `scripts/ui/building_info_panel.gd` | Script |
| `scenes/ui/buildings_panel.tscn` | Scene |
| `scripts/ui/buildings_panel.gd` | Script |
| `scripts/ui/minimap.gd` | Script |

## Modified Files

| File | Change |
|------|--------|
| `scenes/ui/hud.tscn` | Replace toolbar with bottom-right layout: ButtonGroup, MinimapPanel, TimeSpeedPanel, DeliveryPanel |
| `scripts/ui/hud.gd` | Delivery counter, time speed logic, buildings panel toggle, hotkey input handling |
| `scripts/autoload/game_manager.gd` | Add `items_delivered`, `building_hotkeys`, `last_selected_building`, `record_delivery()` |
| `buildings/shared/building_def.gd` | Add `description` export |
| `buildings/sink/sink.gd` | Call `GameManager.record_delivery()` on consume |
| `scripts/game/build_system.gd` | Add `building_mode` flag, `enter_building_mode()`, `exit_building_mode()`, building click detection in inspect mode |
| `project.godot` | Add input actions: `build_mode_toggle`, `time_speed_up`, `time_speed_down`, `time_pause` |
