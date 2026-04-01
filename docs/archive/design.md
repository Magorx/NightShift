# Factor - Game Design Document

## Overview

**Factor** is a 2D top-down factory-building game inspired by Mindustry, Factorio, Opus Magnum, and Satisfactory. The player extracts resources, transports them via conveyors, processes them through converters, and delivers finished products to sinks to progress. The visual style is low-poly/flat with clean geometric shapes and a muted industrial palette.

## Core Loop

1. **Extract** raw resources from sources
2. **Transport** resources via conveyors and logistics
3. **Convert** resources into intermediate and advanced products
4. **Deliver** products to sinks to earn progress/currency
5. **Unlock** new buildings, recipes, and map areas
6. **Optimize** throughput and layout

---

## Core Mechanics

### 1. Resources

Resources are discrete items that move through the factory as individual units on conveyors. Each resource has:

- **ID** — unique identifier
- **Display name** and **icon** (32x32 sprite)
- **Tasg** — raw, liquid, ...
- **Stack size** — max units per conveyor tile (default: 1)

#### Raw Resources

| Resource     | Color   | Found In         |
|-------------|---------|------------------|
| Iron Ore    | Gray    | Iron Deposits    |
| Copper Ore  | Orange  | Copper Deposits  |
| Coal        | Black   | Coal Seams       |
| Quartz Sand | Beige   | Sand Pits        |
| Water       | Blue    | Water Wells      |
| Oil         | Dark    | Oil Geysers      |

#### Intermediate Resources

| Resource       | Made From                  |
|---------------|---------------------------|
| Iron Plate    | Iron Ore                  |
| Copper Wire   | Copper Ore                |
| Steel         | Iron Plate + Coal         |
| Glass         | Quartz Sand               |
| Circuit       | Copper Wire + Glass       |
| Plastic       | Oil                       |

#### Advanced Resources

| Resource          | Made From                      |
|------------------|-------------------------------|
| Processor        | Circuit + Steel               |
| Battery          | Copper Wire + Plastic + Coal  |
| Engine           | Steel + Circuit + Plastic     |
| Solar Panel      | Glass + Circuit + Steel       |

---

### 2. Sources

Sources are map features that produce raw resources when a matching **Extractor** building is placed on them.

| Source Type    | Extractor Building | Base Rate     | Notes                          |
|---------------|-------------------|---------------|--------------------------------|
| Iron Deposit  | Drill             | 1 item/2s     | Infinite, rate upgradeable     |
| Copper Deposit| Drill             | 1 item/2s     | Infinite, rate upgradeable     |
| Coal Seam     | Drill             | 1 item/2.5s   | Infinite, rate upgradeable     |
| Sand Pit      | Dredger           | 1 item/3s     | Infinite                       |
| Water Well    | Pump              | 1 item/1.5s   | Infinite, requires power       |
| Oil Geyser    | Pumpjack          | 1 item/4s     | Infinite, requires power       |

**Characteristics:**
- Sources are fixed locations on the map — the player builds around them
- Each source has a finite number of extractor slots (typically 1-3)
- Extractors output items onto an adjacent conveyor tile
- Higher-tier extractors increase output rate

---

### 3. Conveyors

Conveyors move items from one tile to the next in a fixed direction.

| Conveyor Tier | Speed (tiles/s) | Unlock        |
|--------------|-----------------|---------------|
| Basic        | 1               | Start         |
| Fast         | 2               | Tier 2        |
| Express      | 4               | Tier 3        |

**Characteristics:**
- Each conveyor tile holds at most 1 item at a time
- Items move in the direction the conveyor faces
- Conveyors auto-connect to adjacent conveyors, extractors, converters, and sinks
- Conveyor placement snaps to the tile grid

#### Special Conveyor Buildings

| Building     | Function                                            |
|-------------|-----------------------------------------------------|
| Splitter    | 1 input, 2-3 outputs — distributes items evenly     |
| Merger      | 2-3 inputs, 1 output — merges streams               |
| Bridge      | Tunnels items over 1-4 tiles, crossing other belts  |
| Router      | 1 input, distributes to all adjacent outputs         |
| Sorter      | 1 input, routes a specific item type to side output  |
| Overflow    | Passes items to side output only when main is full   |
| Underflow   | Passes items to side output only when main is empty  |

---

### 4. Converters

Converters are buildings that consume input items and produce output items according to a recipe.

