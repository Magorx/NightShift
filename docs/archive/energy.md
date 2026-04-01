# Energy System Design

## Overview

Energy is a separate resource layer — not an item on conveyors. It flows through an **energy grid**: a network of connected buildings that generate, store, transport, and consume energy. Buildings connect via physical adjacency (4-directional) and explicit energy node connections (long-range, throughput-limited).

Energy enables a progression curve: early buildings work without power, but powered recipes are faster or more efficient, and advanced buildings require energy to operate at all.

---

## Energy Economy

### Where Energy Comes From

**Baseline unit:** 1 coal → 100 energy. All other values are scaled from this.

| Generator | Size | Fuel | Energy per unit | Output | Unlock | Notes |
|-----------|------|------|----------------|--------|--------|-------|
| Coal Burner | 1x2 | 1 coal / 4s | 100 per coal | 25/s | Start | Bootstrap generator, no energy needed to start |
| Wind Turbine | 2x2 | None | — | 10/s (8–12, fluctuates) | Tier 1 | Passive, variable output (sine wave, period ~30s) |
| Solar Panel | 1x1 | None | — | 8/s | Tier 2 | Passive, constant, tiny footprint |
| Geothermal Plant | 3x3 | None | — | 60/s | Tier 2 | Must be placed on geothermal vent (new deposit type) |
| Gas Turbine | 2x2 | 1 oil / 3s | 150 per oil | 50/s | Tier 3 | High output, competes with oil for plastic |
| Nuclear Reactor | 4x4 | 1 uranium_rod / 30s | 6000 per rod | 200/s | Tier 4 | Needs 20/s kickstart to activate |

**Bootstrap path:** Coal Burner requires no energy to start → powers early factory → unlocks better generators.

**Kickstart mechanic:** Some generators (Nuclear Reactor) need energy to activate. The player must route energy from an existing grid to "boot" them. Once running, they self-sustain. If the grid loses all energy, they shut down and need kickstart again.

### Where Energy Goes

Energy consumption has two layers per building:

1. **Base demand** — energy/s needed for the building to operate at all. If unmet, the building is **unpowered** and stops working entirely.
2. **Recipe energy cost** — additional energy consumed per craft to unlock powered recipes. If the building has enough stored energy when starting a craft, it consumes it and uses the powered recipe. Otherwise it falls back to the base (free) recipe if one exists.

| Building | Base Demand | Notes |
|----------|------------|-------|
| Conveyor | 0 | Never needs power |
| Drill / Extractor | 0 | Works unpowered |
| Smelter | 0 | Works unpowered, powered recipes available |
| Assembler | 5 energy/s | Requires power to operate |
| Chemical Plant | 8 energy/s | Requires power to operate |
| Advanced Factory | 15 energy/s | Requires power to operate |
| Pump (water) | 3 energy/s | Requires power |
| Pumpjack (oil) | 5 energy/s | Requires power |

### Recipe Energy Examples

The same converter can have free and powered recipe variants:

| Recipe | Converter | Inputs | Outputs | Time | Energy Cost | Notes |
|--------|-----------|--------|---------|------|-------------|-------|
| Smelt Iron | Smelter | 1 iron_ore | 1 iron_plate | 3s | 0 | Free, baseline |
| Smelt Iron (Powered) | Smelter | 2 iron_ore | 2 iron_plate | 2s | 50 energy | Double throughput — same ratio, faster |
| Forge Steel | Smelter | 1 iron_plate + 1 coal | 1 steel | 4s | 0 | Free, baseline |
| Forge Steel (Powered) | Smelter | 2 iron_plate + 2 coal | 2 steel | 3s | 40 energy | Double throughput — same ratio, faster |
| Make Circuit | Assembler | 2 copper_wire + 1 glass | 1 circuit | 5s | 0 | Base demand covers it |
| Make Processor | Assembler | 2 circuit + 1 steel | 1 processor | 8s | 30 energy | Extra per-craft cost |

`energy_cost` on a recipe is a flat amount consumed when the craft **starts**. The building must have that much energy stored locally. The building's `base_demand` is a continuous drain regardless of whether it's actively crafting.

---

## Core Concepts

### BuildingEnergy (Separate Component Class)

Energy state lives in its own class (`buildings/shared/building_energy.gd`), **not** on BuildingLogic directly. Buildings that participate in the energy grid hold a `BuildingEnergy` instance; all others have `null`.

