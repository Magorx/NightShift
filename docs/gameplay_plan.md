# Gameplay Implementation Plan

## Resource Tree

### Raw Resources (8) - Mined by drills from deposits
| ID | Name | Color | Rarity | Notes |
|---|---|---|---|---|
| iron_ore | Iron Ore | Gray #8C8C8C | Common | Foundation metal |
| copper_ore | Copper Ore | Orange-brown #E08833 | Common | Electrical foundation |
| coal | Coal | Dark #262626 | Common | Fuel + ingredient |
| stone | Stone | Tan #B8A882 | Common | Building material |
| tin_ore | Tin Ore | Silver-blue #8CA8B8 | Medium | Alloys + containers |
| gold_ore | Gold Ore | Yellow #D4AA30 | Rare | Electronics |
| quartz | Quartz | Crystal blue #7BB8D0 | Medium | Glass + optics |
| sulfur | Sulfur | Yellow-green #C8C832 | Rare | Chemistry |

### Smelted / Basic Processing (7) - Smelter recipes
| ID | Name | Recipe | Time | Energy |
|---|---|---|---|---|
| iron_plate | Iron Plate | 1 iron_ore | 3s | 0 (free) |
| copper_plate | Copper Plate | 1 copper_ore | 3s | 0 |
| tin_plate | Tin Plate | 1 tin_ore | 3s | 0 |
| gold_ingot | Gold Ingot | 1 gold_ore | 4s | 50 |
| steel | Steel | 2 iron_plate + 1 coal | 5s | 80 |
| glass | Glass | 2 quartz | 4s | 40 |
| brick | Brick | 2 stone | 3s | 0 |

### Tier 1 Components (8) - Press / Wire Drawer
| ID | Name | Building | Recipe | Time |
|---|---|---|---|---|
| copper_wire | Copper Wire | Wire Drawer | 1 copper_plate → 2 | 2s |
| gold_wire | Gold Wire | Wire Drawer | 1 gold_ingot → 2 | 3s |
| iron_gear | Iron Gear | Press | 2 iron_plate | 2s |
| iron_tube | Iron Tube | Press | 1 iron_plate | 1.5s |
| tin_can | Tin Can | Press | 1 tin_plate | 1.5s |
| steel_beam | Steel Beam | Press | 2 steel | 3s |
| glass_lens | Glass Lens | Press | 1 glass | 2s |
| coke | Coke | Coke Oven | 2 coal → 1 | 4s |

### Tier 2 Assembly (6) - Assembler Mk1
| ID | Name | Recipe | Time | Energy |
|---|---|---|---|---|
| circuit_board | Circuit Board | 2 copper_wire + 1 glass | 4s | 30 |
| motor | Motor | 2 iron_gear + 4 copper_wire + 1 iron_tube | 6s | 50 |
| battery_cell | Battery Cell | 1 tin_can + 1 sulfur + 2 copper_wire | 5s | 40 |
| steel_frame | Steel Frame | 4 steel_beam | 4s | 30 |
| insulated_wire | Insulated Wire | 2 copper_wire + 1 rubber... | - | - |

Actually: replace insulated_wire with:
| concrete | Concrete | 3 brick + 1 iron_plate | 4s | 20 |
| pipe | Pipe | 2 iron_tube + 1 copper_plate | 3s | 20 |

### Tier 3 Advanced (4) - Assembler Mk2
| ID | Name | Recipe | Time | Energy |
|---|---|---|---|---|
| advanced_circuit | Advanced Circuit | 1 circuit_board + 2 gold_wire + 1 glass_lens | 8s | 80 |
| processor | Processor | 2 advanced_circuit + 4 gold_wire | 10s | 120 |
| robo_frame | Robo Frame | 1 steel_frame + 2 motor + 1 advanced_circuit | 12s | 150 |
| engine | Engine | 2 motor + 2 pipe + 1 steel_frame | 10s | 100 |

### Science Packs (3) - Consumed by Research Lab
| ID | Name | Recipe | Building | Time | Energy |
|---|---|---|---|---|---|
| science_pack_1 | Science Pack (Red) | 1 iron_gear + 1 copper_wire | Hand Assembler | 6s | 0 |
| science_pack_2 | Science Pack (Green) | 1 circuit_board + 2 iron_tube + 1 brick | Assembler Mk1 | 10s | 40 |
| science_pack_3 | Science Pack (Blue) | 1 motor + 1 advanced_circuit + 1 steel_frame | Assembler Mk2 | 15s | 100 |

