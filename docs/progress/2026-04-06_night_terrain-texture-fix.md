# 2026-04-06 Night — Terrain Texture Fix

**Duration**: ~0.5h (00:56 – 01:26 MSK)

## Work Done

### Bug Fix: Terrain textures completely invisible
- **Root cause**: `SurfaceTool.generate_normals()` in Godot uses `Plane()` constructor which defaults to clockwise winding convention. Our terrain quads were wound counter-clockwise, producing normals pointing **downward** (-Y). The shader's `v_norm.y > 0.5` check never passed, so all top faces fell through to the vertex-color fallback path. Textures were loaded correctly but never sampled.
- **Fix**: `generate_normals(true)` to flip normals, giving correct upward (+Y) for top faces.
- **Secondary fix**: `texture_scale` was 0.08 (each tile showed 8% of texture = solid color). User adjusted to 0.15 with full 1024px resolution (removed 64px downsample).

## Blockers
- None

## Next
- Continue with kanban board priorities