```gdscript
class_name BuildingEnergy

var energy_stored: float = 0.0        # current energy in this building
var energy_capacity: float = 0.0      # max local storage
var base_energy_demand: float = 0.0   # continuous energy/s needed to operate
var is_powered: bool = true           # computed: true if base_demand is met
var generation_rate: float = 0.0      # energy/s produced (generators only)
```

`BuildingLogic` gains one field:

```gdscript
var energy: BuildingEnergy = null     # null = building does not participate in energy grid
```

Buildings with `energy != null` and `energy.energy_capacity > 0` participate in adjacency equalization. Buildings with `energy == null` are invisible to the energy grid.

### Energy Node (Composable Component)

`EnergyNode` extends `Node2D` (not tied to any building type) so it can be positioned in scenes and support click interaction (area detection, range visualization). Attach it as a child node to any building's scene to grant that building explicit long-range energy connections beyond adjacency.

```gdscript
class_name EnergyNode extends Node2D

@export var max_connections: int = 3           # max number of explicit links
@export var throughput: float = 100.0          # max energy transfer per connection per second
@export var inner_capacity: float = 50.0       # additional energy storage from the node itself
@export var connection_range: float = 5.0      # max distance in tiles for linking

var connections: Array[EnergyNode] = []        # linked nodes (bidirectional)
```

The building's effective `energy_capacity` = its `BuildingEnergy.energy_capacity` + node's `inner_capacity`.

**Examples of node configurations on different buildings:**

| Building | max_connections | throughput | inner_capacity | Why |
|----------|----------------|------------|----------------|-----|
| Basic Energy Pole | 3 | 100/s | 50 | Standard relay |
| Advanced Energy Pole | 6 | 250/s | 100 | High-capacity backbone |
| Battery | 1 | 200/s | 2000 | Huge storage, single link |
| Capacitor Bank | 2 | 500/s | 5000 | Massive storage, dual link |
| Smelter (upgraded) | 1 | 50/s | 20 | Minor relay built into converter |

Node connections are mostly **manual** — the player explicitly links two energy nodes. One exception: when placing a second energy node, it auto-links to the most recently placed node (if in range). All subsequent connections are manual. Connection range is fixed per building type (e.g., 5 tiles for basic pole, 10 for advanced).

### Energy Network

A **network** is a connected component of buildings that can exchange energy. Two buildings are in the same network if:

- They are physically adjacent (4-direction) and both have `energy_capacity > 0`, OR
- They are linked via `EnergyNode` connections (any range)

Networks are tracked by `EnergySystem`. When a building is placed or removed, affected networks are marked dirty and rebuilt next tick.

---

## Network Distribution Algorithm

The algorithm runs once per physics tick per network. It must be O(N) where N = number of buildings in the network to handle large factories.

### Per-Tick Steps

```
For each EnergyNetwork:

  1. GENERATE
     For each generator in the network:
       produced = generation_rate * delta
       generator.energy.energy_stored += produced
       (capped at generator.energy.energy_capacity)

  2. CONSUME BASE DEMAND
     total_base_demand = sum of all energy.base_energy_demand * delta
     total_available = sum of all energy.energy_stored across network

     If total_available >= total_base_demand:
       Each building subtracts its energy.base_energy_demand * delta from local storage
       All buildings set is_powered = true
     Else:
       # Proportional rationing — everyone gets the same fraction
       ratio = total_available / total_base_demand
       Each building subtracts (energy.base_energy_demand * delta * ratio)
       Buildings where ratio < 1.0 set energy.is_powered = false

  3. RESERVE RECIPE ENERGY
     For each consumer with a pending recipe start:
       If consumer.energy.energy_stored >= recipe.energy_cost:
         consumer may use that recipe (sorted by total output, highest first)
       Else:
         consumer tries the next recipe with lower output/energy cost, or waits

  4. EQUALIZE EXCESS
     After generation and consumption, redistribute excess energy
     so that all buildings trend toward proportional fullness:

       total_energy = sum of energy.energy_stored
       total_capacity = sum of energy.energy_capacity
       target_ratio = total_energy / total_capacity

       For each building:
         target = target_ratio * building.energy.energy_capacity
         building.energy.energy_stored = lerp(building.energy.energy_stored, target, EQUALIZE_SPEED * delta)

     EQUALIZE_SPEED is ~2.0 (converges in ~1 second for adjacent buildings).
```

### Throughput Constraints (Node Connections)

The equalization in step 4 applies freely within **adjacency clusters** (groups of buildings touching each other). For energy flowing through `EnergyNode` connections between clusters, the transfer per tick is capped:

