### Session 20 -- Save/Load Bugfixes
- **Date**: 2026-04-05
- **Hours**: ~0.25h (afternoon session, 13:34-13:50 MSK)
- **Work done**:
  - Fixed camera zoom restore: `_restore_camera` was double-multiplying ortho size (`z * 40.0` even for new saves where z is already ortho size), causing camera to always drift to max zoom out after loading
  - Fixed items disappearing on load: `PhysicsItem` rigid bodies (items on conveyors / in transit) were never serialized. Added `_serialize_physics_items()` / `_deserialize_physics_items()` — saves position + velocity, respawns via `PhysicsItem.spawn()` on load
- **Decisions made**:
  - Physics items save position and velocity (not despawn timer — they use the default 120s on reload)
- **Blockers**: None
- **Next session goal**: Playtest physics system visually, tune forces/speeds
