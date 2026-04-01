# Content Update: Rings 4-5 (Chemistry, Biotech, Nuclear, Quantum)

This document describes everything added during the Rings 4-5 content expansion.

## Summary

- **26 new items** across 6 categories (4 raw, 10 intermediate, 4 component, 4 advanced, 3 pinnacle, 1 science)
- **25 new recipes** across 8 converter types
- **8 new buildings** including 3 multipart buildings with non-rectangular shapes
- **2 new research rings** (Ring 4 and Ring 5) with 10 new tech nodes
- **4 new terrain resource deposits** with full world generation and terrain sprites
- **1 new science pack** (Purple, Science Pack 4)
- **New "pinnacle" item tier** above advanced

---

## New Items

### Raw Resources (4)

| Item | Atlas | Color | Export | Notes |
|------|-------|-------|--------|-------|
| Oil | 37 | Dark brown-black | 2 | Extracted by Pump from oil seep deposits |
| Crystal | 38 | Purple/violet | 3 | Rare crystalline deposit, spawns far from spawn |
| Uranium Ore | 39 | Green glow | 4 | Very rare radioactive ore, far deposits only |
| Biomass | 40 | Organic green | 1 | Organic clusters, mid-range and far deposits |

### Intermediates (10)

| Item | Atlas | Recipe Source | Energy | Notes |
|------|-------|-------------|--------|-------|
| Plastic | 41 | 2 oil -> 1 plastic (chemical plant) | 30 | Basis for casings and components |
| Rubber | 42 | 2 oil -> 1 rubber (chemical plant) | 30 | Used for insulation |
| Acid | 43 | 1 sulfur + 1 oil -> 2 acid (chemical plant) | 40 | Key reagent for bio/carbon chemistry |
| Silicon | 44 | 2 quartz + 1 coal -> 1 silicon (smelter) | 60 | Semiconductor material |
| Carbon Fiber | 45 | 2 coal + 1 acid -> 1 carbon fiber (chemical plant) | 50 | High-strength material |
| Refined Uranium | 46 | 3 uranium ore -> 1 refined uranium (centrifuge) | 100 | Purified nuclear fuel |
| Bio Compound | 47 | 2 biomass + 1 acid -> 1 bio compound (chemical plant) | 40 | Organic processing base |
| Ceramic | 48 | 1 brick + 1 quartz -> 1 ceramic (smelter) | 40 | Heat-resistant material |
| Alloy Plate | 49 | 1 steel + 1 tin plate -> 1 alloy plate (smelter) | 60 | Advanced metallic plate |
| Insulated Wire | 50 | 2 copper wire + 1 rubber -> 2 insulated wire (assembler) | 30 | Protected wiring |

### Components (4)

| Item | Atlas | Recipe Source | Energy |
|------|-------|-------------|--------|
| Heat Sink | 51 | 1 alloy plate + 1 copper ring -> 1 heat sink (press) | 30 |
| Filter | 52 | 1 carbon fiber + 1 glass -> 1 filter (press) | 20 |
| Plastic Casing | 53 | 2 plastic -> 1 plastic casing (press) | 20 |
| Crystal Oscillator | 54 | 1 crystal + 2 gold wire -> 1 crystal oscillator (assembler) | 60 |

### Advanced (4)

| Item | Atlas | Recipe Source | Energy |
|------|-------|-------------|--------|
| Quantum Chip | 55 | 1 advanced circuit + 1 crystal oscillator + 2 silicon (particle accelerator) | 200 |
| Nano Fiber | 56 | 2 carbon fiber + 1 bio compound + 1 silicon (assembler mk2) | 150 |
| Fusion Cell | 57 | 1 refined uranium + 1 heat sink + 1 battery cell (centrifuge) | 150 |
| Robot Arm | 58 | 1 motor + 1 processor + 1 plastic casing (assembler mk2) | 120 |

### Science Pack

| Item | Atlas | Recipe Source | Energy |
|------|-------|-------------|--------|
| Science Pack 4 (Purple) | 59 | 1 robot arm + 1 fusion cell + 1 nano fiber (assembler mk2) | 200 |

