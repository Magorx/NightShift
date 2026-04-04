# Night Shift -- Game Design Document

## One-Line Pitch

**"Every belt is a wall. Every machine is a turret. Build smart or die weird."**

## Concept

Session-based factory roguelite. 30-minute runs. Build a factory during day phases, survive psychedelic monster attacks at night. Your factory IS your defense -- conveyors become walls, converters become turrets based on what they processed. The winning feeling is looking at your battered, scarred, still-running factory and feeling pride.

## Core Loop

```
BUILD (2-3 min) -> FIGHT (1-2 min) -> SHOP (30s) -> BUILD -> ... -> FINAL WAVE -> WIN/LOSE
```

- **Build phase**: Place extractors, conveyors, converters. Process resources. Short enough that every placement matters.
- **Fight phase**: Factory transforms. Conveyors become walls, converters become elemental turrets. Psychedelic monsters attack with signature destruction patterns. Player controls character to assist defense.
- **Shop phase**: Buy random building offerings, repair materials. Spend currency earned from kills/production.
- **Escalation**: Each round, monsters get nastier. By round 7-8, the base is scarred, patched, and barely holding -- but it's YOUR scarred, patched base.

## Target Session: 5-8 rounds, ~30 minutes total

| Round | Build Time | Fight Time | Intensity |
|-------|-----------|------------|-----------|
| 1-2   | ~3 min    | ~1 min     | Tutorial-level |
| 3-4   | ~2.5 min  | ~1.5 min   | Core challenge |
| 5-6   | ~2 min    | ~2 min     | High pressure |
| 7-8   | ~1.5 min  | ~2.5 min   | Desperate survival |

Build time shrinks, fight time grows. Tension ramps naturally.

## Elemental Resource System

6 base resources with elemental identities. Each run, the map spawns 5-6 deposits but the player can realistically reach 3-4 given defensive positioning.

| Resource | Element | Color | Turret Effect |
|----------|---------|-------|---------------|
| Pyromite | Fire | Orange/red | Area burn damage |
| Crystalline | Ice | Blue/cyan | Slow + freeze |
| Biovine | Poison | Green | DOT + area denial |
| Voltite | Lightning | Yellow/purple | Chain damage |
| Umbrite | Shadow | Dark purple | Confusion + misdirection |
| Resonite | Force | White/silver | Knockback + stun |

### Combinations

Mixing 2 resources in a converter creates a combined effect:

| Input A | Input B | Result | Effect |
|---------|---------|--------|--------|
| Pyromite | Crystalline | Steam Burst | Explosion + slow |
| Pyromite | Biovine | Napalm | Burning DOT pools |
| Pyromite | Voltite | Plasma | Piercing high damage |
| Crystalline | Biovine | Toxic Ice | Freeze + poison cloud |
| Crystalline | Voltite | Cryo Shock | Shatter (instakill frozen) |
| Biovine | Voltite | Nerve Storm | Chain poison |
| ... | Umbrite | ... | Adds confusion/misdirection |
| ... | Resonite | ... | Adds knockback/stun |

15 total pairwise combinations from 6 resources. Each meaningfully different.

## Factory -> Defense Transformation

When night falls, buildings transform:

| Day Form | Night Form | Behavior |
|----------|-----------|----------|
| Conveyor belt | Wall segment | Blocks pathing, has HP |
| Conveyor Mk2/3 | Reinforced wall | More HP |
| Extractor/Drill | Resource cache | Inert, high HP (protect it) |
| Smelter/Converter | Elemental turret | Fires based on last processed resource |
| Splitter | Multi-target turret | Splits fire to multiple enemies |
| Tunnel/Pipeline | Underground passage | Monsters can't cross, player can use |

The player's factory layout IS the defense layout. A winding conveyor path is also a maze for monsters.

## Monster Design (Psychedelic, Not Horror)

Surreal, colorful, unsettling but not scary. Pulsating geometry, impossible anatomy, vibrant distortion.

### Base Types

