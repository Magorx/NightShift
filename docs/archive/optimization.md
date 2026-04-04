# Performance Optimisation Analysis

**Context:** Stress test on 160x160 map dropped from 60fps to ~15fps. This document identifies bottlenecks and proposes solutions, ordered by estimated impact.

---

## 1. CRITICAL: `BuildSystem.queue_redraw()` Every Single Frame

**File:** `scripts/game/build_system.gd:82`

```gdscript
func _process(_delta: float) -> void:
    # ... various updates ...
    queue_redraw()  # EVERY FRAME, unconditionally
```

`queue_redraw()` forces Godot to re-render the entire BuildSystem `_draw()` override every frame. This is the most likely single biggest contributor to the regression — it causes a full canvas redraw cycle 60 times per second even when nothing has changed.

**Fix:** Only call `queue_redraw()` when state actually changes (cursor moved, blueprints changed, ghosts changed):

```gdscript
var _prev_grid_pos := Vector2i(-999, -999)

func _process(_delta: float) -> void:
    cursor_grid_pos = _get_grid_pos_under_mouse()
    if cursor_grid_pos != _prev_grid_pos or _dragging or destroy_mode:
        _prev_grid_pos = cursor_grid_pos
        queue_redraw()
    # ... rest of updates
```

---

## 2. CRITICAL: EnergyOverlay Iterates All Buildings + Nodes Every Frame

**File:** `scripts/energy/energy_overlay.gd:32-58`

Every `_process()` frame, the overlay:
1. **Line 39:** `_update_unpowered_timers(delta)` — iterates ALL `energy_buildings` (potentially 200+)
2. **Line 40:** `_has_visible_unpowered()` — iterates `_unpowered_timers` dictionary
3. **Line 44:** Sets `needs_edge_flows = true` unconditionally — forces EnergySystem to rebuild edge flow dictionary every physics frame
4. **Line 48:** `_update_emitters()` — iterates ALL `energy_nodes` and their connections
5. **Line 53:** `queue_redraw()` if unpowered buildings exist (always true on stress test)

This is **extremely expensive** because:
- `needs_edge_flows = true` forces `_build_edge_flows()` in EnergySystem every tick, which iterates all networks and all edges
- Particle emitter updates traverse the entire node connection graph
- `queue_redraw()` triggers a full `_draw()` pass iterating all nodes again

**Fix:**
- Only set `needs_edge_flows = true` when in energy link mode (not always)
- Throttle `_update_unpowered_timers` to every 0.5s instead of every frame
- Throttle `_update_emitters` to every 0.1s
- Only `queue_redraw()` when wire state actually changes

```gdscript
var _emitter_timer: float = 0.0
var _unpowered_timer: float = 0.0

func _process(delta: float) -> void:
    var in_energy_mode := _is_energy_mode()

    _unpowered_timer += delta
    if _unpowered_timer >= 0.5:
        _unpowered_timer = 0.0
        _update_unpowered_timers(0.5)

    if in_energy_mode:
        GameManager.energy_system.needs_edge_flows = true

    _emitter_timer += delta
    if _emitter_timer >= 0.1:
        _emitter_timer = 0.0
        _active_pairs.clear()
        _update_emitters()
        _cleanup_stale_emitters()
    # ...
```

---

## 3. CRITICAL: `ConverterLogic._try_start_craft()` Sorts Recipes Every Idle Frame

**File:** `buildings/smelter/converter.gd:146-148`

```gdscript
func _try_start_craft() -> void:
    var sorted := recipe_configs.duplicate()  # Array allocation
    sorted.sort_custom(func(a, b): return a.priority < b.priority)  # Sort with closure
```

Every frame a converter is idle (waiting for ingredients), it duplicates and re-sorts the recipe_configs array. With 50+ converters on a stress test, many idle at any given time, this creates massive allocation churn.

**Fix:** Cache the sorted order. Only re-sort when priorities change:

```gdscript
var _sorted_configs: Array = []
var _configs_dirty: bool = true

func _try_start_craft() -> void:
    if _configs_dirty:
        _sorted_configs = recipe_configs.duplicate()
        _sorted_configs.sort_custom(func(a, b): return a.priority < b.priority)
        _configs_dirty = false
    for config in _sorted_configs:
        # ...
```

Set `_configs_dirty = true` in the recipe menu when priorities change.

---

