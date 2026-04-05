# Terrain Elevation — 2026-04-05 evening

**Duration**: 1h 40m (20:40 - 22:20)
**Card**: MAP.1

## Work done

Built noise-based 3D terrain elevation system from scratch:

- **Height generation**: Dual simplex noise in `WorldGenerator._generate_heights()`, quantized to 0.5-unit steps, flat near spawn, gradually varies outward
- **Visual rendering**: Rewrote `TerrainVisualManager` from MultiMesh flat planes to ArrayMesh with top faces + darkened grass side walls for depth
- **Collision**: HeightMapShape3D provides smooth ramps between height levels so CharacterBody3D walks naturally. Replaces the old infinite ground plane
- **Mouse raycasts**: All 3 raycasts (build system, player mining, inventory drop) now use physics raycast against terrain instead of Y=0 plane. Shared helpers in `GridUtils.raycast_mouse_to_grid/world`
- **Ghost previews**: Position at terrain height, not ground level
- **Step-climbing**: Player must jump to climb terrain steps (`MAX_STEP_UP = 0.25`), walking down is unrestricted. Bot auto-jumps via `_auto_jump_if_step()`
- **Integration**: Buildings, deposits, decorations, player spawn all at terrain height. Save/load serializes heights
- **Testing**: `scn_terrain_elevation` scenario with 16 assertions covering flat ground, step-block, auto-jump, plateau walk, building placement, production chain, walk down, high plateau, height deltas

## Files changed

- `scripts/autoload/game_manager.gd` — terrain_heights storage, get_terrain_height(), building Y
- `scripts/autoload/grid_utils.gd` — grid_to_world_elevated(), raycast_mouse_to_grid/world()
- `scripts/game/world_generator.gd` — _generate_heights() with dual simplex noise
- `scripts/game/terrain_visual_manager.gd` — Full rewrite: ArrayMesh + HeightMapShape3D
- `scripts/game/game_world.gd` — Height pipeline, terrain collision, elevated spawning
- `scripts/game/build_system.gd` — Terrain raycast + ghost elevation
- `scripts/autoload/save_manager.gd` — Height serialization
- `player/player.gd` — Step-block, terrain raycast for mining
- `scripts/ui/inventory_panel.gd` — Terrain raycast for drop
- `tests/scenarios/scenario_base.gd` — _rebuild_terrain()
- `tests/scenarios/scenario_map.gd` — set_height(), set_height_rect()
- `tests/scenarios/bot_controller.gd` — Terrain-aware teleport, auto-jump
- `tests/scenarios/scenarios/scn_terrain_elevation.gd` — New scenario

## Next

- Move MAP.1 to BOARD_SOLVED.md
- Continue with Phase 3 (RoundManager) or more map gen features
