# Bad Design & Technical Debt (Audit 2)

Comprehensive audit of architectural inconsistencies, code duplication, and logic problems that slow down development.

---

## CRITICAL — Must fix before adding more content

### 1. Pipeline is a copy-paste of Tunnel (262 duplicated lines)

**Files:** `buildings/tunnel/tunnel.gd` vs `buildings/pipeline/pipeline.gd`

99% identical code. Only differences:
- `max_tunnel_gap`: 4 vs 9
- Category check in `configure()`: `"tunnel"` vs `"pipeline"`
- Pipeline confusingly uses `"tunnel_buffer"` key in serialization

Every bug fix or enhancement must be manually copied between files.

**Solution:** Create `UndergroundTransportLogic` base class:
```gdscript
# buildings/shared/underground_transport_logic.gd
class_name UndergroundTransportLogic
extends BuildingLogic

@export var max_gap: int = 4  # Override in .tres: tunnel=4, pipeline=9

# Move ALL shared logic here (configure, setup_pair, _physics_process,
# _advance_items, pull interface, serialization, visuals, etc.)
```
Then `TunnelLogic` and `PipelineLogic` become empty subclasses (or just use the base class directly with different `.tres` config).

---

### 2. GameManager is a god object (~650 lines, 10+ domains)

GameManager handles: world state, item definitions/caching, building registry, building placement, conveyor integration, energy integration, pull system, currency, hotkeys, creative mode, item icons.

Key problems:
- `place_building()` is 92 lines mixing validation, scene instantiation, system registration, collision, and conveyor sprite updates
- Pull system (`pull_item`, `peek_output_item`) lives in GameManager but logically belongs in ConveyorSystem
- Type-checks like `if logic is ConveyorBelt` (line ~409) break the interface-based design
- `unique_buildings` array must stay manually in sync with `buildings` dict — fragile
- UI concerns (hiding ConveyorSprite nodes, finding "Rotatable" children) live in game logic

**Solution:** Extract into focused classes over time:
1. **Move pull system to ConveyorSystem** — it already processes conveyors, let it own `pull_item()` / `peek_output_item()` too
2. **Extract `ItemDatabase`** — move `_item_def_cache`, `_item_icon_cache`, `_all_item_defs`, `get_item_def()`, `get_item_icon()`, `get_all_item_defs()`
3. **Derive `unique_buildings` on demand** instead of maintaining a separate list:
   ```gdscript
   func get_unique_buildings() -> Array:
       var seen := {}
       var result := []
       for b in buildings.values():
           var id := b.get_instance_id()
           if not seen.has(id):
               seen[id] = true
               result.append(b)
       return result
   ```
4. **Move visual concerns out of `place_building()`** — conveyor sprite hiding, "Rotatable" node lookups, etc. should be in ConveyorVisualManager or BuildingBase

---

### 3. Tile constants duplicated between game_world.gd and world_generator.gd

Both files define identical sets of:
- `TILE_GROUND`, `TILE_IRON`, `TILE_COPPER`, ... `TILE_WALL` (15+ constants)
- `DEPOSIT_ITEMS` dictionary mapping tile IDs to item IDs
- `WALL_ITEMS`, `WALL_NAMES` dictionaries

Adding a new resource type requires updating both files. Miss one → silent bugs.

**Solution:** Create a single `TileDatabase` autoload or const script:
```gdscript
# scripts/tile_database.gd
class_name TileDatabase

const TILE_GROUND := 0
const TILE_IRON := 1
# ... all constants ...

const DEPOSIT_ITEMS := {
    TILE_IRON: &"iron_ore",
    # ...
}
const WALL_ITEMS := { ... }
const WALL_NAMES := { ... }
const TILE_COLORS := { ... }  # Currently in game_world.gd only
```
Then both `game_world.gd` and `world_generator.gd` reference `TileDatabase.*`.

---

### 4. Inventory serialization duplicated in 5+ buildings

Identical pattern (serialize inventory to dict, deserialize with item validation and capacity fallback) copy-pasted in:
- `converter.gd` (lines ~327-343)
- `extractor.gd` (lines ~75-94)
- `coal_burner_logic.gd` (lines ~102-131)
- `research_lab_logic.gd` (lines ~208-224)
- `borer_logic.gd` (lines ~77-96)