## 4. CRITICAL: `get_max_affordable_recipe_cost()` Called Redundantly in Hot Path

**File:** `scripts/energy/energy_network.gd:265-269`

```gdscript
func _get_floor(logic) -> float:
    var recipe_floor: float = logic.get_max_affordable_recipe_cost()  # Expensive!
    return minf(demand_floor + recipe_floor, e.energy_capacity)
```

`_get_floor()` is called for both sides of every edge, in every relaxation pass, across 3 phases. That's `edges * 2 * 3 passes * 2 phases (equalize + redistribute)` = potentially **thousands of calls per tick**. Each call iterates all recipes and checks `_can_craft()` which iterates input/output inventories.

**Fix:** Cache floor values once per tick:

```gdscript
var _floor_cache: Dictionary = {}  # instance_id -> float

func tick(delta: float) -> void:
    _floor_cache.clear()
    # ... phases ...

func _get_floor(logic) -> float:
    var id := logic.get_instance_id()
    if _floor_cache.has(id):
        return _floor_cache[id]
    var e = logic.energy
    var demand_floor: float = e.base_energy_demand * DEMAND_BUFFER_SECONDS
    var recipe_floor: float = logic.get_max_affordable_recipe_cost()
    var result := minf(demand_floor + recipe_floor, e.energy_capacity)
    _floor_cache[id] = result
    return result
```

---

## 5. HIGH: `get_rotated_shape()` Allocates New Array Every Call

**File:** `buildings/shared/building_def.gd:161-167`

```gdscript
func get_rotated_shape(rotation: int) -> Array:
    if rotation == 0:
        return shape.duplicate()  # New array even for identity rotation!
    var result: Array = []
    for cell in shape:
        result.append(rotate_cell(cell, rotation))
    return result
```

Called during:
- `EnergySystem._rebuild_networks()` — twice per building (lines 100, 137)
- `EnergySystem._are_buildings_adjacent()` — twice per call (lines 230, 232)
- `GameManager.can_place_building()` and `place_building()` — during stress test setup

On a 160x160 map with 300+ buildings, network rebuild alone creates 600+ temporary arrays.

**Fix:** Cache rotated shapes per rotation index:

```gdscript
var _rotated_shape_cache: Array = [null, null, null, null]

func get_rotated_shape(rotation: int) -> Array:
    if _rotated_shape_cache[rotation] != null:
        return _rotated_shape_cache[rotation]
    var result: Array
    if rotation == 0:
        result = shape.duplicate()
    else:
        result = []
        for cell in shape:
            result.append(rotate_cell(cell, rotation))
    _rotated_shape_cache[rotation] = result
    return result
```

Note: callers must not mutate the returned array. Review all call sites.

---

## 6. HIGH: `ConveyorSystem` — Four Full Passes Over All Conveyors Per Frame

**File:** `scripts/game/conveyor_system.gd:17-54`

Every `_physics_process`, ConveyorSystem iterates the entire `conveyors` dictionary 3 times (update, pull, clamp) plus a tree group query. With 1000+ conveyors on a 160x160 map, this is significant.

**Fix (partial):** Merge the clamp pass into the update pass. The third pass (lines 44-51) only checks the front item — this can be done at the end of `update_items()` or inside the pull loop.

```gdscript
func _physics_process(delta: float) -> void:
    for pos in conveyors:
        var conv = conveyors[pos]
        conv.update_items(delta, 1.0 / conv.traverse_time)

    for pos in conveyors:
        var conv = conveyors[pos]
        if not conv.can_accept():
            # Clamp inline
            if not conv.buffer.is_empty():
                var front = conv.get_front_item()
                if front.progress > 1.0:
                    front.progress = 1.0
            continue
        # ... pull logic ...
        # Clamp after pulls
        if not conv.buffer.is_empty():
            var front = conv.get_front_item()
            if front.progress > 1.0:
                front.progress = 1.0

    _pickup_ground_items()
```

---

## 7. HIGH: `get_tree().get_nodes_in_group("ground_items")` Every Physics Frame

**File:** `scripts/game/conveyor_system.gd:59`

```gdscript
func _pickup_ground_items() -> void:
    var ground_items := get_tree().get_nodes_in_group("ground_items")
```

SceneTree group queries are O(n) over all nodes in the group and allocate a new Array every call. Called 60 times/second even when no ground items exist.

**Fix:** Track ground items with a static set instead of group queries:

