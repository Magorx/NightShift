# Session: VIS.1 Shadow Jitter Fix

**Date:** 2026-04-07
**Start:** 10:14
**End:** 11:00
**Elapsed:** ~0.75h (planned 0.5h)

## Work Done

Fixed terrain shadow jitter at day/night light angle transitions (VIS.1). First attempt was wrong; root cause required researching open Godot engine bugs before landing a working fix.

### Failed first attempt (reverted)

Tried `directional_shadow_mode = SHADOW_ORTHOGONAL`, `directional_shadow_max_distance = 120`, and dynamic `shadow_bias` ramp at low sun angles. User reported this made the shadows **much worse** and the jitter increased heavily. Reverted in full (`a2262a5`).

### Research

Investigated open Godot GitHub issues — the jitter is a known engine-level limitation, not a configuration mistake. Key findings:

- **[godotengine/godot#90175](https://github.com/godotengine/godot/issues/90175)** ("Jumping Shadows") — open. Rotating directional light re-orients the shadow frustum; shadow map aliasing occurs when voxels/edges align perfectly with shadow texels during the sweep. Suggested workaround: rotate the light on its local Z-axis (~22.5°) to desync texels from geometry.
- **[godot-proposals#13665](https://github.com/godotengine/godot-proposals/issues/13665)** — open. Stable cascaded shadow mapping (PSSM) isn't fully implemented; texel snapping fixes camera-movement jitter but not light-rotation jitter.
- **[godotengine/godot#84510](https://github.com/godotengine/godot/issues/84510)** — confirms Godot does implement shadow stabilization on the non-VR path, but only for camera movement, not light rotation.
- **[PR#97428](https://github.com/godotengine/godot/pull/97428)** — added `rendering/shadows/use_jitter` project setting targeted at 4.4+. Attempted to use it and `anti_aliasing/quality/use_taa`, but neither exists in 4.5.1's project settings interface — both were rejected/stripped. Reverted.

### Working fix

Applied two offsets to desynchronize shadow texels from world geometry axes:

1. **`SUN_ROLL = deg_to_rad(22.5)`** — rotate sun on local Z-axis (issue #90175 workaround). Applied as Z component of `sun_light.rotation`. Reduced worst-case shadow snapping during light rotation.
2. **`SUN_YAW = deg_to_rad(20.0)`** — yaw sun orbit 20° off world X-axis. Previously sun rose/set along a grid axis, making building shadows run perfectly parallel to conveyor/wall edges at certain times. 20° desynchronizes shadow angles from grid geometry.
3. **Shadow map size bumped to 8192** (user edit, `project.godot`) — doubles effective resolution per texel, reducing aliasing severity.

User confirmed the first rotation fixed the crawling; the yaw offset added on top as quality polish.

## Files Changed

- `scripts/game/day_night_visual.gd` — added `SUN_ROLL` + `SUN_YAW` constants, applied to `sun_light.rotation`
- `project.godot` — `[rendering]` section with `lights_and_shadows/directional_shadow/size=8192` (user edit)
- `docs/kanban/BOARD.md` — VIS.1 moved to Done

## Bugs/Fixes During Implementation

- First fix attempt with SHADOW_ORTHOGONAL made jitter **worse** — the single orthographic frustum stretches at low sun angles, covering a huge depth range that wastes resolution. Lesson: don't assume Godot shadow mode changes help without testing; research the engine's actual behavior first.
- Tried `rendering/shadows/use_jitter=1` and `anti_aliasing/quality/use_taa=true` in `project.godot` — neither is exposed in 4.5.1's project settings UI, both were stripped by the editor. Either the PR #97428 settings didn't land under those exact names or are only editor-UI configurable.

## Next Goals

- Continue with remaining backlog (MAP.1 minimap, UI.1 health bar, MON.0-3 monster variants) or move to Post-M1 work.

## Commits

- `47ecc8c` — Yaw sun 20° off grid axis to avoid shadow-edge alignment
- `a2f1571` — Rotate sun 22.5° on Z-axis to reduce shadow snapping (VIS.1)
- `33ca5e6` — Remove invalid TAA + shadow jitter project settings
- `6d721e3` — Enable TAA + shadow dithering jitter to fix VIS.1 shadow crawl (reverted approach)
- `a2262a5` — Revert "Fix terrain shadow jitter at day/night transitions"
- `6da8964` — Fix terrain shadow jitter at day/night transitions (reverted — made it worse)
