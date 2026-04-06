# 2026-04-06 15:29 — Terrain Fix + Day/Night Lighting System

**Duration**: ~1.25 hours (afternoon, 15:29–16:43)

## Work Done
- **Fixed terrain texture bleeding at wall corners**: `generate_normals()` was smoothing normals across shared vertex positions where top faces meet wall faces. Set explicit flat normals instead. 3-line change in `terrain_visual_manager.gd`.
- **Enabled ambient light**: `ambient_light_source` was set to 1 (Disabled), changed to 2 (Color).
- **Built sun/moon orbital lighting system**: Two DirectionalLight3Ds rotating in different orbital planes (moon tilted 40° off sun). Angle computed deterministically from phase progress — no frame-rate jitter. Speed curve: edges (10% each side) spin at 6x for intense sunrise/sunset, middle 80% normal.
- **ProceduralSkyMaterial**: Replaced flat Color background with Sky + ProceduralSkyMaterial. Sun/moon discs render automatically. Sky colors lerp between day/night palettes.
- **Removed screen flash**: Deleted PhaseFlash ColorRect and flash logic from HUD.
- **Shadow jitter**: Investigated ortho camera shadow texel snapping (known Godot issue). Added angle quantization (0.25° steps). Tried perspective camera but reverted — ortho is core to the isometric feel.

## Blockers
- Shadow jitter with ortho camera + rotating DirectionalLight3D is a known Godot limitation. Quantization helps but doesn't fully solve it. May need custom shadow approach or accept soft shadows.

## Next
- Continue with kanban board priorities
- Consider shadow quality improvements (shadow atlas size, blur settings)
