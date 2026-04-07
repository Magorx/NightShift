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

## Maximum vertical step a ground monster can CLIMB, in world units. Descent
## is always allowed. The terrain mesh uses 0.5 increments (heights 0, 0.5,
## 1.0, 1.5), so 0.6 lets monsters step up one level at a time but still
## refuses a double-height jump from ground straight to a 1.0+ plateau —
## those need an intermediate 0.5 stepping stone, which is exactly what a
## reasonable map generator would place.
const STEP_HEIGHT := 0.6

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

## Reject ASCENT edges whose terrain height increase exceeds STEP_HEIGHT.
## Descent is always allowed — gravity takes care of it and the terrain
## collision mesh doesn't prevent walking off a ledge. If we rejected
## descent too, monsters spawned on elevated plateaus would get stuck at
## the top of the first cliff and never reach buildings on lower ground.
## Sub-cells inside the same tile share a height, so only crossings
## between different game tiles can fail this check.
func _can_traverse_edge(from_gx: int, from_gy: int, to_gx: int, to_gy: int) -> bool:
	@warning_ignore("integer_division")
	var from_tile := Vector2i(from_gx / SUB_CELL, from_gy / SUB_CELL)
	@warning_ignore("integer_division")
	var to_tile := Vector2i(to_gx / SUB_CELL, to_gy / SUB_CELL)
	if from_tile == to_tile:
		return true
	var h_from: float = MapManager.get_terrain_height(from_tile)
	var h_to: float = MapManager.get_terrain_height(to_tile)
	# Allow descent (h_to < h_from); reject climbs > STEP_HEIGHT.
	return (h_to - h_from) <= STEP_HEIGHT