### Pinnacle Tier (3) -- new category above advanced

| Item | Atlas | Recipe Source | Energy | Export |
|------|-------|-------------|--------|--------|
| Quantum Computer | 60 | 2 quantum chip + 1 nano fiber + 1 robot arm (fabricator) | 300 | 120 |
| Power Armor | 61 | 1 fusion cell + 2 nano fiber + 1 robo frame (fabricator) | 300 | 150 |
| Terraformer | 62 | 1 quantum computer + 1 engine + 2 fusion cell (fabricator) | 500 | 200 |

---

## New Buildings

### Standard Buildings

| Building | Size | Category | Type | Unlock | Build Cost |
|----------|------|----------|------|--------|------------|
| Pump | 1x1 | Extractor | ExtractorLogic | tech_pump | 4 steel + 2 pipe |
| Chemical Plant | 2x2 | Converter | ConverterLogic | tech_chemical_plant | 6 steel + 4 pipe + 2 glass |
| Centrifuge | 2x2 | Converter | ConverterLogic | tech_centrifuge | 8 steel + 4 gear + 2 motor |
| Greenhouse | 2x1 | Converter | ConverterLogic | tech_greenhouse | 4 glass + 4 brick + 2 pipe |
| Pipeline | 1x1 pair | Transport | PipelineLogic | tech_pipeline | 2 steel + 1 pipe (each) |

### Multipart Buildings (non-rectangular shapes)

**Particle Accelerator** -- L-shaped, 5 cells
```
[X][X][X]
[X]
[X]
```
- Converter type: `particle_accelerator`
- Makes: Quantum Chip
- Energy: 300 capacity, 20 demand, 200 throughput
- Cost: 10 steel frame + 4 advanced circuit + 8 glass lens + 6 gold wire

**Fabricator** -- T-shaped, 5 cells
```
[X][X][X]
   [X]
   [X]
```
- Converter type: `fabricator`
- Makes: Quantum Computer, Power Armor, Terraformer
- Energy: 400 capacity, 25 demand, 300 throughput
- Cost: 10 steel frame + 4 processor + 6 motor + 4 concrete

**Nuclear Reactor** -- Cross/plus-shaped, 5 cells
```
   [X]
[X][X][X]
   [X]
```
- Converter type: `nuclear_reactor`
- Generator: 1 fusion cell -> 1000 energy (20s)
- Energy: 1200 capacity, 500 throughput, range 8
- Cost: 10 concrete + 6 steel frame + 4 advanced circuit + 4 pipe

### Pipeline (multi-phase transport)

Works like tunnels but with longer range (10 tiles vs 5). Place input endpoint, then output endpoint. Items teleport between them. Useful for late-game logistics.

---

## New Recipes (25 total)

### Chemical Plant (5)
- make_plastic: 2 oil -> 1 plastic (3s, 30E)
- make_rubber: 2 oil -> 1 rubber (3s, 30E)
- make_acid: 1 sulfur + 1 oil -> 2 acid (4s, 40E)
- make_carbon_fiber: 2 coal + 1 acid -> 1 carbon fiber (5s, 50E)
- make_bio_compound: 2 biomass + 1 acid -> 1 bio compound (4s, 40E)

### Smelter (3 new)
- smelt_silicon: 2 quartz + 1 coal -> 1 silicon (5s, 60E)
- smelt_ceramic: 1 brick + 1 quartz -> 1 ceramic (4s, 40E)
- smelt_alloy: 1 steel + 1 tin plate -> 1 alloy plate (5s, 60E)

### Press (3 new)
- press_heat_sink: 1 alloy plate + 1 copper ring -> 1 heat sink (3s, 30E)
- press_filter: 1 carbon fiber + 1 glass -> 1 filter (3s, 20E)
- press_plastic_casing: 2 plastic -> 1 plastic casing (2s, 20E)

