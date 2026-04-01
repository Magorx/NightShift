# Full Playthrough Analysis

Complete analysis of the player's progression from empty inventory through all ring-gate contracts.

## CRITICAL: Economy Blockers Found

The current economy has **three circular dependencies** that prevent the player from progressing. These must be fixed before a full playthrough is possible.

### Blocker 1: Science Pack 1 requires Gears, but Gears require Science Pack 1

- **Science Pack 1** (hand_assembler): 1 gear + 1 copper_wire
- **Gear** (press): 2 iron_plate → 1 gear
- **Press** is locked behind `tech_press`, which costs **10 science_pack_1**

There is no alternative way to obtain gears. The player is deadlocked.

**Suggested fix**: Add a hand_assembler recipe for gears (e.g. 4 iron_plate → 1 gear, slow craft time) so the player can bootstrap SP1 production before unlocking the Press.

### Blocker 2: Science Pack 2 requires Assembler, but Assembler requires Science Pack 2

- **Science Pack 2** (assembler): 1 circuit_board + 2 tube + 1 brick
- **Assembler Mk1** is locked behind `tech_assembler`, which costs **20 science_pack_1 + 20 science_pack_2**

SP2 can only be made in the Assembler, but the Assembler's research costs SP2. Deadlock.

**Suggested fix**: Change `tech_assembler` cost to only require science_pack_1 (e.g. 40 science_pack_1).

### Blocker 3: Science Pack 3 requires Assembler Mk2, but Assembler Mk2 requires Science Pack 3

- **Science Pack 3** (assembler_mk2): 1 motor + 1 advanced_circuit + 1 steel_frame
- **Assembler Mk2** is locked behind `tech_assembler_mk2`, which costs **50 SP1 + 50 SP2 + 50 science_pack_3**

Same pattern. SP3 can only be made in Assembler Mk2, but its research costs SP3.

**Suggested fix**: Change `tech_assembler_mk2` cost to only require SP1 + SP2 (e.g. 50 SP1 + 50 SP2).

### Bug: Missing unlock_tech on drill_mk2 and fuel_generator

Both `drill_mk2.tres` and `fuel_generator.tres` have no `unlock_tech` field set, despite having corresponding tech nodes (`tech_drill_mk2`, `tech_fuel_generator`) in the research tree. This means these buildings are available from game start, bypassing their intended research requirements.

**Fix**: Add `unlock_tech = &"tech_drill_mk2"` to `drill_mk2.tres` and `unlock_tech = &"tech_fuel_generator"` to `fuel_generator.tres`.

---

## Intended Playthrough (assuming blockers are fixed)

Below is the step-by-step path a player would follow. Each phase ends with unlocking a new tier of capability.

---

### Phase 0: Bootstrap (hand mining + hand assembler)

**Goal**: Get first iron plates and basic infrastructure.

**Available buildings** (no research needed): Conveyor Mk1, Drill Mk1, Smelter, Hand Assembler, Coal Burner, Energy Pole, Battery, Sink, Junction, Splitter, Tunnel.

| Step | Action | Details |
|------|--------|---------|
| 1 | Hand-mine iron ore | 3s per ore, 1.5 tile range. Mine ~25 iron ore |
| 2 | Hand-mine copper ore | Mine ~5 copper ore |
| 3 | Build Hand Assembler | Cost: 1 iron_ore + 1 copper_ore |
| 4 | Hand-smelt iron | Drop iron ore near assembler, queue "Hand Smelt Iron": 10 iron_ore → 3 iron_plate (5s). Do 3 batches → 9 iron_plate |
| 5 | Build first Smelter | Cost: 4 iron_plate. Place on/near iron ore deposit |
| 6 | Build first Drill on iron | Cost: 2 iron_plate. Outputs 1 iron_ore every 2s |
| 7 | Connect Drill → Smelter with Conveyors | Cost: 1 iron_plate per conveyor tile |
| 8 | Build second Drill on copper | Cost: 2 iron_plate |
| 9 | Build second Smelter for copper | Cost: 4 iron_plate. Recipe: 1 copper_ore → 1 copper_ring (3s) |

