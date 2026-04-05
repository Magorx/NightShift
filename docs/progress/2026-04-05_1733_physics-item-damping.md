# Physics Item Damping Fix

**Date**: 2026-04-05 (evening)
**Duration**: ~1.1h (16:22 - 17:33)

## Work Done

- **Fixed resource wiggling**: Added `angular_damp = 5.0` to `PhysicsItem` so items stop rolling/spinning when resting on the ground
- **Fixed convex hull collision scale**: The convex hull was being generated from `model.transform` which double-applied the 4x visual scale, making collision shapes oversized. Now uses an explicit `ITEM_MODEL_SCALE` transform so the hull matches the visual model at the correct size
- **Identified pre-existing transport regression**: The `sim_physics_transport` sink test fails (0 items consumed) due to building collision boxes changed to 3 units tall in `building_collision.gd` — items can't enter conveyor ForceZones. Not fixed this session.

## Files Changed

- `scripts/game/physics_item.gd` — angular_damp + convex hull scale fix

## Blockers

- `sim_physics_transport` sink test failing due to tall building collision boxes (separate issue)

## Next

- Fix building collision height blocking item transport