**Total: 8 raw + 7 smelted + 8 components + 6 assembly + 4 advanced + 3 science = 36 items**

---

## Buildings

### Transport
| ID | Name | Size | Speed | Capacity | Cost | Unlock |
|---|---|---|---|---|---|---|
| conveyor | Conveyor Mk1 | 1x1 | 1x | 2 | 1 iron_plate | Start |
| conveyor_mk2 | Conveyor Mk2 | 1x1 | 2x | 3 | 1 iron_plate + 1 iron_gear | Tier 1 |
| conveyor_mk3 | Conveyor Mk3 | 1x1 | 3x | 4 | 1 steel + 1 iron_gear | Tier 2 |
| junction | Junction | 1x1 | 1x | 1/dir | 2 iron_plate | Start |
| splitter | Splitter | 1x1 | 1x | 1/dir | 2 iron_plate + 1 iron_gear | Start |
| tunnel_input | Tunnel | 1x1+1x1 | 1x | dist | 4 iron_plate | Start |

### Production
| ID | Name | Size | Category | Cost | Unlock |
|---|---|---|---|---|---|
| drill | Drill | 1x1 | extractor | 2 iron_plate + 1 iron_gear | Start |
| drill_mk2 | Drill Mk2 | 1x1 | extractor | 4 steel + 2 motor | Tier 2 |
| smelter | Smelter | 2x3 | converter | 4 brick + 4 iron_plate | Start |
| press | Press | 2x1 | converter | 6 iron_plate + 2 iron_gear | Tier 1 |
| wire_drawer | Wire Drawer | 1x2 | converter | 4 copper_plate + 2 iron_gear | Tier 1 |
| hand_assembler | Hand Assembler | 1x1 | converter | 4 iron_plate | Start |
| assembler_mk1 | Assembler Mk1 | 2x2 | converter | 6 steel + 4 iron_gear + 2 circuit_board | Tier 2 |
| assembler_mk2 | Assembler Mk2 | 3x2 | converter | 4 steel_frame + 4 motor + 2 advanced_circuit | Tier 3 |
| coke_oven | Coke Oven | 1x2 | converter | 8 brick | Tier 1 |
| chemical_plant | Chemical Plant | 2x2 | converter | 4 steel + 4 pipe + 2 circuit_board | Tier 2 |

### Energy
| ID | Name | Size | Output | Cost | Unlock |
|---|---|---|---|---|---|
| coal_burner | Coal Burner | 2x1 | 25/s (coal) | 4 iron_plate + 2 brick | Start |
| fuel_generator | Fuel Generator | 2x2 | 50/s (coke) | 6 steel + 2 motor + 4 pipe | Tier 2 |
| solar_panel | Solar Panel | 1x1 | 8/s | 4 glass + 2 copper_wire | Tier 1 |
| energy_pole | Energy Pole | 1x1 | relay | 2 iron_plate + 2 copper_wire | Start |
| battery | Battery | 1x1 | 2000 store | 4 tin_plate + 2 copper_wire | Start |

### Research
| ID | Name | Size | Function | Cost | Unlock |
|---|---|---|---|---|---|
| research_lab | Research Lab | 2x2 | Consumes science packs | 8 iron_plate + 4 copper_wire + 4 iron_gear | Tier 1 |

### Logistics
| ID | Name | Size | Function | Cost | Unlock |
|---|---|---|---|---|---|
| sink | Sink | 1x1 | Consumes items for contracts | 4 iron_plate | Start |
| source | Source | 1x1 | Dev/testing only | - | - |

---

## Research Tree

### Structure
- Ring-based: each ring requires specific science packs
- Contracts gate key milestones (caps between rings)
- Unlocked rings are exponentially larger (more techs to choose from)

### Ring 0 (Free - Starting techs)
- Conveyor Mk1, Drill, Smelter, Hand Assembler, Coal Burner, Sink, Junction, Splitter, Tunnel, Energy Pole, Battery