**Solution:** Add helpers to `Inventory` class:
```gdscript
# scripts/inventory.gd
func serialize() -> Dictionary:
    var data := {}
    for iid in get_item_ids():
        data[str(iid)] = get_count(iid)
    return data

func deserialize(data: Dictionary) -> void:
    for item_id_str in data:
        var iid := StringName(item_id_str)
        if not GameManager.is_valid_item_id(iid):
            GameLogger.warn("Skipped invalid item '%s'" % iid)
            continue
        var count: int = int(data[item_id_str])
        if get_capacity(iid) == 0:
            set_capacity(iid, count + 10)
        for i in count:
            add(iid)
```
Then each building just calls `input_inv.serialize()` / `input_inv.deserialize(state["inventory"])`.

---

## HIGH — Causes friction when adding features

### 5. Slot billet creation duplicated between building_popup.gd and recipe_menu.gd

`_create_slot_billet()` and `_create_empty_billet()` are identical (~50 lines each) in both files. Column width computation (`_compute_column_widths`) is also nearly identical.

**Solution:** Extract to a shared `RecipeRowFactory` utility:
```gdscript
# scripts/ui/recipe_row_factory.gd
class_name RecipeRowFactory

static func create_slot_billet(num_text: String, num_w: float, icon: Control, font_size: int) -> PanelContainer:
    # ... shared implementation ...

static func create_empty_billet(num_w: float, icon_size: Vector2, font_size: int) -> PanelContainer:
    # ... shared implementation ...

static func compute_column_widths(recipes: Array, font: Font, font_size: int, icon_w: float) -> Dictionary:
    # ... shared implementation ...
```

---

### 6. StyleBoxFlat boilerplate repeated 40+ times across UI

Every UI file creates StyleBoxFlat inline with identical margin/corner patterns. Example appears in building_popup.gd, recipe_menu.gd, recipe_browser.gd, buildings_panel.gd, source_item_menu.gd, inventory_panel.gd.

**Solution:** Create a `UIStyles` const script:
```gdscript
# scripts/ui/ui_styles.gd
class_name UIStyles

static func slot_panel(bg_color := Color(0.08, 0.08, 0.08, 0.6)) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg_color
    s.set_corner_radius_all(3)
    s.content_margin_left = 2
    s.content_margin_right = 2
    s.content_margin_top = 1
    s.content_margin_bottom = 1
    return s

static func row_panel(bg_color: Color) -> StyleBoxFlat:
    # ...
```

---

### 7. Energy config hardcoded in ConverterLogic instead of BuildingDef

`converter.gd` has a `ENERGY_CONFIG` dictionary mapping converter type strings to `{capacity, demand}`. Similarly, SolarPanelLogic, BatteryLogic, EnergyPoleLogic, CoalBurnerLogic, ResearchLabLogic all hardcode their energy values in code.

**Solution:** Add energy fields to `BuildingDef`:
```gdscript
# buildings/shared/building_def.gd — add:
@export var energy_capacity: float = 0.0
@export var energy_demand: float = 0.0
@export var energy_generation: float = 0.0
```
Then each building's `.tres` file sets these values. `ConverterLogic.configure()` reads from `def.energy_capacity` instead of the hardcoded dict. Delete `ENERGY_CONFIG` entirely.

---

### 8. Three MultiMesh managers duplicate infrastructure code

`ItemVisualManager`, `ConveyorVisualManager`, `TerrainVisualManager` all have:
- Identical `_grow()` method (~17 lines) for resizing with data preservation
- Identical `_create_quad_mesh()` method
- Same `HIDDEN_POS = Vector2(-99999, -99999)` constant
- Same free-list allocation pattern

**Solution:** Extract `BaseMultiMeshManager`:
```gdscript
# scripts/game/base_multimesh_manager.gd
class_name BaseMultiMeshManager
extends RefCounted

const HIDDEN_POS := Vector2(-99999, -99999)
var multimesh: MultiMesh
var instance: MultiMeshInstance2D
var _free_list: Array[int] = []
var _capacity: int = 0

func _grow(new_capacity: int) -> void:
    # ... shared implementation ...

static func create_quad_mesh(tile_size: float) -> ArrayMesh:
    # ... shared implementation ...

func allocate() -> int:
    if _free_list.is_empty():
        _grow(maxi(_capacity * 2, 64))
    return _free_list.pop_back()

func release(idx: int) -> void:
    multimesh.set_instance_transform_2d(idx, Transform2D(0, HIDDEN_POS))
    _free_list.append(idx)
```

