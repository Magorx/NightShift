# Phase 4: Building Defense System

**Date:** 2026-04-06, evening (16:06 - 18:24 MSK)
**Duration:** 2.3h actual (5.75h estimated for P4 cards)

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

Additional time (~1.5h) spent on critic fixes, bug fixing, and model alignment iteration.

### New Systems
- **HealthComponent** (`scripts/game/health_component.gd`) -- general-purpose HP node with damage/heal/died signals, visual damage states, auto-destroys buildings at 0 HP. HP serialized in save_manager.
- **NightTransform** (`scripts/game/night_transform.gd`) -- calls `set_night_mode()` on all buildings via BuildingLogic virtual. Each building type handles its own transform.
- **AimComponent** (`scripts/game/aim_component.gd`) -- reusable aiming with smooth quaternion slerp rotation
- **TurretBehavior** (`scripts/game/turret_behavior.gd`) -- nearest-monster targeting with per-frame cached group scan, cooldown firing, projectile spawning
- **Projectile** (`scripts/game/projectile.gd`) -- Area3D that moves linearly, damages on contact with monsters

### 3D Models (Blender pipeline)
- Wall model (`buildings/conveyor/models/wall.glb`) -- straight conveyor night form
- Tower model (`buildings/conveyor/models/tower.glb`) -- turn conveyor night form
- Basic turret model (`buildings/drill/models/turret.glb`) -- drill night form
- Rocket turret model (`buildings/smelter/models/rocket_turret.glb`) -- smelter night form

### Architecture
- BuildingLogic base: `health`, `is_night_mode`, `set_night_mode()` virtual, `get_last_resource()`
- ConveyorBelt overrides `set_night_mode()`: saves day variant, swaps to wall/tower, enables force_collision
- ConverterLogic overrides `set_night_mode()`: creates TurretBehavior, swaps to rocket_turret model
- ExtractorLogic overrides `set_night_mode()`: creates TurretBehavior, swaps to turret model
- BuildingBase: trimesh collision from Model meshes (ConcavePolygonShape3D) instead of grid boxes

### Bug Fixes (post-implementation)
- Wall reinforcement bars protruding beyond bounds (removed)
- Drill turret model too small (housing 0.30→0.45, barrel radius 0.045→0.065)
- Smelter rocket turret displaced 0.5 cell (preserve day model transform on swap)
- Conveyor rotation lost after night restore (restore _current_variant tracking)
- Drill/smelter collision persisting from night (regenerate_collision on day restore)
- Night model origins centered at (-0.5,+0.5) instead of cell corner (shifted Blender roots)
- Building collision as uniform boxes instead of mesh-derived (trimesh from Model meshes)

### Verification
- Parse check: 0 errors
- Unit tests: 33/33 passed
- sim_night_transform: 26/26 assertions passed
- sim_physics_transport: passed

## Commits
15 commits (see git log 35fedce..HEAD)

## Blockers
None.

## Next
Phase 5 cards (P5.1-P5.6): Monster system -- Tendril Crawler, spawner, A* pathfinding, monster-building combat, fight end conditions.
