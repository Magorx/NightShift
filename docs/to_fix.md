# Technical Debt & Fixes

Issues ordered by priority. Each has a brief fix description.

---

## P1: Type Dispatch Chains in GameManager (scalability blocker)

`pull_item()`, `has_output_at()`, `has_input_at()`, `peek_output_item()` each contain 7-way if-chains checking `building.has_meta("conveyor")`, `has_meta("source")`, etc. At 500 buildings this means ~50k type checks/frame.

**Fix:** Define a common `OutputProvider` base class with virtual methods (`has_output_toward`, `can_provide_to`, `peek_output_for`, `take_item_for`). On `place_building()`, cache the provider reference in a `Dictionary<Vector2i, OutputProvider>`. Replace all if-chains with a single dict lookup + virtual call.

---

## P2: GameManager is a God Object

GameManager handles 13+ responsibilities: building registry, placement/deletion, pull system, delivery tracking, recipe registry, conveyor sprite updates, rotation math, tunnel linking, deposit tracking, shape/IO extraction.

**Fix:** Extract into focused services:
- `PullSystem` — `pull_item()`, `has_output_at()`, `has_input_at()`, `peek_output_item()` and the provider registry from P1
- `BuildingPlacementService` — `place_building()`, `remove_building()`, `can_place_building()`, sprite updates
- `BuildingRegistry` — `building_defs`, `recipes_by_type`, `get_building_def()`
- GameManager remains as a thin facade holding `buildings` dict, `deposits`, `currency`, and delegating to services

---

## P3: Pull Interface Duplicated Across 7 Buildings

Every output-producing building independently implements `has_output_toward()`, `can_provide_to()`, `peek_output_for()`, `take_item_for()` with nearly identical structure. ~200 lines of duplication across conveyor, source, extractor, converter, splitter, junction, tunnel.

**Fix:** Create `OutputProvider` base class (see P1). Buildings override only what differs. Buffer-based buildings (splitter, junction, tunnel) share a common `BufferOutputProvider` that iterates `buffer.items` checking `progress >= 1.0` and matching `output_dir_idx`.

---

## P4: String-Based Meta Storage for Building Logic

Building logic nodes are stored via `building.set_meta("conveyor", conv)` and retrieved with `building.has_meta("conveyor")`. Typos compile but fail silently at runtime.

**Fix:** Store logic references as typed properties on `BuildingBase`. Either add explicit typed fields (`var logic: Node`) or use a single `var logic_node: Node` that all building types populate. The provider registry from P1 eliminates most meta lookups anyway.

---

## P5: ResourceLoader Called on Every Item Creation

`ItemBuffer._get_item_def()` calls `ResourceLoader.exists()` + `load()` every time an item visual is created. Same pattern in `sink.gd` and `hud.gd`.

**Fix:** Cache loaded ItemDefs in a static Dictionary in GameManager (or the BuildingRegistry from P2). Look up by `item_id` instead of loading from disk each time.

---

## P6: Item Visuals — One Node2D Per Item

Each item on a conveyor creates a new `Node2D` added to `ItemLayer`. At 500 conveyors × 2 items = 1,000 scene tree nodes, each with `_draw()` overhead.

**Fix:** Pool `Node2D` instances. When an item is consumed (by sink, converter, etc.), return its visual to the pool instead of `queue_free()`. On creation, pop from pool before allocating new. Longer-term: consider a single draw node using `_draw()` with batched circles, or `MultiMeshInstance2D`.

---

## P7: Item Positioning Logic Duplicated in 5 Places

`ConveyorBelt._position_item()`, `SplitterLogic._position_item()`, `JunctionLogic._position_item()`, `TunnelLogic._update_item_visual()` each reimplement item-to-world-position conversion with slight variations (bezier vs linear vs zones).

**Fix:** Move positioning into `ItemBuffer` or `ItemVisual` with a configurable strategy (bezier curve points passed in at init). Each building provides its curve/path data, the shared code does the math.

---

## P8: Conveyor Sprite Updates Not Batched

Every `place_building()` and `remove_building()` immediately calls `_update_conveyor_sprites()` → `_update_neighbor_conveyor_sprites()` checking 4 neighbors per cell. Drag-placing 20 conveyors triggers 80+ redundant sprite updates.

**Fix:** Queue dirty positions into a `Set<Vector2i>` during placement. Flush once at end of frame (or end of drag) with deduplication:
```
var _dirty_sprite_positions: Dictionary = {}
func _physics_process(_delta):
    for pos in _dirty_sprite_positions:
        _update_single_conveyor_sprite(pos)
    _dirty_sprite_positions.clear()
```

---

## P9: Splitter._find_free_output() Has Nested Loop

`_find_free_output()` iterates 4 directions × all buffer items to check if a direction is already taken. Called per item per frame.

**Fix:** Maintain a `Dictionary<int, int>` mapping `output_dir_idx → count` of items routed there. Update on item add/remove instead of scanning every frame.

---

## P10: Missing Return Type Annotations

Key functions in `game_manager.gd` lack return types: `get_building_def()`, `get_building_at()`, `pull_item()`, `peek_output_item()`. Hurts IDE autocompletion and makes bugs harder to catch.

**Fix:** Add explicit return types to all public functions across autoloads and building scripts. Low effort, high value for maintainability.

---

## P11: SaveManager Deduplicates Multi-Cell Buildings at Save Time

`GameManager.buildings` stores the same node under every cell it occupies. SaveManager loops all entries and deduplicates by `instance_id` at save time.

**Fix:** Maintain a separate `Array<Node2D>` of unique buildings (append on place, remove on delete). Iterate that directly during save — no dedup needed.

---

## P12: Ghost Node Pool Grows Unbounded

Drag-placing creates ghost preview nodes on demand. The pool grows to match the largest drag but never shrinks until the player switches building type.

**Fix:** Cap pool size (e.g., 64). On drag end, trim pool back to a baseline (e.g., 4). Reuse existing ghosts by toggling visibility instead of creating/freeing.

---

## P13: No `class_name` on Core Scripts

`game_manager.gd`, `build_system.gd`, `conveyor_system.gd`, `game_world.gd` lack `class_name` declarations. Reduces type safety and IDE support.

**Fix:** Add `class_name` to all scripts that are referenced by other scripts. Note: autoload singletons accessed via their autoload name don't strictly need it, but it's still good practice for type hints in function signatures.

---

## P14: Inconsistent Null Safety

Some places use `buildings.has(pos)` then access `buildings[pos]` (assumes valid between check and access). Other places use `buildings.get(pos)` with null check. Mixed patterns.

**Fix:** Standardize on `var b = buildings.get(pos); if b and is_instance_valid(b):` everywhere. Grep for `buildings[` without prior `.has()` guard and fix.