**Milestone**: Automated iron_plate and copper_ring production.

**Resource budget for Phase 0**: ~30 hand-mined iron ore, ~5 hand-mined copper ore.

---

### Phase 1: Copper Wire + Research Lab Unlock

**Goal**: Produce copper wire, unlock Research Lab.

| Step | Action | Details |
|------|--------|---------|
| 1 | Hand-assemble copper wire | Hand Assembler recipe: 3 copper_ring + 1 iron_plate → 3 copper_wire (4s). Need 2 batches for 6 wire |
| 2 | Research "Research Lab" | Instant research: consumes 10 iron_ore + 10 copper_ore from player inventory. Hand-mine these if needed |
| 3 | Build Research Lab | Cost: 8 iron_plate + 4 copper_wire |

**Milestone**: Research Lab built. Can now set research targets and deliver science packs.

---

### Phase 2: Science Pack 1 Production + Ring 1 Research

**Goal**: Produce SP1, research Press and Wire Drawer.

**(Requires Blocker 1 fix — needs a hand_assembler gear recipe)**

| Step | Action | Details |
|------|--------|---------|
| 1 | Hand-assemble gears | (NEW recipe needed) e.g. 4 iron_plate → 1 gear |
| 2 | Hand-assemble copper wire | 3 copper_ring + 1 iron_plate → 3 copper_wire |
| 3 | Hand-assemble Science Pack 1 | 1 gear + 1 copper_wire → 1 SP1 (6s). Need 10+ for first research |
| 4 | Deliver SP1 to Research Lab | Feed SP1 via conveyors into Research Lab |
| 5 | Research Press (10 SP1) | Unlocks: press_gear, press_tube, press_tin_can, press_steel_beam, press_glass_lens, press_pipe |
| 6 | Research Wire Drawer (10 SP1) | Unlocks: draw_copper_wire (1 ring → 2 wire), draw_gold_wire |
| 7 | Research Coke Oven (10 SP1) | Unlocks: make_coke (2 coal → 1 coke) |
| 8 | Research Conveyor Mk2 (15 SP1) | Faster belts (2x speed) |
| 9 | Research Cartography I (10 SP1) | Wider camera zoom |

**Build new infrastructure:**

| Building | Cost | Purpose |
|----------|------|---------|
| Press | 6 iron_plate | Stamp plates into gears, tubes. Replaces hand-assembler for gears |
| Wire Drawer | 4 iron_plate + 2 copper_ring | Draw wire efficiently: 1 copper_ring → 2 copper_wire (2s) |
| Coke Oven | 8 brick | Bake 2 coal → 1 coke (4s). Coke is fuel for Fuel Generator |

**New resource chains to set up:**
- Iron ore → Smelter → iron_plate → Press → gear
- Iron ore → Smelter → iron_plate → Press → tube
- Copper ore → Smelter → copper_ring → Wire Drawer → copper_wire
- Stone → Smelter → brick (2 stone → 1 brick, needs energy... wait, smelt_brick has energy_cost = 0)

**SP1 automation**: Drill (iron) → Smelter → Press (gear) + Drill (copper) → Smelter → Wire Drawer (wire) → Hand Assembler (SP1) → Research Lab

**Milestone**: Ring 1 complete. Press, Wire Drawer, Coke Oven operational.

---

### Phase 3: Gate Contract Ring 1

**Gate requirement**: Deliver 20 iron_plate + 10 copper_wire to Sink.

| Step | Action | Details |
|------|--------|---------|
| 1 | Route iron_plate to Sink | Already producing iron_plate. Route 20 to a Sink |
| 2 | Route copper_wire to Sink | Wire Drawer output → Sink. Need 10 copper_wire |

**Reward**: 1500 currency + 1000 research points. Unlocks Ring 1 side contracts.

