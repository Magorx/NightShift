# Player Collision Fix

**Date**: 2026-04-05 evening
**Duration**: ~30 min

## Work Done

- **Player now collides with resources (PhysicsItems)**: Added item collision layer (bit 8) to player's collision mask in both `player.gd` and `player.tscn`
- **Player now collides with conveyors**: Removed the `is_ground_level` skip in `building_base.gd` so all buildings (including conveyors, junctions, splitters) generate trimesh collision from their 3D models
- **Unified conveyor push system**: Removed the player's separate grid-based `_handle_conveyor_push()` method. Instead, the conveyor's ForceZone Area3D now detects the player (mask includes player layer 1) and sets `player.conveyor_push` directly -- same physics-based approach used for items
- Updated sim_player test assertions to match new collision mask

## Files Changed

- `buildings/shared/building_base.gd` -- removed is_ground_level collision skip
- `buildings/conveyor/conveyor.gd` -- ForceZone now pushes Player via `conveyor_push`
- `buildings/conveyor/conveyor.tscn` -- ForceZone collision_mask 8 -> 9 (items + player)
- `player/player.gd` -- added item layer to mask, removed `_handle_conveyor_push()`, added `conveyor_push` property
- `player/player.tscn` -- collision_mask 6 -> 14
- `tests/simulation/sim_player.gd` -- updated collision mask assertions

## Next

- Continue with Phase 3 (RoundManager) or other backlog items
