class_name FlowField
extends RefCounted

## A per-sector flow field. Coordinates are LOCAL to the sector's sub-cell
## bounds: (0..size-1) on each axis. costs[] is Chebyshev distance in sub-cells
## (UNREACHABLE for cells never touched by the BFS). directions[] points along
## the gradient toward the sector's seed cells (which are either the actual
## goal target cells or the portal boundary toward the next sector on the
## hierarchical path, depending on whether this is a goal sector or an
## intermediate sector).
##
## Each sector stores its own small flow field (typically 32x32 = 1024 cells)
## instead of the old global 256x256 field, so the per-compute cost drops by
## ~64x and we only compute sectors that actually contain monsters.

const UNREACHABLE := 1000000

var size: int  ## sub-cells per axis (local to the owning sector)
var costs: PackedInt32Array
var directions: PackedVector2Array

func _init(p_size: int) -> void:
	size = p_size
	var total: int = p_size * p_size
	costs.resize(total)
	directions.resize(total)
	for i in total:
		costs[i] = UNREACHABLE

## Sample the direction at a sector-local cell (lx, ly). Returns Vector2.ZERO
## for out-of-bounds or unreached cells (caller should fall back to direct
## movement in that case).
func sample_local(lx: int, ly: int) -> Vector2:
	if lx < 0 or ly < 0 or lx >= size or ly >= size:
		return Vector2.ZERO
	return directions[ly * size + lx]

func cost_at_local(lx: int, ly: int) -> int:
	if lx < 0 or ly < 0 or lx >= size or ly >= size:
		return UNREACHABLE
	return costs[ly * size + lx]