| Monster | Destruction Pattern | Counter |
|---------|-------------------|---------|
| Tendril Crawler | Rips a LINE of buildings (follows conveyor paths) | Break conveyor lines into segments |
| Acid Bloom | AREA corrosion, degrades buildings over time | High burst damage to kill fast |
| Phase Shifter | TELEPORTS a building to random location | Walls/mazes (can't phase through walls) |

### Boss Mechanic (Rare)
**Possession** -- a boss-type monster possesses one of your converters, turning its turret against your other buildings. Player must destroy or "exorcise" it.

## Building Damage System

Damage is **persistent but workable**, not binary destruction:

- Buildings have HP
- At 75% HP: visual cracks, still fully functional
- At 50% HP: visible scarring, reduced output (turret fires slower, conveyor moves items slower)
- At 25% HP: heavy damage visuals, severely reduced function
- At 0%: destroyed, leaves rubble (can be rebuilt on)

Repair costs resources in the shop phase. The player constantly decides: repair or expand?

## Map

- Fixed 128x128 grid
- Procedural deposit placement: 5-6 elemental deposits clustered in groups
- Player spawns center-ish
- Deposits at varying distances: 2 close (easy to reach), 2-3 medium, 1-2 far (risky to expand to)
- Terrain features: rocks (natural walls), chasms (impassable), chokepoints

## Player Character

- Moves around the map during both phases
- During build: places buildings, carries resources (8-slot inventory)
- During fight: can perform light actions (manual repair? emergency item use?) but mostly watches the defense play out
- If player dies: run over. Survives across rounds.
- Movement speed matters: reaching far deposits means less build time at base

## Inventory

8 slots total, shared between:
- Building types (bought from shop)
- Raw resources (carried manually for emergency use)

Constraint forces choices: carry more building variety or keep repair materials?

## Shop

Appears between rounds. Offers:
- 3-4 random buildings (from unlocked pool)
- Repair kits
- Possibly: one-time-use power-ups for the next night
- Currency earned from: monster kills, production output, round survival bonus

## Meta-Progression

**Planet screen** after clicking Play:
- 7 biomes arranged on a planet map
- Each biome has unique resource distribution + specific mechanic
- Biomes unlock sequentially (complete tasks to open next)
- Each biome has 3-5 tasks of increasing difficulty

**Persistent unlocks:**
- New resource types (start with 4, unlock up to 6)
- New converter/building types
- New biome access
- Cosmetic: factory skins, player skins
- NO stat boosts -- skill, not numbers

## Technical Foundation (from Factor)

### Reuse directly:
- Pull-based item transfer system (GameManager.pull_item)
- Grid placement + BuildSystem
- ConveyorSystem + ConveyorVisualManager
- ItemVisualManager (MultiMesh rendering)
- BuildingLogic base class + building organization
- BuildingTickSystem
- Data-driven BuildingDef / ItemDef / RecipeDef resources
- Save system structure

### Remove:
- ResearchManager + tech tree
- EnergySystem + EnergyNetwork
- ContractManager
- Complex UI (ResearchPanel, RecipeBrowser, most of HUD)
- AccountManager (replace with simpler progression save)

### Build new:
- RoundManager (build/fight/shop cycle, timer, phase transitions)
- NightTransform (building -> defense conversion logic)
- MonsterSystem (spawning, AI, pathfinding, destruction patterns)
- DamageSystem (building HP, degradation, visual scarring)
- ShopSystem (random offerings, currency, purchasing)
- ElementSystem (resource identities, combination logic)
- MetaProgression (planet screen, biome unlocks, persistent saves)
- New WorldGenerator (128x128, elemental deposits, terrain features)
- Simplified HUD + Inventory (8 slots)

## Art Direction

- Pixel art, same fidelity as Factor (16x16 items, tile-based buildings)
- Day phase: clean, industrial, warm lighting
- Night phase: psychedelic shift -- colors distort, background pulses, buildings glow with elemental energy
- Monsters: vibrant, surreal, pulsating geometry. NOT horror -- more like a fever dream
- Damage: scorch marks, slime trails, cracks, warped metal. Visual storytelling of what happened

## Audio Direction

- Day: calm industrial ambience, rhythmic machine sounds
- Night: tension builds, bass drops, distorted sounds
- Transition: a "shift change" sound effect -- factory powering down, defense powering up
- Monsters: each type has a distinct audio signature (player learns to identify threats by sound)

## Reference Games

| Game | What to learn from it |
|------|----------------------|
| Mindustry | Factory + defense integration |
| Dome Keeper | Session-based dig/defend roguelite pacing |
| Thronefall | Build-by-day / defend-by-night minimalism |
| Balatro | "Number go up" satisfaction, roguelite variety |
| Vampire Survivors | Accessible, addictive, streamer-friendly |
| Noita | Psychedelic visuals, physics-based destruction |
| Tower Factory | Direct competitor -- study what it does and doesn't do well |
