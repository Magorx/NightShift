# Session 23 — Ghost material null errors + RMB exit fix

**Date:** 2026-04-05 (afternoon)
**Duration:** ~0.5h (16:00 – 16:25)

## Work Done

### Bug fix: null material errors when deleting build ghosts
- Traced renderer errors (`material_casts_shadows: Parameter "material" is null`) to known Godot engine bug [godotengine/godot#85817](https://github.com/godotengine/godot/issues/85817)
- Root cause: `queue_free` on MeshInstance3D nodes with surface override materials causes the renderer to access freed material RIDs during teardown
- Fix: `_free_ghost()` helper clears all surface override materials before `queue_free`, preventing the renderer from hitting null references
- Also added null-material fallback in `_apply_ghost_transparency` for robustness

### Bug fix: ghost conveyors persist after RMB during drag
- RMB during drag only called `_cancel_drag()` but stayed in build mode, so `_update_ghosts` immediately recreated a cursor ghost
- Fix: RMB during drag now also calls `exit_building_mode()`, clearing ghosts in one press

### Maintenance: fix `_patch_import_loop` regex bug
- The regex in `export_helpers.py` only replaced the first line of multi-line `_subresources` blocks, leaving orphaned content in `.import` files
- Replaced with balanced-brace counting approach

## Files Changed
- `scripts/game/build_system.gd` — `_free_ghost`, `_clear_surface_overrides`, RMB exit during drag
- `tools/blender/export_helpers.py` — robust `_subresources` replacement

## Next
- Continue with kanban backlog (P3.1 RoundManager or BOT.1)
