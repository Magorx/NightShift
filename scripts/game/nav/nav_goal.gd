class_name NavGoal
extends RefCounted

## A named, multi-cell destination that NavLayer can generate flow fields for.
## Examples:
##   - "factory" = every cell adjacent to any building (many cells, many sectors)
##   - "chase"   = the single sub-cell the player is currently standing on
##
## A goal carries two pieces of cached data:
##   1. sector_next_hop — for every sector in the layer, the next sector to
##      head toward in order to reach the nearest goal sector. Computed once
##      per goal via multi-source BFS on the sector-adjacency graph.
##   2. sector_distance — hop distance from each sector to the nearest goal
##      sector (UNREACHABLE if no path). Useful for debug visualisation and
##      for deciding when to fall back to direct movement.
##
## Both caches are cleared via invalidate() when the goal targets change or
## when a dirty sector rebuild alters the portal graph.

const UNREACHABLE := 1000000

var key: StringName

## All target cells (GLOBAL sub-cell flat indices, row-major over sub_grid_size).
var target_cells_global: PackedInt32Array

## Sectors containing at least one target cell.
var target_sectors: PackedInt32Array

## Per-sector cached next hop (sector index to head toward). -1 = unreachable,
## self-index = this sector already contains the goal. Kept for debug / legacy
## fallback — actual flow-field seeding uses `sector_lower_neighbors`.
var sector_next_hop: PackedInt32Array

## Per-sector hop distance to nearest goal sector. UNREACHABLE for unreached.
var sector_distance: PackedInt32Array

## Per-sector list of neighbour sectors that are STRICTLY closer to the goal
## (i.e. their sector_distance is lower than this one's). When seeding a
## per-sector flow field for an intermediate sector, we seed from the portal
## cells to ALL of these neighbours — that way monsters in the sector naturally
## gravitate toward whichever exit is geometrically closer to their current
## position instead of being forced through a single arbitrary "next hop".
## Array[sector_idx] → PackedInt32Array of lower-distance neighbour indices.
var sector_lower_neighbors: Array[PackedInt32Array] = []

## Set when sector_next_hop / sector_distance need recomputing.
var needs_recompute: bool = true

func invalidate() -> void:
	needs_recompute = true
	sector_next_hop.clear()
	sector_distance.clear()
	sector_lower_neighbors.clear()

## True if this sector is one of the goal's target sectors (so a per-sector
## flow field should use the real target cells rather than portal cells).
func is_goal_sector(sector_idx: int) -> bool:
	for s in target_sectors:
		if s == sector_idx:
			return true
	return false