---

### 9. TILE_SIZE constant defined in 6+ files

`const TILE_SIZE := 32` appears independently in: player.gd, building_logic.gd, building_collision.gd, grid_overlay.gd, stress_test_generator.gd, ground_item.gd (hardcoded as `32.0`).

**Solution:** Define once in GameManager (already has it) or a shared constants file. All other files reference `GameManager.TILE_SIZE` or `BuildingLogic.TILE_SIZE` (already defined there — just use it consistently).

---

### 10. Extractor, Borer, and Source share a "simple producer" pattern

All three implement:
- Timer-based production on interval
- Single-item output in one direction
- Inventory with progress tracking
- Nearly identical `can_provide_to()`, `take_item_for()`, serialization

**Solution:** Extract `SimpleProducerLogic`:
```gdscript
class_name SimpleProducerLogic
extends BuildingLogic

var produce_interval: float = 2.0
var output_capacity: int = 5
var _timer: float = 0.0
var _inventory: Dictionary = {}  # item_id -> count

# Shared: timer advance, output pull interface, serialization
# Subclasses override: what item to produce, placement validation
```

---

### 11. SaveManager couples to private implementation details

SaveManager directly accesses:
- `GameManager.energy_system.loading = true` (private flag)
- `GameManager.energy_system._last_placed_node = null` (private variable!)
- Manually sets `Engine.max_physics_steps_per_frame`
- Calls `GameManager.clear_all()` then re-places every building

**Solution:**
- Add `EnergySystem.begin_batch_load()` / `end_batch_load()` public methods that handle the `loading` flag and `_last_placed_node` cleanup internally
- Add `GameManager.begin_load()` / `end_load()` that coordinate subsystems
- SaveManager calls these high-level methods instead of reaching into internals

---

### 12. No save version validation

`SAVE_VERSION := 1` is defined but never checked during deserialization. Old/incompatible saves load with undefined behavior.

**Solution:** Add version check at top of `_deserialize_run()`:
```gdscript
var version: int = data.get("version", 0)
if version < SAVE_VERSION:
    _migrate_save(data, version)
elif version > SAVE_VERSION:
    GameLogger.err("Save version %d is newer than supported %d" % [version, SAVE_VERSION])
    return
```

---

## MEDIUM — Worth fixing during related work

### 13. Input pulling logic repeated in 6 buildings

Converter, ResearchLab, CoalBurner, Sink, Splitter, and Junction each implement their own round-robin input pulling with subtle variations (some use `RoundRobin.next()`, some use `index % 4`, some use raw `_pull_index`).

**Solution:** Standardize on `RoundRobin.next(count)` everywhere. Add a helper to BuildingLogic:
```gdscript
func _pull_from_inputs(input_points: Array, rr: RoundRobin) -> StringName:
    var count := input_points.size()
    var start := rr.next(count)
    for i in range(count):
        var idx := (start + i) % count
        var result := GameManager.pull_item(grid_pos, input_points[idx].dir_idx)
        if not result.is_empty():
            return result.id
    return &""
```

---

### 14. HandAssemblerLogic duplicates parent's `_build_recipe_configs()`

Only difference from ConverterLogic's version is `config.enabled = false`. 4 lines duplicated to change 1 line.

**Solution:** Add a parameter to ConverterLogic:
```gdscript
func _build_recipe_configs(default_enabled: bool = true) -> void:
    recipe_configs.clear()
    for i in range(recipes.size()):
        var config := RecipeConfig.new(recipes[i], i + 1)
        config.enabled = default_enabled
        recipe_configs.append(config)
```
HandAssemblerLogic just calls `_build_recipe_configs(false)`.

---

### 15. Camera position saved but never restored

`_serialize_camera()` saves x, y, zoom. But `_restore_camera()` ignores x/y and snaps to player position. The saved x/y is dead data.

**Solution:** Either stop saving camera x/y, or restore it properly (snap to saved position, then let smooth follow catch up to player).

---

### 16. Converter capacity multipliers are magic numbers

`_build_capacities()` uses `inp.quantity * 3` for input capacity and `out.quantity * 5` for output. No explanation why 3 and 5.

