class_name NavSector
extends RefCounted

## Metadata for one sector in a NavLayer. A sector is a fixed square region of
## sub-cells (typically 32x32) containing a local walkable mask, a list of
## portals on its boundaries, and dirty state for lazy rebuilds.
##
## The sector does not own any flow fields directly — those are cached on the
## NavLayer keyed by (goal, sector) so a single sector can serve many different
## goals without re-computation between unrelated queries.

var index: int                    ## sector's flat index in the layer
var sx: int                       ## sector grid x
var sy: int                       ## sector grid y
var sub_origin: Vector2i          ## top-left sub-cell of this sector (global sub-cell coords)
var sub_size: int                 ## sub-cells per axis (square)

## Local walkability mask, row-major (ly * sub_size + lx). 1 = walkable, 0 = blocked.
var walkable: PackedByteArray

## Set when a dirty rebuild is pending. NavLayer checks this before serving a query.
var dirty: bool = false

## Wall-clock timestamp (ms since engine start) when this sector's local
## walkable mask was last rebuilt — driven by dirty-sector flushes. Used by
## the debug renderer to flash sector borders YELLOW.
var last_walkable_rebuild_msec: int = 0

## Wall-clock timestamp when a per-sector flow field was last computed within
## this sector — driven by lazy on-demand BFS. Used by the debug renderer to
## flash sector borders CYAN, distinct from walkable rebuilds.
var last_flow_compute_msec: int = 0

func _init(p_index: int, p_sx: int, p_sy: int, p_sub_origin: Vector2i, p_sub_size: int) -> void:
	index = p_index
	sx = p_sx
	sy = p_sy
	sub_origin = p_sub_origin
	sub_size = p_sub_size
	walkable.resize(p_sub_size * p_sub_size)

func is_walkable_local(lx: int, ly: int) -> bool:
	if lx < 0 or ly < 0 or lx >= sub_size or ly >= sub_size:
		return false
	return walkable[ly * sub_size + lx] == 1

## True if the given GLOBAL sub-cell lies inside this sector.
func contains_global_sub(gx: int, gy: int) -> bool:
	var lx: int = gx - sub_origin.x
	var ly: int = gy - sub_origin.y
	return lx >= 0 and ly >= 0 and lx < sub_size and ly < sub_size

## Convert a global sub-cell position into a sector-local index
## (ly * sub_size + lx). Returns -1 if the cell is outside this sector.
func global_to_local_index(gx: int, gy: int) -> int:
	var lx: int = gx - sub_origin.x
	var ly: int = gy - sub_origin.y
	if lx < 0 or ly < 0 or lx >= sub_size or ly >= sub_size:
		return -1
	return ly * sub_size + lx