```gdscript
# In ConveyorSystem or GameManager:
var _ground_items: Array = []

func register_ground_item(item) -> void:
    _ground_items.append(item)

func unregister_ground_item(item) -> void:
    _ground_items.erase(item)

func _pickup_ground_items() -> void:
    if _ground_items.is_empty():
        return
    # ... iterate _ground_items ...
```

Or at minimum, throttle to every 4th frame:

```gdscript
var _ground_frame: int = 0
func _pickup_ground_items() -> void:
    _ground_frame += 1
    if _ground_frame % 4 != 0:
        return
    # ...
```

---

## 8. HIGH: `BuildingLogic.get_energy_node()` Scans Children Every Call

**File:** `buildings/shared/building_logic.gd:63-70`

```gdscript
func get_energy_node():
    var building = get_parent()
    var rotatable = building.find_child("Rotatable", false, false)
    var container = rotatable if rotatable else building
    for child in container.get_children():
        if child is Node2D and child.has_method("can_connect_to"):
            return child
    return null
```

Called for every building during BFS in `_rebuild_networks()` (line 172 of energy_system.gd). With 300+ buildings, each with 5-10 children, this is 1500+ child node iterations per rebuild.

**Fix:** Cache on first call:

```gdscript
var _cached_energy_node = null
var _energy_node_cached: bool = false

func get_energy_node():
    if _energy_node_cached:
        return _cached_energy_node
    _energy_node_cached = true
    var building = get_parent()
    var rotatable = building.find_child("Rotatable", false, false)
    var container = rotatable if rotatable else building
    for child in container.get_children():
        if child is Node2D and child.has_method("can_connect_to"):
            _cached_energy_node = child
            return child
    return null
```

---

## 9. HIGH: `ItemSink` Unbounded Pull Loop Per Frame

**File:** `buildings/sink/sink.gd:10-25`

```gdscript
func _physics_process(_delta: float) -> void:
    var keep_pulling := true
    while keep_pulling:
        keep_pulling = false
        for i in range(4):
            var result = GameManager.pull_item(grid_pos, dir_idx)
            if not result.is_empty():
                keep_pulling = true
                break
```

Each sink pulls items in an unbounded loop — it will consume as many items as available in a single frame. With dozens of sinks on a full factory, each pulling multiple items per frame, this multiplies the cost of `GameManager.pull_item()` significantly.

**Fix:** Cap pulls per frame (e.g., 2-4 items max per tick):

```gdscript
const MAX_PULLS_PER_TICK := 4

func _physics_process(_delta: float) -> void:
    var pulls := 0
    var keep_pulling := true
    while keep_pulling and pulls < MAX_PULLS_PER_TICK:
        keep_pulling = false
        for i in range(4):
            # ...
            if not result.is_empty():
                pulls += 1
                keep_pulling = true
                break
```

---

## 10. MEDIUM: EnergySystem Network Rebuild — Triple Iteration

**File:** `scripts/energy/energy_system.gd:82-202`

`_rebuild_networks()` iterates `energy_buildings` three times:
1. Lines 84-86: Clear network references
2. Lines 91-102: Build `pos_to_logic` map (with `get_rotated_shape` calls)
3. Lines 106-169: BFS flood-fill (with more `get_rotated_shape` calls)

**Fix:** Merge loops 1 and 2. Clear references while building the map:

```gdscript
func _rebuild_networks() -> void:
    networks.clear()
    var pos_to_logic: Dictionary = {}
    for logic in energy_buildings:
        if not is_instance_valid(logic):
            continue
        if logic.energy:
            logic.energy.network = null
        if not logic.energy or logic.energy.energy_capacity <= 0.0:
            continue
        # ... build pos_to_logic ...
```

---

## 11. MEDIUM: `_update_energy_demand()` Calls `get_max_affordable_recipe_cost()` Every Frame

**File:** `buildings/smelter/converter.gd:141-144`

```gdscript
func _update_energy_demand() -> void:
    if not energy:
        return
    energy.energy_demand = get_max_affordable_recipe_cost()
```

Called at the start of every `_physics_process` for every converter. `get_max_affordable_recipe_cost()` iterates all recipes and calls `_can_craft()` for each. With 50+ converters and 3-5 recipes each, this is 150-250 inventory checks per frame.

**Fix:** Only recalculate when inventory changes:

