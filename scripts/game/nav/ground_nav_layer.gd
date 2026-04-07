class_name GroundNavLayer
extends NavLayer

## Ground-walking monsters: cannot enter walls or buildings, and cannot step
## up or down a terrain cliff larger than STEP_HEIGHT. The physics layer still
## provides a safety backstop (terrain collision blocks them), but the nav
## layer now routes AROUND cliffs so monsters don't waste time head-butting
## elevated walls.
##
## The edge constraint hooks into both:
##   - portal detection (in NavLayer._detect_portals_between) so portals
##     don't form across cliff edges
##   - per-sector BFS (in NavLayer._compute_sector_flow_field) so the flow
##     field within a sector bends around elevation changes
##
## When you add "jumping ground" monsters, subclass this and raise STEP_HEIGHT
## or override _can_traverse_edge() entirely. The sector/portal/BFS machinery
## in NavLayer is reusable as-is.

## Maximum vertical step a ground monster can traverse, in world units. Values
## above this are treated as impassable cliffs. The terrain mesh uses 0.5 and
## 1.0 increments, so 0.3 cleanly rejects any stepping-up.
const STEP_HEIGHT := 0.3

func _init() -> void:
	super(&"ground")

func _compute_sub_walkable_raw(gx: int, gy: int) -> bool:
	if gx < 0 or gy < 0 or gx >= sub_grid_size or gy >= sub_grid_size:
		return false
	@warning_ignore("integer_division")
	var grid_pos := Vector2i(gx / SUB_CELL, gy / SUB_CELL)
	if MapManager.walls.has(grid_pos):
		return false
	if BuildingRegistry.get_building_at(grid_pos) != null:
		return false
	return true

## Reject edges between cells whose terrain height differs by more than
## STEP_HEIGHT. Sub-cells inside the same tile share a height, so only
## boundary crossings (between different game tiles) can fail this check.
## Both directions (up and down) are rejected because ground monsters can't
## safely drop off a cliff either — the terrain collision mesh has walls on
## both sides of the step.
func _can_traverse_edge(from_gx: int, from_gy: int, to_gx: int, to_gy: int) -> bool:
	@warning_ignore("integer_division")
	var from_tile := Vector2i(from_gx / SUB_CELL, from_gy / SUB_CELL)
	@warning_ignore("integer_division")
	var to_tile := Vector2i(to_gx / SUB_CELL, to_gy / SUB_CELL)
	if from_tile == to_tile:
		return true
	var h_from: float = MapManager.get_terrain_height(from_tile)
	var h_to: float = MapManager.get_terrain_height(to_tile)
	return absf(h_to - h_from) <= STEP_HEIGHT
