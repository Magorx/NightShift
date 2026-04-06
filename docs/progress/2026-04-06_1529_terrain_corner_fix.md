# 2026-04-06 15:29 — Terrain Corner Texture Fix

**Duration**: ~15 minutes (evening)

## Work Done
- **Fixed terrain texture bleeding at wall corners**: `generate_normals()` was smoothing normals across shared vertex positions where top faces meet wall faces. The averaged normal still had `y > 0.5`, causing the shader to incorrectly apply grass texture onto wall faces — most visible at corners where 3 faces share a vertex.
- **Solution**: Set explicit flat normals (`Vector3.UP` for tops, `Vector3(dx, 0, dz)` for walls) instead of relying on `generate_normals()`. 3-line change in `terrain_visual_manager.gd`.

## Next
- Continue with kanban board priorities