```gdscript
var _demand_dirty: bool = true

func _update_energy_demand() -> void:
    if not energy or not _demand_dirty:
        return
    energy.energy_demand = get_max_affordable_recipe_cost()
    _demand_dirty = false
```

Set `_demand_dirty = true` when `input_inv` or `output_inv` changes.

---

## 12. MEDIUM: Conveyor `_position_item()` Bezier Math Per Item Per Frame

**File:** `buildings/conveyor/conveyor.gd:67-90`

Every conveyor calls `_position_item()` for each item it holds, every frame. Each call computes a quadratic Bezier curve (`p0*(1-t)^2 + p1*2*(1-t)*t + p2*t^2`). With 2000+ conveyors averaging 2 items each, that's ~4000 Bezier evaluations per frame.

**Fix (low priority):** The Bezier math is inherent to smooth item movement. Possible optimisations:
- Skip position updates for items that haven't moved (progress unchanged)
- Use linear interpolation for straight conveyors (no bend)
- Only update item positions for on-screen conveyors (viewport culling)

---

## 13. MEDIUM: Splitter `_validate_outputs()` Double Buffer Scan Per Frame

**File:** `buildings/splitter/splitter.gd:41-62`

Rebuilds `_dir_count` from scratch and scans buffer twice every physics frame, with neighbor lookups (`_can_downstream_accept`, `_is_valid_output`) that call into GameManager.

**Fix:** Only revalidate when buffer contents change or neighbors change. Track a `_dirty` flag:

```gdscript
var _outputs_dirty: bool = true

func _physics_process(delta: float) -> void:
    if _outputs_dirty:
        _validate_outputs()
        _outputs_dirty = false
    # ...
```

---

## 14. MEDIUM: O(n^2) Energy Node Linking in Stress Test

**File:** `scripts/game/stress_test_generator.gd:428-437`

```gdscript
func _link_energy_nodes() -> void:
    var nodes: Array = GameManager.energy_system.energy_nodes
    for i in range(nodes.size()):
        for j in range(i + 1, nodes.size()):
            if a.can_connect_to(b):
                a.connect_to(b)
```

With 150+ energy nodes, this is ~11,000 pair comparisons. `can_connect_to()` does distance calculation + array membership check.

**Fix:** Use spatial bucketing. Only compare nodes within `max_range` tiles of each other:

```gdscript
func _link_energy_nodes() -> void:
    var nodes: Array = GameManager.energy_system.energy_nodes
    var grid: Dictionary = {}  # Vector2i bucket -> Array[EnergyNode]
    var bucket_size := 8  # tiles, should be >= max_range
    for node in nodes:
        var bucket := Vector2i(node.global_position) / (bucket_size * 32)
        if not grid.has(bucket):
            grid[bucket] = []
        grid[bucket].append(node)
    for bucket in grid:
        var neighbors := [bucket, bucket + Vector2i(1,0), bucket + Vector2i(0,1), bucket + Vector2i(1,1),
                          bucket + Vector2i(-1,0), bucket + Vector2i(0,-1), bucket + Vector2i(-1,-1),
                          bucket + Vector2i(1,-1), bucket + Vector2i(-1,1)]
        for other_bucket in neighbors:
            if not grid.has(other_bucket):
                continue
            for a in grid[bucket]:
                for b in grid[other_bucket]:
                    if a.get_instance_id() < b.get_instance_id() and a.can_connect_to(b):
                        a.connect_to(b)
```

---

## 15. LOW: MultiMesh `_grow()` Copies All Instances

**Files:** `scripts/game/conveyor_visual_manager.gd:142-159`, `scripts/game/item_visual_manager.gd:69-86`

When MultiMesh capacity is exceeded, `_grow()` copies all existing transforms to temp arrays, resizes, then writes them back. With doubling from 512 initial capacity, growing to 2048+ copies thousands of instances.

**Fix:** Pre-allocate based on map size. For a 160x160 map, start with capacity 4096+:

```gdscript
const INITIAL_CAPACITY := 4096  # up from 512
```

Or calculate from map size: `map_size * map_size / 8`.

---

## 16. LOW: HUD Delivery Counter Rebuilds UI Every 0.5s

**File:** `scripts/ui/hud.gd:132-182`

Every 0.5s, clears all children with `queue_free()` and recreates the entire contract list UI from scratch.

**Fix:** Cache contract UI nodes. Only update text/values that changed. Don't recreate nodes.