| Converter Type   | Size  | Input Slots | Output Slots | Base Craft Time |
|-----------------|-------|-------------|-------------- |-----------------|
| Smelter         | 2x2   | 1           | 1             | 3s              |
| Assembler       | 3x3   | 2           | 1             | 5s              |
| Chemical Plant  | 3x3   | 2           | 1-2           | 6s              |
| Advanced Factory| 4x4   | 3           | 1-2           | 8s              |

**Characteristics:**
- Each converter has designated input/output sides (configurable in-editor)
- Converters pull items from adjacent conveyors on input sides
- Converters push finished items onto adjacent conveyors on output sides
- If the output is blocked (conveyor full), the converter pauses
- Converters can be rotated in 90-degree increments
- Each converter type can only process recipes assigned to its category

---

### 5. Recipes

Recipes define what a converter transforms. Each recipe specifies:

- **Converter type** it runs in
- **Inputs** — list of (resource, quantity) pairs
- **Outputs** — list of (resource, quantity) pairs
- **Craft time** — seconds per cycle (overrides converter base time)

#### Recipe Table

| Recipe              | Converter       | Inputs                          | Outputs          | Time |
|--------------------|----------------|---------------------------------|-----------------|------|
| Smelt Iron         | Smelter        | 1 Iron Ore                      | 1 Iron Plate    | 3s   |
| Draw Copper Wire   | Smelter        | 1 Copper Ore                    | 2 Copper Wire   | 3s   |
| Forge Steel        | Smelter        | 1 Iron Plate + 1 Coal           | 1 Steel         | 4s   |
| Melt Glass         | Smelter        | 2 Quartz Sand                   | 1 Glass         | 4s   |
| Refine Plastic     | Chemical Plant | 2 Oil                           | 1 Plastic       | 5s   |
| Make Circuit       | Assembler      | 2 Copper Wire + 1 Glass         | 1 Circuit       | 5s   |
| Make Processor     | Assembler      | 2 Circuit + 1 Steel             | 1 Processor     | 8s   |
| Make Battery       | Assembler      | 1 Copper Wire + 1 Plastic + 1 Coal | 1 Battery   | 6s   |
| Build Engine       | Adv. Factory   | 2 Steel + 1 Circuit + 1 Plastic | 1 Engine        | 10s  |
| Build Solar Panel  | Adv. Factory   | 2 Glass + 1 Circuit + 1 Steel   | 1 Solar Panel   | 10s  |

Recipes are defined as Godot Resources (`.tres` files) so they can be edited in the inspector.

---

### 6. Sinks

Sinks consume finished products and reward the player with **Progress Points (PP)** and/or currency.

| Sink Type        | Accepts            | Reward                          |
|-----------------|--------------------|---------------------------------|
| Export Terminal  | Any item           | Currency proportional to complexity |
| Research Lab    | Specific items     | Unlocks new tech/buildings       |
| Mission Target  | Mission-specific   | Mission completion + bonus PP    |

**Characteristics:**
- Export Terminal accepts any item; value scales with recipe chain depth
- Research Lab requires specific items in specific quantities to unlock tech tree nodes
- Mission Targets are per-level objectives (e.g., "deliver 50 Processors")
- Sinks pull items from adjacent conveyors (same as converter inputs)
- Sinks have infinite capacity — they never block

#### Progression Value Table

| Item          | Export Value | Research Value |
|--------------|-------------|----------------|
| Raw resource | 1           | -              |
| Iron Plate   | 3           | 1              |
| Steel        | 8           | 3              |
| Circuit      | 15          | 5              |
| Processor    | 40          | 12             |
| Engine       | 50          | 15             |
| Solar Panel  | 45          | 14             |

---

### 7. Power (Future Expansion)

Some buildings require power. Power is generated by:
- **Coal Generator** — consumes Coal, produces power
- **Solar Array** — passive power during day cycle
- Power is distributed globally (no wires in v1)

---

### 8. Tech Tree

The tech tree is a directed graph of unlockable nodes. Each node requires delivering specific items to a Research Lab. Unlocking a node grants access to new buildings, recipes, conveyor tiers, or extractor upgrades.

---

## Map & Levels

- Maps are tile-based grids (e.g., 128x128 or 256x256)
- Maps are authored as Godot TileMap scenes
- Each map has pre-placed source locations
- Campaign: linear sequence of maps with increasing complexity
- Sandbox: large open map with all source types

---

## Visual Style

- Top-down 2D, 32x32 pixel tile grid
- Flat/low-poly aesthetic with limited color palette
- Buildings are simple geometric shapes with clear silhouettes
- Items on conveyors are small colored icons
- Minimal UI — context appears on hover/select