### Assembler (2 new)
- assemble_insulated_wire: 2 copper wire + 1 rubber -> 2 insulated wire (3s, 30E)
- assemble_crystal_oscillator: 1 crystal + 2 gold wire -> 1 crystal oscillator (5s, 60E)

### Assembler Mk2 (3 new)
- assemble_robot_arm: 1 motor + 1 processor + 1 plastic casing -> 1 robot arm (10s, 120E)
- assemble_nano_fiber: 2 carbon fiber + 1 bio compound + 1 silicon -> 1 nano fiber (12s, 150E)
- assemble_science_pack_4: 1 robot arm + 1 fusion cell + 1 nano fiber -> 1 science pack 4 (20s, 200E)

### Centrifuge (2)
- refine_uranium: 3 uranium ore -> 1 refined uranium (8s, 100E)
- make_fusion_cell: 1 refined uranium + 1 heat sink + 1 battery cell -> 1 fusion cell (10s, 150E)

### Particle Accelerator (1)
- make_quantum_chip: 1 advanced circuit + 1 crystal oscillator + 2 silicon -> 1 quantum chip (15s, 200E)

### Fabricator (3)
- fabricate_quantum_computer: 2 quantum chip + 1 nano fiber + 1 robot arm -> 1 quantum computer (20s, 300E)
- fabricate_power_armor: 1 fusion cell + 2 nano fiber + 1 robo frame -> 1 power armor (20s, 300E)
- fabricate_terraformer: 1 quantum computer + 1 engine + 2 fusion cell -> 1 terraformer (25s, 500E)

### Generators (2 new)
- nuclear_fission: 1 fusion cell -> 1000 energy (20s) -- Nuclear Reactor
- burn_biomass: 1 biomass -> 60 energy (3s) -- Coal Burner

### Greenhouse (1)
- grow_biomass: 1 bio compound -> 3 biomass (10s, 50E) -- renewable loop!

---

## Research Tree Expansion

### Ring 4 (costs SP1+SP2+SP3, unlocked by gate contract)

| Tech | Cost | Unlocks | Dependencies |
|------|------|---------|-------------|
| tech_pump | 20 SP1, 20 SP2, 10 SP3 | Pump | assembler_mk2 |
| tech_chemical_plant | 30 SP1, 30 SP2, 20 SP3 | Chemical Plant | assembler_mk2, pump |
| tech_centrifuge | 30 SP1, 30 SP2, 30 SP3 | Centrifuge | assembler_mk2 |
| tech_greenhouse | 20 SP2, 20 SP3 | Greenhouse | fuel_generator, assembler_mk2 |
| tech_pipeline | 20 SP1, 20 SP2, 20 SP3 | Pipeline | conveyor_mk3 |
| tech_cartography_4 | 30 SP2, 30 SP3, 5 engine | Zoom 0.5x | cartography_3 |

### Ring 5 (costs SP2+SP3+SP4, unlocked by gate contract)

| Tech | Cost | Unlocks | Dependencies |
|------|------|---------|-------------|
| tech_particle_accelerator | 30 SP2, 30 SP3, 20 SP4 | Particle Accelerator | chemical_plant, centrifuge |
| tech_fabricator | 40 SP2, 40 SP3, 30 SP4 | Fabricator | particle_accelerator, chemical_plant |
| tech_nuclear_reactor | 40 SP3, 30 SP4 | Nuclear Reactor | centrifuge |
| tech_cartography_5 | 30 SP3, 20 SP4, 2 quantum computer | Zoom 0.35x | cartography_4 |