```
For each EnergyNode connection (A ↔ B):
  energy_diff = A.cluster_energy_ratio - B.cluster_energy_ratio
  desired_transfer = energy_diff * transfer_factor * delta
  actual_transfer = clamp(desired_transfer, -throughput * delta, throughput * delta)
  Move actual_transfer from higher to lower cluster
```

This means node connections are bottlenecks — large factories need adequate node infrastructure to distribute energy across distant sections.

### Network Rebuild Strategy

Rebuilding networks on every building change is expensive if done naively. Strategy:

1. **Dirty flag**: When a building is placed/removed, mark a `_networks_dirty = true` flag.
2. **Lazy rebuild**: At the start of the next energy tick, if dirty, rebuild all networks via flood-fill from all energy-capable buildings. Use a visited set to avoid duplicates.
3. **Incremental optimization** (future): For placement, check if the new building bridges two existing networks (merge) or extends one. For removal, check if the network splits (requires BFS from neighbors). This avoids full rebuild but adds complexity — defer until profiling shows it's needed.

Flood-fill rebuild is O(B) where B = total energy-capable buildings. With thousands of buildings this takes <1ms — acceptable for the dirty-flag cadence.

---

## Building Catalog

### Generators

**Coal Burner** (1x2)
- Has 1 item input (pulls coal from adjacent conveyor)
- Consumes 1 coal every 4 seconds → 100 energy per coal → 25 energy/s while fueled
- energy_capacity: 200 (internal buffer)
- No EnergyNode (energy transfers via adjacency only)
- No energy needed to start (bootstrap generator)

**Wind Turbine** (2x2)
- No inputs, passive generation
- Produces 8–12 energy/s (fluctuates with a slow sine wave, period ~30s)
- energy_capacity: 80
- No EnergyNode
- Takes space but no fuel, good for early supplemental power

**Solar Panel** (1x1)
- No inputs, passive generation
- Produces 8 energy/s constant
- energy_capacity: 30
- No EnergyNode
- Tiny footprint, low output — tile many for meaningful power

**Geothermal Plant** (3x3)
- Must be placed on geothermal vent deposit (new source type on tilemap)
- Produces 60 energy/s, no fuel
- energy_capacity: 500
- Has EnergyNode: 2 connections, 150 throughput each
- Strong mid-game power source, location-dependent

**Gas Turbine** (2x2)
- Has 1 item input (pulls oil)
- Consumes 1 oil every 3 seconds → produces 50 energy/s
- energy_capacity: 300
- No EnergyNode
- High output, competes with oil for plastic production

**Nuclear Reactor** (4x4)
- Has 1 item input (uranium_rod, new advanced item)
- Consumes 1 uranium_rod every 30 seconds → produces 200 energy/s
- energy_capacity: 2000
- Has EnergyNode: 4 connections, 300 throughput each
- Requires 20 energy/s kickstart (base_energy_demand = 20, must be powered to generate)
- Endgame power source

### Transport & Storage

**Basic Energy Pole** (1x1)
- No items, no generation, no consumption
- energy_capacity: 50
- EnergyNode: 3 connections, 100 throughput, 50 inner_capacity
- Connection range: 5 tiles
- Core transport building — chains of poles form the energy backbone

**Advanced Energy Pole** (1x1)
- energy_capacity: 100
- EnergyNode: 6 connections, 250 throughput, 100 inner_capacity
- Connection range: 10 tiles
- Upgraded backbone for large factories

**Battery** (1x1)
- energy_capacity: 2000
- EnergyNode: 1 connection, 200 throughput, 2000 inner_capacity
- Huge storage buffer. Place near generators to absorb surplus, near consumers to buffer demand spikes.
- Critical for kickstarting generators after grid failure.

**Capacitor Bank** (2x2)
- energy_capacity: 5000
- EnergyNode: 2 connections, 500 throughput, 5000 inner_capacity
- Massive storage for endgame grids.

---

## Recipe Integration

### RecipeDef Changes

Add one field to `RecipeDef`:

```gdscript
@export var energy_cost: float = 0.0  # energy consumed when craft starts (0 = free)
```

### Converter Logic Changes

When a converter calls `_try_start_craft()`:

1. Gather candidate recipes (inputs available, outputs have space) — same as now
2. Sort candidates by **total output quantity** (sum of all output stacks), highest first — prefer recipes that produce more
3. For the best candidate: if `recipe.energy_cost > 0`, check `energy.energy_stored >= recipe.energy_cost`
4. If energy is sufficient: consume `energy_cost` from `energy.energy_stored`, start that recipe
5. If energy is insufficient: skip it and try the next candidate (lower output but affordable)
6. If no candidate is affordable: wait

