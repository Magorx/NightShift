# GameManager Decomposition

**Date**: 2026-04-06 (evening)
**Duration**: ~30 minutes
**Type**: Architecture refactoring

## Work Done

Decomposed the 543-line GameManager god object into 4 focused subsystems + thin facade:

| System | Lines | Responsibility |
|--------|-------|---------------|
| **MapManager** | 80 | Terrain data, deposits, walls, world seed/size |
| **ItemRegistry** | 95 | Item definitions, icons, atlas, visual acquire/release |
| **BuildingRegistry** | 250 | Building defs, recipes, placement/removal, queries |
| **EconomyTracker** | 25 | Currency, delivery tracking, creative mode |
| **GameManager** (facade) | 42 | Scene-layer refs (player, layers), hotkeys, clear_all() |

### Migration scope
- 49 files changed, 867 insertions, 824 deletions
- ~40 caller files updated across production code, UI, buildings, and tests
- SaveManager fully rewritten to serialize/deserialize through correct subsystems
- Test infrastructure (simulation_base, scenario_base, scenario_map) updated

### Verification
- Parse check: 0 errors
- Unit tests: 33/33 passed
- Simulations: all pass (conveyor, drill, physics, round cycle, player, smelter)
- Scenario: scn_drill_to_sink — 3/3 assertions passed

## Blockers
None.

## Next
- Continue with Night Shift feature development on the now-cleaner architecture
