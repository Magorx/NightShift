# Phase 4: Building Defense System

**Date:** 2026-04-06, evening (16:06 - 17:13 MSK)
**Duration:** 1.1h actual (5.75h estimated for P4 cards)

## Work Done

### Phase 4 Cards (all 6 completed)

| Card | Task | Estimated | Actual |
|------|------|-----------|--------|
| P4.1 | General HP component | 0.5h | 0.1h |
| P4.2 | Night transform: conveyors become walls | 1h | 0.15h |
| P4.3 | Aiming system + turret behavior | 1.5h | 0.15h |
| P4.4 | Resource memory for buildings | 0.5h | 0.05h |
| P4.5 | Night transform 3D models | 2h | 0.2h |
| P4.6 | Sim test: transformation | 0.25h | 0.1h |

### New Systems
- **HealthComponent** (`scripts/game/health_component.gd`) -- general-purpose HP node with damage/heal/died signals, visual damage states, auto-destroys buildings at 0 HP
- **NightTransform** (`scripts/game/night_transform.gd`) -- iterates all buildings on phase change: conveyors stop + swap to wall/tower models, converters activate turret behavior
- **AimComponent** (`scripts/game/aim_component.gd`) -- reusable aiming with smooth rotation via quaternion slerp
- **TurretBehavior** (`scripts/game/turret_behavior.gd`) -- nearest-monster targeting, cooldown firing, projectile spawning
- **Projectile** (`scripts/game/projectile.gd`) -- Area3D that moves linearly, damages on contact with monsters

### 3D Models (Blender pipeline)
- Wall model (`buildings/conveyor/models/wall.glb`) -- straight conveyor night form
- Tower model (`buildings/conveyor/models/tower.glb`) -- turn conveyor night form  
- Basic turret model (`buildings/drill/models/turret.glb`) -- drill night form
- Rocket turret model (`buildings/smelter/models/rocket_turret.glb`) -- smelter night form

### Architecture
- BuildingLogic base class extended with `health`, `is_night_mode`, `get_last_resource()`
- ConveyorBelt gets night form state + model swap support
- ConverterLogic gets night mode with auto-created TurretBehavior child
- P4.2 and P4.3 built in parallel worktree agents, P4.5 art in separate worktree

### Verification
- Parse check: 0 errors
- Unit tests: 33/33 passed
- sim_night_transform: 26/26 assertions passed (HP, night mode, turret, restore, destroy)
- sim_physics_transport: passed
- sim_player: passed
- sim_round_cycle: passed (2 pre-existing timer value warnings)

## Commits
1. `5ce86fe` -- Add HealthComponent and resource memory interface (P4.1 + P4.4)
2. `185a928` -- Add is_night_mode flag to BuildingLogic base class
3. `d8d3ee3` -- Add night transform system (P4.2)
4. `7df6c1b` -- Add aiming system and turret behavior (P4.3)
5. `c88e4e5` -- Wire night transform to converter turret system (P4.2+P4.3 integration)
6. `0e2caee` -- Add night transform simulation test (P4.6)
7. `4ff0d50` -- Add night transform 3D models (P4.5)
8. `aca372f` -- Wire night model swapping

## Blockers
None.

## Next
Phase 5 cards (P5.1-P5.6): Monster system -- Tendril Crawler, spawner, A* pathfinding, monster-building combat, fight end conditions.