This means converters prefer the most productive recipe they can currently afford. When energy is scarce, they naturally fall back to free/cheaper recipes.

### Base Demand Integration

In `BuildingLogic._physics_process()` (or called by EnergySystem):

- If `energy != null` and `energy.base_energy_demand > 0` and `not energy.is_powered`: skip all processing (building is idle)
- The `is_powered` flag is set by EnergySystem during the distribution step each tick

This is a clean separation: EnergySystem handles distribution, individual buildings just check `energy.is_powered`.

---

## Adjacency Transfer Detail

Buildings with `energy_capacity > 0` that physically touch (share a grid edge) automatically exchange energy. No player action needed — this is passive equalization.

For multi-cell buildings (e.g., 2x2 smelter): all cells occupied by the building count. A conveyor touching any cell of the smelter is adjacent to it. But conveyors have `energy_capacity = 0` by default, so they don't participate unless we decide otherwise.

**Which buildings participate in adjacency?**

| Building | energy_capacity | Participates? |
|----------|----------------|---------------|
| Conveyor | 0 | No |
| Drill | 0 | No |
| Smelter | 20 | Yes (small buffer for recipe energy) |
| Assembler | 50 | Yes |
| Chemical Plant | 80 | Yes |
| Advanced Factory | 120 | Yes |
| All generators | varies | Yes |
| Energy poles | varies | Yes |
| Battery / Capacitor | varies | Yes |
| Sink | 0 | No |
| Source | 0 | No |
| Splitter / Junction / Tunnel | 0 | No |

This means logistics buildings (conveyors, splitters, etc.) are transparent to energy — energy flows through the production buildings and dedicated energy infrastructure, not through belts.

---

## EnergySystem Architecture

`EnergySystem` is a new script, either an autoload singleton or a child of `GameWorld` (like `ConveyorSystem`). It owns all energy processing.

### Data Structures

```gdscript
# All buildings with energy != null, registered on placement
var energy_buildings: Array[BuildingLogic] = []

# All EnergyNode instances, registered on placement
var energy_nodes: Array[EnergyNode] = []

# Computed networks (rebuilt when dirty)
var networks: Array[EnergyNetwork] = []
var _networks_dirty: bool = true

# Tracks last placed node for auto-link on next placement
var _last_placed_node: EnergyNode = null

class EnergyNetwork:
    var buildings: Array[BuildingLogic] = []
    var generators: Array[BuildingLogic] = []  # subset where energy.generation_rate > 0
    var consumers: Array[BuildingLogic] = []   # subset where energy.base_energy_demand > 0
    var node_edges: Array[Dictionary] = []     # {from: EnergyNode, to: EnergyNode}
    var total_capacity: float = 0.0
    var total_stored: float = 0.0              # cached, updated each tick
```

### Registration

When `GameManager.place_building()` is called:
- If the building's logic has `energy != null`: register with `EnergySystem.register_building(logic)`
- If the building has an `EnergyNode` child: register with `EnergySystem.register_node(node)`, auto-link to `_last_placed_node` if in range, then set `_last_placed_node = node`
- Mark `_networks_dirty = true`

Same pattern for removal.

### Tick Processing

```gdscript
func _physics_process(delta: float) -> void:
    if _networks_dirty:
        _rebuild_networks()
        _networks_dirty = false

    for network in networks:
        _tick_network(network, delta)
```

`_tick_network` implements the 4-step algorithm described above.

---

## Energy Node Connection UX

### Link Mode Flow

1. Player clicks any building that has an `EnergyNode` → info panel opens (shows energy stats, connections)
2. Player clicks the **same building again** → enters **energy link mode**
   - A wire is drawn from the building to the cursor
   - The reachable area (connection range) is highlighted as a circle/overlay
3. As the cursor moves:
   - If hovering over a valid target (has EnergyNode, in range, both have free connection slots): wire ghost turns **green**
   - Otherwise: wire ghost stays gray/red
4. **LMB click** on a valid target → connection established, **stays in energy mode** — wire now draws from the same origin to the cursor again, ready for the next link
5. **RMB** at any time → exits energy link mode, returns to normal

### Auto-Link on Placement

When placing the **second** energy node building, it auto-links to the most recently placed node (if within range and both have free slots). The first node placed is not linked. All subsequent connections beyond the auto-link are manual via link mode.

