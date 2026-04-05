# Session: Smelter Remodel to 2x2 L-Shape

**Date:** 2026-04-05 (afternoon)
**Duration:** ~1h 20m (15:58–17:17)

## Work Done

Completely remodeled the smelter building from 2x3 (5 cells, center missing) to 2x2 L-shape (3 cells, bottom-right missing):

```
OLD:          NEW:
[X][X]        [X][X]
[X][ ]        [X][ ] ← output gap
[X][X]
```

### Scene (smelter.tscn)
- Removed bottom row cells (Cell_0_2, Cell_1_2)
- Fixed coordinate system: cells use center-aligned grid (0, 0.5, 0) not corner-aligned (0.5, 0.5, 0.5)
- Model positioned at (0.5, 0, 0.5) — bounding box center of the L
- Removed BuildAnchor (defaults to cell 0,0)
- 5 input zones with 0.8 collision boxes, positioned at cell edges
- Output zone at missing cell center (1, 0.2, 1)

### 3D Model (smelter_model.py)
- Full rewrite: L-shaped geometry using two-bar composition (top row + left extension)
- Crucible on cell (0,0), chimney on cell (0,1), output chute toward gap
- Gears, hoppers, pipes, control panel, bolts distributed across L
- All 4 animation states preserved (idle/windup/active/winddown)

### Simulations Updated
- sim_smelter_converter.gd — new cell positions, output gap at (15,11)
- sim_elemental_flow.gd — feed from rows 10+11 instead of 9+10

### Key Learning
Grid cells are **center-aligned**: `grid_to_world()` returns cell center, `world_to_grid()` rounds. Cell (X,Y) spans world [X-0.5, X+0.5]. Models at origin align with cell center. The initial 0.5-cell misalignment was caused by using corner-aligned positions.

## Blockers
- Physics item flow through smelter doesn't work in headless simulation (pre-existing issue — baseline drill→conveyor→sink also fails)

## Next
- Playtest smelter visually in-game to verify alignment and item flow