**Solution:** Make them named constants:
```gdscript
const INPUT_CAPACITY_MULTIPLIER := 3   # Buffer 3 batches of each input
const OUTPUT_CAPACITY_MULTIPLIER := 5  # Buffer 5 batches of each output
```

---

### 17. RecipeConfig.deserialize_into() is O(n²)

Loops through all configs for each saved entry. With 58 recipes, this is fine now but scales poorly.

**Solution:** Build a lookup dict first:
```gdscript
static func deserialize_into(configs: Array, data: Array) -> void:
    var by_id := {}
    for config in configs:
        by_id[config.recipe.id] = config
    for entry in data:
        var rid := StringName(entry.get("recipe_id", ""))
        var config = by_id.get(rid)
        if config:
            config.priority = int(entry.get("priority", 1))
            config.enabled = bool(entry.get("enabled", true))
```

---

### 18. Cantor pairing formula duplicated in energy_system.gd and energy_overlay.gd

Both files compute `(min_id + max_id) * (min_id + max_id + 1) / 2 + max_id` for edge dedup.

**Solution:** Add to EnergySystem as a static helper:
```gdscript
static func edge_key(id_a: int, id_b: int) -> int:
    var lo := mini(id_a, id_b)
    var hi := maxi(id_a, id_b)
    return (lo + hi) * (lo + hi + 1) / 2 + hi
```

---

### 19. Player.gd is 761 lines with 9 responsibilities

Handles movement, health, inventory, mining, item pickup/drop, conveyor interaction, visuals, input, serialization. Mining visualization alone is 50 lines of `_draw()`.

