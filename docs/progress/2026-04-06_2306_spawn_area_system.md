# Spawn Area System

**Date**: 2026-04-06 (evening)
**Duration**: 0.3h (23:06 - 23:26)

## Work Done

Replaced the simple ring-spawner with a full SpawnArea zone system for monster spawning.

### New Files
- `scripts/game/spawn_area.gd` — SpawnArea Node3D: shape (SQUARE 5x5 / LINE 8-cell), budget, monster pool, particle visuals
- `scripts/game/spawn_logic.gd` — SpawnLogic base class (RefCounted)
- `scripts/game/spawn_logic_one_by_one.gd` — trickle-spawns with random intervals, dumps remainder at 50% fight time
- `scripts/game/spawn_logic_all_together.gd` — batch-spawns in 2-5 waves within first 1/3 of fight

### Modified Files
- `monsters/monster_base.gd` — added `budget_cost = 2`
- `scripts/game/monster_spawner.gd` — fully rewritten: creates 2-6 SpawnAreas in a ring, distributes budget, alternates shapes and logics
- `tests/scenarios/scenarios/scn_fight_phase_end.gd` — added more buildings so base survives full fight timer

### Key Design Decisions
- Budget formula: `10 * round + 2 * round^1.5`
- Areas alternate square/line shapes and OneByOne/AllTogether logics
- Spawn areas have visible ground highlight + searing particles
- Monster pool uses GDScript classes (`.new()`) not PackedScenes since TendrilCrawler has no `.tscn`
- Line shape orients parallel to the base (perpendicular to direction toward factory center)

## Test Results
- `scn_monster_spawn`: PASS
- `scn_turret_kills_monster`: PASS
- `scn_fight_phase_end`: PASS (after fix)
- `scn_full_combat_loop`: PASS
- Parse check: clean

## Next
- Tune spawn area visuals in-game (visual mode)
- Add more monster types to the pool
- Add more spawn area shapes