**Milestone**: Ring 1 gate cleared. New side contracts available requesting: copper_ring, tin_plate, copper_wire, gear, tube, glass, brick.

---

### Phase 4: Energy Infrastructure + Steel Production

**Goal**: Set up energy grid for powered recipes.

Powered smelting recipes unlock major efficiency:
- Smelt Iron (Powered): 2 iron_ore → 2 iron_plate (2s, 50 energy) — faster than unpowered (3s)
- Smelt Steel: 2 iron_plate + 1 coal → 1 steel (5s, 80 energy)
- Smelt Gold: 1 gold_ore → 1 gold_ingot (4s, 50 energy)
- Smelt Glass: 2 quartz → 1 glass (4s, 40 energy)

| Step | Action | Details |
|------|--------|---------|
| 1 | Build Coal Burners | Cost: 4 iron_plate each. Burns 1 coal/4s = 25 energy/s. No research needed |
| 2 | Build Energy Poles | Cost: 2 iron_plate each. Relay energy between buildings |
| 3 | Set up coal supply | Drill on coal deposit → conveyors → Coal Burner |
| 4 | Expand to stone/quartz/tin deposits | New drills + smelters for brick, glass, tin_plate |
| 5 | Set up steel production | Smelter: 2 iron_plate + 1 coal → 1 steel (5s, 80 energy) |

**Energy budget**: Coal Burner produces 25 energy/s. Steel smelting needs 80 energy per craft (16 energy/s at full speed). One Coal Burner can sustain ~1.5 steel smelters.

**Milestone**: Energy grid running. Steel, glass, brick, tin_plate production online.

---

### Phase 5: Assembler Mk1 + Science Pack 2

**Goal**: Research Assembler, produce SP2 for Ring 2 techs.

**(Requires Blocker 2 fix — tech_assembler should cost only SP1)**

| Step | Action | Details |
|------|--------|---------|
| 1 | Research Assembler Mk1 | (Fixed cost, e.g. 40 SP1). Requires tech_press + tech_wire_drawer completed |
| 2 | Build Assembler Mk1 | Cost: 6 steel + 4 gear. 2x2 building, needs energy |
| 3 | Set up circuit board production | Assembler: 2 copper_wire + 1 glass → 1 circuit_board (4s, 30 energy) |
| 4 | Set up SP2 production | Assembler: 1 circuit_board + 2 tube + 1 brick → 1 SP2 (10s, 40 energy) |

**SP2 supply chain:**
```
copper_ore → copper_ring → copper_wire ──┐
quartz → glass ─────────────────────────┤→ circuit_board ──┐
                                                            ├→ Science Pack 2
iron_ore → iron_plate → tube (press) ─── × 2 ──────────┤
stone → brick ──────────────────────────────────────────┘
```

**Research with SP2:**

| Tech | Cost | Unlocks |
|------|------|---------|
| Fuel Generator | 20 SP1 + 20 SP2 | Burns coke for 33 energy/s (200 energy / 6s). Much more efficient than Coal Burner |
| Drill Mk2 | 15 SP1 + 15 SP2 | 2x extraction speed (1 ore/s vs 1 ore/2s). Cost: 4 steel |
| Cartography II | 15 SP1 + 15 SP2 | Even wider camera zoom |

**Build Fuel Generators**: Cost 6 steel + 4 pipe each. Need coke supply (Coke Oven: 2 coal → 1 coke).

**Milestone**: Ring 2 techs researched. High-energy infrastructure operational.

---

### Phase 6: Gate Contract Ring 2

**Gate requirement**: Deliver 10 motor + 10 circuit_board to Sink.

**Motor production chain:**
```
iron_ore → iron_plate → gear (press) ─── × 2 ──┐
copper_ore → copper_ring → copper_wire ── × 4 ──┤→ motor (assembler, 6s, 50 energy)
iron_ore → iron_plate → tube (press) ───────────┘
```