### Visual Feedback

- Connected nodes show colored lines between them with small **blue-ish particles** moving along the wire (direction indicates flow)
- Particle speed/density scales with current energy throughput
- Buildings with `energy.is_powered == false` show a "no power" icon overlay (red lightning bolt)
- Energy bars shown on hover (small horizontal bar above building showing stored/capacity)

---

## Serialization

### Per-Building State

Buildings with `energy != null` include energy state via `BuildingEnergy.serialize()`:

```json
{
  "energy": {
    "energy_stored": 150.0
  }
}
```

### EnergyNode State

Nodes serialize their connections as grid position pairs:

```json
{
  "energy_node": {
    "connections": [
      {"x": 10, "y": 5},
      {"x": 14, "y": 5}
    ]
  }
}
```

On load, connections are restored by looking up nodes at the saved positions (similar to tunnel pair restoration).

---

## Performance Considerations

| Concern | Strategy |
|---------|----------|
| Network rebuild | Lazy rebuild on dirty flag, flood-fill O(B) |
| Per-tick distribution | O(N) per network, no iteration over pairs |
| Many small networks | Each is independent, trivially parallel if needed |
| Adjacency lookup | Reuse GameManager.buildings dictionary (O(1) per neighbor) |
| Node connections | Array iteration, typically <100 connections per network |
| Memory | ~32 bytes per building (4 floats + 1 bool), negligible |

**Worst case**: 1000 energy-capable buildings in one network = 1000 iterations per tick. At 60 FPS that's 60K simple float operations per second — trivial.

**Scaling limit**: If networks exceed ~10K buildings, consider spatial partitioning or sub-network clustering. Not needed for expected factory sizes.

---

## Implementation Plan

### Phase 1: Core Infrastructure

**1.1 — BuildingEnergy class** (`buildings/shared/building_energy.gd`)
- Standalone `RefCounted` or inner class with `energy_stored`, `energy_capacity`, `base_energy_demand`, `is_powered`, `generation_rate`
- Serialization helpers: `serialize() -> Dictionary`, `deserialize(data: Dictionary)`

**1.2 — EnergyNode script** (`buildings/shared/energy_node.gd`)
- Extends `Node2D` — positionable in scenes, supports click interaction (area detection for link mode)
- Exported properties: `max_connections`, `throughput`, `inner_capacity`, `connection_range`
- Connection management: `connect_to(other)`, `disconnect_from(other)`, `is_connected_to(other)`, `can_connect_to(other)`, `is_in_range(other)`

**1.3 — BuildingLogic integration** (`buildings/shared/building_logic.gd`)
- Add `var energy: BuildingEnergy = null` field
- Add `get_energy_node() -> EnergyNode` helper (finds child EnergyNode if present)
- Update `serialize_state()` / `deserialize_state()` base to include energy when `energy != null`
- Update `get_info_stats()` base to include energy bar when `energy != null`

**1.4 — EnergyNetwork class** (`scripts/energy/energy_network.gd`)
- Data class holding building lists, generator/consumer subsets, node edges
- `tick(delta)` method implementing the 4-step distribution algorithm

**1.5 — EnergySystem** (`scripts/energy/energy_system.gd`)
- Manages registration, dirty-flag rebuild, per-tick processing
- Added as child of GameWorld (like ConveyorSystem)
- Network flood-fill rebuild from energy_buildings + energy_nodes

**1.6 — RecipeDef energy_cost field** (`scripts/resources/recipe_def.gd`)
- Add `@export var energy_cost: float = 0.0`
- Existing recipes keep 0 (no energy needed)

**1.7 — Converter energy integration** (`buildings/smelter/converter.gd`)
- Modify `_try_start_craft()` to sort candidates by total output quantity (highest first)
- For each candidate: if `energy_cost > 0`, check `energy.energy_stored >= recipe.energy_cost`
- Consume `energy_cost` from `energy.energy_stored` on craft start, fall back to cheaper recipe if insufficient
- Check `energy.is_powered` before processing (skip if `energy.base_energy_demand > 0` and not powered)

**1.8 — GameManager registration hooks**
- On `place_building`: register energy-capable buildings/nodes with EnergySystem
- On `remove_building`: deregister, mark networks dirty

### Phase 2: First Energy Buildings