**Solution:** Extract into component scripts added as child nodes:
- `PlayerHealth` — damage, regen, death, respawn
- `PlayerMining` — hand mining logic + beam/sparkle/arc visualization
- Keep movement, inventory, and input in Player (they're tightly coupled to physics)

---

### 20. recipe_browser.gd hardcodes CONVERTER_COLORS dict

Building colors are already defined in `BuildingDef.color`. The recipe browser defines its own `CONVERTER_COLORS` dictionary with potentially different values.

**Solution:** Look up the building def for the converter type and use `def.color`:
```gdscript
var def = GameManager.get_building_def(recipe.converter_type)
var color = def.color if def else Color.GRAY
```

---

### 21. Z-index values scattered and inconsistent

GameManager defines `Z_BUILDING_BASE`, `Z_CONVEYOR`, `Z_ITEM`, etc. But Player.gd hardcodes its own z-indices (5, 15, 20). GroundItem defines `Z_NORMAL := 10`, `Z_HOVERED := 20`.

**Solution:** Move all z-index constants to GameManager (or a shared ZOrder class) and reference them everywhere.

---

### 22. Direction vector calculation repeated everywhere

Many buildings compute `grid_pos + DIRECTION_VECTORS[dir_idx]` or `grid_pos + DIRECTION_VECTORS[(direction + 2) % 4]` inline. No shared helper.

**Solution:** Add to BuildingLogic:
```gdscript
func adjacent_cell(dir_idx: int) -> Vector2i:
    return grid_pos + DIRECTION_VECTORS[dir_idx]

func opposite_dir(dir_idx: int) -> int:
    return (dir_idx + 2) % 4
```

---

### 23. World generator deposit plan is fully hardcoded

`world_generator.gd` has a 20-entry array of `[tile_id, min_dist, max_dist, count, size_min, size_max]` with undocumented format and magic distribution values.

**Solution:** Move to a JSON config file (`resources/world/deposit_plan.json`) or at minimum document the tuple format and add named constants for the indices.

---

### 24. Contract gate definitions hardcoded in code

`ContractManager.GATE_DEFS` is a const dictionary with all 5 ring-gate requirements. Adding Ring 6 requires editing code.

**Solution:** Move to a JSON file (`resources/contracts/gate_defs.json`) loaded at runtime, similar to `research_tree.json`.

---

## LOW — Cleanup when touching these files

### 25. `cleanup_visuals()` overridden as empty in 9 buildings

ExtractorLogic, ItemSource, ItemSink, ResearchLabLogic, CoalBurnerLogic, SolarPanelLogic, BatteryLogic, EnergyPoleLogic, BorerLogic all override `cleanup_visuals()` with `pass`.

**Solution:** Make the base class implementation a no-op (it already is — these overrides are unnecessary). Remove the empty overrides.

---

### 26. Enable/disable colors inconsistent across UI

`source_item_menu.gd` uses `Color(0.2, 0.8, 0.3, 0.9)` (alpha 0.9), `recipe_menu.gd` uses `Color(0.2, 0.8, 0.3)` (alpha 1.0). Other panels use entirely different color schemes.

**Solution:** Centralize in `UIStyles`:
```gdscript
const ENABLED_COLOR := Color(0.2, 0.8, 0.3)
const DISABLED_COLOR := Color(0.8, 0.2, 0.2)
```

---

### 27. ConveyorVisualManager variant selection uses magic row numbers

Lines ~56-92 use float literals (0.0, 1.0, 2.0, 3.0, 4.0, 5.0) for atlas row selection with comments. Should be an enum:
```gdscript
enum Variant { STRAIGHT, TURN, DUAL_SIDE, SIDE_INPUT, CROSSROAD, START }
```

---

### 28. TechDef.type is StringName but should be enum

Currently `&"normal"` / `&"instant"` as strings. Easy to typo with no compile-time check.

**Solution:**
```gdscript
enum TechType { NORMAL, INSTANT }
@export var type: TechType = TechType.NORMAL
```

---

### 29. Conveyor variant logic has redundant conditions

"has_right without has_back" and "has_left without has_back" both set `variant_row = 1.0` (turn), differing only in `flip_v`. Could be simplified with a lookup table keyed on `(has_back, has_right, has_left)`.

---

### 30. GridOverlay redraws every frame

Draws all visible grid lines on every `_draw()` call. Should only `queue_redraw()` when camera moves or zooms.

---

## Summary

| # | Severity | Category | Effort |
|---|----------|----------|--------|
| 1 | CRITICAL | Tunnel/Pipeline duplication | Small — extract base class |
| 2 | CRITICAL | GameManager god object | Large — incremental extraction |
| 3 | CRITICAL | Tile constant duplication | Small — create const file |
| 4 | CRITICAL | Inventory serialization duplication | Small — add helpers to Inventory |
| 5 | HIGH | Slot billet duplication | Small — extract factory |
| 6 | HIGH | StyleBoxFlat boilerplate | Small — UIStyles helper |
| 7 | HIGH | Energy config hardcoded | Medium — add fields to BuildingDef |
| 8 | HIGH | MultiMesh manager duplication | Medium — extract base class |
| 9 | HIGH | TILE_SIZE scattered | Trivial — use existing constant |
| 10 | HIGH | Simple producer duplication | Medium — extract base class |
| 11 | HIGH | SaveManager coupling | Medium — add public batch API |
| 12 | HIGH | No save version check | Trivial — add check |
| 13 | MEDIUM | Input pulling duplication | Small — add helper |
| 14 | MEDIUM | HandAssembler config duplication | Trivial — add parameter |
| 15 | MEDIUM | Camera save/restore asymmetry | Trivial — stop saving x/y |
| 16 | MEDIUM | Converter capacity magic numbers | Trivial — name constants |
| 17 | MEDIUM | RecipeConfig O(n²) | Trivial — use dict lookup |
| 18 | MEDIUM | Cantor pairing duplication | Trivial — extract static method |
| 19 | MEDIUM | Player.gd too large | Medium — extract components |
| 20 | MEDIUM | CONVERTER_COLORS duplication | Trivial — use BuildingDef.color |
| 21 | MEDIUM | Z-index values scattered | Small — centralize constants |
| 22 | MEDIUM | Direction vector calc repeated | Trivial — add helper methods |
| 23 | MEDIUM | World gen deposit plan hardcoded | Small — externalize to JSON |
| 24 | MEDIUM | Gate defs hardcoded | Small — externalize to JSON |
| 25 | LOW | Empty cleanup_visuals overrides | Trivial — delete them |
| 26 | LOW | Enable/disable color inconsistency | Trivial — centralize |
| 27 | LOW | Conveyor variant magic numbers | Trivial — add enum |
| 28 | LOW | TechDef.type string vs enum | Trivial — change to enum |
| 29 | LOW | Conveyor variant redundant conditions | Trivial — simplify |
| 30 | LOW | GridOverlay unnecessary redraws | Small — cache/dirty flag |