### Ring 1 (Red Science Packs - 10 packs each)
- Press (10 red)
- Wire Drawer (10 red)
- Solar Panel (10 red)
- Coke Oven (10 red)
- Conveyor Mk2 (15 red)
- Research Lab (5 red) [meta: unlocks consuming green]
- **CONTRACT GATE: Deliver 20 iron_plate + 10 copper_wire** → unlocks Ring 2

### Ring 2 (Red + Green Science Packs - 20 each)
- Assembler Mk1 (20R + 20G)
- Chemical Plant (20R + 20G)
- Drill Mk2 (15R + 15G)
- Fuel Generator (20R + 20G)
- Conveyor Mk3 (15R + 15G)
- **CONTRACT GATE: Deliver 10 motor + 10 circuit_board** → unlocks Ring 3

### Ring 3 (Red + Green + Blue Science Packs - 50 each)
- Assembler Mk2 (50R + 50G + 50B)
- Advanced recipes
- **CONTRACT GATE: Deliver 5 processor + 5 robo_frame** → endgame

---

## Contract System

### Design
- Contracts are dynamically generated, not hardcoded
- Each contract specifies items to deliver to sinks
- Difficulty scales with current tech level
- Completing contracts unlocks ring gates (key progression milestones)
- Between gates, contracts give currency/research points

### Contract Generation Rules
1. Only request items the player can currently craft (based on unlocked techs)
2. Quantities start small, grow exponentially
3. Each contract is "next-to-fulfillable" - pushable with current automation
4. Time pressure: soft deadlines that reduce rewards but don't fail
5. Multiple active contracts (3 at a time)

### Contract Types
- **Gate Contracts**: Required for ring progression, fixed requirements (see tree above)
- **Side Contracts**: Random, reward research points / currency
- **Rush Contracts**: Time-limited, bonus rewards

---

## Economy Balancing

### Tempo Goals
- Minutes 0-5: Manual crafting, first iron plates, coal power
- Minutes 5-15: First conveyor lines, automate iron/copper smelting
- Minutes 15-30: Press + Wire Drawer unlocked, tier 1 components flowing
- Minutes 30-60: First science packs, research lab, Ring 1 completion
- Minutes 60-90: Assembler Mk1, complex item chains, Ring 2
- Minutes 90+: Advanced circuits, processors, Ring 3

### Balance Levers
- Drill rate: items/min per drill
- Smelter speed: seconds per smelt
- Conveyor throughput: items/min per belt tier
- Recipe complexity: number of inputs per recipe
- Energy costs: gate progression by energy infrastructure
- Building costs: gate building placement by resource accumulation

### Formula for contract scaling
```
base_quantity = ring_number * 5 + 5
scaling = 1.5 ^ (contracts_completed_in_ring)
quantity = ceil(base_quantity * scaling)
```

---

## Hand Assembler Special Mechanics

1. **Input**: Items dropped from player inventory land on ground, get sucked in (existing ground_item → try_insert_item flow)
2. **Recipes**: All disabled (red) by default - player enables one at a time
3. **New UI button**: "Craft Once" button in recipe popup
   - Each click queues one craft cycle
   - Hold for 2 seconds = clear queue
   - Visual counter shows queued crafts
4. **Output**: Has output cell, items can flow to conveyors
5. **Can also be fully automated**: Player can enable recipes and connect conveyors normally

---

## Building Costs Implementation

1. Add `cost: Array[ItemStack]` to BuildingDef
2. On placement: check player inventory has all items
3. Deduct items on successful placement
4. On removal: optionally return partial resources (50%?)
5. UI: Show cost in building panel tooltip

---

## Sprite Plan

### Items (16x16 atlas)
- 8x5 grid = 40 slots (128x80 texture)
- Each item gets distinctive pixel art at 16x16
- Atlas compiled via Aseprite Lua script

### Buildings (animated spritesheets)
- Follow existing pattern: base + top layers, idle/windup/active/winddown tags
- Generated via Aseprite Lua scripts using building palette
- Each building has generate.lua in its sprites/ folder

### Item sprites should be:
- Recognizable at 12px (conveyor size) and 28px (inventory size)
- Distinct silhouettes for each category
- Consistent lighting (top-left light source)
- Raw ores: rough, chunky shapes
- Plates/ingots: flat rectangular shapes
- Components: distinctive shapes (gear = circle with teeth, wire = coil, etc.)
- Science packs: colored flasks/vials