| Step | Action | Details |
|------|--------|---------|
| 1 | Automate motor production | Assembler: 2 gear + 4 copper_wire + 1 tube → 1 motor |
| 2 | Route motors + circuit boards to Sink | Need 10 of each |

**Reward**: 3000 currency + 2000 research points. Unlocks Ring 2 side contracts.

**Milestone**: Ring 2 gate cleared. Side contracts now request: circuit_board, motor, battery_cell, steel_frame, steel, steel_beam.

---

### Phase 7: Advanced Production + Science Pack 3

**Goal**: Research Assembler Mk2, produce SP3 for Ring 3 techs.

**(Requires Blocker 3 fix — tech_assembler_mk2 should cost only SP1 + SP2)**

First, set up advanced component production:

| Component | Recipe | Building | Inputs |
|-----------|--------|----------|--------|
| steel_beam | Press | press | 2 steel → 1 steel_beam (3s, 20 energy) |
| glass_lens | Press | press | 1 glass → 1 glass_lens (2s, 10 energy) |
| pipe | Press | press | 2 tube + 1 copper_ring → 1 pipe (3s, 20 energy) |
| gold_wire | Wire Drawer | wire_drawer | 1 gold_ingot → 2 gold_wire (3s, 30 energy) |
| tin_can | Press | press | 1 tin_plate → 1 tin_can (1.5s, 0 energy) |
| steel_frame | Assembler | assembler | 4 steel_beam → 1 steel_frame (4s, 30 energy) |
| battery_cell | Assembler | assembler | 1 tin_can + 1 sulfur + 2 copper_wire → 1 battery_cell (5s, 40 energy) |
| concrete | Assembler | assembler | 3 brick + 1 iron_plate → 1 concrete (4s, 20 energy) |

**Research Assembler Mk2**: (Fixed cost, e.g. 50 SP1 + 50 SP2). Requires tech_assembler.

**Build Assembler Mk2**: Cost: 4 steel_frame + 4 motor. 3x2 building.

**Assembler Mk2 products:**

| Product | Inputs | Time | Energy |
|---------|--------|------|--------|
| advanced_circuit | 1 circuit_board + 2 gold_wire + 1 glass_lens | 8s | 80 |
| processor | 2 advanced_circuit + 4 gold_wire | 10s | 120 |
| engine | 2 motor + 2 pipe + 1 steel_frame | 10s | 100 |
| robo_frame | 1 steel_frame + 2 motor + 1 advanced_circuit | 12s | 150 |
| science_pack_3 | 1 motor + 1 advanced_circuit + 1 steel_frame | 15s | 100 |

**SP3 supply chain:**
```
iron_ore ─→ iron_plate ─→ gear ─── × 2 ─┐
copper_ore → copper_ring → copper_wire × 4 ┤→ motor ──────────────┐
iron_ore → iron_plate → tube ────────────┘                       │
                                                                   ├→ SP3 (assembler_mk2)
copper_wire × 2 + glass → circuit_board ─┐                       │    15s, 100 energy
gold_ore → gold_ingot → gold_wire × 2 ──┤→ advanced_circuit ────┤
quartz → glass → glass_lens ────────────┘                       │
                                                                   │
iron_plate + coal → steel → steel_beam × 4 → steel_frame ───────┘
```

**Milestone**: SP3 production online.

---

### Phase 8: Gate Contract Ring 3 (Final)

**Gate requirement**: Deliver 5 processor + 5 robo_frame to Sink.

**Processor chain:**
```
copper_wire × 2 + glass → circuit_board ─┐
gold_ore → gold_ingot → gold_wire × 2 ──┤→ advanced_circuit × 2 ─┐
quartz → glass → glass_lens ────────────┘                         ├→ processor (10s, 120 energy)
gold_ore → gold_ingot → gold_wire × 4 ───────────────────────────┘
```

