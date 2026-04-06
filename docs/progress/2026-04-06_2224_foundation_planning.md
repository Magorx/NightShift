# Foundation Building Planning Session

- **Date**: 2026-04-06 evening (~22:10-22:24)
- **Duration**: ~0.25h
- **Type**: Planning only, no code changes

## Work Done

- Explored the full building system (BuildingRegistry, BuildSystem ghosts, destruction, monster targeting, save/load) to plan a "foundation" building (1x1x1 metal cube that other buildings stack on)
- User clarified: foundation stays visible when built upon (real vertical stacking, not hidden/replaced)
- User clarified: the game needs a real 3D world with 3D terrain (caves) and 3D building placement
- Concluded that hacking foundation onto the 2D grid is throwaway work -- 3D grid migration should come first
- Created 5 kanban cards in Post-M1 Backlog:
  - **3D.1** Migrate grid Vector2i -> Vector3i (3h)
  - **3D.2** Vertical placement UX (2h)
  - **3D.3** 3D terrain with caves (4h)
  - **3D.4** Pathfinding for vertical world (1.5h)
  - **FOUND.1** Foundation building (1h, depends on 3D.1 + 3D.2)
- Moved P5.x solved cards to BOARD_SOLVED.md

## Key Decision

Foundation requires 3D grid first. Critical path: 3D.1 -> 3D.2 -> FOUND.1 (~6h). Caves (3D.3) and 3D pathfinding (3D.4) are parallel/optional.

## Next

Continue with M1 backlog (P6.x) or start 3D world migration depending on priority.
