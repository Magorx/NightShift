class_name NavPortal
extends RefCounted

## A connection between two adjacent sectors. Represents one contiguous run of
## sub-cells along the shared edge where BOTH sides are walkable — there can
## be multiple portals between the same sector pair if the boundary is broken
## up by walls/buildings.
##
## cells_a and cells_b store local (sector-relative) indices, so given a
## monster entering an intermediate sector, we can seed the per-sector BFS
## directly from these cells without any coordinate translation.

var sector_a: int                     ## index of the "A" sector
var sector_b: int                     ## index of the "B" sector
var cells_a: PackedInt32Array         ## local indices in sector A (sector A-relative)
var cells_b: PackedInt32Array         ## local indices in sector B (sector B-relative)

## Representative local cell on sector A's side (midpoint of the run). Handy
## for sector-level heuristics and debug visualisation.
var rep_a: int = -1
## Representative local cell on sector B's side.
var rep_b: int = -1

## Return the "other" sector of this portal relative to the given one.
## Returns -1 if sector_idx isn't a member of this portal.
func other_sector(sector_idx: int) -> int:
	if sector_idx == sector_a:
		return sector_b
	if sector_idx == sector_b:
		return sector_a
	return -1

## Return the local cell array on the given sector's side (or empty array).
func cells_for(sector_idx: int) -> PackedInt32Array:
	if sector_idx == sector_a:
		return cells_a
	if sector_idx == sector_b:
		return cells_b
	return PackedInt32Array()