### Ring Colors
- Ring 4: Orange (#CC8833)
- Ring 5: Purple (#9933CC)

### Gate Contracts
- **Ring 3 -> Ring 4**: 10 processor + 5 engine + 5 robo frame
- **Ring 4 -> Ring 5**: 5 robot arm + 5 nano fiber + 5 fusion cell

---

## World Generation

### New Terrain Deposits

| Tile ID | Resource | Spawn Range | Count | Notes |
|---------|----------|-------------|-------|-------|
| TILE_OIL (12) | Oil | 22-40 tiles | 2 deposits | Dark iridescent pools |
| TILE_CRYSTAL (13) | Crystal | 32-44 tiles | 2 deposits | Rare purple prismatic |
| TILE_URANIUM (14) | Uranium Ore | 34-46 tiles | 2 deposits | Very rare, green glow |
| TILE_BIOMASS (15) | Biomass | 14-34 tiles | 2 deposits | Organic, closer to spawn |

Terrain atlas expanded from 8x10 to 8x14 grid (256x448 pixels). Each new deposit type has unique procedural background, foreground veins/formations, and misc detail sprites.

---

## Progression Flow (no softlocks)

```
Ring 0-3 (existing) -> Gate: 10 processor + 5 engine + 5 robo frame
                              |
                        Ring 4 unlocked
                              |
    +-- Pump (oil extraction)
    +-- Chemical Plant (plastics, rubber, acid, carbon fiber, bio compound)
    +-- Centrifuge (refined uranium, fusion cells)
    +-- Greenhouse (renewable biomass loop)
    +-- Pipeline (long-range transport)
                              |
    Can now craft: robot arm, nano fiber, fusion cell
    Can now craft: Science Pack 4 (Purple)
                              |
                   Gate: 5 robot arm + 5 nano fiber + 5 fusion cell
                              |
                        Ring 5 unlocked
                              |
    +-- Particle Accelerator (quantum chips)
    +-- Fabricator (quantum computer, power armor, terraformer)
    +-- Nuclear Reactor (1000 energy from fusion cells)
```

### Key Renewable Loop

Greenhouse creates a sustainable biomass cycle:
```
biomass + acid -> bio compound (chemical plant)
bio compound -> 3 biomass (greenhouse)
```
This means biomass is not exhaustible once you have a greenhouse + chemical plant running.

---

## Technical Changes

### Item Atlas
- Expanded from 8x5 (40 slots) to 8x8 (64 slots)
- `item_visual_manager.gd`: Updated `ATLAS_ROWS` 5->8 and shader `ROWS` 5.0->8.0
- `generate_atlas.lua`: 26 new item draw functions with unique pixel art silhouettes

### Converter Energy Config
New entries in `ConverterLogic.ENERGY_CONFIG`:
- `chemical_plant`: capacity=120, demand=8
- `centrifuge`: capacity=200, demand=15
- `greenhouse`: capacity=80, demand=5
- `particle_accelerator`: capacity=300, demand=20
- `fabricator`: capacity=400, demand=25
- `nuclear_reactor`: capacity=1200, demand=0

### Buildings Panel
- Added `pipeline` category mapped to "Transportation"
- Added `pipeline_output` to hidden categories

### Contract Manager
- Added Ring 4 and 5 item pools for side contract generation
- Added gate contract definitions for rings 4 and 5

### Research Lab
- Updated `_accepted_packs` to include `science_pack_4`

### Pipeline System
- New `PipelineLogic` extending `BuildingLogic` (similar to TunnelLogic)
- Max distance: 10 tiles (vs tunnel's 5)
- Registered in `GameManager._register_placement_phases()`

---

## Testing

### New Simulation: `sim_content_update`

Verifies:
1. All 26 new items registered with correct atlas indices (37-62)
2. Items spawn on conveyors with distinct sprites (visual screenshot)
3. Chemical Plant placement + 5 recipes loaded
4. Particle Accelerator L-shape: 5 cells occupied, 2 gaps verified free
5. Fabricator T-shape: 5 cells occupied, gaps verified free
6. Nuclear Reactor cross-shape placement
7. Greenhouse: 1 recipe loaded
8. Centrifuge: 2 recipes loaded
9. Pump: extracts oil from deposits (299 items in 15s headless)
10. Ring 4 and 5 techs exist in research tree
11. Gate 4 and 5 contracts defined

Run: `$GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- sim_content_update`

Screenshot mode: `$GODOT --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- sim_content_update --screenshot-baseline`