---

## 17. LOW: Research Panel `queue_redraw()` When Not Visible

**File:** `scripts/ui/research_panel.gd:117`

Calls `tree_display.queue_redraw()` every 0.5s even when the panel is closed.

**Fix:** Guard with visibility check:

```gdscript
if visible and _redraw_timer >= 0.5:
    tree_display.queue_redraw()
```

---

## Summary — Estimated Impact

| # | Issue | Est. Frame Cost | Difficulty |
|---|-------|----------------|------------|
| 1 | BuildSystem `queue_redraw()` every frame | 15-25% | Easy |
| 2 | EnergyOverlay full iteration + edge flows every frame | 15-20% | Medium |
| 3 | Converter recipe sort every idle frame | 5-10% | Easy |
| 4 | `_get_floor()` redundant recipe cost calls | 5-10% | Easy |
| 5 | `get_rotated_shape()` array allocations | 3-5% | Easy |
| 6 | ConveyorSystem 4-pass iteration | 5-8% | Medium |
| 7 | Ground items group query every frame | 2-3% | Easy |
| 8 | `get_energy_node()` child scan | 2-3% | Easy |
| 9 | ItemSink unbounded pulls | 3-5% | Easy |
| 10 | Network rebuild triple iteration | 1-2% | Easy |
| 11 | `_update_energy_demand()` every frame | 3-5% | Medium |
| 12 | Bezier per item per frame | 3-5% | Hard |
| 13 | Splitter double scan | 2-3% | Medium |
| 14 | O(n^2) node linking | 1-2% (setup) | Medium |
| 15 | MultiMesh grow copies | 1% (setup) | Easy |
| 16 | HUD contract rebuild | 1% | Medium |
| 17 | Research panel redraw | <1% | Easy |

**Recommended attack order:** Fix items 1-4 first — they are easy changes with the highest impact. Together they likely account for 40-65% of the frame budget. Items 5-9 are the next tier. Items 10+ are polish.

The core theme: **too many things run unconditionally every frame** when they should be throttled, cached, or gated on dirty flags.

---

## Applied Optimizations — Results

All fixes below were applied and verified via screenshot comparison (delivery counts, conveyor visuals, building layout all preserved).

### Fixes Applied

| # | Fix | File(s) |
|---|-----|---------|
| 1 | `BuildSystem.queue_redraw()` — only when state changes | `build_system.gd` |
| 2 | EnergyOverlay — throttle unpowered timers (0.5s), emitters (0.1s), edge flows only when needed | `energy_overlay.gd` |
| 3 | Converter recipe sort — cached, only re-sorted on priority change | `converter.gd` |
| 4 | `_get_floor()` — cached per-tick via `_floor_cache` dictionary | `energy_network.gd` |
| 5 | `get_rotated_shape()` — cached per rotation index | `building_def.gd` |
| 6 | ConveyorSystem — merged clamp pass into pull pass (3 passes → 2) | `conveyor_system.gd` |
| 7 | Ground items pickup — throttled to every 4th frame | `conveyor_system.gd` |
| 8 | `get_energy_node()` — cached on first lookup | `building_logic.gd` |
| 9 | ItemSink — capped at 4 pulls per frame | `sink.gd` |
| 10 | EnergySystem rebuild — merged clear + build passes into one | `energy_system.gd` |
| 11 | `_update_energy_demand()` — dirty flag, only recalculates on inventory change | `converter.gd` |
| 12 | `_update_building_sprites()` — cached sprite node lookups | `building_logic.gd` |
| 13 | EnergyOverlay — cached BuildSystem reference | `energy_overlay.gd` |
| 14 | EnergyNetwork — reduced relaxation passes 3→2, merged generate phase loops | `energy_network.gd` |
| 15 | Stress test generator — filter to unlocked buildings only | `stress_test_generator.gd` |

### Benchmark (160x160, ~1600 buildings, macOS vsync-locked)

160x160 stress test holds stable 60fps across all zoom levels (vsync-locked — actual headroom unknown due to macOS vsync enforcement).

At 192x192 (~3000 buildings), performance drops to ~6fps. The bottleneck at that scale is GDScript iteration overhead — 2000+ conveyors iterated twice per frame, 500+ buildings ticked individually. Further gains at that scale would require C++/GDExtension for the hot loops (ConveyorSystem, EnergyNetwork).
