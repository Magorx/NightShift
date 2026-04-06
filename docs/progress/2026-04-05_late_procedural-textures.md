# Procedural Textures Pipeline

**Date:** 2026-04-05 (late evening)
**Duration:** ~0.5h

## Work Done

### Split procedural textures into individual files
- Moved 6 existing textures from monolithic `procedural.py` into `tools/blender/materials/procedural/` package
- Each texture in its own file: `metal_scratched.py`, `riveted_plate.py`, `panel_seams.py`, `corrugated.py`, `rust_patchy.py`, `grime_gradient.py`
- Shared `_base.py` for `setup_material()` helper
- `__init__.py` re-exports (user trimmed to just `rocky_land` for now)

### Created rocky_land texture
- Layered Voronoi (large cracks + fine cracks) with Noise (surface variation)
- Chained Bump nodes for depth (Distance 0.05-0.15, Strength 1.0)
- Crack color at ~30% of base for strong contrast
- Height output node labeled for baking

### Created preview_material.py
- Generates `.blend` with sphere + cube + hidden bake plane
- Full node graph preserved for manual tweaking in Blender
- Auto-layout of shader nodes (BFS column arrangement)
- `--bake` flag bakes full PBR texture set (diffuse + normal + height)
- `--bake-size` controls resolution (default 1024)

### Updated bake.py for PBR texture sets
- `bake_texture_set()` — bakes diffuse, height (via Emission trick), and normal
- Normal map derived from height via Sobel filter (numpy) — Cycles NORMAL bake doesn't capture bump nodes
- Handles hidden bake objects (auto unhide/restore)

## Key Learnings
- Cycles NORMAL bake does NOT include bump node perturbations on flat geometry — derive normals from height map instead
- Procedural texture params need aggressive defaults: bump Distance 0.05+, crack color at 30% of base, bump Strength 1.0

## Next
- Create more textures as needed for terrain/buildings
- User can tweak parameters in Blender and feed values back
