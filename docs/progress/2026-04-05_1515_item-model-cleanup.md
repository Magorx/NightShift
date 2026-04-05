# Session: Item Model Cleanup

**Date**: 2026-04-05, 15:15–15:52 MSK (afternoon)
**Duration**: 0.6h

## Work Done

- **Unified item model creation**: Consolidated 3 duplicate load/cache/scale/animate/fallback paths (`PhysicsItem._add_model`, `ItemVisualManager.create_item_visual`, `GroundItem._add_item_model`) into a single `PhysicsItem.create_item_model()` static function
- **Model-derived collision shapes**: Replaced hardcoded `SphereShape3D(0.12)` on PhysicsItem with `ConvexPolygonShape3D` built from actual mesh vertices — collision hulls now match the model silhouette
- **Single scale constant**: Added `PhysicsItem.ITEM_MODEL_SCALE` as the one knob for item model scale, referenced by all three consumers (user set to 4.0)
- **Random spawn rotation**: Items now spawn with random rotation on all three axes
- **Removed idle animation on spawn**: Items are static by default

## Files Changed

- `scripts/game/physics_item.gd` — `create_item_model()`, `_gather_vertices()`, convex collision, random rotation on spawn
- `scripts/game/item_visual_manager.gd` — gutted duplicate cache/loading, delegates to `PhysicsItem.create_item_model()`
- `player/ground_item.gd` — gutted duplicate loading, delegates to `PhysicsItem.create_item_model()`

## Next

- Phase 3 (RoundManager) or further 3D polish