**2.1 — Coal Burner** (`buildings/coal_burner/`)
- 1x2 building, 1 input side (pulls coal), no item output
- Logic extends BuildingLogic: timer consumes 1 coal every 4s → adds 100 energy per coal (25 energy/s)
- BuildingEnergy: energy_capacity 200, generation_rate 25

**2.2 — Basic Energy Pole** (`buildings/energy_pole/`)
- 1x1 building, no items
- Has EnergyNode (Node2D) child: 3 connections, 100 throughput, 50 inner_capacity, range 5
- BuildingEnergy: energy_capacity 50
- Energy link mode UI (click-click-to-enter, LMB to link, RMB to exit)

**2.3 — Battery** (`buildings/battery/`)
- 1x1 building, no items
- Has EnergyNode child: 1 connection, 200 throughput, 2000 inner_capacity
- energy_capacity: 2000

**2.4 — Solar Panel** (`buildings/solar_panel/`)
- 1x1 building, no items, no inputs
- Passive generation: 8 energy/s
- BuildingEnergy: energy_capacity 30

### Phase 3: Visual Feedback & UX

**3.1 — Power status overlay**
- "No power" icon on unpowered buildings
- Energy bar on hover (small horizontal bar)

**3.2 — Node connection visuals**
- Colored lines between connected energy nodes
- Small blue-ish particles moving along wires (direction = flow direction)
- Particle speed/density scales with throughput utilization

**3.3 — Link mode**
- Click node building → info panel; click again → energy mode
- Wire drawn to cursor, range circle highlighted
- Green wire ghost on valid targets; LMB links and stays in mode; RMB exits

**3.4 — Info panel energy stats**
- Energy stored/capacity bar
- Generation/consumption rates
- Connection list for nodes

### Phase 4: Powered Recipes & Content

**4.1 — Powered recipe variants**
- Create `.tres` for powered smelter recipes (smelt_iron_powered, forge_steel_powered, etc.)
- Set `energy_cost` on each

**4.2 — Existing building energy values**
- Set `energy_capacity` and `base_energy_demand` on Assembler, Chemical Plant, etc.
- These buildings now require power to function

**4.3 — Geothermal vent deposit**
- New source tile type on TileMapLayer
- Geothermal Plant building placed on it

**4.4 — Remaining generators**
- Wind Turbine, Gas Turbine, Nuclear Reactor
- uranium_rod item and its recipe chain

### Phase 5: Testing

**5.1 — Unit tests**
- EnergyNode connection logic
- EnergyNetwork distribution math
- Converter recipe selection with energy

**5.2 — Simulation tests**
- `sim_energy_basic`: coal burner → pole → smelter, verify powered recipe selected
- `sim_energy_grid`: multiple generators, consumers, verify proportional distribution
- `sim_energy_kickstart`: nuclear reactor boot sequence

**5.3 — Performance benchmark**
- 500+ energy buildings in one network, verify tick time < 1ms

---

## New Items for Energy Economy

| Item | Category | Source | Used In |
|------|----------|--------|---------|
| coal | raw | Coal Seam (existing) | Coal Burner fuel, Steel recipe |
| oil | raw | Oil Geyser | Gas Turbine fuel, Plastic recipe |
| uranium_ore | raw | Uranium Deposit (new) | Uranium Rod recipe |
| uranium_rod | intermediate | Assembler: 2 uranium_ore + 1 steel | Nuclear Reactor fuel |

Coal and oil already exist as planned items. Only uranium_ore and uranium_rod are new additions for the energy system.

### New Deposit Type

| Deposit | Extractor | Rate | Notes |
|---------|-----------|------|-------|
| Geothermal Vent | Geothermal Plant | N/A (no items) | Energy only, no resource extraction |
| Uranium Deposit | Drill | 1 / 5s | Slow, rare deposit |

---

## Design Decisions (Resolved)

1. **Conveyors do NOT conduct energy.** Transport buildings (conveyors, splitters, junctions, tunnels) are invisible to the energy grid. Energy flows through production buildings and dedicated energy infrastructure only.
2. **Connection range is fixed per building type.** Basic pole = 5 tiles, advanced pole = 10 tiles. No research scaling.
3. **Visual style:** Colored lines between connected nodes with small blue-ish particles moving along the wire. Particle direction indicates flow direction, speed/density indicates throughput.
4. **Auto-link behavior:** The first energy node placed is unlinked. The second auto-links to the first (if in range). All subsequent connections are manual via link mode.
5. **Grid failure is graceful degradation.** Proportional rationing — when energy is insufficient, all buildings with base demand get the same fraction. No blackout/brownout cascade.