**Robo Frame chain:**
```
steel → steel_beam × 4 → steel_frame ─────────┐
gear × 2 + copper_wire × 4 + tube → motor × 2 ┤→ robo_frame (12s, 150 energy)
circuit_board + gold_wire × 2 + glass_lens     │
  → advanced_circuit ──────────────────────────┘
```

**Energy requirement**: Processor (120) + Robo Frame (150) = 270 energy per craft cycle. Multiple Fuel Generators needed (each produces 33 energy/s).

| Step | Action | Details |
|------|--------|---------|
| 1 | Set up processor production line | Need: advanced_circuit, gold_wire, Assembler Mk2 |
| 2 | Set up robo_frame production line | Need: steel_frame, motor, advanced_circuit, Assembler Mk2 |
| 3 | Scale energy production | Multiple Fuel Generators with coke supply |
| 4 | Deliver 5 processors + 5 robo_frames | Route to Sink |

**Reward**: 5000 currency + 4000 research points.

**Milestone**: Ring 3 gate cleared. Game "won."

---

## Complete Raw Resource Requirements

Every advanced item ultimately traces back to these 8 mined resources:

| Raw Resource | Used For |
|---|---|
| **Iron Ore** | iron_plate → gears, tubes, pipes, steel, steel_beam, steel_frame, buildings |
| **Copper Ore** | copper_ring → copper_wire → circuit_boards, motors, buildings |
| **Coal** | fuel (Coal Burner, Coke Oven), steel smelting |
| **Stone** | brick → concrete, SP2 |
| **Quartz** | glass → glass_lens, circuit_board |
| **Gold Ore** | gold_ingot → gold_wire → advanced_circuit, processor |
| **Tin Ore** | tin_plate → tin_can → battery_cell |
| **Sulfur** | battery_cell |

---

## Full Dependency Tree (item → required raw inputs)

```
science_pack_1 = gear + copper_wire
  gear = 2 iron_plate = 2 iron_ore
  copper_wire = 1 copper_ring = 1 copper_ore  (via wire_drawer)

science_pack_2 = circuit_board + 2 tube + brick
  circuit_board = 2 copper_wire + glass = 2 copper_ore + 2 quartz
  tube = 1 iron_plate = 1 iron_ore  (×2)
  brick = 2 stone

science_pack_3 = motor + advanced_circuit + steel_frame
  motor = 2 gear + 4 copper_wire + tube = 4+1 iron_ore + 4 copper_ore
  advanced_circuit = circuit_board + 2 gold_wire + glass_lens
    = 2 copper_ore + 2 quartz + 1 gold_ore + 1 quartz
  steel_frame = 4 steel_beam = 8 steel = 16 iron_ore + 8 coal (each needs energy)

processor = 2 advanced_circuit + 4 gold_wire
  = 4 copper_ore + 4 quartz + 2 gold_ore + 2 quartz + 2 gold_ore
  = 4 copper_ore + 6 quartz + 4 gold_ore

robo_frame = steel_frame + 2 motor + advanced_circuit
  = 16 iron_ore + 8 coal + (8+2 iron_ore + 8 copper_ore) + (2 copper_ore + 3 quartz + 1 gold_ore)
  = 26 iron_ore + 8 coal + 10 copper_ore + 3 quartz + 1 gold_ore
```

---

## Summary of Issues to Fix

| Issue | Severity | Fix |
|-------|----------|-----|
| SP1 needs gear, gear needs Press, Press needs SP1 | **BLOCKER** | Add hand_assembler recipe for gears |
| SP2 needs Assembler, Assembler research needs SP2 | **BLOCKER** | Remove SP2 from tech_assembler cost |
| SP3 needs Assembler Mk2, its research needs SP3 | **BLOCKER** | Remove SP3 from tech_assembler_mk2 cost |
| drill_mk2.tres missing unlock_tech | Bug | Add `unlock_tech = &"tech_drill_mk2"` |
| fuel_generator.tres missing unlock_tech | Bug | Add `unlock_tech = &"tech_fuel_generator"` |
